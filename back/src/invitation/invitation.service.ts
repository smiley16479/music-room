import {
  Injectable,
  NotFoundException,
  BadRequestException,
  ForbiddenException,
  ConflictException,
} from '@nestjs/common';
import { InjectRepository } from '@nestjs/typeorm';
import { Repository, In, LessThan } from 'typeorm';
import { Cron, CronExpression } from '@nestjs/schedule';

import { 
  Invitation, 
  InvitationType, 
  InvitationStatus 
} from 'src/invitation/entities/invitation.entity';
import { User } from 'src/user/entities/user.entity';
import { Event } from 'src/event/entities/event.entity';
import { EventParticipantService } from '../event/event-participant.service';
import { ParticipantRole } from '../event/entities/event-participant.entity';

import { CreateInvitationDto } from './dto/create-invitation.dto';
import { RespondInvitationDto } from './dto/respond-invitation.dto';
import { PaginationDto } from '../common/dto/pagination.dto';

import { EmailService } from '../email/email.service';

export interface InvitationWithDetails extends Invitation {
  inviter: User;
  invitee: User;
  event?: Event;
}

export interface InvitationStats {
  total: number;
  pending: number;
  accepted: number;
  declined: number;
  expired: number;
  byType: {
    event: number;
    playlist: number;
    friend: number;
  };
}

@Injectable()
export class InvitationService {
  constructor(
    @InjectRepository(Invitation)
    private readonly invitationRepository: Repository<Invitation>,
    @InjectRepository(User)
    private readonly userRepository: Repository<User>,
    @InjectRepository(Event)
    private readonly eventRepository: Repository<Event>,
    private readonly emailService: EmailService,
    private readonly eventParticipantService: EventParticipantService,
  ) {}

  // Core CRUD Operations
  async create(createInvitationDto: CreateInvitationDto, inviterId: string): Promise<InvitationWithDetails> {
    const { inviteeId, type, eventId, playlistId, message, expiresAt } = createInvitationDto;

    // Get inviter
    const inviter = await this.userRepository.findOne({ where: { id: inviterId } });
    if (!inviter) {
      throw new NotFoundException('Inviter not found');
    }

    // Get invitee
    const invitee = await this.userRepository.findOne({ where: { id: inviteeId } });
    if (!invitee) {
      throw new NotFoundException('Invitee not found');
    }

    // Cannot invite yourself
    if (inviterId === inviteeId) {
      throw new BadRequestException('Cannot invite yourself');
    }

    // Validate and check permissions based on type
    await this.validateInvitationPermissions(type, inviterId, eventId, playlistId);

    // For playlist invitations, playlistId is now an eventId (Event IS Playlist when type=playlist)
    let finalEventId = eventId;
    if (type === InvitationType.PLAYLIST && playlistId) {
      // playlistId is actually an eventId now
      finalEventId = playlistId;
    }

    // Check for existing invitation
    const existingInvitation = await this.findExistingInvitation(
      inviterId, inviteeId, type, finalEventId, playlistId
    );

    if (existingInvitation) {
      if (existingInvitation.status === InvitationStatus.PENDING) {
        throw new ConflictException('Invitation already exists');
      }
      
      // If previous invitation was declined/expired, we can create a new one
      if (existingInvitation.status !== InvitationStatus.ACCEPTED) {
        // Update existing invitation instead of creating new one
        existingInvitation.status = InvitationStatus.PENDING;
        existingInvitation.message = message;
        existingInvitation.expiresAt = expiresAt ? new Date(expiresAt) : this.getDefaultExpiration(type);
        
        const updatedInvitation = await this.invitationRepository.save(existingInvitation);
        await this.sendInvitationEmail(updatedInvitation, inviter, invitee);
        
        return this.findByIdWithDetails(updatedInvitation.id);
      }
    }

    // Set default expiration if not provided
    const defaultExpiresAt = expiresAt ? new Date(expiresAt) : this.getDefaultExpiration(type);

    // Create invitation
    const invitation = this.invitationRepository.create({
      inviterId,
      inviteeId,
      type,
      eventId: finalEventId,
      message,
      status: InvitationStatus.PENDING,
      expiresAt: defaultExpiresAt,
    });

    const savedInvitation = await this.invitationRepository.save(invitation);

    // Send email notification
    await this.sendInvitationEmail(savedInvitation, inviter, invitee);

    return this.findByIdWithDetails(savedInvitation.id);
  }

  async findAll(paginationDto: PaginationDto, userId?: string) {
    const { page, limit, skip } = paginationDto;

    let queryBuilder = this.invitationRepository.createQueryBuilder('invitation')
      .leftJoinAndSelect('invitation.inviter', 'inviter')
      .leftJoinAndSelect('invitation.invitee', 'invitee')
      .leftJoinAndSelect('invitation.event', 'event');

    if (userId) {
      queryBuilder = queryBuilder.where(
        'invitation.inviterId = :userId OR invitation.inviteeId = :userId',
        { userId }
      );
    }

    const [invitations, total] = await queryBuilder
      .orderBy('invitation.createdAt', 'DESC')
      .skip(skip)
      .take(limit)
      .getManyAndCount();

    const totalPages = Math.ceil(total / limit);

    return {
      success: true,
      data: invitations as InvitationWithDetails[],
      pagination: {
        page,
        limit,
        total,
        totalPages,
        hasNext: page < totalPages,
        hasPrev: page > 1,
      },
      timestamp: new Date().toISOString(),
    };
  }

  async findByIdWithDetails(id: string): Promise<InvitationWithDetails> {
    const invitation = await this.invitationRepository.findOne({
      where: { id },
      relations: ['inviter', 'invitee', 'event'],
    });

    if (!invitation) {
      throw new NotFoundException('Invitation not found');
    }

    return invitation as InvitationWithDetails;
  }

  async findById(id: string, userId?: string): Promise<InvitationWithDetails> {
    const invitation = await this.findByIdWithDetails(id);

    // Check if user has access to this invitation
    if (userId && invitation.inviterId !== userId && invitation.inviteeId !== userId) {
      throw new ForbiddenException('You do not have access to this invitation');
    }

    return invitation;
  }

  // User-specific invitation queries
  async getReceivedInvitations(
    userId: string, 
    status?: InvitationStatus, 
    type?: InvitationType,
    paginationDto?: PaginationDto
  ) {
    const { page = 1, limit = 20, skip = 0 } = paginationDto || {};

    let queryBuilder = this.invitationRepository.createQueryBuilder('invitation')
      .leftJoinAndSelect('invitation.inviter', 'inviter')
      .leftJoinAndSelect('invitation.event', 'event')
      .where('invitation.inviteeId = :userId', { userId });

    if (status) {
      queryBuilder = queryBuilder.andWhere('invitation.status = :status', { status });
    }

    if (type) {
      queryBuilder = queryBuilder.andWhere('invitation.type = :type', { type });
    }

    const [invitations, total] = await queryBuilder
      .orderBy('invitation.createdAt', 'DESC')
      .skip(skip)
      .take(limit)
      .getManyAndCount();

    const totalPages = Math.ceil(total / limit);

    return {
      success: true,
      data: invitations as InvitationWithDetails[],
      pagination: {
        page,
        limit,
        total,
        totalPages,
        hasNext: page < totalPages,
        hasPrev: page > 1,
      },
      timestamp: new Date().toISOString(),
    };
  }

  async getSentInvitations(
    userId: string, 
    status?: InvitationStatus, 
    type?: InvitationType,
    paginationDto?: PaginationDto
  ) {
    const { page = 1, limit = 20, skip = 0 } = paginationDto || {};

    let queryBuilder = this.invitationRepository.createQueryBuilder('invitation')
      .leftJoinAndSelect('invitation.invitee', 'invitee')
      .leftJoinAndSelect('invitation.event', 'event')
      .where('invitation.inviterId = :userId', { userId });

    if (status) {
      queryBuilder = queryBuilder.andWhere('invitation.status = :status', { status });
    }

    if (type) {
      queryBuilder = queryBuilder.andWhere('invitation.type = :type', { type });
    }

    const [invitations, total] = await queryBuilder
      .orderBy('invitation.createdAt', 'DESC')
      .skip(skip)
      .take(limit)
      .getManyAndCount();

    const totalPages = Math.ceil(total / limit);

    return {
      success: true,
      data: invitations as InvitationWithDetails[],
      pagination: {
        page,
        limit,
        total,
        totalPages,
        hasNext: page < totalPages,
        hasPrev: page > 1,
      },
      timestamp: new Date().toISOString(),
    };
  }

  async getPendingInvitations(userId: string) {
    return this.getReceivedInvitations(userId, InvitationStatus.PENDING);
  }

  // Invitation Actions
  async respond(id: string, userId: string, respondDto: RespondInvitationDto): Promise<InvitationWithDetails> {
    const invitation = await this.findById(id, userId);

    // Only invitee can respond
    if (invitation.inviteeId !== userId) {
      throw new ForbiddenException('Only the invitee can respond to this invitation');
    }

    // Check if invitation is still pending
    if (invitation.status !== InvitationStatus.PENDING) {
      throw new BadRequestException('This invitation has already been responded to');
    }

    // Check if invitation has expired
    if (invitation.expiresAt && invitation.expiresAt < new Date()) {
      throw new BadRequestException('This invitation has expired');
    }

    // Process the response based on status
    if (respondDto.status === InvitationStatus.ACCEPTED) {
      // Process the accepted invitation (add to participants, etc.)
      // This should throw if it fails, so we know there's an issue
      await this.processAcceptedInvitation(invitation);

      // Send notification email to inviter (async, don't wait or fail)
      try {
        await this.sendResponseNotificationEmail(invitation, respondDto.status);
      } catch (e) {
        console.error('Error sending response notification email:', e);
        // Email errors shouldn't prevent acceptance
      }

      // For friend invitations, delete the invitation after accepting
      if (invitation.type === InvitationType.FRIEND) {
        // Get the full details before deletion for the return value
        const invitationDetails = await this.findByIdWithDetails(invitation.id);
        await this.invitationRepository.remove(invitation);
        return invitationDetails;
      }
    }

    // For non-accepted responses or non-friend invitations, update the status
    invitation.status = respondDto.status;
    const updatedInvitation = await this.invitationRepository.save(invitation);

    // Send notification email to inviter (async, don't wait or fail)
    try {
      await this.sendResponseNotificationEmail(invitation, respondDto.status);
    } catch (e) {
      console.error('Error sending response notification email:', e);
    }

    return this.findByIdWithDetails(updatedInvitation.id);
  }

  async cancel(id: string, userId: string): Promise<void> {
    const invitation = await this.findById(id, userId);

    // Only inviter can cancel
    if (invitation.inviterId !== userId) {
      throw new ForbiddenException('Only the inviter can cancel this invitation');
    }

    // Can only cancel pending invitations
    if (invitation.status !== InvitationStatus.PENDING) {
      throw new BadRequestException('Can only cancel pending invitations');
    }

    await this.invitationRepository.remove(invitation);

    // Optionally notify invitee about cancellation
    await this.sendCancellationNotificationEmail(invitation);
  }

  async resend(id: string, userId: string): Promise<InvitationWithDetails> {
    const invitation = await this.findById(id, userId);

    // Only inviter can resend
    if (invitation.inviterId !== userId) {
      throw new ForbiddenException('Only the inviter can resend this invitation');
    }

    // Can only resend pending invitations
    if (invitation.status !== InvitationStatus.PENDING) {
      throw new BadRequestException('Can only resend pending invitations');
    }

    // Extend expiration if needed
    if (invitation.expiresAt && invitation.expiresAt < new Date()) {
      invitation.expiresAt = this.getDefaultExpiration(invitation.type);
      await this.invitationRepository.save(invitation);
    }

    // Resend email
    await this.sendInvitationEmail(
      invitation,
      invitation.inviter,
      invitation.invitee
    );

    return invitation;
  }

  // Batch Operations
  async inviteMultipleUsers(
    inviterUserId: string,
    inviteeEmails: string[],
    type: InvitationType,
    resourceId?: string, // eventId or playlistId
    message?: string
  ): Promise<{ successful: InvitationWithDetails[], failed: { email: string, reason: string }[] }> {
    const successful: InvitationWithDetails[] = [];
    const failed: { email: string, reason: string }[] = [];

    for (const email of inviteeEmails) {
      try {
        // Find user by email
        const invitee = await this.userRepository.findOne({ where: { email } });
        
        if (!invitee) {
          failed.push({ email, reason: 'User not found' });
          continue;
        }

        // Create invitation DTO
        const invitationDto: CreateInvitationDto = {
          inviteeId: invitee.id,
          type,
          message,
        };

        if (type === InvitationType.EVENT) {
          invitationDto.eventId = resourceId;
        } else if (type === InvitationType.PLAYLIST) {
          invitationDto.playlistId = resourceId;
        }

        const invitation = await this.create(invitationDto, inviterUserId);
        successful.push(invitation);

      } catch (error) {
        failed.push({ 
          email, 
          reason: error.message || 'Unknown error' 
        });
      }
    }

    return { successful, failed };
  }

  async acceptAllPendingInvitations(userId: string, type?: InvitationType): Promise<number> {
    let queryBuilder = this.invitationRepository.createQueryBuilder('invitation')
      .where('invitation.inviteeId = :userId', { userId })
      .andWhere('invitation.status = :status', { status: InvitationStatus.PENDING })
      .andWhere('(invitation.expiresAt IS NULL OR invitation.expiresAt > :now)', { now: new Date() });

    if (type) {
      queryBuilder = queryBuilder.andWhere('invitation.type = :type', { type });
    }

    const pendingInvitations = await queryBuilder.getMany();

    let acceptedCount = 0;
    for (const invitation of pendingInvitations) {
      try {
        await this.respond(invitation.id, userId, { status: InvitationStatus.ACCEPTED });
        acceptedCount++;
      } catch (error) {
        // Log error but continue with other invitations
        console.error(`Failed to accept invitation ${invitation.id}:`, error.message);
      }
    }

    return acceptedCount;
  }

  // Statistics and Analytics
  async getInvitationStats(userId: string, timeframe?: 'week' | 'month' | 'year'): Promise<InvitationStats> {
    let dateFilter: Date | undefined;
    
    if (timeframe) {
      dateFilter = new Date();
      switch (timeframe) {
        case 'week':
          dateFilter.setDate(dateFilter.getDate() - 7);
          break;
        case 'month':
          dateFilter.setMonth(dateFilter.getMonth() - 1);
          break;
        case 'year':
          dateFilter.setFullYear(dateFilter.getFullYear() - 1);
          break;
      }
    }

    let queryBuilder = this.invitationRepository.createQueryBuilder('invitation')
      .where('invitation.inviterId = :userId OR invitation.inviteeId = :userId', { userId });

    if (dateFilter) {
      queryBuilder = queryBuilder.andWhere('invitation.createdAt >= :dateFilter', { dateFilter });
    }

    const invitations = await queryBuilder.getMany();

    const stats: InvitationStats = {
      total: invitations.length,
      pending: 0,
      accepted: 0,
      declined: 0,
      expired: 0,
      byType: {
        event: 0,
        playlist: 0,
        friend: 0,
      },
    };

    const now = new Date();
    invitations.forEach(invitation => {
      // Count by status
      if (invitation.status === InvitationStatus.PENDING) {
        if (invitation.expiresAt && invitation.expiresAt < now) {
          stats.expired++;
        } else {
          stats.pending++;
        }
      } else if (invitation.status === InvitationStatus.ACCEPTED) {
        stats.accepted++;
      } else if (invitation.status === InvitationStatus.DECLINED) {
        stats.declined++;
      }

      // Count by type
      stats.byType[invitation.type]++;
    });

    return stats;
  }

  // Helper Methods
  private async validateInvitationPermissions(
    type: InvitationType, 
    inviterId: string, 
    eventId?: string, 
    playlistId?: string
  ): Promise<void> {
    switch (type) {
      case InvitationType.EVENT:
        if (!eventId) {
          throw new BadRequestException('Event ID is required for event invitations');
        }
        
        const event = await this.eventRepository.findOne({ 
          where: { id: eventId },
          relations: ['creator', 'participants']
        });
        
        if (!event) {
          throw new NotFoundException('Event not found');
        }
        
        // Check if user can invite to this event
        const canInviteToEvent = event.creatorId === inviterId || 
          event.participants?.some(p => p.userId === inviterId);
        
        if (!canInviteToEvent) {
          throw new ForbiddenException('You cannot invite users to this event');
        }
        break;

      case InvitationType.PLAYLIST:
        if (!playlistId) {
          throw new BadRequestException('Playlist ID is required for playlist invitations');
        }
        
        // playlistId is now an eventId (Event IS Playlist when type=playlist)
        const playlistEvent = await this.eventRepository.findOne({ 
          where: { id: playlistId },
          relations: ['participants']
        });
        
        if (!playlistEvent) {
          throw new NotFoundException('Playlist (Event) not found');
        }
        
        // Check if user can invite to this playlist/event
        const canInviteToPlaylist = playlistEvent.creatorId === inviterId || 
          playlistEvent.participants?.some(p => p.userId === inviterId);
        
        if (!canInviteToPlaylist) {
          throw new ForbiddenException('You cannot invite users to this playlist');
        }
        break;

      case InvitationType.FRIEND:
        // No additional validation needed for friend invitations
        break;
    }
  }

  private async findExistingInvitation(
    inviterId: string,
    inviteeId: string,
    type: InvitationType,
    eventId?: string,
    playlistId?: string
  ): Promise<Invitation | null> {
    const whereCondition: any = {
      inviterId,
      inviteeId,
      type,
    };

    if (eventId) whereCondition.eventId = eventId;
    if (playlistId) whereCondition.playlistId = playlistId;

    return this.invitationRepository.findOne({ 
      where: whereCondition,
      relations: ['inviter', 'invitee', 'event']
    });
  }

  private getDefaultExpiration(type: InvitationType): Date {
    const now = new Date();
    switch (type) {
      case InvitationType.EVENT:
        return new Date(now.getTime() + 7 * 24 * 60 * 60 * 1000); // 7 days
      case InvitationType.PLAYLIST:
        return new Date(now.getTime() + 30 * 24 * 60 * 60 * 1000); // 30 days
      case InvitationType.FRIEND:
        return new Date(now.getTime() + 90 * 24 * 60 * 60 * 1000); // 90 days
      default:
        return new Date(now.getTime() + 7 * 24 * 60 * 60 * 1000); // Default 7 days
    }
  }

  private async processAcceptedInvitation(invitation: Invitation): Promise<void> {
    switch (invitation.type) {
      case InvitationType.EVENT:
        if (invitation.eventId) {
          // Add user to event participants with PARTICIPANT role
          try {
            console.log(`Processing event invitation: Adding user ${invitation.inviteeId} to event ${invitation.eventId}`);
            await this.eventParticipantService.addParticipant(
              invitation.eventId,
              invitation.inviteeId,
              ParticipantRole.PARTICIPANT
            );
            console.log(`✓ User ${invitation.inviteeId} successfully added as participant to event ${invitation.eventId}`);
          } catch (e) {
            console.error('✗ Error adding user to event participants:', e);
            throw e; // Re-throw to make the error visible
          }
        } else {
          console.error('✗ Event invitation missing eventId:', invitation);
        }
        break;

      case InvitationType.PLAYLIST:
        // Add user as collaborator to the playlist (which is an Event with type=LISTENING_SESSION)
        if (invitation.eventId) {
          try {
            console.log(`Processing playlist invitation: Adding user ${invitation.inviteeId} as collaborator to playlist ${invitation.eventId}`);
            const participant = await this.eventParticipantService.addParticipant(
              invitation.eventId,
              invitation.inviteeId,
              ParticipantRole.COLLABORATOR
            );
            console.log(`✓ User ${invitation.inviteeId} successfully added as collaborator to playlist ${invitation.eventId}`, participant);
          } catch (e) {
            console.error('✗ Error adding user to playlist as collaborator:', e);
            throw e; // Re-throw to make the error visible
          }
        } else {
          console.error('✗ Playlist invitation missing eventId:', invitation);
        }
        break;

      case InvitationType.FRIEND:
        // Add bidirectional friend relationship
        try {
          await this.userRepository
            .createQueryBuilder()
            .relation(User, 'friends')
            .of(invitation.inviterId)
            .add(invitation.inviteeId);
          
          await this.userRepository
            .createQueryBuilder()
            .relation(User, 'friends')
            .of(invitation.inviteeId)
            .add(invitation.inviterId);
        } catch (e) {
          console.error('Error adding friend relationship:', e);
        }
        break;
    }
  }

  private async sendInvitationEmail(
    invitation: Invitation, 
    inviter: User, 
    invitee: User
  ): Promise<void> {
    const frontendUrl = process.env.FRONTEND_URL || 'http://localhost:5173';
    
    switch (invitation.type) {
      case InvitationType.EVENT:
        if (invitation.event) {
          const eventUrl = `${frontendUrl}/events/${invitation.eventId}`;
          await this.emailService.sendEventInvitation(
            invitee.email,
            invitation.event.name,
            inviter.displayName || inviter.email,
            eventUrl
          );
        }
        break;

      // case InvitationType.PLAYLIST:
      //   if (invitation.playlist) {
      //     const playlistUrl = `${frontendUrl}/playlists/${invitation.playlistId}`;
      //     await this.emailService.sendPlaylistInvitation(
      //       invitee.email,
      //       invitation.playlist.name,
      //       inviter.displayName || inviter.email,
      //       playlistUrl
      //     );
      //   }
      //   break;

      case InvitationType.FRIEND:
        const profileUrl = `${frontendUrl}/users/${invitation.inviterId}`;
        await this.emailService.sendFriendRequest(
          invitee.email,
          inviter.displayName || inviter.email,
          profileUrl
        );
        break;
    }
  }

  private async sendResponseNotificationEmail(
    invitation: Invitation,
    response: InvitationStatus
  ): Promise<void> {
    // TODO: Implement response notification emails
    // This would notify the inviter about the response
  }

  private async sendCancellationNotificationEmail(invitation: Invitation): Promise<void> {
    // TODO: Implement cancellation notification emails
    // This would notify the invitee about the cancellation
  }

  // Automated Cleanup
  @Cron(CronExpression.EVERY_DAY_AT_MIDNIGHT)
  async cleanupExpiredInvitations(): Promise<void> {
    const expiredInvitations = await this.invitationRepository.find({
      where: {
        status: InvitationStatus.PENDING,
        expiresAt: LessThan(new Date()),
      },
    });

    if (expiredInvitations.length > 0) {
      await this.invitationRepository.update(
        { id: In(expiredInvitations.map(inv => inv.id)) },
        { status: InvitationStatus.EXPIRED }
      );

      console.log(`Marked ${expiredInvitations.length} invitations as expired`);
    }
  }

  @Cron(CronExpression.EVERY_WEEK)
  async cleanupOldInvitations(): Promise<void> {
    // Delete invitations older than 6 months
    const sixMonthsAgo = new Date();
    sixMonthsAgo.setMonth(sixMonthsAgo.getMonth() - 6);

    const result = await this.invitationRepository
      .createQueryBuilder()
      .delete()
      .from(Invitation)
      .where('createdAt < :sixMonthsAgo', { sixMonthsAgo })
      .execute();

    if (result.affected && result.affected > 0) {
      console.log(`Deleted ${result.affected} old invitations`);
    }
  }
}