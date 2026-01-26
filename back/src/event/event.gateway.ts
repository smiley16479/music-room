import {
  WebSocketGateway,
  SubscribeMessage,
  MessageBody,
  OnGatewayInit,
  OnGatewayConnection,
  OnGatewayDisconnect,
  WebSocketServer,
  ConnectedSocket,
} from '@nestjs/websockets';
import { Server, Socket } from 'socket.io';
import { Logger, Inject, forwardRef } from '@nestjs/common';
import { JwtService } from '@nestjs/jwt';
import { ConfigService } from '@nestjs/config';

import { Event, EventVisibility } from 'src/event/entities/event.entity';
import { Vote } from 'src/event/entities/vote.entity';
import { Track } from 'src/music/entities/track.entity';
import { User, VisibilityLevel } from 'src/user/entities/user.entity';
import { TrackVoteSnapshot } from './event.service';
import { EventService } from './event.service';
import { PlaylistService } from 'src/playlist/playlist.service';

import { SOCKET_ROOMS } from '../common/constants/socket-rooms';
import { IsLatitude } from 'class-validator';
import { getAvatarUrl } from 'src/common/utils/avatar.utils';
import { create } from 'domain';
import { UserService } from 'src/user/user.service';
import { ParticipantRole } from './entities/event-participant.entity';

interface AuthenticatedSocket extends Socket {
  userId?: string;
  user?: User;
}

@WebSocketGateway({
  cors: {
    origin: '*', // process.env.FRONTEND_URL || 'http://localhost:5173',
    credentials: true,
  },
  namespace: '/events',
})
export class EventGateway implements OnGatewayInit, OnGatewayConnection, OnGatewayDisconnect {
  @WebSocketServer()
  server: Server;

  private readonly logger = new Logger(EventGateway.name);

  constructor(
    private jwtService: JwtService,
    private configService: ConfigService,
    private userService: UserService,
    @Inject(forwardRef(() => EventService))
    private eventService: EventService,
    @Inject(forwardRef(() => PlaylistService))
    private playlistService: PlaylistService,
  ) {}

  afterInit(server: Server) {
    this.logger.log('Events WebSocket Gateway initialized');
  }

  async handleConnection(client: AuthenticatedSocket) {
    try {
      // Extract token from handshake
      const token = client.handshake.auth?.token || client.handshake.headers?.authorization?.split(' ')[1];
      
      if (!token) {
        this.logger.warn(`Connection rejected: No token provided for client ${client.id}`);
        client.disconnect();
        return;
      }

      // Verify JWT token
      const payload = this.jwtService.verify(token, {
        secret: this.configService.get<string>('JWT_SECRET'),
      });
      client.userId = payload.sub;

      // Fetch user information with retry logic and fallback
      if (client.userId) {
        let retryCount = 0;
        const maxRetries = 3;
        
        while (retryCount < maxRetries) {
          try {
            const user = await this.userService.findById(client.userId);
            client.user = user;
            this.logger.log(`Client connected: ${client.id} (User: ${client.userId}, Display: ${user.displayName || user.email || 'No name'})`);
            break;
          } catch (error) {
            retryCount++;
            this.logger.warn(`Attempt ${retryCount}/${maxRetries} failed to fetch user data for ${client.userId}: ${error.message}`);
            
            if (retryCount < maxRetries) {
              // Wait a bit before retrying
              await new Promise(resolve => setTimeout(resolve, 100 * retryCount));
            } else {
              this.logger.error(`Failed to fetch user data for ${client.userId} after ${maxRetries} attempts`);
              // Continue without user data but don't disconnect
            }
          }
        }
      }

      if (!client.user) {
        this.logger.warn(`Client ${client.id} connected without user data - using fallback`);
      }
    } catch (error) {
      this.logger.error(`Connection rejected for client ${client.id}: Invalid token - ${error.message}`);
      client.disconnect();
    }
  }

  handleDisconnect(client: AuthenticatedSocket) {
    this.logger.log(`Client disconnected: ${client.id} (User: ${client.userId})`);
    
    // Notify all event rooms this user was in that they left
    // We need to check which rooms the client was in and notify them
    if (client.userId && client.user) {
      // Get all rooms the client was in and notify them
      const rooms = Array.from(client.rooms);
      this.logger.log(`User ${client.userId} was in rooms: ${rooms.join(', ')}`);
      rooms.forEach(room => {
        if (room.startsWith('event:')) {
          this.logger.log(`Notifying room ${room} that user ${client.userId} left`);
          this.server.to(room).emit('user-left', {
            userId: client.userId,
            displayName: client.user?.displayName || 'Unknown User',
            timestamp: new Date().toISOString(),
          });
        }
      });
    }
  }

  @SubscribeMessage('join-events-room')
  async handleJoinEventsRoom(
    @ConnectedSocket() client: AuthenticatedSocket,
    @MessageBody() data?: any,
  ) {
    try {

      const eventId = Array.isArray(data) && data.length > 0 ? data[0]?.eventId : data?.eventId;
      this.logger.debug(`User ${client.userId} is joining global & event room ${eventId}`);

      if (!client.userId) {
        client.emit('error', { message: 'Authentication required' });
        return;
      }

      await client.join(SOCKET_ROOMS.EVENT(eventId));
      client.emit('joined-events-room', { room: SOCKET_ROOMS.EVENTS });
      this.logger.log(`User ${client.userId} joined global events room`);
    } catch (error) {
      client.emit('error', { message: 'Failed to join events room', details: error.message });
    }
  }

   @SubscribeMessage('test')
    async handleTest(
      @ConnectedSocket() client: AuthenticatedSocket,
      @MessageBody() data: any,
    ) {
      // Test event handler
    }

  // Event Room Management
  @SubscribeMessage('join-event')
  async handleJoinEvent(
    @ConnectedSocket() client: AuthenticatedSocket,
    @MessageBody() { eventId }: { eventId: string },
  ) {
    try {
      if (!client.userId) {
        client.emit('error', { message: 'Authentication required' });
        return;
      }

      const room = SOCKET_ROOMS.EVENT(eventId);
      await client.join(room);

      // Ensure we have user data before proceeding
      if (!client.user) {
        this.logger.warn(`User data not available for ${client.userId}, attempting to fetch...`);
        try {
          client.user = await this.userService.findById(client.userId);
          this.logger.log(`Successfully fetched user data for ${client.userId}: ${client.user.displayName}`);
        } catch (error) {
          this.logger.error(`Failed to fetch user data for ${client.userId}: ${error.message}`);
          // Continue with fallback data
        }
      }

      // Get current participants in the room (before this user joined)
      const currentParticipants = await this.getEventParticipants(eventId);
      
      // Send current participant list to the new user
      const participantDetails: Array<{
        userId: string;
        displayName: string;
        avatarUrl: string | null;
        email: string;
        createdAt?: string;
        updatedAt?: string;
      }> = [];
      for (const participantId of currentParticipants) {
        if (participantId !== client.userId) { // Don't include themselves
          try {
            const participant = await this.userService.findById(participantId);
            participantDetails.push({
              userId: participant.id,
              displayName: participant.displayName || 'Unknown User',
              avatarUrl: participant.avatarUrl || null,
              email: participant.email,
              createdAt: participant.createdAt?.toISOString(),
              updatedAt: participant.updatedAt?.toISOString(),
            });
          } catch (error) {
            this.logger.warn(`Failed to fetch participant data for ${participantId}: ${error.message}`);
          }
        }
      }

      // Send current participants to the new user
      if (participantDetails.length > 0) {
        client.emit('current-participants', {
          eventId,
          participants: participantDetails,
          timestamp: new Date().toISOString(),
        });
      }

      // Create user data for broadcast - ensure we have the proper display name with multiple fallbacks
      const userDisplayName = client.user?.displayName || 
                              client.user?.email?.split('@')[0] || 
                              `User-${client.userId.substring(0, 8)}` || 
                              'Unknown User';
      this.logger.log(`Broadcasting user-joined for ${client.userId} with display name: ${userDisplayName}`);

      // Send user joined event to all participants in the room (including the user who just joined)
      this.server.to(room).emit('user-joined', {
        userId: client.userId,
        socketId: client.id,
        displayName: userDisplayName,
        avatarUrl: client.user?.avatarUrl || null,
        email: client.user?.email || '',
        createdAt: client.user?.createdAt?.toISOString(),
        updatedAt: client.user?.updatedAt?.toISOString(),
        timestamp: new Date().toISOString(),
      });

      // Send current playback state if event is live and has a current track
      try {
        const eventWithStats = await this.eventService.findById(eventId);
        if (eventWithStats && eventWithStats.status === 'live' && eventWithStats.currentTrackId) {
          // Get accurate current playback position and state
          const playbackState = await this.eventService.getCurrentPlaybackPosition(eventId);
          
          // Only send sync if there's actually a track playing
          if (playbackState.trackId && eventWithStats.currentTrack) {
            client.emit('playback-sync', {
              eventId,
              currentTrackId: playbackState.trackId,
              currentTrack: eventWithStats.currentTrack,
              startTime: playbackState.position,
              isPlaying: playbackState.isPlaying,
              timestamp: new Date().toISOString(),
              syncType: 'initial-join'
            });
          }
        }
      } catch (syncError) {
        this.logger.warn(`Failed to send playback sync to user ${client.userId}: ${syncError.message}`);
        // Don't fail the join process if sync fails
      }

      // Start periodic time sync for live events
      this.startTimeSyncForEvent(eventId);

      // Confirm to the client that they joined
      client.emit('joined-event', { eventId, room });
      this.logger.log(`User ${client.userId} (${userDisplayName}) joined event ${eventId}`);
    } catch (error) {
      this.logger.error(`Error in handleJoinEvent for user ${client.userId}, event ${eventId}: ${error.message}`);
      client.emit('error', { message: 'Failed to join event', details: error.message });
    }
  }

  @SubscribeMessage('leave-event')
  async handleLeaveEvent(
    @ConnectedSocket() client: AuthenticatedSocket,
    @MessageBody() { eventId }: { eventId: string },
  ) {
    try {
      this.logger.debug(`User ${client.userId} is leaving event room ${eventId}`);
      const room = SOCKET_ROOMS.EVENT(eventId);
      await client.leave(room);

      // Check if this was the last user in the event room
      const remainingSockets = await this.server.in(room).fetchSockets();
      if (remainingSockets.length === 0) {
        // No users left in event, stop time sync
        this.stopTimeSyncForEvent(eventId);
      }

      // Notify other participants that user left
      this.server.to(room).emit('user-left', {
        userId: client.userId,
        displayName: client.user?.displayName || 'Unknown User',
        timestamp: new Date().toISOString(),
      });

      client.emit('left-event', { userId: client.userId });
      this.logger.log(`User ${client.userId} left event ${eventId} - notified other participants`);
    } catch (error) {
      client.emit('error', { message: 'Failed to leave event', details: error.message });
    }
  }

  // Track Suggestions (for real-time suggestions without voting)
  @SubscribeMessage('suggest-track')
  async handleSuggestTrack(
    @ConnectedSocket() client: AuthenticatedSocket,
    @MessageBody() { eventId, trackId, trackData }: { eventId: string; trackId: string; trackData: any },
  ) {
    try {
      if (!client.userId) {
        client.emit('error', { message: 'Authentication required' });
        return;
      }

      const room = SOCKET_ROOMS.EVENT(eventId);
      
      // Broadcast track suggestion to all participants
      this.server.to(room).emit('track-suggested', {
        eventId,
        trackId,
        trackData,
        suggestedBy: client.userId,
        timestamp: new Date().toISOString(),
      });

      this.logger.log(`User ${client.userId} suggested track ${trackId} in event ${eventId}`);
    } catch (error) {
      client.emit('error', { message: 'Failed to suggest track', details: error.message });
    }
  }

  // Real-time chat for events
  @SubscribeMessage('send-message')
  async handleSendMessage(
    @ConnectedSocket() client: AuthenticatedSocket,
    @MessageBody() { eventId, message }: { eventId: string; message: string },
  ) {
    try {
      if (!client.userId) {
        client.emit('error', { message: 'Authentication required' });
        return;
      }

      if (!message || message.trim().length === 0) {
        client.emit('error', { message: 'Message cannot be empty' });
        return;
      }

      if (message.length > 500) {
        client.emit('error', { message: 'Message too long (max 500 characters)' });
        return;
      }

      const room = SOCKET_ROOMS.EVENT(eventId);
      
      // Broadcast message to all participants
      this.server.to(room).emit('new-message', {
        eventId,
        message: message.trim(),
        senderId: client.userId,
        timestamp: new Date().toISOString(),
        messageId: `${client.userId}-${Date.now()}`, // Simple message ID
      });

      this.logger.log(`User ${client.userId} sent message in event ${eventId}`);
    } catch (error) {
      client.emit('error', { message: 'Failed to send message', details: error.message });
    }
  }
/*
  // User location updates (for location-based events)
  @SubscribeMessage('update-location')
  async handleUpdateLocation(
    @ConnectedSocket() client: AuthenticatedSocket,
    @MessageBody() { eventId, location }: { eventId: string; location: { latitude: number; longitude: number } },
  ) {
    try {
      if (!client.userId) {
        client.emit('error', { message: 'Authentication required' });
        return;
      }

      // Validate coordinates
      if (!location.latitude || !location.longitude ||
          Math.abs(location.latitude) > 90 || Math.abs(location.longitude) > 180) {
        client.emit('error', { message: 'Invalid coordinates' });
        return;
      }

      const room = SOCKET_ROOMS.EVENT(eventId);
      
      // Store user location in socket data
      client.data.location = location;
      client.data.locationUpdatedAt = new Date().toISOString();

      // Optionally notify event creator about user locations (for monitoring)
      client.to(room).emit('user-location-updated', {
        userId: client.userId,
        location,
        timestamp: new Date().toISOString(),
      });

      client.emit('location-updated', { success: true });
      this.logger.log(`User ${client.userId} updated location in event ${eventId}`);
    } catch (error) {
      client.emit('error', { message: 'Failed to update location', details: error.message });
    }
  }*/

  // Server-side notification methods (called by EventsService)
  notifyEventCreated(event: Event, creator: User) {
    this.server.to(SOCKET_ROOMS.EVENTS).emit('event-created', {
      event : {
        id: event.id,
        name: event.name,
        description: event.description,
        visibility: event.visibility,
        licenseType: event.licenseType,
        status: event.status,
        locationName: event.locationName,
        eventDate: event.eventDate,
        endDate: event.endDate,
        participants: event.participants ? event.participants.map(p => ({ id: p.userId, displayName: p.user.displayName, avatarUrl: p.user.avatarUrl })) : [],
        participantsCount: event.participants ? event.participants.length : 0,
        creator: creator ? { id: creator.id, displayName: creator.displayName, avatarUrl: creator.avatarUrl } : null,
      },
      timestamp: new Date().toISOString(),
    });
  }

  notifyEventUpdated(eventId: string, event: Event) {
    const room = SOCKET_ROOMS.EVENT(eventId);
    this.server.to(room).emit('event-updated', {
      eventId,
      event,
      timestamp: new Date().toISOString(),
    });
  }

  notifyEventDeleted(eventId: string) {
    const rooms = SOCKET_ROOMS.EVENTS;
    this.server.to(rooms).emit('event-deleted', {
      eventId,
      timestamp: new Date().toISOString(),
    });

    const room = SOCKET_ROOMS.EVENT(eventId);
    this.server.to(room).emit('event-deleted', {
      eventId,
      timestamp: new Date().toISOString(),
    });
  }

  notifyAdminAdded(eventId: string, userId: string) {
    const room = SOCKET_ROOMS.EVENT(eventId);
    this.server.to(room).emit('admin-added', {
      eventId,
      userId,
      timestamp: new Date().toISOString(),
    });
  }

  notifyAdminRemoved(eventId: string, userId: string) {
    const room = SOCKET_ROOMS.EVENT(eventId);
    this.server.to(room).emit('admin-removed', {
      eventId,
      userId,
      timestamp: new Date().toISOString(),
    });
  }

  notifyParticipantJoined(eventId: string, user: User) {
    const room = SOCKET_ROOMS.EVENT(eventId);
    this.server.to(room).emit('participant-joined', {
      eventId,
      user: {
        id: user.id,
        displayName: user.displayName,
        avatarUrl: user.avatarUrl,
      },
      timestamp: new Date().toISOString(),
    });
  }

  notifyParticipantLeft(eventId: string, user: User) {
    const room = SOCKET_ROOMS.EVENT(eventId);
    this.server.to(room).emit('participant-left', {
      eventId,
      user: {
        id: user.id,
        displayName: user.displayName,
        avatarUrl: user.avatarUrl,
      },
      timestamp: new Date().toISOString(),
    });
  }

  notifyVoteUpdated(eventId: string, vote: Vote/* , tracks: TrackVoteSnapshot[] */) {
    const room = SOCKET_ROOMS.EVENT(eventId);
    this.logger.debug(`Notifying vote update in event ${eventId} for track ${vote.trackId} by user ${vote.userId}`);
    this.server.to(room).emit('vote-updated', {
      eventId,
      vote: {
        trackId: vote.trackId,
        userId: vote.userId,
        type: vote.type,
        weight: vote.weight,
      },
      // results: tracks.slice(0, 10), // Top 10 tracks only
      // timestamp: new Date().toISOString(),
    });
  }

  notifyVoteRemoved(eventId: string, vote: Vote/* , tracks: TrackVoteSnapshot[]*/) {
    const room = SOCKET_ROOMS.EVENT(eventId);
    this.server.to(room).emit('vote-removed', {
      eventId,
      vote: {
        trackId: vote.trackId,
        userId: vote.userId,
        type: vote.type,
        weight: vote.weight,
      },
      // results: tracks.slice(0, 10),
      // timestamp: new Date().toISOString(),
    });
  }

  notifyNowPlaying(eventId: string, trackId: string) {
    const room = SOCKET_ROOMS.EVENT(eventId);
    this.server.to(room).emit('now-playing', {
      eventId,
      trackId,
      startedAt: new Date().toISOString(),
    });
  }

  notifyTrackEnded(eventId: string) {
    const room = SOCKET_ROOMS.EVENT(eventId);
    this.server.to(room).emit('track-ended', {
      eventId,
      timestamp: new Date().toISOString(),
    });
  }

  // Track Management (for events that use playlists)
  notifyTrackAdded(eventId: string, track: any, addedBy: string, updatedTrackCount?: number) {
    const room = SOCKET_ROOMS.EVENT(eventId);
    
    // Handle both Track and PlaylistTrackWithDetails
    const trackData = track.track ? {
      id: track.track.id,
      title: track.track.title,
      artist: track.track.artist,
      album: track.track.album,
      duration: track.track.duration,
      thumbnailUrl: track.track.albumCoverUrl,
      previewUrl: track.track.previewUrl,
      addedBy: track.addedBy ? {
        id: track.addedBy.id,
        displayName: track.addedBy.displayName,
        avatarUrl: track.addedBy.avatarUrl,
      } : undefined,
      position: track.position,
      addedAt: track.addedAt,
    } : {
      id: track.id,
      title: track.title,
      artist: track.artist,
      album: track.album,
      duration: track.duration,
      thumbnailUrl: track.albumCoverUrl,
      previewUrl: track.previewUrl,
      addedBy,
    };

    this.server.to(room).emit('track-added', {
      eventId,
      playlistId: eventId, // Support both
      track: trackData,
      addedBy,
      timestamp: new Date().toISOString(),
    });
  }

  notifyTrackRemoved(eventId: string, trackId: string, removedBy: string, updatedTrackCount?: number) {
    const room = SOCKET_ROOMS.EVENT(eventId);
    this.server.to(room).emit('track-removed', {
      eventId,
      playlistId: eventId, // Support both
      trackId,
      removedBy,
      timestamp: new Date().toISOString(),
    });
  }

  notifyTracksReordered(eventId: string, trackOrder: string[], reorderedBy: string) {
    const room = SOCKET_ROOMS.EVENT(eventId);
    this.server.to(room).emit('tracks-reordered', {
      eventId,
      playlistId: eventId, // Support both eventId and playlistId
      trackOrder,
      trackIds: trackOrder, // Support both trackOrder and trackIds
      reorderedBy,
      timestamp: new Date().toISOString(),
    });

    // Also notify global events room
    this.server.to(SOCKET_ROOMS.EVENTS).emit('playlist-tracks-reordered', {
      playlistId: eventId,
      timestamp: new Date().toISOString(),
    });
  }

  // Get connected users in an event
  async getEventParticipants(eventId: string): Promise<string[]> {
    const room = SOCKET_ROOMS.EVENT(eventId);
    const sockets = await this.server.in(room).fetchSockets();
    return sockets
      .map(socket => (socket as unknown as AuthenticatedSocket).userId)
      .filter(userId => userId !== undefined) as string[];
  }
/*
  // Kick user from event (admin function)
  async kickUserFromEvent(eventId: string, userId: string, reason?: string) {
    const room = SOCKET_ROOMS.EVENT(eventId);
    const sockets = await this.server.in(room).fetchSockets();
    
    const userSocket = sockets.find(socket => (socket as unknown as AuthenticatedSocket).userId === userId);
    
    if (userSocket) {
      userSocket.emit('kicked-from-event', {
        eventId,
        reason: reason || 'You have been removed from this event',
        timestamp: new Date().toISOString(),
      });
      
      userSocket.leave(room);
      
      // Notify other participants
      this.server.to(room).emit('participant-kicked', {
        eventId,
        userId,
        reason,
        timestamp: new Date().toISOString(),
      });
    }
  }

  // Track voting via WebSocket for real-time feedback
  // Note: For persistent voting, use the HTTP endpoints in EventController
  // This WebSocket method provides real-time user experience feedback
  @SubscribeMessage('vote-track')
  async handleVoteTrack(
    @ConnectedSocket() client: AuthenticatedSocket,
    @MessageBody() { eventId, trackId, type }: { eventId: string; trackId: string; type: 'upvote' | 'downvote' }
  ) {
    try {
      if (!client.userId) {
        client.emit('error', { message: 'Authentication required' });
        return;
      }

      // Broadcast optimistic vote update to all participants for immediate feedback
      // The client should also call the HTTP API for persistent voting
      this.server.to(SOCKET_ROOMS.EVENT(eventId)).emit('vote-optimistic-update', {
        eventId,
        vote: { trackId, userId: client.userId, type },
        timestamp: new Date().toISOString(),
      });

      this.logger.log(`User ${client.userId} voted ${type} for track ${trackId} in event ${eventId} (WebSocket)`);
      
    } catch (error) {
      this.logger.error(`Vote WebSocket error for user ${client.userId}: ${error.message}`);
      client.emit('error', { 
        message: 'Failed to vote for track', 
        details: error.message 
      });
    }
  }

  // Request voting results
  @SubscribeMessage('get-voting-results')
  async handleGetVotingResults(
    @ConnectedSocket() client: AuthenticatedSocket,
    @MessageBody() { eventId }: { eventId: string }
  ) {
    try {
      if (!client.userId) {
        client.emit('error', { message: 'Authentication required' });
        return;
      }

      // Send current voting results to the requesting client
      client.emit('voting-results-update', {
        eventId,
        message: 'Use HTTP API /api/events/{eventId}/voting-results for detailed results',
        timestamp: new Date().toISOString(),
      });
      
    } catch (error) {
      this.logger.error(`Get voting results error: ${error.message}`);
      client.emit('error', { 
        message: 'Failed to get voting results', 
        details: error.message 
      });
    }
  }
*/

  // Music playback control - only for creators and admins
  @SubscribeMessage('play-track')
  async handlePlayTrack(
    @ConnectedSocket() client: AuthenticatedSocket,
    @MessageBody() { eventId, trackId, startTime }: { eventId: string; trackId?: string; startTime?: number }
  ) {
    try {
      if (!client.userId) {
        client.emit('error', { message: 'Authentication required' });
        return;
      }

      // Check if user can control playback
      const canControl = await this.canControlPlayback(eventId, client.userId);
      if (!canControl) {
        client.emit('error', { message: 'Only event creators and admins can control playback' });
        return;
      }

      // Get current playback position if startTime is not provided (resuming after pause)
      let currentStartTime = startTime;
        if (currentStartTime === undefined || currentStartTime === null) {
        try {
          const currentState = await this.eventService.getCurrentPlaybackPosition(eventId);
          currentStartTime = currentState.position;
        } catch (error) {
          this.logger.warn(`Failed to get current position, defaulting to 0: ${error.message}`);
          currentStartTime = 0;
        }
      }      // Update playback state in database first
      await this.eventService.updatePlaybackState(eventId, true, currentStartTime);
      
      if (trackId) {
        try {
          const currentEvent = await this.eventService.findById(eventId);
          
          if (currentEvent.currentTrackId !== trackId) {
            await this.eventService.updateCurrentTrack(eventId, trackId);
          }
        } catch (dbError) {
          this.logger.warn(`Failed to update current track in database: ${dbError.message}`);
        }
      }

      this.startTimeSyncForEvent(eventId);

      const playbackState = {
        eventId,
        ...(trackId && { trackId }),
        startTime: currentStartTime,
        controlledBy: client.userId,
        timestamp: new Date().toISOString(),
        syncType: 'admin-play'
      };
      
      this.server.to(SOCKET_ROOMS.EVENT(eventId)).emit('music-play', playbackState);
      
      this.logger.log(`User ${client.userId} played track ${trackId} in event ${eventId}`);
    } catch (error) {
      this.logger.error(`Play track error: ${error.message}`);
      client.emit('error', { message: 'Failed to play track', details: error.message });
    }
  }

  @SubscribeMessage('pause-track')
  async handlePauseTrack(
    @ConnectedSocket() client: AuthenticatedSocket,
    @MessageBody() { eventId, currentTime }: { eventId: string; currentTime?: number }
  ) {
    try {
      if (!client.userId) {
        client.emit('error', { message: 'Authentication required' });
        return;
      }

      // Check if user can control playback
      const canControl = await this.canControlPlayback(eventId, client.userId);
      if (!canControl) {
        client.emit('error', { message: 'Only event creators and admins can control playback' });
        return;
      }

      const pausePosition = currentTime || 0;
      await this.eventService.updatePlaybackState(eventId, false, pausePosition);

      this.stopTimeSyncForEvent(eventId);

      const pauseState = {
        eventId,
        controlledBy: client.userId,
        currentTime: pausePosition,
        timestamp: new Date().toISOString(),
        syncType: 'admin-pause'
      };
      
      this.server.to(SOCKET_ROOMS.EVENT(eventId)).emit('music-pause', pauseState);
      
      this.logger.log(`User ${client.userId} paused playback in event ${eventId}`);
    } catch (error) {
      this.logger.error(`Pause track error: ${error.message}`);
      client.emit('error', { message: 'Failed to pause track', details: error.message });
    }
  }

  @SubscribeMessage('seek-track')
  async handleSeekTrack(
    @ConnectedSocket() client: AuthenticatedSocket,
    @MessageBody() { eventId, seekTime }: { eventId: string; seekTime: number }
  ) {
    try {
      if (!client.userId) {
        client.emit('error', { message: 'Authentication required' });
        return;
      }

      // Check if user can control playback
      const canControl = await this.canControlPlayback(eventId, client.userId);
      if (!canControl) {
        client.emit('error', { message: 'Only event creators and admins can control playback' });
        return;
      }

      const currentState = await this.eventService.getCurrentPlaybackPosition(eventId);
      
      await this.eventService.updatePlaybackState(eventId, currentState.isPlaying, seekTime);

      const seekState = {
        eventId,
        seekTime,
        controlledBy: client.userId,
        timestamp: new Date().toISOString(),
        syncType: 'admin-seek'
      };
      
      this.server.to(SOCKET_ROOMS.EVENT(eventId)).emit('music-seek', seekState);
      
      this.logger.log(`User ${client.userId} seeked to ${seekTime}s in event ${eventId}`);
    } catch (error) {
      this.logger.error(`Seek track error: ${error.message}`);
      client.emit('error', { message: 'Failed to seek track', details: error.message });
    }
  }

  @SubscribeMessage('change-track')
  async handleChangeTrack(
    @ConnectedSocket() client: AuthenticatedSocket,
    @MessageBody() { eventId, trackId, trackIndex }: { eventId: string; trackId: string; trackIndex?: number }
  ) {
    try {
      if (!client.userId) {
        client.emit('error', { message: 'Authentication required' });
        return;
      }

      // Check if user can control playback
      const canControl = await this.canControlPlayback(eventId, client.userId);
      if (!canControl) {
        client.emit('error', { message: 'Only event creators and admins can control playback' });
        return;
      }

      this.server.to(SOCKET_ROOMS.EVENT(eventId)).emit('music-track-changed', {
        eventId,
        trackId,
        trackIndex,
        controlledBy: client.userId,
        timestamp: new Date().toISOString(),
      });

      try {
        await this.eventService.updateCurrentTrack(eventId, trackId);
      } catch (dbError) {
        this.logger.warn(`Failed to update current track in database: ${dbError.message}`);
      }

      this.logger.log(`User ${client.userId} changed track to ${trackId} in event ${eventId}`);
    } catch (error) {
      this.logger.error(`Change track error: ${error.message}`);
      client.emit('error', { message: 'Failed to change track', details: error.message });
    }
  }

  @SubscribeMessage('set-volume')
  async handleSetVolume(
    @ConnectedSocket() client: AuthenticatedSocket,
    @MessageBody() { eventId, volume }: { eventId: string; volume: number }
  ) {
    try {
      if (!client.userId) {
        client.emit('error', { message: 'Authentication required' });
        return;
      }

      // Check if user can control playback
      const canControl = await this.canControlPlayback(eventId, client.userId);
      if (!canControl) {
        client.emit('error', { message: 'Only event creators and admins can control playback' });
        return;
      }

      this.server.to(SOCKET_ROOMS.EVENT(eventId)).emit('music-volume', {
        eventId,
        volume: Math.max(0, Math.min(100, volume)),
        controlledBy: client.userId,
        timestamp: new Date().toISOString(),
      });

      this.logger.log(`User ${client.userId} set volume to ${volume} in event ${eventId}`);
    } catch (error) {
      this.logger.error(`Set volume error: ${error.message}`);
      client.emit('error', { message: 'Failed to set volume', details: error.message });
    }
  }

  @SubscribeMessage('skip-track')
  async handleSkipTrack(
    @ConnectedSocket() client: AuthenticatedSocket,
    @MessageBody() { eventId }: { eventId: string }
  ) {
    try {
      if (!client.userId) {
        client.emit('error', { message: 'Authentication required' });
        return;
      }

      // Check if user can control playback
      const canControl = await this.canControlPlayback(eventId, client.userId);
      if (!canControl) {
        client.emit('error', { message: 'Only event creators and admins can skip tracks' });
        return;
      }

      this.server.to(SOCKET_ROOMS.EVENT(eventId)).emit('track-skipped', {
        eventId,
        controlledBy: client.userId,
        timestamp: new Date().toISOString(),
      });

      this.logger.log(`User ${client.userId} skipped track in event ${eventId}`);
    } catch (error) {
      this.logger.error(`Skip track error: ${error.message}`);
      client.emit('error', { message: 'Failed to skip track', details: error.message });
    }
  }

  // Track accessibility tracking
  private trackAccessibilityReports = new Map<string, Map<string, { canPlay: boolean; timestamp: Date }>>();

  // @SubscribeMessage('track-accessibility-report')
  // async handleTrackAccessibilityReport(
  //   @ConnectedSocket() client: AuthenticatedSocket,
  //   @MessageBody() { eventId, trackId, canPlay, reason }: { 
  //     eventId: string; 
  //     trackId: string; 
  //     canPlay: boolean; 
  //     reason?: string;
  //   }
  // ) {
  //   try {
  //     if (!client.userId) {
  //       client.emit('error', { message: 'Authentication required' });
  //       return;
  //     }

  //     const reportKey = `${eventId}:${trackId}`;
      
  //     if (!this.trackAccessibilityReports.has(reportKey)) {
  //       this.trackAccessibilityReports.set(reportKey, new Map());
  //     }
      
  //     const trackReports = this.trackAccessibilityReports.get(reportKey)!;
  //     trackReports.set(client.userId, {
  //       canPlay,
  //       timestamp: new Date()
  //     });

  //     this.logger.log(`User ${client.userId} reported track ${trackId} accessibility: ${canPlay ? 'playable' : 'unplayable'} ${reason ? `(${reason})` : ''}`);

  //     const participants = await this.getEventParticipants(eventId);
  //     const participantCount = participants.length;
      
  //     if (trackReports.size >= Math.min(3, Math.ceil(participantCount * 0.6))) {
  //       const canPlayCount = Array.from(trackReports.values()).filter(report => report.canPlay).length;
  //       const cannotPlayCount = trackReports.size - canPlayCount;
        
  //       if (cannotPlayCount > canPlayCount && cannotPlayCount >= 2) {
  //         const event = await this.eventService.findById(eventId, client.userId);
          
  //         let adminUserId = event.creatorId;
  //         if (!adminUserId && event.admins && event.admins.length > 0) {
  //           adminUserId = event.admins[0].id;
  //         }
          
  //         if (adminUserId) {
  //           await this.handleTrackSkipDueToAccessibility(eventId, trackId, adminUserId, 'majority_cannot_play');
  //         }
  //       }
  //     }

  //   } catch (error) {
  //     this.logger.error(`Track accessibility report error: ${error.message}`);
  //     client.emit('error', { message: 'Failed to report track accessibility', details: error.message });
  //   }
  // }

  private async handleTrackSkipDueToAccessibility(eventId: string, trackId: string, adminUserId: string, reason: string) {
    try {
      const room = SOCKET_ROOMS.EVENT(eventId);
      const event = await this.eventService.findById(eventId, adminUserId);
      
      // Event IS playlist when type=LISTENING_SESSION
      if (event.trackCount !== undefined && event.trackCount !== null) {
        await this.playlistService.removeTrack(event.id, trackId, adminUserId);
        
        const updatedPlaylist = await this.playlistService.getPlaylistTracks(event.id);
        
        if (updatedPlaylist.length > 0) {
          const nextTrack = updatedPlaylist[0];
          
          this.server.to(room).emit('music-track-changed', {
            eventId,
            trackId: nextTrack.track.id,
            trackIndex: 0,
            controlledBy: adminUserId,
            autoSkipped: true,
            skipReason: reason,
            continuePlaying: true,
            timestamp: new Date().toISOString(),
          });
          
          this.trackAccessibilityReports.delete(`${eventId}:${trackId}`);
          
          await this.eventService.updateCurrentTrack(eventId, nextTrack.track.id);
        } else {
          this.server.to(room).emit('music-pause', {
            eventId,
            controlledBy: adminUserId,
            reason: 'no_more_tracks',
            timestamp: new Date().toISOString(),
          });
        }
      }
      
    } catch (error) {
      this.logger.error(`Auto-skip error: ${error.message}`);
    }
  }

  @SubscribeMessage('track-ended')
  async handleTrackEnded(
    @ConnectedSocket() client: AuthenticatedSocket,
    @MessageBody() { eventId, trackId }: { eventId: string; trackId: string }
  ) {
    try {
      if (!client.userId) {
        client.emit('error', { message: 'Authentication required' });
        return;
      }

      const room = SOCKET_ROOMS.EVENT(eventId);
      
      this.server.to(room).emit('track-ended', {
        eventId,
        trackId,
        notifiedBy: client.userId,
        timestamp: new Date().toISOString(),
      });

      this.logger.log(`User ${client.userId} notified that track ${trackId} ended in event ${eventId}`);

      const event = await this.eventService.findById(eventId, client.userId);
      const isCreator = event.creatorId === client.userId;
      // const isAdmin = event.admins?.some(admin => admin.id === client.userId) || false;

      if (isCreator /* || isAdmin */) {
        try {
          // Event IS playlist when type=LISTENING_SESSION
          if (event.trackCount !== undefined && event.trackCount !== null) {
            await this.playlistService.removeTrack(event.id, trackId, client.userId);
            
            this.trackAccessibilityReports.delete(`${eventId}:${trackId}`);
            
            const updatedPlaylist = await this.playlistService.getPlaylistTracks(event.id);
            
            if (updatedPlaylist.length > 0) {
              const nextTrack = updatedPlaylist[0];
              
              if (nextTrack && nextTrack.track) {
                this.server.to(room).emit('music-track-changed', {
                  eventId,
                  trackId: nextTrack.track.id,
                  trackIndex: 0,
                  controlledBy: client.userId,
                  continuePlaying: true,
                  timestamp: new Date().toISOString(),
                });

                await this.eventService.updateCurrentTrack(eventId, nextTrack.track.id);
              } else {
                this.server.to(room).emit('music-pause', {
                  eventId,
                  pausedBy: client.userId,
                  timestamp: new Date().toISOString(),
                });
              }
            } else {
              this.server.to(room).emit('music-pause', {
                eventId,
                pausedBy: client.userId,
                timestamp: new Date().toISOString(),
              });
            }
          }
        } catch (playlistError) {
          this.logger.error(`Failed to handle track progression for event ${eventId}: ${playlistError.message}`);
          this.server.to(room).emit('music-pause', {
            eventId,
            pausedBy: client.userId,
            timestamp: new Date().toISOString(),
          });
        }
      }
    } catch (error) {
      this.logger.error(`Track ended notification error: ${error.message}`);
      client.emit('error', { message: 'Failed to notify track ended', details: error.message });
    }
  }

  // Periodic time sync for live events to keep all users in perfect sync
  private syncIntervals = new Map<string, NodeJS.Timeout>();

  private async startTimeSyncForEvent(eventId: string) {
    // Don't start if already running
    if (this.syncIntervals.has(eventId)) {
      return;
    }

    const interval = setInterval(async () => {
      try {
        const playbackState = await this.eventService.getCurrentPlaybackPosition(eventId);
        
        if (playbackState.isPlaying && playbackState.trackId) {
          const room = SOCKET_ROOMS.EVENT(eventId);
          
          const roomSockets = await this.server.in(room).fetchSockets();
          if (roomSockets.length > 0) {
            this.server.to(room).emit('time-sync', {
              eventId,
              trackId: playbackState.trackId,
              currentTime: playbackState.position,
              timestamp: new Date().toISOString(),
              syncType: 'periodic-sync'
            });
          }
        }
      } catch (error) {
        this.logger.error(`Time sync error for event ${eventId}: ${error.message}`);
      }
    }, 1000); // Sync every second during playback

    this.syncIntervals.set(eventId, interval);
    this.logger.log(`Started time sync broadcasts for event ${eventId}`);
  }

  private stopTimeSyncForEvent(eventId: string) {
    const interval = this.syncIntervals.get(eventId);
    if (interval) {
      clearInterval(interval);
      this.syncIntervals.delete(eventId);
      this.logger.log(`Stopped time sync broadcasts for event ${eventId}`);
    }
  }

  // Helper method to check if user can control playback
  private async canControlPlayback(eventId: string, userId: string): Promise<boolean> {
    try {
      const event = await this.eventService.findById(eventId, userId);
      if (!event) {
        return false;
      }

      // Check if user is creator
      if (event.creatorId === userId) {
        return true;
      }

      // Check if user is admin
      const isAdmin = event.participants?.some(participant => participant.userId === userId && participant.role === ParticipantRole.ADMIN);
      return !!isAdmin;
    } catch (error) {
      this.logger.error(`Error checking playback control permissions: ${error.message}`);
      return false;
    }
  }

  // Synchronisation de l'état du player (play/pause/next/previous/position/volume)
  @SubscribeMessage('playback-state')
  async handlePlaybackState(
    @ConnectedSocket() client: AuthenticatedSocket,
    @MessageBody() { eventId, state }: { eventId: string; state: any }
  ) {
    if (!client.userId) return;
    this.server.to(SOCKET_ROOMS.EVENT(eventId)).emit('playback-state-updated', {
      eventId,
      state,
      timestamp: new Date().toISOString(),
    });
  }

  // ============================================
  // PLAYLIST NOTIFICATIONS (centralized here)
  // ============================================

  notifyPlaylistCreated(playlist: any, creator: any) {
    // Since all playlists are event-based, notify both rooms
    if (playlist.event?.visibility === EventVisibility.PUBLIC) {
      this.server.to(SOCKET_ROOMS.EVENTS).emit('playlist-created', {
        playlist: {
          id: playlist.id,
          name: playlist.event?.name,
          description: playlist.event?.description,
          coverImageUrl: playlist.event?.coverImageUrl,
          createdAt: playlist.createdAt,
          creator: creator ? {
            id: creator.id,
            displayName: creator.displayName,
            avatarUrl: creator.avatarUrl,
          } : null,
        },
        timestamp: new Date().toISOString(),
      });
    }
  }

  notifyPlaylistUpdated(playlistId: string, playlist: any, userId: string) {
    const room = SOCKET_ROOMS.EVENT(playlistId);
    this.server.to(room).emit('playlist-updated', {
      playlistId,
      playlist: {
        id: playlist.id,
        name: playlist.event?.name,
        description: playlist.event?.description,
        coverImageUrl: playlist.event?.coverImageUrl,
        updatedAt: playlist.updatedAt,
      },
      updatedBy: userId,
      timestamp: new Date().toISOString(),
    });

    if (playlist.event?.visibility === EventVisibility.PUBLIC) {
      this.server.to(SOCKET_ROOMS.EVENTS).emit('playlist-updated', {
        playlistId,
        playlist: {
          id: playlist.id,
          name: playlist.event?.name,
          description: playlist.event?.description,
          coverImageUrl: playlist.event?.coverImageUrl,
          updatedAt: playlist.updatedAt,
        },
        updatedBy: userId,
        timestamp: new Date().toISOString(),
      });
    }
  }

  notifyPlaylistDeleted(playlistId: string, deletedBy: string) {
    this.server.to(SOCKET_ROOMS.EVENTS).emit('playlist-deleted', {
      playlistId,
      deletedBy,
      timestamp: new Date().toISOString(),
    });

    const room = SOCKET_ROOMS.EVENT(playlistId);
    this.server.to(room).emit('playlist-deleted', {
      playlistId,
      deletedBy,
      timestamp: new Date().toISOString(),
    });
  }

  notifyCollaboratorAdded(playlistId: string, collaborator: any, addedBy: string) {
    const room = SOCKET_ROOMS.EVENT(playlistId);
    this.server.to(room).emit('collaborator-added', {
      playlistId,
      collaborator: {
        id: collaborator.id,
        displayName: collaborator.displayName,
        avatarUrl: collaborator.avatarUrl,
      },
      addedBy,
      timestamp: new Date().toISOString(),
    });
  }

  notifyCollaboratorRemoved(playlistId: string, collaborator: any, removedBy: string) {
    const room = SOCKET_ROOMS.EVENT(playlistId);
    this.server.to(room).emit('collaborator-removed', {
      playlistId,
      collaborator: {
        id: collaborator.id,
        displayName: collaborator.displayName,
        avatarUrl: collaborator.avatarUrl,
      },
      removedBy,
      timestamp: new Date().toISOString(),
    });
  }
}
