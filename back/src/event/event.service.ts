import {
  Injectable,
  NotFoundException,
  BadRequestException,
  ForbiddenException,
  ConflictException,
  Inject,
  forwardRef,
} from '@nestjs/common';
import { InjectRepository } from '@nestjs/typeorm';
import { Repository, FindOptionsWhere, In } from 'typeorm';
import { Cron, CronExpression } from '@nestjs/schedule';

import { Event, EventStatus, EventVisibility, EventLicenseType } from 'src/event/entities/event.entity';
import { EventType } from 'src/event/entities/event-type.enum';
import { Vote, VoteType } from 'src/event/entities/vote.entity';
import { PlaylistTrack } from 'src/event/entities/playlist-track.entity';
import { Track } from 'src/music/entities/track.entity';
import { User } from 'src/user/entities/user.entity';
import { Invitation, InvitationType, InvitationStatus } from 'src/invitation/entities/invitation.entity';
import { EventParticipantService } from './event-participant.service';
import { EventParticipant, ParticipantRole } from 'src/event/entities/event-participant.entity';

import { CreateEventDto } from './dto/event/create-event.dto';
import { UpdateEventDto } from './dto/event/update-event.dto';
import { LocationDto } from '../common/dto/location.dto';
import { CreateVoteDto } from './dto/vote.dto';
import { PaginationDto } from '../common/dto/pagination.dto';
import { AddTrackToPlaylistDto } from './dto/playlist/add-track.dto';

import { EmailService } from '../email/email.service';
import { EventGateway } from './event.gateway';
import { GeocodingService } from '../common/services/geocoding.service';
import { toZonedTime } from 'date-fns-tz';

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

// Snapshot (Short version VoteResult) of track votes for response
export interface TrackVoteSnapshot {
  trackId: string;
  upvotes: number;
  downvotes: number;
  position: number;
}

@Injectable()
export class EventService {
  constructor(
    @InjectRepository(Event)
    private readonly eventRepository: Repository<Event>,
    @InjectRepository(EventParticipant)
    private readonly eventParticipantRepository: Repository<EventParticipant>,
    @InjectRepository(Vote)
    private readonly voteRepository: Repository<Vote>,
    @InjectRepository(Track)
    private readonly trackRepository: Repository<Track>,
    @InjectRepository(User)
    private readonly userRepository: Repository<User>,
    @InjectRepository(Invitation)
    private readonly invitationRepository: Repository<Invitation>,
    private readonly eventParticipantService: EventParticipantService,
    private readonly emailService: EmailService,
    private readonly eventGateway: EventGateway,
    private readonly geocodingService: GeocodingService,
  ) {}

  // CRUD Operations
  async create(createEventDto: CreateEventDto, creatorId: string): Promise<Event> {

    const creator = await this.userRepository.findOne({ where: { id: creatorId } });
    if (!creator) {
      throw new NotFoundException('Creator not found');
    }

    // Handle location-based event requirements
    if (createEventDto.licenseType === EventLicenseType.LOCATION_BASED) {
      if (!createEventDto.locationRadius) {
        throw new BadRequestException('Location-based events require a location radius');
      }
      if (!createEventDto.votingStartTime || !createEventDto.votingEndTime) {
        throw new BadRequestException('Location-based events require voting time constraints');
      }

      // Handle city-based geocoding or direct coordinates
      if (createEventDto.cityName) {
        // Use city name to get coordinates
        try {
          const geocodeResult = await this.geocodingService.geocodeCity(createEventDto.cityName);
          createEventDto.latitude = geocodeResult.latitude;
          createEventDto.longitude = geocodeResult.longitude;
          createEventDto.locationName = geocodeResult.displayName;
        } catch (error) {
          throw new BadRequestException(`Unable to find location for city "${createEventDto.cityName}": ${error.message}`);
        }
      } else if (!createEventDto.latitude || !createEventDto.longitude) {
        throw new BadRequestException('Location-based events require either a city name or coordinates (latitude/longitude)');
      }
    }

    console.log('Creating event with DTO:', createEventDto);
    
    const event = this.eventRepository.create({
      ...createEventDto,
      creatorId,
      status: EventStatus.UPCOMING,
    });
    
    console.log('Event object before save:', {
      name: event.name,
      type: event.type,
      visibility: event.visibility,
      creatorId: event.creatorId,
    });
 
    let savedEvent: Event;
    
    // Add track from selected playlist to event playlist
    if (createEventDto.selectedPlaylistId) {
        const { 
          selectedPlaylistId: originalPlaylistId,
          playlistName: newName
        } = createEventDto
        
        // Initialize event with playlist fields
        event.trackCount = 0;
        event.totalDuration = 0;
        
        // Save the event first to get its ID
        savedEvent = await this.eventRepository.save(event);
        
        // Copy playlist tracks from original playlist to this event
        // This will be done by PlaylistService.duplicatePlaylist or manually copy tracks
        // For now, just create empty event - tracks can be added later via API
        
    } else if (createEventDto.playlistName) {
        // Update event name with playlist name if provided
        event.name = createEventDto.playlistName.trim();
        
        // Initialize playlist fields for this event
        event.trackCount = 0;
        event.totalDuration = 0;
        
        // Save the event (which now has playlist capabilities)
        savedEvent = await this.eventRepository.save(event);
    } else {
        // Save the event without playlist
        savedEvent = await this.eventRepository.save(event);
    }

    console.log('Event saved with ID:', savedEvent.id, 'Type:', savedEvent.type);
    
    // Add creator as an admin participant for playlists, or as a collaborator for events
    try {
      const role = savedEvent.type === EventType.PLAYLIST 
        ? ParticipantRole.ADMIN 
        : ParticipantRole.COLLABORATOR;
      
      await this.eventParticipantService.addParticipant(
        savedEvent.id,
        creatorId,
        role
      );
      console.log(`Creator added as ${role} for event:`, savedEvent.id);
    } catch (error) {
      console.error('Error adding creator as participant:', error);
    }
    
    this.eventGateway.notifyEventCreated(savedEvent, creator);

    return this.findById(savedEvent.id, creatorId);
  }

  async findAll(paginationDto: PaginationDto, userId?: string, userLocation?: LocationDto, type?: string) {
    const { page, limit, skip } = paginationDto;

    const queryBuilder = this.eventRepository.createQueryBuilder('event')
      .leftJoinAndSelect('event.participants', 'participants')
      .leftJoinAndSelect('participants.user', 'participantUser')

    if (userId) {
      // Show public events + private events where user has access (creator, participant, admin)
      queryBuilder
        .where('event.visibility = :visibility', { visibility: EventVisibility.PUBLIC })
        .orWhere('event.creatorId = :userId', { userId })
        .orWhere('participants.userId = :userId', { userId });
    } else {
      // For unauthenticated users, only show public events
      queryBuilder.where('event.visibility = :visibility', { visibility: EventVisibility.PUBLIC });
    }

    // Filter by type if provided
    if (type) {
      queryBuilder.andWhere('event.type = :type', { type });
    }

    queryBuilder
      .orderBy('event.createdAt', 'DESC')
      .skip(skip)
      .take(limit);

    const [events, total] = await queryBuilder.getManyAndCount();

    // Always filter location-based events based on user location
    const filteredEvents = await this.filterEventsByLocation(events, userLocation, userId);

    const eventsWithStats = await Promise.all(
      filteredEvents.map(event => this.addEventStats(event, userId)),
    );

    const totalPages = Math.ceil(total / limit);

    return {
      success: true,
      data: eventsWithStats,
      pagination: {
        page,
        limit,
        total: filteredEvents.length,
        totalPages: Math.ceil(filteredEvents.length / limit),
        hasNext: page < Math.ceil(filteredEvents.length / limit),
        hasPrev: page > 1,
      },
      timestamp: new Date().toISOString(),
    };
  }

  async findMyEvents(paginationDto: PaginationDto, userId?: string, type?: string) {
    if (!userId) {
      throw new ForbiddenException('Authentication required');
    }

    const { page, limit, skip } = paginationDto;

    const queryBuilder = this.eventRepository.createQueryBuilder('event')
      .leftJoinAndSelect('event.participants', 'participants')
      .leftJoinAndSelect('participants.user', 'participantUser')
      .leftJoinAndSelect('event.creator', 'creator')
      .where(
        '(event.creatorId = :userId OR participants.userId = :userId)',
        { userId }
      );

    // Filter by type if provided
    if (type) {
      queryBuilder.andWhere('event.type = :type', { type });
    }

    queryBuilder
      .orderBy('event.createdAt', 'DESC')
      .skip(skip)
      .take(limit);

    const [events, total] = await queryBuilder.getManyAndCount();

    console.log(`Found my events for user ${userId}:`, events.length);
    console.log('Events types:', events.map(e => ({ id: e.id, name: e.name, type: e.type })));

    const eventsWithStats = await Promise.all(
      events.map(event => this.addEventStats(event, userId)),
    );

    return {
      success: true,
      data: eventsWithStats,
      pagination: {
        page,
        limit,
        total,
        totalPages: Math.ceil(total / limit),
        hasNext: page < Math.ceil(total / limit),
        hasPrev: page > 1,
      },
      timestamp: new Date().toISOString(),
    };
  }

  private async filterEventsByLocation(events: Event[], userLocation: LocationDto | undefined, userId?: string): Promise<Event[]> {
    const filteredEvents: Event[] = [];

    for (const event of events) {
      // Non-location-based events are always shown
      if (event.licenseType !== EventLicenseType.LOCATION_BASED) {
        filteredEvents.push(event);
        continue;
      }

      // Always show events created by the user, regardless of location
      if (event.creatorId === userId) {
        filteredEvents.push(event);
        continue;
      }

      // For location-based events, check if user is within range
      // If no location is provided, don't show location-based events (unless user is creator)
      if (userLocation) {
        const hasLocationPermission = await this.checkLocationPermission(event.id, userLocation, userId);
        if (hasLocationPermission) {
          filteredEvents.push(event);
        }
      }
      // If no userLocation, location-based events are not shown (except for creators, handled above)
    }

    return filteredEvents;
  }

  async findById(id: string, userId?: string): Promise<EventWithStats> {
    const event = await this.eventRepository.findOne({
      where: { id },
      relations: ['creator', 'participants', 'participants.user', 'votes', 'votes.user', 'votes.track'],
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

    // Store original license type for comparison
    const originalLicenseType = event.licenseType;

    // Handle city-based geocoding for location-based events
    if (updateEventDto.licenseType === EventLicenseType.LOCATION_BASED || event.licenseType === EventLicenseType.LOCATION_BASED) {
      if (updateEventDto.cityName) {
        // Use city name to get coordinates
        try {
          const geocodeResult = await this.geocodingService.geocodeCity(updateEventDto.cityName);
          updateEventDto.latitude = geocodeResult.latitude;
          updateEventDto.longitude = geocodeResult.longitude;
          updateEventDto.locationName = geocodeResult.displayName;
        } catch (error) {
          throw new BadRequestException(`Unable to find location for city "${updateEventDto.cityName}": ${error.message}`);
        }
      }
    }

    // Handle copying tracks from another playlist if selectedPlaylistId is provided
    if (updateEventDto.selectedPlaylistId) {
      const sourcePlaylist = await this.eventRepository.findOne({
        where: { id: updateEventDto.selectedPlaylistId },
        relations: ['tracks', 'tracks.track'],
      });

      if (!sourcePlaylist) {
        throw new NotFoundException('Source playlist not found');
      }

      // Only allow copying if user owns the source playlist or is authorized
      if (sourcePlaylist.creatorId !== userId) {
        throw new ForbiddenException('You can only copy playlists you own');
      }

      // Clear existing tracks and copy from source
      event.tracks = [];
      await this.eventRepository.save(event);

      // Copy tracks from source playlist
      if (sourcePlaylist.tracks && sourcePlaylist.tracks.length > 0) {
        const newTracks = sourcePlaylist.tracks.map(pt => ({
          ...pt,
          id: undefined, // Remove ID to create new instances
          event: event, // Associate with current event
        }));

        const trackRepository = this.eventRepository.manager.getRepository(PlaylistTrack);
        await trackRepository.save(newTracks);
      }

      // Remove selectedPlaylistId from the DTO after copying
      delete updateEventDto.selectedPlaylistId;
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
  async addParticipant(eventId: string, userId: string, userLocation?: LocationDto): Promise<void> {
    const event = await this.eventRepository.findOne({
      where: { id: eventId },
      relations: ['participants'],
    });

    if (!event) {
      throw new NotFoundException('Event not found');
    }

    // Check if already participating
    const isParticipating = event.participants?.some(p => p.userId === userId);
    if (isParticipating) {
      throw new ConflictException('User is already participating in this event');
    }

    // Check access permissions
    await this.checkEventAccess(event, userId);

    // For location-based events, verify user location permissions (skip for event creators)
    if (event.licenseType === EventLicenseType.LOCATION_BASED && event.creatorId !== userId) {
      if (!userLocation) {
        throw new BadRequestException('Location is required to join this location-based event');
      }
      
      const hasLocationPermission = await this.checkLocationPermission(eventId, userLocation, userId);
      if (!hasLocationPermission) {
        throw new ForbiddenException('You are not within the required location radius to join this event');
      }
    }

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
      throw new BadRequestException('Event creator cannot be removed from the event');
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
        'participants'
      ]
    });

    if (!event)
      throw new NotFoundException('Event not found');
    
    // Only creator or existing admin can promote
    if (event.creatorId !== actorId && !(event.participants?.some(a => a.userId === actorId))) {
      throw new ForbiddenException('Only creator or admin can promote another user');
    }
    
    // Creator is automatically an admin and cannot be promoted
    if (event.creatorId === userId) {
      throw new BadRequestException('Event creator is already an admin by default');
    }

    // Check if user has access to this event (creator, participant, or playlist collaborator)
    const hasAccess = event.creatorId === userId ||
      event.participants?.some(p => p.userId === userId)

    if (!hasAccess) {
      throw new ForbiddenException('User must have access to the event to be promoted to admin');
    }
    
    // Add user as participant if not already participating
    const isParticipant = event.participants?.some(p => p.userId === userId);
    if (!isParticipant) {
      // Add directly without access check since we already verified access above
      const user = await this.userRepository.findOne({ where: { id: userId } });
      if (!user) {
        throw new NotFoundException('User not found');
      }

      await this.eventRepository
        .createQueryBuilder()
        .relation(Event, 'participants')
        .of(eventId)
        .add(userId);

      // Notify other participants
      this.eventGateway.notifyParticipantJoined(eventId, user);
    }

    // Check if already admin
    if (event.participants?.some(a => a.userId === userId && a.role === ParticipantRole.ADMIN)) {
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
        'participants',
      ]
    });

    if (!event) {
      throw new NotFoundException('Event not found');
    }
    // Only creator or existing admin can remove
    if (event.creatorId !== actorId && !(event.participants?.some(a => a.userId === actorId && a.role === ParticipantRole.ADMIN))) {
      throw new ForbiddenException('Only creator or admin can remove another admin');
    }
    // Can't remove creator from admins
    if (event.creatorId === userId) {
      throw new BadRequestException('Cannot remove creator from admins');
    }
    // Check if user is actually an admin
    if (!event.participants?.some(a => a.userId === userId && a.role === ParticipantRole.ADMIN)) {
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
  async voteForTrack(eventId: string, userId: string, voteDto: CreateVoteDto)/* : Promise<TrackVoteSnapshot[]> */ {

    const event = await this.findById(eventId, userId);

    // Check if user can vote
    await this.checkVotingPermissions(event, userId);

    // Get track
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

    // Verify track is in the event (now tracks are directly on Event)
    const playlistTrackId = event.tracks?.find(pt => pt.trackId === voteDto.trackId)?.id;
    if (!playlistTrackId) {
      throw new BadRequestException('Track is not in the event playlist');
    }


    // Create vote
    const vote = this.voteRepository.create({
      eventId,
      userId,
      trackId: voteDto.trackId,
      playlistTrackId,
      type: voteDto.type || VoteType.UPVOTE,
      weight: voteDto.weight || 1,
    });

    await this.voteRepository.save(vote);

    /* // Get updated voting results
    const results = await this.getVotingResults(eventId, userId);

    // Reorder playlist tracks based on votes
    await this.reorderPlaylistByVotes(eventId); */

    // Notify participants
    this.eventGateway.notifyVoteUpdated(eventId, vote/* , results */);

    return;
  }

  async removeVotesOfTrack(eventId: string, trackId: string): Promise<void> {
    const event = await this.eventRepository.findOne({ where: { id: eventId } });

    if (!event) {
      throw new NotFoundException('Event not found');
    }

    const votesToRemove = await this.voteRepository.find({
      where: { eventId, trackId },
      relations: ['user'],
    });

    // Remove all votes for the specified track
    await this.voteRepository.delete({
      eventId,
      trackId,
    });

    // Get updated voting results after removal
    // const results = await this.getVotingResults(eventId);

    // Reorder playlist tracks based on updated votes
    // await this.reorderPlaylistByVotes(eventId);

    // Notify all participants about each removed vote (users regain their vote capacity)
    for (const vote of votesToRemove) {
      this.eventGateway.notifyVoteRemoved(eventId, vote);
    }
  }

  async removeVote(eventId: string, userId: string, trackId: string)/* : Promise<TrackVoteSnapshot[]> */ {
    const event = await this.findById(eventId, userId);

    const vote = await this.voteRepository.findOne({
      where: { eventId, userId, trackId },
    });

    if (!vote) {
      throw new NotFoundException('Vote not found');
    }

    await this.voteRepository.remove(vote);

    // Get updated voting results
    // const results = await this.getVotingResults(eventId);

    // Reorder playlist tracks based on votes
    // await this.reorderPlaylistByVotes(eventId);

    // Notify participants (without user-specific vote data)
    this.eventGateway.notifyVoteRemoved(eventId, vote);

    // return results;
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
        relations: ['tracks'],
      });

      if (!event?.tracks) {
        return;
      }

      /* // Get voting results for this event
      const voteResults = await this.getVotingResults(eventId);
      return;
      const playlistTracks = voteResults.sort((a, b) => a.position - b.position)

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
 */
    } catch (error) {
      console.error('Failed to reorder playlist by votes:', error);
      // Don't throw the error to avoid disrupting the voting process
    }
  }

  /* async getVotingResults(eventId: string, userId?: string): Promise<VoteResult[]> {
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

    // Calculate vote results for ALL tracks in the playlist
    const results: VoteResult[] = [];
    
    // Sort playlist tracks by position to maintain consistent order
    const sortedPlaylistTracks = event.playlist.playlistTracks.sort((a, b) => a.position - b.position);
    
    for (const playlistTrack of sortedPlaylistTracks) {
      const track = playlistTrack.track;
      const trackVoteList = trackVotes.get(track.id) || [];
      
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
  } */

  async getVotingResults(eventId: string, userId?: string)/* : Promise<TrackVoteSnapshot[]>  */{
    const votes = await this.voteRepository
      .createQueryBuilder('vote')
      .leftJoinAndSelect('vote.track', 'track')
      .where('vote.eventId = :eventId', { eventId })
      .getMany();

      return votes;

    // Grouper par track
    const trackVotes = new Map<string, Vote[]>();
    votes.forEach(vote => {
      if (!trackVotes.has(vote.trackId)) {
        trackVotes.set(vote.trackId, []);
      }
      trackVotes.get(vote.trackId)!.push(vote);
    });

    // Créer les snapshots
    const tracks: TrackVoteSnapshot[] = [];
    for (const [trackId, voteList] of trackVotes) {
      const upvotes = voteList.filter(v => v.type === VoteType.UPVOTE).length;
      const downvotes = voteList.filter(v => v.type === VoteType.DOWNVOTE).length;
      
      tracks.push({
        trackId,
        upvotes,
        downvotes,
        position: 0 // Sera mis à jour après tri
      });
    }

    // Trier et mettre à jour positions
    tracks.sort((a, b) => (b.upvotes - b.downvotes) - (a.upvotes - a.downvotes));
    tracks.forEach((track, index) => track.position = index + 1);

    return tracks;
  }

  // Location-based features
  async findNearbyEvents(location: LocationDto, radiusKm = 10, userId?: string) {
    const { latitude, longitude } = location;

    const events = await this.eventRepository
      .createQueryBuilder('event')
      .leftJoinAndSelect('event.creator', 'creator')
      .leftJoinAndSelect('event.participants', 'participants')
      .leftJoinAndSelect('participants.user', 'participantUser')
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

  async checkLocationPermission(eventId: string, userLocation: LocationDto, userId?: string): Promise<boolean> {
    const event = await this.eventRepository.findOne({ where: { id: eventId } });

    if (!event || event.licenseType !== EventLicenseType.LOCATION_BASED) {
      return true; // Not location-based
    }

    // Event creators and admins bypass location restrictions
    if (userId && (event.creatorId === userId || event.participants?.some(a => a.userId === userId && a.role === ParticipantRole.ADMIN))) {
      return true;
    }

    if (!event.latitude || !event.longitude || !event.locationRadius) {
      return false;
    }

    // Calculate distance - this is the only check for joining events
    const distance = this.calculateDistance(
      userLocation.latitude,
      userLocation.longitude,
      event.latitude,
      event.longitude,
    );

    return distance <= (event.locationRadius / 1000); // Convert meters to km
  }

  private async checkVotingTimePermission(event: Event, userId?: string): Promise<boolean> {
    // Event creators and admins bypass time restrictions
    if (userId && (event.creatorId === userId || event.participants?.some(a => a.userId === userId && a.role === ParticipantRole.ADMIN))) {
      return true;
    }

    // Check if current time is within voting hours (only applies to location-based events)
    if (event.licenseType === EventLicenseType.LOCATION_BASED && event.votingStartTime && event.votingEndTime) {
      const now = new Date();
      const currentTime = now.toTimeString().substring(0, 5); // HH:MM format

      if (currentTime < event.votingStartTime || currentTime > event.votingEndTime) {
        return false;
      }
    }

    return true;
  }

  // Event State Management
  async startEvent(eventId: string, userId: string): Promise<Event> {
    const event = await this.findById(eventId, userId);

    if (event.creatorId !== userId && !event.participants?.some(a => a.userId === userId && a.role === ParticipantRole.ADMIN)) {
      throw new ForbiddenException('Only the creator or admin can start the event');
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

    if (event.creatorId !== userId && !event.participants?.some(a => a.userId === userId && a.role === ParticipantRole.ADMIN)) {
      throw new ForbiddenException('Only the creator or admin can end the event');
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

/*   async playNextTrack(eventId: string, userId: string): Promise<TrackVoteSnapshot | null> {
    const event = await this.findById(eventId, userId);

    const isCreator = event.creatorId === userId;
    const isAdmin = event.participants?.some(a => a.userId === userId && a.role === ParticipantRole.ADMIN) || false;

    if (!isCreator && !isAdmin) {
      throw new ForbiddenException('Only the creator or admins can control playback');
    }

    // Get top voted track
    const tracks = await this.getVotingResults(eventId);
    const nextTrack = tracks.length > 0 ? tracks[0] : null;

    if (nextTrack) {
      event.currentTrackId = nextTrack.trackId;
      event.currentTrackStartedAt = new Date();
      await this.eventRepository.save(event);

      // Notify participants
      this.eventGateway.notifyNowPlaying(eventId, nextTrack);

      // Remove votes for the played track to avoid replay
      await this.voteRepository.delete({ eventId, trackId: nextTrack.trackId });
    }

    return nextTrack;
  } */

  async setCurrentTrack(eventId: string, trackId: string, userId: string): Promise<void> {
    console.log("🎵 setCurrentTrack called with:", { eventId, trackId, userId });
    try {
      

      const event = await this.findById(eventId, userId);

      if (!event) {
        throw new NotFoundException('Event not found');
      }

      console.log("🎵 Current event currentTrackId before update:", event.currentTrackId);
      console.log("🎵 Requested trackId:", trackId);
      console.log("🎵 Available tracks in playlist:");
      event.tracks?.forEach(element => {
        console.log("  - trackId:", element.trackId, "position:", element.position);
      });

      // Vérifier que la track existe dans la playlist de l'event (tracks are now directly on Event)
      const trackExists = event.tracks?.some(pt => pt.trackId === trackId);
      if (!trackExists) {
        throw new NotFoundException(`Track ${trackId} not found in event playlist`);
      }

      // Vérifier que la track existe vraiment dans la DB (crucial pour la relation)
      const track = await this.trackRepository.findOne({ where: { id: trackId } });
      if (!track) {
        throw new NotFoundException(`Track ${trackId} does not exist in database`);
      }
      console.log("🎵 Track found in DB:", track.title, "by", track.artist);

      // Only creator or existing admin can set current track
      if (event.creatorId !== userId && !(event.participants?.some(a => a.userId === userId && a.role === ParticipantRole.ADMIN))) {
        throw new ForbiddenException('Only creator and admins can set current track');
      }

      /* A vérifier (chatGPT) ⚠️
      Si tu mets à jour currentTrackId et recharges l’entité avec la relation, tu obtiens bien l’entité Track correspondante dans currentTrack.
      La synchronisation se fait à la lecture, pas à l’écriture. NON C FAUX
      */
      // SOLUTION: Assigner directement la relation ET l'ID pour éviter les problèmes de cohérence
      event.currentTrack = track;  // ✅ Assigne la relation directement
      event.currentTrackId = trackId;  // ✅ Assigne aussi l'ID pour la cohérence
      event.currentTrackStartedAt = new Date();
      
      const savedEvent = await this.eventRepository.save(event);
      
      console.log("🎵 Event saved with currentTrackId:", savedEvent.currentTrackId);
      console.log("🎵 Event saved with currentTrackStartedAt:", savedEvent.currentTrackStartedAt);

      // Notify participants
      this.eventGateway.notifyNowPlaying(eventId, trackId);
    } catch (error) {
      console.error('ERROR:', error);
      
    }
  }

  // Update current track for an event (for music synchronization)
  async updateCurrentTrack(eventId: string, trackId: string): Promise<void> {
    const event = await this.eventRepository.findOne({ where: { id: eventId } });
    if (!event) {
      throw new NotFoundException('Event not found');
    }

    // Verify the track exists
    const track = await this.trackRepository.findOne({ where: { id: trackId } });
    if (!track) {
      throw new NotFoundException('Track not found');
    }

    // Update current track and reset playback position to start
    event.currentTrackId = trackId;
    event.currentTrackStartedAt = new Date();
    // CRITICAL: Reset position to 0 when changing tracks
    event.currentPosition = 0;
    event.lastPositionUpdate = new Date();
    await this.eventRepository.save(event);
  }

  // Update playback state for precise synchronization
  async updatePlaybackState(eventId: string, isPlaying: boolean, currentPosition: number): Promise<void> {
    const event = await this.eventRepository.findOne({ where: { id: eventId } });
    if (!event) {
      throw new NotFoundException('Event not found');
    }

    // Update playback state with precise timing
    event.isPlaying = isPlaying;
    event.currentPosition = currentPosition;
    event.lastPositionUpdate = new Date();
    
    // If resuming playback, adjust start time to account for current position
    if (isPlaying && event.currentTrackStartedAt) {
      event.currentTrackStartedAt = new Date(Date.now() - (currentPosition * 1000));
    }
    
    await this.eventRepository.save(event);
  }

  // Calculate current playback position accounting for paused state
  async getCurrentPlaybackPosition(eventId: string): Promise<{ position: number; isPlaying: boolean; trackId: string | null }> {
    const event = await this.eventRepository.findOne({ where: { id: eventId } });
    if (!event || !event.currentTrackId) {
      return { position: 0, isPlaying: false, trackId: null };
    }

    if (!event.isPlaying) {
      // If paused, return the stored position
      return { 
        position: parseFloat(event.currentPosition?.toString() || '0'), 
        isPlaying: false, 
        trackId: event.currentTrackId 
      };
    }

    // If playing, calculate current position = stored position + elapsed time since resumed
    const storedPosition = parseFloat(event.currentPosition?.toString() || '0');
    const elapsedTime = event.lastPositionUpdate ? 
      Math.floor((Date.now() - event.lastPositionUpdate.getTime()) / 1000) : 0;
    
    const currentPosition = storedPosition + elapsedTime;
    
    return { 
      position: currentPosition, 
      isPlaying: true, 
      trackId: event.currentTrackId 
    };
  }

  /** Récupère tous les events où l'utilisateur est créateur, participant, ou collaborateur de playlist, avec les admins */
  async getEventsUserCanInviteWithAdmins(userId: string): Promise<Event[]> {
    const events = await this.eventRepository
      .createQueryBuilder('event')
      .leftJoinAndSelect('event.participants', 'participant')
      .leftJoinAndSelect('participant.user', 'participantUser')
      .where('event.creatorId = :userId', { userId })
      .orWhere('participant.userId = :userId', { userId })
      .getMany();

    console.log('Events user can invite with admins:', events);
    const timeZone = 'Europe/Paris';
    return events.map(event => ({
      ...event,
      // eventDate: toZonedTime(new Date(event.eventDate), timeZone),
      // eventEndDate: toZonedTime(new Date(event.eventEndDate), timeZone),
      status: this.computeStatus(event),
    }));
  }

  // Invitation System
  async inviteUsers(eventId: string, inviterUserId: string, inviteeIds: string[], message?: string): Promise<any> {
    const event = await this.findById(eventId, inviterUserId);

    // Only creator or participants can invite (depending on license)
    const canInvite = event.creatorId === inviterUserId ||
      event.participants?.some(p => p.userId === inviterUserId);

    if (!canInvite) {
      throw new ForbiddenException('You cannot invite users to this event');
    }

    const inviter = await this.userRepository.findOne({ where: { id: inviterUserId } });

    const createdInvitations: Invitation[] = [];
    const skipped: { userId: string; reason: string }[] = [];
    const uniqueInviteeIds = Array.from(new Set(inviteeIds));

    for (const inviteeId of uniqueInviteeIds) {
      if (inviteeId === inviterUserId) {
        skipped.push({ userId: inviteeId, reason: 'cannot_invite_self' });
        continue;
      }

      const invitee = await this.userRepository.findOne({ where: { id: inviteeId } });

      if (!invitee) {
        skipped.push({ userId: inviteeId, reason: 'user_not_found' });
        continue;
      }

      if (event.participants?.some(p => p.userId === inviteeId)) {
        skipped.push({ userId: inviteeId, reason: 'already_participant' });
        continue;
      }

      if (event.participants?.some(a => a.role === ParticipantRole.ADMIN &&  a.userId === inviteeId) || event.creatorId === inviteeId) {
        skipped.push({ userId: inviteeId, reason: 'already_admin' });
        continue;
      }

      const existingInvitation = await this.invitationRepository.findOne({
        where: {
          eventId,
          inviteeId,
          type: InvitationType.EVENT,
        },
        order: { createdAt: 'DESC' },
      });

      const expiresAt = new Date(Date.now() + 7 * 24 * 60 * 60 * 1000);

      if (existingInvitation && existingInvitation.status === InvitationStatus.PENDING) {
        skipped.push({ userId: inviteeId, reason: 'already_invited' });
        continue;
      }

      let savedInvitation: Invitation;

      if (existingInvitation) {
        existingInvitation.status = InvitationStatus.PENDING;
        existingInvitation.message = message;
        existingInvitation.inviterId = inviterUserId;
        existingInvitation.expiresAt = expiresAt;
        savedInvitation = await this.invitationRepository.save(existingInvitation);
      } else {
        const invitation = this.invitationRepository.create({
          inviterId: inviterUserId,
          inviteeId,
          eventId,
          type: InvitationType.EVENT,
          status: InvitationStatus.PENDING,
          message,
          expiresAt,
        });

        savedInvitation = await this.invitationRepository.save(invitation);
      }

      createdInvitations.push(savedInvitation);

      if (invitee.email) {
        const baseUrl = process.env.FRONTEND_URL || 'https://music-room.com';
        const eventUrl = `${baseUrl}/events/${eventId}`;
        await this.emailService.sendEventInvitation(
          invitee.email,
          event.name,
          inviter?.displayName || 'A friend',
          eventUrl,
        );
      }
    }

    return { invitations: createdInvitations, skipped };
  }

  // Helper Methods
  private async addEventStats(event: Event, userId?: string): Promise<EventWithStats> {
    const participantCount = event.participants?.length || 0;
    const voteCount = event.votes?.length || 0;
    
    // Get unique tracks from votes
    const uniqueTrackIds = new Set(event.votes?.map(v => v.trackId) || []);
    const trackCount = uniqueTrackIds.size;
    const timeZone = 'Europe/Paris';
    const isUserParticipating = userId ? 
      event.participants?.some(p => p.userId === userId) || false : false;

    return {
      ...event,
      // eventDate: toZonedTime(new Date(event.eventDate), timeZone),
      // eventEndDate: toZonedTime(new Date(event.eventEndDate), timeZone),
      status: this.computeStatus(event),
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

    // Check if user is a participant (any role: admin, collaborator, or participant)
    const isParticipant = event.participants?.some(
      participant => participant.userId === userId
    );
    
    if (isParticipant) {
      return; // User is a participant (admin, collaborator, or participant)
    }

    // Check if user is invited
    const invitation = await this.invitationRepository.findOne({
      where: {
        eventId: event.id,
        inviteeId: userId,
        status: InvitationStatus.ACCEPTED,
      },
    });

    if (invitation) {
      return; // User has an accepted invitation
    }

    throw new ForbiddenException('You are not invited to this private event');
  }

  private async checkVotingPermissions(event: Event, userId: string): Promise<void> {
    // Check if event should be live based on dates (fallback for cron job delays)
    const now = new Date();
    let effectiveStatus = event.status;
    
    if (event.eventDate && event.endDate) {
      if (now >= event.eventDate && now < event.endDate) {
        effectiveStatus = EventStatus.LIVE;
        
        // Update status in database if it's different
        if (event.status !== EventStatus.LIVE) {
          await this.eventRepository.update(event.id, { status: EventStatus.LIVE });
        }
      } else if (now >= event.endDate && event.status === EventStatus.LIVE) {
        effectiveStatus = EventStatus.ENDED;
        await this.eventRepository.update(event.id, { status: EventStatus.ENDED });
      }
    }

    if (effectiveStatus === EventStatus.ENDED) {
      throw new BadRequestException('Voting is only allowed during live events');
    }

    if (event.visibility === EventVisibility.PUBLIC && event.licenseType === EventLicenseType.NONE)
        return; // Everyone can vote

    if ( event.visibility === EventVisibility.PRIVATE ) {
        // Check if user is the event creator
        if (event.creatorId === userId) {
          return;
        }

        // Check if user is an admin
        if (event.participants?.some(a => a.userId === userId && a.role === ParticipantRole.ADMIN)) {
          return;
        }

        // Check if user has an accepted invitation
        const invitation = await this.invitationRepository.findOne({
          where: {
            eventId: event.id,
            inviteeId: userId,
            status: InvitationStatus.ACCEPTED,
          },
        });

        if (invitation) {
          return;
        }

        // Check if user is a participant on the event
        const isParticipant = event.participants?.some(
          participant => participant.userId === userId
        );
        
        if (isParticipant) {
          return;
        }

        throw new ForbiddenException('Only invited users can vote in this event');

      }

      // Event creators can always vote in their own events
      if ( event.licenseType === EventLicenseType.LOCATION_BASED ) {
        
        if (event.creatorId === userId) {
          return;
        }
        
        // Event admins can always vote
        if (event.participants?.some(a => a.userId === userId && a.role === ParticipantRole.ADMIN)) {
          return;
        }
        
        // Check voting time restrictions for location-based events
        const canVoteByTime = await this.checkVotingTimePermission(event, userId);
        if (!canVoteByTime) {
          throw new ForbiddenException('Voting is not allowed outside the specified voting hours for this location-based event');
        }
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

  computeStatus(event: Event): EventStatus {
    // For playlists or events without dates, return the stored status or default to UPCOMING
    if (!event.eventDate || !event.endDate) {
      return event.status || EventStatus.UPCOMING;
    }

    // Convertit la date courante en heure de Paris
    const timeZone = 'Europe/Paris';
    const now = toZonedTime(new Date(), timeZone);

    const start = toZonedTime(new Date(event.eventDate), timeZone);
    const end = toZonedTime(new Date(event.endDate), timeZone);

    if (now < start) return EventStatus.UPCOMING;
    if (now >= start && now <= end) return EventStatus.LIVE;
    return EventStatus.ENDED;
  }

  // =====================================================
  // PLAYLIST MANAGEMENT (Event-centric approach)
  // All playlist operations go through Event
  // =====================================================

  /**
   * Get all tracks in an event/playlist
   */
  async getPlaylistTracks(eventId: string): Promise<any[]> {
    const event = await this.eventRepository.findOne({
      where: { id: eventId },
      relations: ['tracks', 'tracks.track', 'tracks.addedBy'],
    });

    if (!event) {
      throw new NotFoundException('Event not found');
    }

    // Sort by position and map to the expected format
    return event.tracks
      .sort((a, b) => a.position - b.position)
      .map(playlistTrack => ({
        id: playlistTrack.id,
        eventId: playlistTrack.eventId,
        trackId: playlistTrack.trackId,
        position: playlistTrack.position,
        votes: 0, // TODO: Calculate actual votes
        trackTitle: playlistTrack.track?.title,
        trackArtist: playlistTrack.track?.artist,
        trackAlbum: playlistTrack.track?.album,
        coverUrl: playlistTrack.track?.albumCoverUrl,
        previewUrl: playlistTrack.track?.previewUrl,
        duration: playlistTrack.track?.duration,
        createdAt: playlistTrack.createdAt,
        updatedAt: playlistTrack.addedAt || playlistTrack.createdAt,
      }));
  }

  /**
   * Remove a track from an event/playlist
   */
  async removeTrack(eventId: string, trackId: string, userId: string): Promise<void> {
    const event = await this.findById(eventId, userId);

    // Only creator or admin can remove tracks
    const isCreator = event.creatorId === userId;
    const isAdmin = event.participants?.some(p => p.userId === userId && p.role === ParticipantRole.ADMIN);

    if (!isCreator && !isAdmin) {
      throw new ForbiddenException('Only the creator or admins can remove tracks');
    }

    // Find and remove the track
    const playlistTrackRepository = this.eventRepository.manager.getRepository('PlaylistTrack');
    const playlistTrack = await playlistTrackRepository.findOne({
      where: { eventId, trackId },
    });

    if (!playlistTrack) {
      throw new NotFoundException('Track not found in this event');
    }

    // Store position before removal
    const removedPosition = playlistTrack.position;

    // Remove votes for this track
    await this.removeVotesOfTrack(eventId, trackId);

    // Delete the track
    await playlistTrackRepository.remove(playlistTrack);

    // Recompute positions for tracks after the removed one
    const tracksToUpdate = await playlistTrackRepository.find({
      where: { eventId },
      order: { position: 'ASC' },
    });

    // Update positions to fill the gap
    for (const track of tracksToUpdate) {
      if (track.position > removedPosition) {
        track.position = track.position - 1;
      }
    }
    await playlistTrackRepository.save(tracksToUpdate);

    // Update track count
    event.trackCount = Math.max(0, (event.trackCount || 0) - 1);
    await this.eventRepository.save(event);

    // Notify participants
    this.eventGateway.notifyTrackRemoved(eventId, trackId, userId);
  }

  /**
   * Add a track to an event/playlist
   */
  async addTrack(eventId: string, userId: string, dto: AddTrackToPlaylistDto): Promise<any> {
    const event = await this.findById(eventId, userId);

    // Only creator or admin can add tracks
    const isCreator = event.creatorId === userId;
    const isAdmin = event.participants?.some(p => p.userId === userId && p.role === ParticipantRole.ADMIN);

    if (!isCreator && !isAdmin) {
      throw new ForbiddenException('Only the creator or admins can add tracks');
    }

    // Get or create track from Deezer ID
    let track = await this.trackRepository.findOne({ where: { deezerId: dto.deezerId } });
    if (!track) {
      track = this.trackRepository.create({
        deezerId: dto.deezerId,
        title: dto.title,
        artist: dto.artist,
        album: dto.album,
        albumCoverUrl: dto.albumCoverUrl,
        previewUrl: dto.previewUrl,
        duration: dto.duration,
      });
      track = await this.trackRepository.save(track);
    }

    // Get current track count to set position
    const playlistTrackRepository = this.eventRepository.manager.getRepository('PlaylistTrack');
    const count = await playlistTrackRepository.count({ where: { eventId } });

    // Create playlist track
    const playlistTrack = playlistTrackRepository.create({
      eventId,
      trackId: track.id,
      position: dto.position || count + 1,
      addedById: userId,
      addedAt: new Date(),
    });

    const saved = await playlistTrackRepository.save(playlistTrack);

    // Update event track count and duration
    event.trackCount = (event.trackCount || 0) + 1;
    event.totalDuration = (event.totalDuration || 0) + (track.duration || 0);
    await this.eventRepository.save(event);

    // Notify participants
    this.eventGateway.notifyTrackAdded(eventId, saved, userId);

    // Return formatted response matching Flutter model expectations
    return {
      id: saved.id,
      eventId: saved.eventId,
      trackId: saved.trackId,
      position: saved.position,
      votes: 0,
      trackTitle: track.title,
      trackArtist: track.artist,
      trackAlbum: track.album,
      coverUrl: track.albumCoverUrl,
      previewUrl: track.previewUrl,
      duration: track.duration,
      createdAt: saved.createdAt,
      updatedAt: saved.addedAt || saved.createdAt,
    };
  }

  /**
   * Reorder playlist tracks using an ordered list of playlist-track IDs
   */
  async reorderPlaylistTracks(playlistId: string, userId: string, trackIds: string[]): Promise<void> {
    const event = await this.findById(playlistId, userId);

    // Permission: only creator or admins
    const isCreator = event.creatorId === userId;
    const isAdmin = event.participants?.some(p => p.userId === userId && p.role === ParticipantRole.ADMIN);

    if (!isCreator && !isAdmin) {
      throw new ForbiddenException('Only the creator or admins can reorder tracks');
    }

    const playlistTrackRepository = this.eventRepository.manager.getRepository('PlaylistTrack');
    const existingTracks = await playlistTrackRepository.find({ where: { eventId: playlistId } });

    if (!existingTracks || existingTracks.length === 0) {
      throw new NotFoundException('No tracks found for this playlist');
    }

    // Ensure provided list covers exactly the existing tracks
    if (trackIds.length !== existingTracks.length) {
      throw new BadRequestException('trackIds length does not match current playlist track count');
    }

    // Map by id for quick lookup
    const byId = new Map(existingTracks.map((t: any) => [t.id, t]));

    const toSave: any[] = [];
    for (let i = 0; i < trackIds.length; i++) {
      const id = trackIds[i];
      const pt = byId.get(id);
      if (!pt) {
        throw new NotFoundException(`Playlist track not found: ${id}`);
      }
      pt.position = i + 1;
      toSave.push(pt);
    }

    await playlistTrackRepository.save(toSave);

    // Notify participants via gateway
    this.eventGateway.notifyTracksReordered(playlistId, trackIds, userId);
  }
}
