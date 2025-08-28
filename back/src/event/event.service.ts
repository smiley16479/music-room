import {
  Injectable,
  NotFoundException,
  BadRequestException,
  ForbiddenException,
  ConflictException,
} from '@nestjs/common';
import { InjectRepository } from '@nestjs/typeorm';
import { Repository, FindOptionsWhere, In } from 'typeorm';
import { Cron, CronExpression } from '@nestjs/schedule';

import { Event, EventStatus, EventVisibility, EventLicenseType } from 'src/event/entities/event.entity';
import { Vote, VoteType } from 'src/event/entities/vote.entity';
import { Track } from 'src/music/entities/track.entity';
import { User } from 'src/user/entities/user.entity';
import { Invitation, InvitationType, InvitationStatus } from 'src/invitation/entities/invitation.entity';

import { CreateEventDto } from './dto/create-event.dto';
import { UpdateEventDto } from './dto/update-event.dto';
import { CreateVoteDto } from './dto/vote.dto';
import { PaginationDto } from '../common/dto/pagination.dto';
import { LocationDto } from '../common/dto/location.dto';

import { PlaylistService } from 'src/playlist/playlist.service';
import { EmailService } from '../email/email.service';
import { EventGateway } from './event.gateway';
import { Playlist } from 'src/playlist/entities/playlist.entity';
import { PlaylistTrack } from 'src/playlist/entities/playlist-track.entity';

export interface EventWithStats extends Event {
  stats: {
    participantCount: number;
    voteCount: number;
    trackCount: number;
    isUserParticipating: boolean;
  };
}

export interface VoteResult {
  track: Track;
  voteCount: number;
  userVote?: Vote;
  position: number;
}

@Injectable()
export class EventService {
  constructor(
    @InjectRepository(Event)
    private readonly eventRepository: Repository<Event>,
    @InjectRepository(Playlist)
    private readonly playlistRepository: Repository<Playlist>,
    @InjectRepository(Vote)
    private readonly voteRepository: Repository<Vote>,
    @InjectRepository(Track)
    private readonly trackRepository: Repository<Track>,
    @InjectRepository(User)
    private readonly userRepository: Repository<User>,
    @InjectRepository(Invitation)
    private readonly invitationRepository: Repository<Invitation>,
    private readonly playlistService: PlaylistService,
    private readonly emailService: EmailService,
    private readonly eventGateway: EventGateway,
  ) {}

  // CRUD Operations
  async create(createEventDto: CreateEventDto, creatorId: string): Promise<Event> {

    const creator = await this.userRepository.findOne({ where: { id: creatorId } });
    if (!creator) {
      throw new NotFoundException('Creator not found');
    }

    // Validate location-based event requirements
    if (createEventDto.licenseType === EventLicenseType.LOCATION_BASED) {
      if (!createEventDto.latitude || !createEventDto.longitude || !createEventDto.locationRadius) {
        throw new BadRequestException('Location-based events require coordinates and radius');
      }
      if (!createEventDto.votingStartTime || !createEventDto.votingEndTime) {
        throw new BadRequestException('Location-based events require voting time constraints');
      }
    }

    const event = this.eventRepository.create({
      ...createEventDto,
      creatorId,
      status: EventStatus.UPCOMING,
    });
 
    let savedEvent: Event;
    
    // Add track from selected playlist to event playlist
    if (createEventDto.selectedPlaylistId) {
        const { 
          selectedPlaylistId: originalPlaylistId,
          playlistName: newName
        } = createEventDto
        const playlistCopied = await this.playlistService.duplicatePlaylist(originalPlaylistId, creator.id, `[Event] ${newName}`);
        
        // Save the event first to get its ID
        savedEvent = await this.eventRepository.save(event);
        
        // Set the eventId on the playlist to link it to this event
        playlistCopied.eventId = savedEvent.id;
        playlistCopied.event = savedEvent;
        await this.playlistRepository.save(playlistCopied);
        
        savedEvent.playlist = playlistCopied;
    } else if (createEventDto.playlistName) {
        // Save the event first to get its ID
        savedEvent = await this.eventRepository.save(event);
        
        const playlist = new Playlist()
        playlist.name = `[Event] ${createEventDto.playlistName.trim()}`
        playlist.eventId = savedEvent.id; // Set the eventId to link it to this event
        playlist.event = savedEvent;
        playlist.creator = creator;
        playlist.creatorId = creator.id;
        await this.playlistRepository.save(playlist);
        
        savedEvent.playlist = playlist;
    } else {
        // Save the event without playlist
        savedEvent = await this.eventRepository.save(event);
    }

    // Add creator as first participant
    await this.addParticipant(savedEvent.id, creatorId);

    this.eventGateway.notifyEventCreated(savedEvent, creatorId);

    return this.findById(savedEvent.id, creatorId);
  }

  async findAll(paginationDto: PaginationDto, userId?: string) {
    const { page, limit, skip } = paginationDto;

    const queryBuilder = this.eventRepository.createQueryBuilder('event')
      .leftJoinAndSelect('event.creator', 'creator')
      .leftJoinAndSelect('event.participants', 'participants')
      .leftJoinAndSelect('event.currentTrack', 'currentTrack')
      .leftJoinAndSelect('event.playlist', 'playlist')
      .where('event.visibility = :visibility', { visibility: EventVisibility.PUBLIC })
      .orWhere('event.creatorId = :userId', { userId })
      .orderBy('event.createdAt', 'DESC')
      .skip(skip)
      .take(limit);

    const [events, total] = await queryBuilder.getManyAndCount();

    const eventsWithStats = await Promise.all(
      events.map(event => this.addEventStats(event, userId)),
    );

    const totalPages = Math.ceil(total / limit);

    return {
      success: true,
      data: eventsWithStats,
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

  async findById(id: string, userId?: string): Promise<EventWithStats> {
    const event = await this.eventRepository.findOne({
      where: { id },
      relations: ['creator', 'participants', 'admins', 'currentTrack', 
        'playlist', 'playlist.playlistTracks', 
        'votes', 'votes.user', 'votes.track'
      ],
    });

    if (!event) {
      throw new NotFoundException('Event not found');
    }

    // Check access permissions
    await this.checkEventAccess(event, userId);

    return this.addEventStats(event, userId);
  }

  async update(id: string, updateEventDto: UpdateEventDto, userId: string): Promise<Event> {
    const event = await this.findById(id, userId);

    // Only creator can update event
    if (event.creatorId !== userId) {
      throw new ForbiddenException('Only the creator can update this event');
    }

    Object.assign(event, updateEventDto);
    const updatedEvent = await this.eventRepository.save(event);

    // Notify participants of changes
    this.eventGateway.notifyEventUpdated(id, updatedEvent);

    return updatedEvent;
  }

  async remove(id: string, userId: string): Promise<void> {
    const event = await this.findById(id, userId);

    if (event.creatorId !== userId) {
      throw new ForbiddenException('Only the creator can delete this event');
    }

    this.eventGateway.notifyEventDeleted(id);

    await this.eventRepository.remove(event);
  }

  // Participant Management
  async addParticipant(eventId: string, userId: string): Promise<void> {
    const event = await this.eventRepository.findOne({
      where: { id: eventId },
      relations: ['participants'],
    });

    if (!event) {
      throw new NotFoundException('Event not found');
    }

    // Check if already participating
    const isParticipating = event.participants?.some(p => p.id === userId);
    if (isParticipating) {
      throw new ConflictException('User is already participating in this event');
    }

    // Check access permissions
    await this.checkEventAccess(event, userId);

    const user = await this.userRepository.findOne({ where: { id: userId } });
    if (!user) {
      throw new NotFoundException('User not found');
    }

    // Add participant
    await this.eventRepository
      .createQueryBuilder()
      .relation(Event, 'participants')
      .of(eventId)
      .add(userId);

    // Notify other participants
    this.eventGateway.notifyParticipantJoined(eventId, user);
  }

  async removeParticipant(eventId: string, userId: string): Promise<void> {
    const event = await this.findById(eventId, userId);

    // Can't remove creator
    if (event.creatorId === userId) {
      throw new BadRequestException('Event creator cannot leave the event');
    }

    const user = await this.userRepository.findOne({ where: { id: userId } });
    if (!user) {
      throw new NotFoundException('User not found');
    }

    await this.eventRepository
      .createQueryBuilder()
      .relation(Event, 'participants')
      .of(eventId)
      .remove(userId);

    // Remove user's votes
    await this.voteRepository.delete({ eventId, userId });

    this.eventGateway.notifyParticipantLeft(eventId, user);
  }

  /** Promote a user to admin for an event */
  async promoteAdmin(eventId: string, actorId: string, userId: string): Promise<void> {
    const event = await this.eventRepository.findOne({
      where: { id: eventId },
      relations: [
        'creator',
        'admins',
        'participants',
      ]
    });

    if (!event)
      throw new NotFoundException('Event not found');
    
    // Only creator or existing admin can promote
    if (event.creatorId !== actorId && !(event.admins?.some(a => a.id === actorId))) {
      throw new ForbiddenException('Only creator or admin can promote another user');
    }
    
    // Creator is automatically an admin and cannot be promoted
    if (event.creatorId === userId) {
      throw new BadRequestException('Event creator is already an admin by default');
    }
    
    const isParticipant = event.participants?.some(p => p.id === userId);
    if (!isParticipant) {
      await this.addParticipant(eventId, userId);
    }
    // Check if already admin
    if (event.admins?.some(a => a.id === userId)) {
      throw new ConflictException('User is already an admin');
    }
    // Add user to admins relation
    await this.eventRepository
      .createQueryBuilder()
      .relation(Event, 'admins')
      .of(eventId)
      .add(userId);
    // Optionally notify participants
    this.eventGateway.notifyAdminAdded(eventId, userId);
  }

  /** Remove a user from the admins of an event */
  async removeAdmin(eventId: string, actorId: string, userId: string): Promise<void> {
    const event = await this.eventRepository.findOne({
      where: { id: eventId },
      relations: [
        'creator',
        'admins',
      ]
    });

    if (!event) {
      throw new NotFoundException('Event not found');
    }
    // Only creator or existing admin can remove
    if (event.creatorId !== actorId && !(event.admins?.some(a => a.id === actorId))) {
      throw new ForbiddenException('Only creator or admin can remove another admin');
    }
    // Can't remove creator from admins
    if (event.creatorId === userId) {
      throw new BadRequestException('Cannot remove creator from admins');
    }
    // Check if user is actually an admin
    if (!event.admins?.some(a => a.id === userId)) {
      throw new NotFoundException('User is not an admin');
    }
    // Remove user from admins relation
    await this.eventRepository
      .createQueryBuilder()
      .relation(Event, 'admins')
      .of(eventId)
      .remove(userId);
    this.eventGateway.notifyAdminRemoved(eventId, userId);
  }


  // Voting System
  async voteForTrack(eventId: string, userId: string, voteDto: CreateVoteDto): Promise<VoteResult[]> {
    const event = await this.findById(eventId, userId);

    // Check if user can vote
    await this.checkVotingPermissions(event, userId);

    // Check if user has reached vote limit (0 means unlimited)
    if (event.maxVotesPerUser > 0) {
      const userVoteCount = await this.voteRepository.count({
        where: { eventId, userId },
      });

      if (userVoteCount >= event.maxVotesPerUser) {
        throw new BadRequestException(`Maximum ${event.maxVotesPerUser} votes allowed per user`);
      }
    }

    // Get or create track
    const track = await this.trackRepository.findOne({
      where: { id: voteDto.trackId },
    });

    if (!track) {
      throw new NotFoundException('Track not found');
    }

    // Check if user already voted for this track
    const existingVote = await this.voteRepository.findOne({
      where: { eventId, userId, trackId: voteDto.trackId },
    });

    if (existingVote) {
      throw new ConflictException('User has already voted for this track');
    }

    // Create vote
    const vote = this.voteRepository.create({
      eventId,
      userId,
      trackId: voteDto.trackId,
      type: voteDto.type || VoteType.UPVOTE,
      weight: voteDto.weight || 1,
    });

    await this.voteRepository.save(vote);

    // Get updated voting results
    const results = await this.getVotingResults(eventId, userId);

    // Reorder playlist tracks based on votes
    await this.reorderPlaylistByVotes(eventId);

    // Notify participants
    this.eventGateway.notifyVoteUpdated(eventId, vote, results);

    return results;
  }

  async removeVote(eventId: string, userId: string, trackId: string): Promise<VoteResult[]> {
    const event = await this.findById(eventId, userId);

    const vote = await this.voteRepository.findOne({
      where: { eventId, userId, trackId },
    });

    if (!vote) {
      throw new NotFoundException('Vote not found');
    }

    await this.voteRepository.remove(vote);

    // Get updated voting results
    const results = await this.getVotingResults(eventId, userId);

    // Reorder playlist tracks based on votes
    await this.reorderPlaylistByVotes(eventId);

    // Notify participants
    this.eventGateway.notifyVoteRemoved(eventId, vote, results);

    return results;
  }

  /**
   * Reorders the playlist tracks based on their vote counts
   * Tracks with higher vote counts move up in the playlist
   */
  private async reorderPlaylistByVotes(eventId: string): Promise<void> {
    try {
      // Get the event with its playlist
      const event = await this.eventRepository.findOne({
        where: { id: eventId },
        relations: ['playlist', 'playlist.playlistTracks'],
      });

      if (!event?.playlist?.playlistTracks) {
        return;
      }

      // Get voting results for this event
      const voteResults = await this.getVotingResults(eventId);
      const voteMap = new Map(voteResults.map(result => [result.track.id, result.voteCount]));

      // Get playlist tracks and sort them by votes (descending), then by original position
      const playlistTracks = event.playlist.playlistTracks.sort((a, b) => {
        const aVotes = voteMap.get(a.trackId) || 0;
        const bVotes = voteMap.get(b.trackId) || 0;
        
        // First sort by votes (higher votes first)
        if (aVotes !== bVotes) {
          return bVotes - aVotes;
        }
        
        // If votes are equal, maintain original order (earlier position first)
        return a.position - b.position;
      });

      // Update positions based on new order using the playlist service reorder method
      const trackOrder = playlistTracks.map(pt => pt.trackId);
      
      // Use the existing reorder method from playlist service
      await this.playlistService.reorderTracks(
        event.playlist.id, 
        event.creatorId, // Use the event creator as the acting user
        { trackIds: trackOrder }
      );

      // Notify participants about the reordering
      this.eventGateway.notifyTracksReordered(eventId, trackOrder, 'voting-system');

    } catch (error) {
      console.error('Failed to reorder playlist by votes:', error);
      // Don't throw the error to avoid disrupting the voting process
    }
  }

  async getVotingResults(eventId: string, userId?: string): Promise<VoteResult[]> {
    const votes = await this.voteRepository
      .createQueryBuilder('vote')
      .leftJoinAndSelect('vote.track', 'track')
      .leftJoinAndSelect('vote.user', 'user')
      .where('vote.eventId = :eventId', { eventId })
      .getMany();

    // Group votes by track
    const trackVotes = new Map<string, Vote[]>();
    votes.forEach(vote => {
      const trackId = vote.trackId;
      if (!trackVotes.has(trackId)) {
        trackVotes.set(trackId, []);
      }
      trackVotes.get(trackId)!.push(vote);
    });

    // Calculate vote results
    const results: VoteResult[] = [];
    for (const [trackId, trackVoteList] of trackVotes) {
      const track = trackVoteList[0].track;
      const voteCount = trackVoteList.reduce((sum, vote) => {
        return sum + (vote.type === VoteType.UPVOTE ? vote.weight : -vote.weight);
      }, 0);

      const userVote = userId ? trackVoteList.find(v => v.userId === userId) : undefined;

      results.push({
        track,
        voteCount,
        userVote,
        position: 0, // Will be set after sorting
      });
    }

    // Sort by vote count (descending) and set positions
    results.sort((a, b) => b.voteCount - a.voteCount);
    results.forEach((result, index) => {
      result.position = index + 1;
    });

    return results;
  }

  // Location-based features
  async findNearbyEvents(location: LocationDto, radiusKm = 10, userId?: string) {
    const { latitude, longitude } = location;

    const events = await this.eventRepository
      .createQueryBuilder('event')
      .leftJoinAndSelect('event.creator', 'creator')
      .leftJoinAndSelect('event.participants', 'participants')
      .where('event.visibility = :visibility', { visibility: EventVisibility.PUBLIC })
      .andWhere('event.status = :status', { status: EventStatus.LIVE })
      .andWhere('event.latitude IS NOT NULL AND event.longitude IS NOT NULL')
      .andWhere(
        `(6371 * acos(cos(radians(:lat)) * cos(radians(event.latitude)) * cos(radians(event.longitude) - radians(:lng)) + sin(radians(:lat)) * sin(radians(event.latitude)))) <= :radius`,
        { lat: latitude, lng: longitude, radius: radiusKm },
      )
      .orderBy('event.createdAt', 'DESC')
      .getMany();

    const eventsWithStats = await Promise.all(
      events.map(event => this.addEventStats(event, userId)),
    );

    return {
      success: true,
      data: eventsWithStats,
      timestamp: new Date().toISOString(),
    };
  }

  async checkLocationPermission(eventId: string, userLocation: LocationDto): Promise<boolean> {
    const event = await this.eventRepository.findOne({ where: { id: eventId } });

    if (!event || event.licenseType !== EventLicenseType.LOCATION_BASED) {
      return true; // Not location-based
    }

    if (!event.latitude || !event.longitude || !event.locationRadius) {
      return false;
    }

    // Check if current time is within voting hours
    const now = new Date();
    const currentTime = now.toTimeString().substring(0, 5); // HH:MM format

    if (event.votingStartTime && event.votingEndTime) {
      if (currentTime < event.votingStartTime || currentTime > event.votingEndTime) {
        return false;
      }
    }

    // Calculate distance
    const distance = this.calculateDistance(
      userLocation.latitude,
      userLocation.longitude,
      event.latitude,
      event.longitude,
    );

    return distance <= (event.locationRadius / 1000); // Convert meters to km
  }

  // Event State Management
  async startEvent(eventId: string, userId: string): Promise<Event> {
    const event = await this.findById(eventId, userId);

    if (event.creatorId !== userId) {
      throw new ForbiddenException('Only the creator can start the event');
    }

    if (event.status !== EventStatus.UPCOMING) {
      throw new BadRequestException('Event is not in upcoming state');
    }

    event.status = EventStatus.LIVE;
    const updatedEvent = await this.eventRepository.save(event);

    // Notify participants
    this.eventGateway.notifyEventUpdated(eventId, updatedEvent);

    return updatedEvent;
  }

  async endEvent(eventId: string, userId: string): Promise<Event> {
    const event = await this.findById(eventId, userId);

    if (event.creatorId !== userId) {
      throw new ForbiddenException('Only the creator can end the event');
    }

    if (event.status !== EventStatus.LIVE) {
      throw new BadRequestException('Event is not live');
    }

    event.status = EventStatus.ENDED;
    const updatedEvent = await this.eventRepository.save(event);

    // Notify participants
    this.eventGateway.notifyEventUpdated(eventId, updatedEvent);

    return updatedEvent;
  }

  async playNextTrack(eventId: string, userId: string): Promise<Track | null> {
    const event = await this.findById(eventId, userId);

    if (event.creatorId !== userId) {
      throw new ForbiddenException('Only the creator can control playback');
    }

    // Get top voted track
    const results = await this.getVotingResults(eventId);
    const nextTrack = results.length > 0 ? results[0].track : null;

    if (nextTrack) {
      event.currentTrackId = nextTrack.id;
      event.currentTrackStartedAt = new Date();
      await this.eventRepository.save(event);

      // Notify participants
      this.eventGateway.notifyNowPlaying(eventId, nextTrack);

      // Remove votes for the played track to avoid replay
      await this.voteRepository.delete({ eventId, trackId: nextTrack.id });
    }

    return nextTrack;
  }

  /** Récupère tous les events où l'utilisateur est créateur ou participant, avec les admins */
  async getEventsUserCanInviteWithAdmins(userId: string): Promise<Event[]> {
    const events = await this.eventRepository
      .createQueryBuilder('event')
      .leftJoinAndSelect('event.participants', 'participant')
      .leftJoinAndSelect('event.admins', 'admin')
      .leftJoinAndSelect('event.playlist', 'playlist')
      .where('event.creatorId = :userId', { userId })
      .orWhere('participant.id = :userId', { userId })
      .getMany();
    return events;
  }

  // Invitation System
  async inviteUsers(eventId: string, inviterUserId: string, inviteeEmails: string[]): Promise<void> {
    const event = await this.findById(eventId, inviterUserId);

    // Only creator or participants can invite (depending on license)
    const canInvite = event.creatorId === inviterUserId || 
      event.participants?.some(p => p.id === inviterUserId);

    if (!canInvite) {
      throw new ForbiddenException('You cannot invite users to this event');
    }

    const inviter = await this.userRepository.findOne({ where: { id: inviterUserId } });

    for (const email of inviteeEmails) {
      // Check if user exists
      const invitee = await this.userRepository.findOne({ where: { email } });

      if (invitee) {
        // Create invitation record
        const invitation = this.invitationRepository.create({
          inviterId: inviterUserId,
          inviteeId: invitee.id,
          eventId,
          type: InvitationType.EVENT,
          status: InvitationStatus.PENDING,
          expiresAt: new Date(Date.now() + 7 * 24 * 60 * 60 * 1000), // 7 days
        });

        await this.invitationRepository.save(invitation);
      }

      // Send invitation email
      const eventUrl = `${process.env.FRONTEND_URL}/events/${eventId}`;
      await this.emailService.sendEventInvitation(
        email,
        event.name,
        inviter?.displayName || 'A friend',
        eventUrl,
      );
    }
  }

  // Helper Methods
  private async addEventStats(event: Event, userId?: string): Promise<EventWithStats> {
    const participantCount = event.participants?.length || 0;
    const voteCount = event.votes?.length || 0;
    
    // Get unique tracks from votes
    const uniqueTrackIds = new Set(event.votes?.map(v => v.trackId) || []);
    const trackCount = uniqueTrackIds.size;

    const isUserParticipating = userId ? 
      event.participants?.some(p => p.id === userId) || false : false;

    return {
      ...event,
      stats: {
        participantCount,
        voteCount,
        trackCount,
        isUserParticipating,
      },
    };
  }

  private async checkEventAccess(event: Event, userId?: string): Promise<void> {
    if (event.visibility === EventVisibility.PUBLIC) {
      return; // Public events are accessible to everyone
    }

    if (!userId) {
      throw new ForbiddenException('Authentication required for private events');
    }

    // Check if user is creator
    if (event.creatorId === userId) {
      return;
    }

    // Check if user is invited
    const invitation = await this.invitationRepository.findOne({
      where: {
        eventId: event.id,
        inviteeId: userId,
        status: InvitationStatus.ACCEPTED,
      },
    });

    if (!invitation) {
      throw new ForbiddenException('You are not invited to this private event');
    }
  }

  private async checkVotingPermissions(event: Event, userId: string): Promise<void> {
    // Check if event should be live based on dates (fallback for cron job delays)
    const now = new Date();
    let effectiveStatus = event.status;
    
    if (event.eventDate && event.eventEndDate) {
      if (now >= event.eventDate && now < event.eventEndDate) {
        effectiveStatus = EventStatus.LIVE;
        
        // Update status in database if it's different
        if (event.status !== EventStatus.LIVE) {
          await this.eventRepository.update(event.id, { status: EventStatus.LIVE });
          console.log(`Auto-updated event ${event.id} status to LIVE based on dates`);
        }
      } else if (now >= event.eventEndDate && event.status === EventStatus.LIVE) {
        effectiveStatus = EventStatus.ENDED;
        await this.eventRepository.update(event.id, { status: EventStatus.ENDED });
        console.log(`Auto-updated event ${event.id} status to ENDED based on dates`);
      }
    }

    if (effectiveStatus !== EventStatus.LIVE) {
      throw new BadRequestException('Voting is only allowed during live events');
    }

    switch (event.licenseType) {
      case EventLicenseType.OPEN:
        return; // Everyone can vote

      case EventLicenseType.INVITED:
        const invitation = await this.invitationRepository.findOne({
          where: {
            eventId: event.id,
            inviteeId: userId,
            status: InvitationStatus.ACCEPTED,
          },
        });

        if (!invitation && event.creatorId !== userId) {
          throw new ForbiddenException('Only invited users can vote in this event');
        }
        break;

      case EventLicenseType.LOCATION_BASED:
        // Location check would be done on the frontend before calling this
        // We assume if the call reaches here, location was already verified
        break;
    }
  }

  private calculateDistance(lat1: number, lon1: number, lat2: number, lon2: number): number {
    const R = 6371; // Earth's radius in kilometers
    const dLat = this.degreeToRadian(lat2 - lat1);
    const dLon = this.degreeToRadian(lon2 - lon1);

    const a = 
      Math.sin(dLat / 2) * Math.sin(dLat / 2) +
      Math.cos(this.degreeToRadian(lat1)) * Math.cos(this.degreeToRadian(lat2)) *
      Math.sin(dLon / 2) * Math.sin(dLon / 2);

    const c = 2 * Math.atan2(Math.sqrt(a), Math.sqrt(1 - a));
    return R * c;
  }

  private degreeToRadian(degree: number): number {
    return degree * (Math.PI / 180);
  }

  // Manual status update method that can be called when needed
  async manuallyUpdateEventStatuses(): Promise<void> {
    await this.updateEventStatuses();
  }

  // Automated tasks
  @Cron(CronExpression.EVERY_MINUTE)
  async updateEventStatuses(): Promise<void> {
    const now = new Date();

    // Start events that should be live
    await this.eventRepository
      .createQueryBuilder()
      .update(Event)
      .set({ status: EventStatus.LIVE })
      .where('status = :status', { status: EventStatus.UPCOMING })
      .andWhere('eventDate <= :now', { now })
      .execute();

    // End events that have passed their end time
    await this.eventRepository
      .createQueryBuilder()
      .update(Event)
      .set({ status: EventStatus.ENDED })
      .where('status = :status', { status: EventStatus.LIVE })
      .andWhere('eventEndDate <= :now', { now })
      .execute();
  }
}