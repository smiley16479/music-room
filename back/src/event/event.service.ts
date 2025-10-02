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
import { Vote, VoteType } from 'src/event/entities/vote.entity';
import { Track } from 'src/music/entities/track.entity';
import { User } from 'src/user/entities/user.entity';
import { Invitation, InvitationType, InvitationStatus } from 'src/invitation/entities/invitation.entity';

import { CreateEventDto } from './dto/create-event.dto';
import { UpdateEventDto } from './dto/update-event.dto';
import { LocationDto } from '../common/dto/location.dto';
import { CreateVoteDto } from './dto/vote.dto';
import { PaginationDto } from '../common/dto/pagination.dto';

import { PlaylistService } from 'src/playlist/playlist.service';
import { EmailService } from '../email/email.service';
import { EventGateway } from './event.gateway';
import { GeocodingService } from '../common/services/geocoding.service';
import { Playlist } from 'src/playlist/entities/playlist.entity';
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
    @Inject(forwardRef(() => PlaylistService))
    private readonly playlistService: PlaylistService,
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

    this.eventGateway.notifyEventCreated(savedEvent, creator);

    return this.findById(savedEvent.id, creatorId);
  }

  async findAll(paginationDto: PaginationDto, userId?: string, userLocation?: LocationDto) {
    const { page, limit, skip } = paginationDto;

    const queryBuilder = this.eventRepository.createQueryBuilder('event')
      .leftJoinAndSelect('event.creator', 'creator')
      .leftJoinAndSelect('event.participants', 'participants')
      .leftJoinAndSelect('event.admins', 'admins')
      .leftJoinAndSelect('event.currentTrack', 'currentTrack')
      .leftJoinAndSelect('event.playlist', 'playlist')
      .leftJoinAndSelect('playlist.collaborators', 'playlistCollaborators');

    if (userId) {
      // Show public events + private events where user has access (creator, participant, admin, or playlist collaborator)
      queryBuilder
        .where('event.visibility = :visibility', { visibility: EventVisibility.PUBLIC })
        .orWhere('event.creatorId = :userId', { userId })
        .orWhere('participants.id = :userId', { userId })
        .orWhere('admins.id = :userId', { userId })
        .orWhere('playlistCollaborators.id = :userId', { userId });
    } else {
      // For unauthenticated users, only show public events
      queryBuilder.where('event.visibility = :visibility', { visibility: EventVisibility.PUBLIC });
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
      relations: ['creator', 'participants', 'admins', 'currentTrack', 
        'playlist', 'playlist.playlistTracks', 'playlist.collaborators',
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

    Object.assign(event, updateEventDto);
    const updatedEvent = await this.eventRepository.save(event);

    // Update associated playlist license type if it exists and license type changed
    if (updatedEvent.playlist && updateEventDto.licenseType && updateEventDto.licenseType !== originalLicenseType) {
      try {
        await this.eventRepository.manager.query(
          'UPDATE playlists SET license_type = $1 WHERE id = $2',
          [updateEventDto.licenseType, updatedEvent.playlist.id]
        );
        console.log(`📝 Updated playlist ${updatedEvent.playlist.id} license type from ${originalLicenseType} to ${updateEventDto.licenseType}`);
      } catch (error) {
        console.error(`❌ Failed to update playlist license type:`, error);
      }
    }

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
      relations: ['participants', 'playlist', 'playlist.collaborators'],
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

    /*// Can't remove creator
    if (event.creatorId === userId) {
      throw new BadRequestException('Event creator cannot leave the event');
    }*/

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
        'playlist',
        'playlist.collaborators'
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

    // Check if user has access to this event (creator, participant, or playlist collaborator)
    const hasAccess = event.creatorId === userId ||
      event.participants?.some(p => p.id === userId) ||
      (event.playlist?.collaborators?.some(c => c.id === userId));

    if (!hasAccess) {
      throw new ForbiddenException('User must have access to the event to be promoted to admin');
    }
    
    // Add user as participant if not already participating
    const isParticipant = event.participants?.some(p => p.id === userId);
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

    const playlistTrackId = event.playlist?.playlistTracks?.find(pt => pt.trackId === voteDto.trackId)?.id;
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
        relations: ['playlist', 'playlist.playlistTracks'],
      });

      if (!event?.playlist?.playlistTracks) {
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
    if (userId && (event.creatorId === userId || event.admins?.some(admin => admin.id === userId))) {
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
    if (userId && (event.creatorId === userId || event.admins?.some(admin => admin.id === userId))) {
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

    if (event.creatorId !== userId && !event.admins?.some(admin => admin.id === userId)) {
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

    if (event.creatorId !== userId && !event.admins?.some(admin => admin.id === userId)) {
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
    const isAdmin = event.admins?.some(admin => admin.id === userId) || false;

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
      event.playlist?.playlistTracks.forEach(element => {
        console.log("  - trackId:", element.trackId, "position:", element.position);
      });

      // Vérifier que la track existe dans la playlist de l'event
      const trackExists = event.playlist?.playlistTracks.some(pt => pt.trackId === trackId);
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
      if (event.creatorId !== userId && !(event.admins?.some(a => a.id === userId))) {
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
      .leftJoinAndSelect('event.admins', 'admin')
      .leftJoinAndSelect('event.playlist', 'playlist')
      .leftJoinAndSelect('playlist.collaborators', 'playlistCollaborators')
      .leftJoinAndSelect('event.creator', 'creator')
      .where('event.creatorId = :userId', { userId })
      .orWhere('participant.id = :userId', { userId })
      .orWhere('playlistCollaborators.id = :userId', { userId })
      .getMany();

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
      event.participants?.some(p => p.id === inviterUserId);

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

      if (event.participants?.some(p => p.id === inviteeId)) {
        skipped.push({ userId: inviteeId, reason: 'already_participant' });
        continue;
      }

      if (event.admins?.some(a => a.id === inviteeId) || event.creatorId === inviteeId) {
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
      event.participants?.some(p => p.id === userId) || false : false;

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

    // Check if user is an admin
    if (event.admins?.some(admin => admin.id === userId)) {
      return; // User is an admin
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

    // Check if user is a collaborator on the event's playlist
    if (event.playlist && event.playlist.id) {
      const playlistWithCollaborators = await this.playlistRepository.findOne({
        where: { id: event.playlist.id },
        relations: ['collaborators'],
      });

      if (playlistWithCollaborators && playlistWithCollaborators.collaborators) {
        const isPlaylistCollaborator = playlistWithCollaborators.collaborators.some(
          collaborator => collaborator.id === userId
        );
        
        if (isPlaylistCollaborator) {
          return; // User is a playlist collaborator
        }
      }
    }

    throw new ForbiddenException('You are not invited to this private event');
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
        }
      } else if (now >= event.eventEndDate && event.status === EventStatus.LIVE) {
        effectiveStatus = EventStatus.ENDED;
        await this.eventRepository.update(event.id, { status: EventStatus.ENDED });
      }
    }

    if (effectiveStatus === EventStatus.ENDED) {
      throw new BadRequestException('Voting is only allowed during live events');
    }

    switch (event.licenseType) {
      case EventLicenseType.OPEN:
        return; // Everyone can vote

      case EventLicenseType.INVITED:
        // Check if user is the event creator
        if (event.creatorId === userId) {
          return;
        }

        // Check if user is an admin
        if (event.admins?.some(admin => admin.id === userId)) {
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

        // Check if user is a collaborator on the event's playlist
        if (event.playlist && event.playlist.id) {
          const playlistWithCollaborators = await this.playlistRepository.findOne({
            where: { id: event.playlist.id },
            relations: ['collaborators'],
          });

          if (playlistWithCollaborators && playlistWithCollaborators.collaborators) {
            const isPlaylistCollaborator = playlistWithCollaborators.collaborators.some(
              collaborator => collaborator.id === userId
            );
            
            if (isPlaylistCollaborator) {
              return;
            }
          }
        }

        throw new ForbiddenException('Only invited users or playlist collaborators can vote in this event');
        break;

      case EventLicenseType.LOCATION_BASED:
        // Event creators can always vote in their own events
        if (event.creatorId === userId) {
          return;
        }
        
        // Event admins can always vote
        if (event.admins?.some(admin => admin.id === userId)) {
          return;
        }
        
        // Check voting time restrictions for location-based events
        const canVoteByTime = await this.checkVotingTimePermission(event, userId);
        if (!canVoteByTime) {
          throw new ForbiddenException('Voting is not allowed outside the specified voting hours for this location-based event');
        }
        
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

  computeStatus(event: Event): EventStatus {
    // Convertit la date courante en heure de Paris
    const timeZone = 'Europe/Paris';
    const now = toZonedTime(new Date(), timeZone);

    const start = toZonedTime(new Date(event.eventDate), timeZone);
    const end = toZonedTime(new Date(event.eventEndDate), timeZone);

    if (now < start) return EventStatus.UPCOMING;
    if (now >= start && now <= end) return EventStatus.LIVE;
    return EventStatus.ENDED;
  }
}