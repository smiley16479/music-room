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
import { UseGuards, Logger } from '@nestjs/common';
import { JwtService } from '@nestjs/jwt';
import { ConfigService } from '@nestjs/config';

import { Event } from 'src/event/entities/event.entity';
import { Vote } from 'src/event/entities/vote.entity';
import { Track } from 'src/music/entities/track.entity';
import { User, VisibilityLevel } from 'src/user/entities/user.entity';
import { VoteResult } from './event.service';

import { SOCKET_ROOMS } from '../common/constants/socket-rooms';
import { IsLatitude } from 'class-validator';
import { getAvatarUrl } from 'src/common/utils/avatar.utils';
import { create } from 'domain';
import { UserService } from 'src/user/user.service';

interface AuthenticatedSocket extends Socket {
  userId?: string;
  user?: User;
}

@WebSocketGateway({
  cors: {
    origin: process.env.FRONTEND_URL || 'http://localhost:5173',
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
      if (!client.userId) {
        client.emit('error', { message: 'Authentication required' });
        return;
      }

      await client.join(SOCKET_ROOMS.EVENTS);
      client.emit('joined-events-room', { room: SOCKET_ROOMS.EVENTS });
      this.logger.log(`User ${client.userId} joined global events room`);
    } catch (error) {
      client.emit('error', { message: 'Failed to join events room', details: error.message });
    }
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
      const room = SOCKET_ROOMS.EVENT(eventId);
      await client.leave(room);

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
  }

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
        eventEndDate: event.eventEndDate,
        participants: event.participants ? event.participants.map(p => ({ id: p.id, displayName: p.displayName, avatarUrl: p.avatarUrl })) : [],
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

  notifyVoteUpdated(eventId: string, vote: Vote, results: VoteResult[]) {
    const room = SOCKET_ROOMS.EVENT(eventId);
    this.server.to(room).emit('vote-updated', {
      eventId,
      vote: {
        trackId: vote.trackId,
        userId: vote.userId,
        type: vote.type,
        weight: vote.weight,
      },
      results: results.slice(0, 10), // Top 10 tracks only
      timestamp: new Date().toISOString(),
    });
  }

  notifyVoteRemoved(eventId: string, vote: Vote, results: VoteResult[]) {
    const room = SOCKET_ROOMS.EVENT(eventId);
    this.server.to(room).emit('vote-removed', {
      eventId,
      vote: {
        trackId: vote.trackId,
        userId: vote.userId,
      },
      results: results.slice(0, 10),
      timestamp: new Date().toISOString(),
    });
  }

  notifyNowPlaying(eventId: string, track: Track) {
    const room = SOCKET_ROOMS.EVENT(eventId);
    this.server.to(room).emit('now-playing', {
      eventId,
      track: {
        id: track.id,
        title: track.title,
        artist: track.artist,
        album: track.album,
        duration: track.duration,
        albumCoverUrl: track.albumCoverUrl,
        previewUrl: track.previewUrl,
      },
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
  notifyTrackAdded(eventId: string, track: Track, addedBy: string) {
    const room = SOCKET_ROOMS.EVENT(eventId);
    this.server.to(room).emit('track-added', {
      eventId,
      track: {
        id: track.id,
        title: track.title,
        artist: track.artist,
        album: track.album,
        duration: track.duration,
        thumbnailUrl: track.albumCoverUrl,
        previewUrl: track.previewUrl,
        addedBy,
      },
      timestamp: new Date().toISOString(),
    });
  }

  notifyTrackRemoved(eventId: string, trackId: string, removedBy: string) {
    const room = SOCKET_ROOMS.EVENT(eventId);
    this.server.to(room).emit('track-removed', {
      eventId,
      trackId,
      removedBy,
      timestamp: new Date().toISOString(),
    });
  }

  notifyTracksReordered(eventId: string, trackOrder: string[], reorderedBy: string) {
    const room = SOCKET_ROOMS.EVENT(eventId);
    this.server.to(room).emit('tracks-reordered', {
      eventId,
      trackOrder,
      reorderedBy,
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

  // Synchronisation de l'état du player (play/pause/next/previous/position/volume)
  @SubscribeMessage('playback-state')
  async handlePlaybackState(
    @ConnectedSocket() client: AuthenticatedSocket,
    @MessageBody() { eventId, state }: { eventId: string; state: any }
  ) {
    if (!client.userId) return;
    // Broadcast à tous les participants
    this.server.to(SOCKET_ROOMS.EVENT(eventId)).emit('playback-state-updated', {
      eventId,
      state,
      timestamp: new Date().toISOString(),
    });
  }
}