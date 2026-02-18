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
import { EventStreamService } from './event-stream.service';

import { SOCKET_ROOMS } from '../common/constants/socket-rooms';
import { IsLatitude } from 'class-validator';
import { getAvatarUrl } from 'src/common/utils/avatar.utils';
import { create } from 'domain';
import { UserService } from 'src/user/user.service';
import { ParticipantRole } from './entities/event-participant.entity';
import { Device, DeviceStatus } from 'src/device/entities/device.entity';
import { DeviceService, PlaybackCommand } from 'src/device/device.service';

interface AuthenticatedSocket extends Socket {
  userId?: string;
  deviceId?: string;
  deviceIdentifier?: string;
  user?: User;
}

interface DeviceConnectionInfo {
  deviceId: string;
  deviceName: string;
  userId: string;
  userAgent?: string;
  connectedAt: string;
}

@WebSocketGateway({
  cors: {
    origin: '*', // process.env.FRONTEND_URL || 'http://localhost:5173',
    credentials: true,
  },
  namespace: '/',
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
    @Inject(forwardRef(() => EventStreamService))
    private eventStreamService: EventStreamService,
    @Inject(forwardRef(() => DeviceService))
    private deviceService: DeviceService,
  ) {}

  afterInit(server: Server) {
    this.logger.log('WebSocket Gateway initialized (Events & Devices)');
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
            
            // Automatically join the user's personal room for notifications
            const userRoom = SOCKET_ROOMS.USER(client.userId);
            await client.join(userRoom);
            
            this.logger.log(`✅ Client connected: ${client.id} (User: ${client.userId}, Display: ${user.displayName || user.email || 'No name'}) - Joined room: ${userRoom}`);
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
        } else if (room.startsWith('event-detail:')) {
          this.logger.log(`📋 Notifying room ${room} that user ${client.userId} left detail view`);
          this.server.to(room).emit('user-left-detail', {
            userId: client.userId,
            displayName: client.user?.displayName || 'Unknown User',
            timestamp: new Date().toISOString(),
          });
        } else if (room.startsWith('event-playlist:')) {
          this.logger.log(`🎵 Notifying room ${room} that user ${client.userId} left playlist view`);
          this.server.to(room).emit('user-left-playlist', {
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
      this.logger.debug(`User ${client.userId} is joining global events room ${eventId ? `and event room ${eventId}` : ''}`);

      if (!client.userId) {
        client.emit('error', { message: 'Authentication required' });
        return;
      }

      // Join the global EVENTS room to receive all event notifications
      await client.join(SOCKET_ROOMS.EVENTS);
      
      // Also join specific event room if eventId is provided
      if (eventId) {
        await client.join(SOCKET_ROOMS.EVENT(eventId));
      }
      
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
        const streamState = this.eventStreamService.getStreamState(eventId);
        if (streamState.trackId) {
          client.emit('playback-sync', {
            eventId,
            currentTrackId: streamState.trackId,
            startTime: streamState.position,
            isPlaying: streamState.isPlaying,
            trackDuration: streamState.trackDuration,
            timestamp: new Date().toISOString(),
            syncType: 'initial-join',
          });
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

  // ========== EVENT DETAIL ROOM HANDLERS ==========

  @SubscribeMessage('join-event-detail')
  async handleJoinEventDetail(
    @ConnectedSocket() client: AuthenticatedSocket,
    @MessageBody() { eventId }: { eventId: string },
  ) {
    try {
      if (!client.userId) {
        client.emit('error', { message: 'Authentication required' });
        return;
      }

      const room = SOCKET_ROOMS.EVENT_DETAIL(eventId);
      await client.join(room);

      // Ensure we have user data before proceeding
      if (!client.user) {
        this.logger.warn(`User data not available for ${client.userId}, attempting to fetch...`);
        try {
          client.user = await this.userService.findById(client.userId);
        } catch (error) {
          this.logger.error(`Failed to fetch user data for ${client.userId}: ${error.message}`);
        }
      }

      // Get current participants in the detail room (before broadcasting)
      const currentDetailParticipants = await this.getEventDetailParticipants(eventId);
      // Also get participants from the event-playlist room
      const currentPlaylistParticipants = await this.getEventPlaylistParticipants(eventId);
      // Merge unique user IDs from both rooms
      const allParticipantIds = [...new Set([...currentDetailParticipants, ...currentPlaylistParticipants])];

      // Build participant details and send to the new user
      const participantDetails: Array<{
        userId: string;
        displayName: string;
        avatarUrl: string | null;
        email: string;
      }> = [];
      for (const participantId of allParticipantIds) {
        if (participantId !== client.userId) {
          try {
            const participant = await this.userService.findById(participantId);
            participantDetails.push({
              userId: participant.id,
              displayName: participant.displayName || 'Unknown User',
              avatarUrl: participant.avatarUrl || null,
              email: participant.email,
            });
          } catch (error) {
            this.logger.warn(`Failed to fetch detail participant data for ${participantId}: ${error.message}`);
          }
        }
      }

      // Send current participants list to the joining user
      if (participantDetails.length > 0) {
        client.emit('current-participants-detail', {
          eventId,
          participants: participantDetails,
          timestamp: new Date().toISOString(),
        });
      }

      // Get user display name with fallback
      const userDisplayName = client.user?.displayName || 
                              client.user?.email?.split('@')[0] || 
                              `User-${client.userId.substring(0, 8)}` || 
                              'Unknown User';

      // Log user joining event detail room
      this.logger.log(`📋 User ${client.userId} (${userDisplayName}) joined event-detail room: ${eventId}`);

      // Broadcast to others in the room
      this.server.to(room).emit('user-joined-detail', {
        userId: client.userId,
        socketId: client.id,
        displayName: userDisplayName,
        avatarUrl: client.user?.avatarUrl || null,
        email: client.user?.email || '',
        timestamp: new Date().toISOString(),
      });

      // Confirm to the client that they joined
      client.emit('joined-event-detail', { eventId, room });
    } catch (error) {
      this.logger.error(`Error joining event detail room: ${error.message}`);
      client.emit('error', { message: 'Failed to join event detail', details: error.message });
    }
  }

  @SubscribeMessage('leave-event-detail')
  async handleLeaveEventDetail(
    @ConnectedSocket() client: AuthenticatedSocket,
    @MessageBody() { eventId }: { eventId: string },
  ) {
    try {
      this.logger.debug(`User ${client.userId} is leaving event-detail room ${eventId}`);
      const room = SOCKET_ROOMS.EVENT_DETAIL(eventId);
      await client.leave(room);

      if (!client.userId)
        client.userId = `User-${client.id.substring(0, 8)}`;
      // Get user display name with fallback
      const userDisplayName = client.user?.displayName || 
                              client.user?.email?.split('@')[0] || 
                              `User-${client.userId.substring(0, 8)}` || 
                              'Unknown User';
      // Log user leaving event detail room
      this.logger.log(`📋 User ${client.userId} (${userDisplayName}) left event-detail room: ${eventId}`);

      // Notify other participants that user left
      this.server.to(room).emit('user-left-detail', {
        userId: client.userId,
        displayName: userDisplayName,
        timestamp: new Date().toISOString(),
      });

      client.emit('left-event-detail', { eventId });
    } catch (error) {
      client.emit('error', { message: 'Failed to leave event detail', details: error.message });
    }
  }

  // ========== EVENT PLAYLIST ROOM HANDLERS ==========

  @SubscribeMessage('join-event-playlist')
  async handleJoinEventPlaylist(
    @ConnectedSocket() client: AuthenticatedSocket,
    @MessageBody() { eventId }: { eventId: string },
  ) {
    try {
      if (!client.userId) {
        client.emit('error', { message: 'Authentication required' });
        return;
      }

      const room = SOCKET_ROOMS.EVENT_PLAYLIST(eventId);
      await client.join(room);

      // Get user display name with fallback
      const userDisplayName = client.user?.displayName || 
                              client.user?.email?.split('@')[0] || 
                              `User-${client.userId.substring(0, 8)}` || 
                              'Unknown User';

      // Log user joining event playlist room
      this.logger.log(`🎵 User ${client.userId} (${userDisplayName}) joined event-playlist room: ${eventId}`);

      // Broadcast to others in the playlist room
      this.server.to(room).emit('user-joined-playlist', {
        userId: client.userId,
        socketId: client.id,
        displayName: userDisplayName,
        avatarUrl: client.user?.avatarUrl || null,
        email: client.user?.email || '',
        timestamp: new Date().toISOString(),
      });

      // Also notify the detail room so EventDetailsScreen sees this user
      const detailRoom = SOCKET_ROOMS.EVENT_DETAIL(eventId);
      this.server.to(detailRoom).emit('user-joined-detail', {
        userId: client.userId,
        socketId: client.id,
        displayName: userDisplayName,
        avatarUrl: client.user?.avatarUrl || null,
        email: client.user?.email || '',
        timestamp: new Date().toISOString(),
      });

      // Send current playback state so the joining user can sync
      try {
        // Use the stream service for accurate server-side position
        const streamState = this.eventStreamService.getStreamState(eventId);
        if (streamState.trackId) {
          client.emit('playback-sync', {
            eventId,
            currentTrackId: streamState.trackId,
            startTime: streamState.position,
            isPlaying: streamState.isPlaying,
            trackDuration: streamState.trackDuration,
            timestamp: new Date().toISOString(),
            syncType: 'initial-join',
          });
        }
      } catch (syncError) {
        this.logger.warn(`Failed to send playback sync on playlist join for user ${client.userId}: ${syncError.message}`);
      }

      // Confirm to the client that they joined
      client.emit('joined-event-playlist', { eventId, room });
    } catch (error) {
      this.logger.error(`Error joining event playlist room: ${error.message}`);
      client.emit('error', { message: 'Failed to join event playlist', details: error.message });
    }
  }

  @SubscribeMessage('leave-event-playlist')
  async handleLeaveEventPlaylist(
    @ConnectedSocket() client: AuthenticatedSocket,
    @MessageBody() { eventId }: { eventId: string },
  ) {
    try {
      this.logger.debug(`User ${client.userId} is leaving event-playlist room ${eventId}`);
      const room = SOCKET_ROOMS.EVENT_PLAYLIST(eventId);
      await client.leave(room);

      if (!client.userId)
        client.userId = `User-${client.id.substring(0, 8)}`;

      // Get user display name with fallback
      const userDisplayName = client.user?.displayName || 
                              client.user?.email?.split('@')[0] || 
                              `User-${client.userId.substring(0, 8)}` || 
                              'Unknown User';

      // Log user leaving event playlist room
      this.logger.log(`🎵 User ${client.userId} (${userDisplayName}) left event-playlist room: ${eventId}`);

      // Notify other participants in the playlist room that user left
      this.server.to(room).emit('user-left-playlist', {
        userId: client.userId,
        displayName: userDisplayName,
        timestamp: new Date().toISOString(),
      });

      // Also notify the detail room so EventDetailsScreen removes this user
      // (only if user is not still in the detail room itself)
      const detailRoom = SOCKET_ROOMS.EVENT_DETAIL(eventId);
      const detailSockets = await this.server.in(detailRoom).fetchSockets();
      const stillInDetailRoom = detailSockets.some(
        s => (s as unknown as AuthenticatedSocket).userId === client.userId
      );
      if (!stillInDetailRoom) {
        this.server.to(detailRoom).emit('user-left-detail', {
          userId: client.userId,
          displayName: userDisplayName,
          timestamp: new Date().toISOString(),
        });
      }

      client.emit('left-event-playlist', { eventId });
    } catch (error) {
      client.emit('error', { message: 'Failed to leave event playlist', details: error.message });
    }
  }

  // ========== VOTING SOCKET HANDLERS ==========

  /**
   * Handle upvote for a track via WebSocket
   * Provides real-time voting without needing HTTP call
   */
  @SubscribeMessage('upvote-track')
  async handleUpvoteTrack(
    @ConnectedSocket() client: AuthenticatedSocket,
    @MessageBody() { eventId, trackId, latitude, longitude }: { eventId: string; trackId: string; latitude?: number; longitude?: number },
  ) {
    try {
      if (!client.userId) {
        client.emit('error', { message: 'Authentication required' });
        return;
      }

      await this.eventService.voteForTrack(eventId, client.userId, {
        trackId,
        type: 'upvote' as any,
      }, latitude, longitude);

      this.logger.log(`User ${client.userId} upvoted track ${trackId} in event ${eventId}`);
    } catch (error) {
      this.logger.error(`Upvote error for user ${client.userId}: ${error.message}`);
      client.emit('error', { message: error.message || 'Failed to upvote track' });
    }
  }

  /**
   * Handle downvote for a track via WebSocket
   */
  @SubscribeMessage('downvote-track')
  async handleDownvoteTrack(
    @ConnectedSocket() client: AuthenticatedSocket,
    @MessageBody() { eventId, trackId, latitude, longitude }: { eventId: string; trackId: string; latitude?: number; longitude?: number },
  ) {
    try {
      if (!client.userId) {
        client.emit('error', { message: 'Authentication required' });
        return;
      }

      await this.eventService.voteForTrack(eventId, client.userId, {
        trackId,
        type: 'downvote' as any,
      }, latitude, longitude);

      this.logger.log(`User ${client.userId} downvoted track ${trackId} in event ${eventId}`);
    } catch (error) {
      this.logger.error(`Downvote error for user ${client.userId}: ${error.message}`);
      client.emit('error', { message: error.message || 'Failed to downvote track' });
    }
  }

  /**
   * Handle vote removal via WebSocket
   */
  @SubscribeMessage('remove-vote')
  async handleRemoveVote(
    @ConnectedSocket() client: AuthenticatedSocket,
    @MessageBody() { eventId, trackId }: { eventId: string; trackId: string },
  ) {
    try {
      if (!client.userId) {
        client.emit('error', { message: 'Authentication required' });
        return;
      }

      await this.eventService.removeVote(eventId, client.userId, trackId);

      this.logger.log(`User ${client.userId} removed vote for track ${trackId} in event ${eventId}`);
    } catch (error) {
      this.logger.error(`Remove vote error for user ${client.userId}: ${error.message}`);
      client.emit('error', { message: error.message || 'Failed to remove vote' });
    }
  }

  /**
   * Request current voting results
   */
  @SubscribeMessage('get-voting-results')
  async handleGetVotingResults(
    @ConnectedSocket() client: AuthenticatedSocket,
    @MessageBody() { eventId }: { eventId: string },
  ) {
    try {
      if (!client.userId) {
        client.emit('error', { message: 'Authentication required' });
        return;
      }

      const results = await this.eventService.getVotingResults(eventId, client.userId);
      
      client.emit('voting-results', {
        eventId,
        results,
        timestamp: new Date().toISOString(),
      });
      
      this.logger.log(`Sent voting results to user ${client.userId} for event ${eventId}`);
    } catch (error) {
      this.logger.error(`Get voting results error: ${error.message}`);
      client.emit('error', { message: 'Failed to get voting results' });
    }
  }

  /**
   * Request queue reorder (trigger manual reorder based on votes)
   */
  @SubscribeMessage('reorder-queue')
  async handleReorderQueue(
    @ConnectedSocket() client: AuthenticatedSocket,
    @MessageBody() { eventId }: { eventId: string },
  ) {
    try {
      if (!client.userId) {
        client.emit('error', { message: 'Authentication required' });
        return;
      }

      // Check if user can control playback (admin/creator)
      const canControl = await this.canControlPlayback(eventId, client.userId);
      if (!canControl) {
        client.emit('error', { message: 'Only event creators and admins can reorder queue' });
        return;
      }

      await this.eventService.reorderQueueByVotes(eventId);

      this.logger.log(`User ${client.userId} triggered queue reorder for event ${eventId}`);
    } catch (error) {
      this.logger.error(`Reorder queue error: ${error.message}`);
      client.emit('error', { message: 'Failed to reorder queue' });
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
    // Only broadcast new events to the global events room when they are public.
    // Private events should not be announced to everyone.
    const safeDateToISOString = (value: any) => {
      if (!value) return null;
      try {
        const d = value instanceof Date ? value : new Date(value);
        if (isNaN(d.getTime())) return null;
        return d.toISOString();
      } catch {
        return null;
      }
    };

    const payload = {
      event : {
        id: event.id,
        name: event.name,
        description: event.description,
        // Ensure string values for enums to avoid client-side decode errors
        type: event.type ?? 'playlist',
        visibility: event.visibility ?? 'private',
        licenseType: event.licenseType ?? null,
        status: event.status ?? null,
        locationName: event.locationName ?? null,
        eventDate: safeDateToISOString(event.eventDate),
        endDate: safeDateToISOString(event.endDate),
        createdAt: safeDateToISOString(event.createdAt) ?? new Date().toISOString(),
        updatedAt: safeDateToISOString(event.updatedAt) ?? new Date().toISOString(),
        participants: event.participants ? event.participants.map(p => ({
          eventId: p.eventId,
          userId: p.userId,
          role: p.role,
          joinedAt: safeDateToISOString(p.joinedAt),
          user: p.user ? {
            id: p.user.id,
            displayName: p.user.displayName ?? null,
            avatarUrl: p.user.avatarUrl ?? null,
            createdAt: safeDateToISOString(p.user.createdAt),
            updatedAt: safeDateToISOString(p.user.updatedAt),
          } : null,
        })) : [],
        participantsCount: event.participants ? event.participants.length : 0,
        // Playlist stats
        trackCount: event.tracks ? event.tracks.length : 0,
        totalDuration: event.totalDuration ?? 0,
        collaboratorCount: event.participants ? event.participants.filter(p => p.role === ParticipantRole.COLLABORATOR || p.role === ParticipantRole.ADMIN).length : 0,
        creator: creator ? {
          id: creator.id,
          displayName: creator.displayName ?? null,
          avatarUrl: creator.avatarUrl ?? null,
          createdAt: safeDateToISOString(creator.createdAt) ?? new Date().toISOString(),
          updatedAt: safeDateToISOString(creator.updatedAt),
        } : null,
      },
      timestamp: new Date().toISOString(),
    };

    if (event.visibility === EventVisibility.PUBLIC) {
      this.server.to(SOCKET_ROOMS.EVENTS).emit('event-created', payload);
    } else if (creator && creator.id) {
      // Emit to the creator's personal room so the creator still receives the confirmation via sockets
      this.server.to(SOCKET_ROOMS.USER(creator.id)).emit('event-created', payload);
    }
  }

  notifyEventUpdated(eventId: string, event: Event) {
    const payload = {
      eventId,
      event,
      timestamp: new Date().toISOString(),
    };

    // Always notify clients currently in the event room (join-event)
    this.server.to(SOCKET_ROOMS.EVENT(eventId)).emit('event-updated', payload);

    // Notify clients viewing the event detail screen
    this.server.to(SOCKET_ROOMS.EVENT_DETAIL(eventId)).emit('event-updated', payload);

    // Notify clients viewing the playlist detail screen
    this.server.to(SOCKET_ROOMS.EVENT_PLAYLIST(eventId)).emit('event-updated', payload);

    // For public events: broadcast to the global events list room
    if (event.visibility === EventVisibility.PUBLIC) {
      this.server.to(SOCKET_ROOMS.EVENTS).emit('event-updated', payload);
    } else {
      // For private events: notify creator and each participant via their personal rooms
      if (event.creatorId) {
        this.server.to(SOCKET_ROOMS.USER(event.creatorId)).emit('event-updated', payload);
      }
      if (event.participants) {
        for (const p of event.participants) {
          if (p && p.userId) {
            this.server.to(SOCKET_ROOMS.USER(p.userId)).emit('event-updated', payload);
          }
        }
      }
    }
  }

  async notifyEventDeleted(eventId: string) {
    try {
      const event = await this.eventService.findByIdNoAccess(eventId);

      const payload = {
        eventId,
        timestamp: new Date().toISOString(),
      };

      // Only broadcast to the global events room for PUBLIC events
      if (event.visibility === EventVisibility.PUBLIC) {
        this.server.to(SOCKET_ROOMS.EVENTS).emit('event-deleted', payload);
      } else {
        // For private events, notify the creator and known participants via their user rooms
        if (event.creatorId) {
          this.server.to(SOCKET_ROOMS.USER(event.creatorId)).emit('event-deleted', payload);
        }

        if (event.participants) {
          for (const p of event.participants) {
            if (p && p.userId) {
              this.server.to(SOCKET_ROOMS.USER(p.userId)).emit('event-deleted', payload);
            }
          }
        }
      }

      // Always emit to the specific event room (clients currently in the room)
      const room = SOCKET_ROOMS.EVENT(eventId);
      this.server.to(room).emit('event-deleted', payload);
    } catch (error) {
      // If we couldn't load the event for any reason, fall back to emitting to the event room only
      const room = SOCKET_ROOMS.EVENT(eventId);
      this.server.to(room).emit('event-deleted', {
        eventId,
        timestamp: new Date().toISOString(),
      });
    }
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
    const playlistRoom = SOCKET_ROOMS.EVENT_PLAYLIST(eventId);
    this.logger.debug(`Notifying vote update in event ${eventId} for track ${vote.trackId} by user ${vote.userId}`);

    const payload = {
      eventId,
      vote: {
        trackId: vote.trackId,
        userId: vote.userId,
        type: vote.type,
        weight: vote.weight,
      },
      // results: tracks.slice(0, 10), // Top 10 tracks only
      // timestamp: new Date().toISOString(),
    };

    // Emit to all relevant rooms
    this.server.to(room).emit('vote-updated', payload);
    this.server.to(playlistRoom).emit('vote-updated', payload);
  }

  notifyVoteRemoved(eventId: string, vote: Vote/* , tracks: TrackVoteSnapshot[]*/) {
    const room = SOCKET_ROOMS.EVENT(eventId);
    const playlistRoom = SOCKET_ROOMS.EVENT_PLAYLIST(eventId);

    const payload = {
      eventId,
      vote: {
        trackId: vote.trackId,
        userId: vote.userId,
        type: vote.type,
        weight: vote.weight,
      },
      // results: tracks.slice(0, 10),
      // timestamp: new Date().toISOString(),
    };

    this.server.to(room).emit('vote-removed', payload);
    this.server.to(playlistRoom).emit('vote-removed', payload);
  }

  /**
   * Notify when queue is reordered based on votes
   */
  notifyQueueReordered(eventId: string, trackOrder: string[], trackScores: Map<string, number>) {
    const room = SOCKET_ROOMS.EVENT(eventId);
    const playlistRoom = SOCKET_ROOMS.EVENT_PLAYLIST(eventId);
    
    // Convert Map to object for JSON serialization
    const scoresObject: Record<string, number> = {};
    trackScores.forEach((score, trackId) => {
      scoresObject[trackId] = score;
    });

    const payload = {
      eventId,
      trackOrder,
      trackScores: scoresObject,
      timestamp: new Date().toISOString(),
    };

    this.server.to(room).emit('queue-reordered', payload);
    // Also notify event playlist viewers (not generic playlists)
    try {
      this.server.to(playlistRoom).emit('queue-reordered', payload);
    } catch (e) {
      this.logger.debug(`Failed to emit queue-reordered to event-playlist room for ${eventId}: ${e?.message || e}`);
    }
    // Also emit legacy reorder events so clients listening to those get updates
    try {
      const reorderPayload = {
        eventId,
        playlistId: eventId,
        trackOrder,
        trackIds: trackOrder,
        reorderedBy: 'voting-system',
        timestamp: new Date().toISOString(),
      };

      this.server.to(room).emit('tracks-reordered', reorderPayload);
      this.server.to(playlistRoom).emit('tracks-reordered', reorderPayload);

      // Also notify global events room about playlist reorder
      this.server.to(SOCKET_ROOMS.EVENTS).emit('playlist-tracks-reordered', {
        playlistId: eventId,
        timestamp: new Date().toISOString(),
      });
    } catch (e) {
      this.logger.debug(`Failed to emit tracks-reordered to playlist rooms for ${eventId}: ${e?.message || e}`);
    }
    
    this.logger.log(`Queue reordered for event ${eventId} based on votes`);
  }

  /**
   * Notify when a track's vote count changes (for real-time UI updates)
   */
  notifyTrackVotesChanged(eventId: string, trackId: string, upvotes: number, downvotes: number, score: number) {
    const room = SOCKET_ROOMS.EVENT(eventId);
    const playlistRoom = SOCKET_ROOMS.EVENT_PLAYLIST(eventId);
    const genericPlaylistRoom = SOCKET_ROOMS.PLAYLIST(eventId);

    const payload = {
      eventId,
      trackId,
      upvotes,
      downvotes,
      score,
      timestamp: new Date().toISOString(),
    };

    this.server.to(room).emit('track-votes-changed', payload);
    this.server.to(playlistRoom).emit('track-votes-changed', payload);
    this.server.to(genericPlaylistRoom).emit('track-votes-changed', payload);
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
    const playlistRoom = SOCKET_ROOMS.EVENT_PLAYLIST(eventId);
    const genericPlaylistRoom = SOCKET_ROOMS.PLAYLIST(eventId);
    
    // Handle both Track and PlaylistTrackWithDetails
    const trackData = track.track ? {
      // Use the playlist-track id as the emitted id (so clients can deduplicate)
      id: track.id,
      // Keep the underlying music track id available as trackId
      trackId: track.track.id,
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
      trackId: track.trackId || track.track?.id,
      title: track.title,
      artist: track.artist,
      album: track.album,
      duration: track.duration,
      thumbnailUrl: track.albumCoverUrl,
      previewUrl: track.previewUrl,
      addedBy,
    };

    // Emit to event room
    this.server.to(room).emit('track-added', {
      eventId,
      playlistId: eventId, // Support both
      track: trackData,
      addedBy,
      timestamp: new Date().toISOString(),
    });

    // Also emit to clients viewing the event playlist and generic playlist room
    try {
      this.server.to(playlistRoom).emit('track-added', {
        eventId,
        playlistId: eventId,
        track: trackData,
        addedBy,
        timestamp: new Date().toISOString(),
      });

      this.server.to(genericPlaylistRoom).emit('track-added', {
        eventId,
        playlistId: eventId,
        track: trackData,
        addedBy,
        timestamp: new Date().toISOString(),
      });
    } catch (e) {
      this.logger.debug(`Failed to emit track-added to playlist rooms for ${eventId}: ${e?.message || e}`);
    }
  }

  notifyTrackRemoved(eventId: string, trackId: string, removedBy: string, updatedTrackCount?: number) {
    const room = SOCKET_ROOMS.EVENT(eventId);
    const playlistRoom = SOCKET_ROOMS.EVENT_PLAYLIST(eventId);
    const genericPlaylistRoom = SOCKET_ROOMS.PLAYLIST(eventId);

    // Emit to event room
    this.server.to(room).emit('track-removed', {
      eventId,
      playlistId: eventId, // Support both
      trackId,
      removedBy,
      timestamp: new Date().toISOString(),
    });

    // Also emit to clients viewing the event playlist and generic playlist room
    try {
      this.server.to(playlistRoom).emit('track-removed', {
        eventId,
        playlistId: eventId,
        trackId,
        removedBy,
        timestamp: new Date().toISOString(),
      });

      this.server.to(genericPlaylistRoom).emit('track-removed', {
        eventId,
        playlistId: eventId,
        trackId,
        removedBy,
        timestamp: new Date().toISOString(),
      });
    } catch (e) {
      this.logger.debug(`Failed to emit track-removed to playlist rooms for ${eventId}: ${e?.message || e}`);
    }
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

  // Get connected users in an event-detail room
  async getEventDetailParticipants(eventId: string): Promise<string[]> {
    const room = SOCKET_ROOMS.EVENT_DETAIL(eventId);
    const sockets = await this.server.in(room).fetchSockets();
    return sockets
      .map(socket => (socket as unknown as AuthenticatedSocket).userId)
      .filter(userId => userId !== undefined) as string[];
  }

  // Get connected users in an event-playlist room
  async getEventPlaylistParticipants(eventId: string): Promise<string[]> {
    const room = SOCKET_ROOMS.EVENT_PLAYLIST(eventId);
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
  // All playback is now driven by the server-side EventStreamService
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

      const canControl = await this.canControlPlayback(eventId, client.userId);
      if (!canControl) {
        client.emit('error', { message: 'Only event creators and admins can control playback' });
        return;
      }

      if (this.eventStreamService.hasActiveStream(eventId)) {
        // Stream already active — resume or change track
        const state = this.eventStreamService.getStreamState(eventId);
        if (trackId && trackId !== state.trackId) {
          await this.eventStreamService.changeTrack(eventId, trackId);
        } else {
          this.eventStreamService.resumeStream(eventId, startTime ?? undefined);
        }
      } else {
        // Start new stream
        await this.eventStreamService.startStream(eventId, trackId ?? undefined);
      }

      this.logger.log(`User ${client.userId} played track ${trackId || '(current)'} in event ${eventId} via stream engine`);
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

      const canControl = await this.canControlPlayback(eventId, client.userId);
      if (!canControl) {
        client.emit('error', { message: 'Only event creators and admins can control playback' });
        return;
      }

      this.eventStreamService.pauseStream(eventId);

      this.logger.log(`User ${client.userId} paused playback in event ${eventId} via stream engine`);
    } catch (error) {
      this.logger.error(`Pause track error: ${error.message}`);
      client.emit('error', { message: 'Failed to pause track', details: error.message });
    }
  }

  @SubscribeMessage('stop-stream')
  async handleStopStream(
    @ConnectedSocket() client: AuthenticatedSocket,
    @MessageBody() { eventId }: { eventId: string }
  ) {
    try {
      if (!client.userId) {
        client.emit('error', { message: 'Authentication required' });
        return;
      }

      const canControl = await this.canControlPlayback(eventId, client.userId);
      if (!canControl) {
        client.emit('error', { message: 'Only event creators and admins can control playback' });
        return;
      }

      this.eventStreamService.stopStream(eventId);

      this.logger.log(`User ${client.userId} stopped stream in event ${eventId}`);
    } catch (error) {
      this.logger.error(`Stop stream error: ${error.message}`);
      client.emit('error', { message: 'Failed to stop stream', details: error.message });
    }
  }

  @SubscribeMessage('seek-track')
  async handleSeekTrack(
    @ConnectedSocket() client: AuthenticatedSocket,
    @MessageBody() { eventId, seekTime, trackId, isPlaying }: { eventId: string; seekTime: number; trackId?: string; isPlaying?: boolean }
  ) {
    try {
      if (!client.userId) {
        client.emit('error', { message: 'Authentication required' });
        return;
      }

      const canControl = await this.canControlPlayback(eventId, client.userId);
      if (!canControl) {
        client.emit('error', { message: 'Only event creators and admins can control playback' });
        return;
      }

      this.eventStreamService.seekStream(eventId, seekTime);

      this.logger.log(`User ${client.userId} seeked to ${seekTime}s in event ${eventId} via stream engine`);
    } catch (error) {
      this.logger.error(`Seek track error: ${error.message}`);
      client.emit('error', { message: 'Failed to seek track', details: error.message });
    }
  }

  @SubscribeMessage('request-playback-sync')
  async handleRequestPlaybackSync(
    @ConnectedSocket() client: AuthenticatedSocket,
    @MessageBody() { eventId }: { eventId: string }
  ) {
    try {
      if (!client.userId) {
        client.emit('error', { message: 'Authentication required' });
        return;
      }

      const streamState = this.eventStreamService.getStreamState(eventId);
      if (streamState.trackId) {
        client.emit('playback-sync', {
          eventId,
          currentTrackId: streamState.trackId,
          startTime: streamState.position,
          isPlaying: streamState.isPlaying,
          trackDuration: streamState.trackDuration,
          timestamp: new Date().toISOString(),
          syncType: 'user-request',
        });
      }

      this.logger.log(`User ${client.userId} requested playback sync for event ${eventId}`);
    } catch (error) {
      this.logger.error(`Request playback sync error: ${error.message}`);
      client.emit('error', { message: 'Failed to sync playback', details: error.message });
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

      const canControl = await this.canControlPlayback(eventId, client.userId);
      if (!canControl) {
        client.emit('error', { message: 'Only event creators and admins can control playback' });
        return;
      }

      if (this.eventStreamService.hasActiveStream(eventId)) {
        await this.eventStreamService.changeTrack(eventId, trackId);
      } else {
        await this.eventStreamService.startStream(eventId, trackId);
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

      const genericPlaylistRoom = SOCKET_ROOMS.PLAYLIST(eventId);
      this.server.to(SOCKET_ROOMS.EVENT(eventId)).emit('music-volume', {
        eventId,
        volume: Math.max(0, Math.min(100, volume)),
        controlledBy: client.userId,
        timestamp: new Date().toISOString(),
      });

      this.server.to(SOCKET_ROOMS.EVENT_PLAYLIST(eventId)).emit('music-volume', {
        eventId,
        volume: Math.max(0, Math.min(100, volume)),
        controlledBy: client.userId,
        timestamp: new Date().toISOString(),
      });

      this.server.to(genericPlaylistRoom).emit('music-volume', {
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

      const canControl = await this.canControlPlayback(eventId, client.userId);
      if (!canControl) {
        client.emit('error', { message: 'Only event creators and admins can skip tracks' });
        return;
      }

      await this.eventStreamService.skipTrack(eventId);

      this.logger.log(`User ${client.userId} skipped track in event ${eventId} via stream engine`);
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
      const playlistRoom = SOCKET_ROOMS.EVENT_PLAYLIST(eventId);
      const event = await this.eventService.findById(eventId, adminUserId);
      
      // Event IS playlist when type=playlist
      if (event.trackCount !== undefined && event.trackCount !== null) {
        await this.eventService.removeTrack(event.id, trackId, adminUserId);
        
        const updatedPlaylist = await this.eventService.getPlaylistTracks(event.id);
        
        if (updatedPlaylist.length > 0) {
          const nextTrack = updatedPlaylist[0];
          
          const payload = {
            eventId,
            trackId: nextTrack.trackId,
            trackIndex: 0,
            controlledBy: adminUserId,
            autoSkipped: true,
            skipReason: reason,
            continuePlaying: true,
            timestamp: new Date().toISOString(),
          };
          this.server.to(room).emit('music-track-changed', payload);
          this.server.to(playlistRoom).emit('music-track-changed', payload);
          
          this.trackAccessibilityReports.delete(`${eventId}:${trackId}`);
          
          await this.eventService.updateCurrentTrack(eventId, nextTrack.trackId);
        } else {
          await this.eventService.clearCurrentTrack(eventId);
          const pausePayload = {
            eventId,
            controlledBy: adminUserId,
            reason: 'no_more_tracks',
            timestamp: new Date().toISOString(),
          };
          this.server.to(room).emit('music-pause', pausePayload);
          this.server.to(playlistRoom).emit('music-pause', pausePayload);
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

      // Track-ended is now handled server-side by EventStreamService.
      // If an admin sends this, treat it as a skip request.
      const canControl = await this.canControlPlayback(eventId, client.userId);
      if (canControl) {
        this.logger.log(`Admin ${client.userId} sent track-ended for ${trackId} in ${eventId} — treating as skip`);
        await this.eventStreamService.skipTrack(eventId);
      } else {
        // Non-admin: ignore. Server drives the stream.
        this.logger.debug(`Non-admin ${client.userId} sent track-ended — ignoring (server drives stream)`);
      }
    } catch (error) {
      this.logger.error(`Track ended notification error: ${error.message}`);
      client.emit('error', { message: 'Failed to notify track ended', details: error.message });
    }
  }

  // Periodic time sync for live events — now handled by EventStreamService.
  // These methods are kept as no-ops for backward compatibility.
  private syncIntervals = new Map<string, NodeJS.Timeout>();

  private async startTimeSyncForEvent(eventId: string) {
    // No-op: EventStreamService now broadcasts time-sync from its tick loop
  }

  private stopTimeSyncForEvent(eventId: string) {
    // No-op: EventStreamService manages its own timers
    const interval = this.syncIntervals.get(eventId);
    if (interval) {
      clearInterval(interval);
      this.syncIntervals.delete(eventId);
    }
  }

  // ============================
  // Stream broadcast methods (called by EventStreamService)
  // ============================

  broadcastStreamPlay(eventId: string, data: { trackId: string | null; position: number; isPlaying: boolean }) {
    const payload = {
      eventId,
      trackId: data.trackId,
      startTime: data.position,
      isPlaying: data.isPlaying,
      controlledBy: 'server',
      timestamp: new Date().toISOString(),
      syncType: 'server-play',
    };
    this.server.to(SOCKET_ROOMS.EVENT(eventId)).emit('music-play', payload);
    this.server.to(SOCKET_ROOMS.EVENT_PLAYLIST(eventId)).emit('music-play', payload);
    this.server.to(SOCKET_ROOMS.PLAYLIST(eventId)).emit('music-play', payload);
  }

  broadcastStreamPause(eventId: string, data: { trackId: string | null; position: number; isPlaying: boolean }) {
    const payload = {
      eventId,
      trackId: data.trackId,
      currentTime: data.position,
      isPlaying: data.isPlaying,
      controlledBy: 'server',
      timestamp: new Date().toISOString(),
      syncType: 'server-pause',
    };
    this.server.to(SOCKET_ROOMS.EVENT(eventId)).emit('music-pause', payload);
    this.server.to(SOCKET_ROOMS.EVENT_PLAYLIST(eventId)).emit('music-pause', payload);
    this.server.to(SOCKET_ROOMS.PLAYLIST(eventId)).emit('music-pause', payload);
  }

  broadcastStreamSeek(eventId: string, data: { trackId: string | null; position: number; isPlaying: boolean }) {
    const payload = {
      eventId,
      seekTime: data.position,
      trackId: data.trackId,
      isPlaying: data.isPlaying,
      shouldPlay: data.isPlaying,
      controlledBy: 'server',
      timestamp: new Date().toISOString(),
      syncType: 'server-seek',
    };
    this.server.to(SOCKET_ROOMS.EVENT(eventId)).emit('music-seek', payload);
    this.server.to(SOCKET_ROOMS.EVENT_PLAYLIST(eventId)).emit('music-seek', payload);
    this.server.to(SOCKET_ROOMS.PLAYLIST(eventId)).emit('music-seek', payload);
  }

  broadcastStreamStop(eventId: string) {
    const payload = {
      eventId,
      stoppedBy: 'server',
      reason: 'no_more_tracks',
      timestamp: new Date().toISOString(),
    };
    this.server.to(SOCKET_ROOMS.EVENT(eventId)).emit('music-stop', payload);
    this.server.to(SOCKET_ROOMS.EVENT_PLAYLIST(eventId)).emit('music-stop', payload);
    this.server.to(SOCKET_ROOMS.PLAYLIST(eventId)).emit('music-stop', payload);
  }

  broadcastStreamTrackChanged(eventId: string, data: { trackId: string; position: number; isPlaying: boolean; trackDuration: number }) {
    const payload = {
      eventId,
      trackId: data.trackId,
      trackIndex: 0,
      position: data.position,
      isPlaying: data.isPlaying,
      trackDuration: data.trackDuration,
      continuePlaying: false, // will become true after loading grace period
      controlledBy: 'server',
      timestamp: new Date().toISOString(),
    };
    this.server.to(SOCKET_ROOMS.EVENT(eventId)).emit('music-track-changed', payload);
    this.server.to(SOCKET_ROOMS.EVENT_PLAYLIST(eventId)).emit('music-track-changed', payload);
    this.server.to(SOCKET_ROOMS.PLAYLIST(eventId)).emit('music-track-changed', payload);
  }

  broadcastStreamTrackEnded(eventId: string, trackId: string) {
    const payload = {
      eventId,
      trackId,
      notifiedBy: 'server',
      timestamp: new Date().toISOString(),
    };
    this.server.to(SOCKET_ROOMS.EVENT(eventId)).emit('track-ended', payload);
    this.server.to(SOCKET_ROOMS.EVENT_PLAYLIST(eventId)).emit('track-ended', payload);
  }

  broadcastTimeSync(eventId: string, data: { trackId: string | null; position: number; isPlaying: boolean; trackDuration: number }) {
    const payload = {
      eventId,
      trackId: data.trackId,
      currentTime: data.position,
      isPlaying: data.isPlaying,
      trackDuration: data.trackDuration,
      timestamp: new Date().toISOString(),
      syncType: 'server-periodic-sync',
    };
    this.server.to(SOCKET_ROOMS.EVENT(eventId)).emit('time-sync', payload);
    this.server.to(SOCKET_ROOMS.EVENT_PLAYLIST(eventId)).emit('time-sync', payload);
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
      if (isAdmin) {
        return true;
      }

      // Check if user has delegation from the event creator
      // User can control if they have an active device delegation from the creator
      const delegatedDevices = await this.deviceService.findDelegatedDevices(userId);
      const hasDelegationFromCreator = delegatedDevices.some(device => {
        // Check if device is owned by event creator and delegation is still active
        const isFromCreator = device.ownerId === event.creatorId;
        const isActive = device.delegationExpiresAt && new Date(device.delegationExpiresAt) > new Date();
        return isFromCreator && isActive;
      });

      return hasDelegationFromCreator;
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
          type: playlist.event?.type,
          visibility: playlist.event?.visibility,
          coverImageUrl: playlist.event?.coverImageUrl,
          createdAt: playlist.createdAt,
          updatedAt: playlist.updatedAt || playlist.createdAt,
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

  // ============================================
  // INVITATION NOTIFICATIONS
  // ============================================

  /**
   * Notify a user that they received an invitation
   */
  notifyInvitationReceived(inviteeId: string, invitation: any) {
    const userRoom = SOCKET_ROOMS.USER(inviteeId);
    this.server.to(userRoom).emit('invitation-received', {
      invitation: {
        id: invitation.id,
        type: invitation.type,
        status: invitation.status,
        message: invitation.message,
        eventId: invitation.eventId,
        eventName: invitation.event?.name,
        inviter: invitation.inviter ? {
          id: invitation.inviter.id,
          displayName: invitation.inviter.displayName,
          avatarUrl: invitation.inviter.avatarUrl,
        } : null,
        createdAt: invitation.createdAt,
        expiresAt: invitation.expiresAt,
      },
      timestamp: new Date().toISOString(),
    });
    this.logger.log(`Notified user ${inviteeId} of new invitation`);
  }

  /**
   * Notify the inviter that their invitation was responded to
   */
  notifyInvitationResponded(inviterId: string, invitation: any, response: string) {
    const userRoom = SOCKET_ROOMS.USER(inviterId);
    this.server.to(userRoom).emit('invitation-responded', {
      invitation: {
        id: invitation.id,
        type: invitation.type,
        status: response,
        eventId: invitation.eventId,
        eventName: invitation.event?.name,
        invitee: invitation.invitee ? {
          id: invitation.invitee.id,
          displayName: invitation.invitee.displayName,
          avatarUrl: invitation.invitee.avatarUrl,
        } : null,
      },
      response,
      timestamp: new Date().toISOString(),
    });
    this.logger.log(`Notified user ${inviterId} that invitation was ${response}`);
  }

  /**
   * Notify event participants when a new user joins via invitation
   */
  notifyInvitationAccepted(eventId: string, user: any) {
    const room = SOCKET_ROOMS.EVENT(eventId);
    this.server.to(room).emit('invitation-accepted', {
      eventId,
      user: {
        id: user.id,
        displayName: user.displayName,
        avatarUrl: user.avatarUrl,
      },
      timestamp: new Date().toISOString(),
    });
  }

  /**
   * Allow users to join their personal notification room
   */
  @SubscribeMessage('join-user-room')
  async handleJoinUserRoom(
    @ConnectedSocket() client: AuthenticatedSocket,
  ) {
    try {
      if (!client.userId) {
        client.emit('error', { message: 'Authentication required' });
        return;
      }

      const userRoom = SOCKET_ROOMS.USER(client.userId);
      await client.join(userRoom);
      
      client.emit('joined-user-room', { room: userRoom });
      this.logger.log(`User ${client.userId} joined their personal room`);
    } catch (error) {
      client.emit('error', { message: 'Failed to join user room' });
    }
  }

  // ==================== DEVICE HANDLERS ====================

  // Device Connection Management
  @SubscribeMessage('connect-device')
  async handleConnectDevice(
    @ConnectedSocket() client: AuthenticatedSocket,
    @MessageBody() data?: any,
  ) {
    const deviceIdentifier = data[0]?.deviceIdentifier;
    console.log('handleConnectDevice called', deviceIdentifier, client.id);

    try {
      if (!client.userId) {
        client.emit('error', { message: 'Authentication required' });
        console.error('handleConnectDevice unauthorized: no userId', { clientUserId: client.userId });
        return;
      }

      // Register connection with device service
      await this.deviceService.registerConnection(
        client.userId,
        client.id,
        undefined,
        deviceIdentifier,
      );

      // Join device room
      const room = SOCKET_ROOMS.DEVICE(deviceIdentifier);
      this.logger.debug(`Joining DEVICE room ${room} for device ${deviceIdentifier}`);
      await client.join(room);
      const userRoom = SOCKET_ROOMS.USER(client.userId);
      await client.join(userRoom);
      
      // Store device info in client
      client.deviceIdentifier = deviceIdentifier;
      client.data.connectedAt = new Date().toISOString();

      client.emit('device-connected', {
        deviceIdentifier,
        message: 'Successfully connected to device',
        timestamp: new Date().toISOString(),
      });

      this.logger.log(`User ${client.userId} connected to device ${deviceIdentifier}`);
    } catch (error) {
      client.emit('error', { message: 'Failed to connect to device', details: error.message });
      this.logger.error(`device ${deviceIdentifier} Error: ${error.message}`);
    }
  }

  @SubscribeMessage('disconnect-device')
  async handleDisconnectDevice(
    @ConnectedSocket() client: AuthenticatedSocket,
    @MessageBody() { deviceId }: { deviceId: string },
    @MessageBody() data?: any,
  ) {
    console.log('handle disconnect-device called', { deviceId, data });

    try {
      if (!client.userId || client.deviceId !== deviceId) {
        console.log('handle disconnect-device unauthorized', { clientUserId: client.userId, clientDeviceId: client.deviceId, deviceId });
        client.emit('error', { message: 'Not connected to this device' });
        return;
      }

      // Leave device room
      const room = SOCKET_ROOMS.DEVICE(deviceId);
      await client.leave(room);

      // Unregister connection
      await this.deviceService.unregisterConnection(client.id);

      // Clear device info from client
      delete client.deviceId;
      delete client.data.deviceInfo;
      delete client.data.connectedAt;

      client.emit('device-disconnected', {
        deviceId,
        message: 'Successfully disconnected from device',
        timestamp: new Date().toISOString(),
      });

      this.logger.log(`User ${client.userId} disconnected from device ${deviceId}`);
    } catch (error) {
      client.emit('error', { message: 'Failed to disconnect from device', details: error.message });
    }
  }

  // Heartbeat for connection maintenance
  @SubscribeMessage('heartbeat')
  async handleHeartbeat(
    @ConnectedSocket() client: AuthenticatedSocket,
    @MessageBody() { deviceId }: { deviceId?: string },
  ) {
    try {
      if (client.deviceId && deviceId && client.deviceId === deviceId) {
        await this.deviceService.updateLastActivity(client.id);
        client.emit('heartbeat-ack', { timestamp: new Date().toISOString() });
      }
    } catch (error) {
      // Silently handle heartbeat errors
    }
  }

  // Device Status Updates
  @SubscribeMessage('update-device-status')
  async handleUpdateDeviceStatus(
    @ConnectedSocket() client: AuthenticatedSocket,
    @MessageBody() { deviceId, status, metadata }: { 
      deviceId: string; 
      status: DeviceStatus; 
      metadata?: any;
    },
  ) {
    try {
      if (!client.userId || client.deviceId !== deviceId) {
        client.emit('error', { message: 'Unauthorized device status update' });
        return;
      }

      // Update last activity
      await this.deviceService.updateLastActivity(client.id);

      // Broadcast status update to device room
      const room = SOCKET_ROOMS.DEVICE(deviceId);
      this.server.to(room).emit('device-status-updated', {
        deviceId,
        status,
        metadata,
        updatedBy: client.userId,
        timestamp: new Date().toISOString(),
      });

      this.logger.log(`Device ${deviceId} status updated to ${status}`);
    } catch (error) {
      client.emit('error', { message: 'Failed to update device status', details: error.message });
    }
  }

  // Playback State Synchronization (for devices)
  @SubscribeMessage('device-playback-state')
  async handleDevicePlaybackState(
    @ConnectedSocket() client: AuthenticatedSocket,
    @MessageBody() data?: any,
  ) {
    const { deviceIdentifier, command } = data[0];

    this.logger.debug(`SubscribeMessage('device-playback-state') Device ${deviceIdentifier} state command: ${command}`);

    try {
      // Update last activity
      await this.deviceService.updateLastActivity(client.id);

      // Broadcast playback state to device room
      const room = SOCKET_ROOMS.DEVICE(deviceIdentifier);
      client.to(room).emit('playback-state-updated', {
        deviceIdentifier,
        command,
        timestamp: new Date().toISOString(),
      });
    } catch (error) {
      // Silently handle playback state errors
    }
  }

  // Real-time notifications to device controllers
  @SubscribeMessage('request-device-info')
  async handleRequestDeviceInfo(
    @ConnectedSocket() client: AuthenticatedSocket,
    @MessageBody() { deviceId }: { deviceId: string },
  ) {
    try {
      if (!client.userId) {
        client.emit('error', { message: 'Authentication required' });
        return;
      }

      // Check if user has access to device
      const device = await this.deviceService.findById(deviceId, client.userId);
      
      // Request info from connected device clients
      const room = SOCKET_ROOMS.DEVICE(deviceId);
      this.server.to(room).emit('device-info-requested', {
        requesterId: client.userId,
        requestId: `${client.id}-${Date.now()}`,
        timestamp: new Date().toISOString(),
      });

    } catch (error) {
      client.emit('error', { message: 'Failed to request device info', details: error.message });
    }
  }

  @SubscribeMessage('device-info-response')
  async handleDeviceInfoResponse(
    @ConnectedSocket() client: AuthenticatedSocket,
    @MessageBody() { requestId, deviceInfo, playbackState }: { 
      requestId: string;
      deviceInfo: any;
      playbackState: any;
    },
  ) {
    try {
      // Forward response back to requester
      this.server.emit('device-info-received', {
        requestId,
        deviceId: client.deviceId,
        deviceInfo,
        playbackState,
        timestamp: new Date().toISOString(),
      });
    } catch (error) {
      // Silently handle response errors
    }
  }

  // Get device connections in real-time
  @SubscribeMessage('get-device-connections')
  async handleGetDeviceConnections(
    @ConnectedSocket() client: AuthenticatedSocket,
    @MessageBody() data?: any,
  ) {
    const deviceId = data[0]?.deviceId;
    try {
      if (!client.userId) {
        client.emit('error', { message: 'Authentication required' });
        return;
      }
      const connections = await this.getDeviceConnections(deviceId);
      console.log('handleGetDeviceConnections called', { deviceId, connections });
      client.emit('device-connections', { deviceId, connections });
    } catch (error) {
      client.emit('error', { message: 'Failed to get device connections', details: error.message });
    }
  }

  @SubscribeMessage('which-rooms')
  async handleGetwhichRooms(
    @ConnectedSocket() client: AuthenticatedSocket,
    @MessageBody() data?: any,
  ) {
    console.log('Rooms du client:', Array.from(client.rooms));
  }

  // ==================== DEVICE NOTIFICATION METHODS ====================

  // Server-side notification methods (called by DeviceService)
  notifyDeviceConnected(deviceId: string, userId: string) {
    const room = SOCKET_ROOMS.DEVICE(deviceId);
    this.server.to(room).emit('device-connected-notification', {
      deviceId,
      userId,
      timestamp: new Date().toISOString(),
    });
  }

  notifyDeviceDisconnected(deviceId: string, userId: string) {
    const room = SOCKET_ROOMS.DEVICE(deviceId);
    this.server.to(room).emit('device-disconnected-notification', {
      deviceId,
      userId,
      timestamp: new Date().toISOString(),
    });
  }

  notifyDeviceUpdated(deviceId: string, device: Device) {
    const room = SOCKET_ROOMS.DEVICE(deviceId);
    this.server.to(room).emit('device-updated', {
      deviceId,
      device: {
        id: device.id,
        name: device.name,
        type: device.type,
        status: device.status,
        canBeControlled: device.canBeControlled,
        lastSeen: device.lastSeen,
      },
      timestamp: new Date().toISOString(),
    });
  }

  notifyDeviceStatusChanged(deviceId: string, status: DeviceStatus) {
    const room = SOCKET_ROOMS.DEVICE(deviceId);
    this.server.to(room).emit('device-status-changed', {
      deviceId,
      status,
      timestamp: new Date().toISOString(),
    });
  }

  notifyControlDelegated(
    deviceId: string, 
    delegatedTo: User, 
    permissions: any, 
    delegatedBy: User
  ) {
    const room = SOCKET_ROOMS.DEVICE(deviceId);
    this.server.to(room).emit('control-delegated', {
      deviceId,
      delegatedTo: {
        id: delegatedTo.id,
        displayName: delegatedTo.displayName,
        avatarUrl: delegatedTo.avatarUrl,
      },
      permissions,
      delegatedBy: {
        id: delegatedBy.id,
        displayName: delegatedBy.displayName,
      },
      timestamp: new Date().toISOString(),
    });

    // Also notify the delegated user directly
    const userRoom = SOCKET_ROOMS.USER(delegatedTo.id);
    const socketsInRoom = this.server?.sockets?.adapter?.rooms?.get(userRoom)?.size || 0;
    
    this.server.to(userRoom).emit('device-control-received', {
      deviceId,
      permissions,
      delegatedBy: {
        id: delegatedBy.id,
        displayName: delegatedBy.displayName,
      },
      timestamp: new Date().toISOString(),
    });

    console.log(`✅ Control delegated - deviceRoom: ${room}, userRoom: ${userRoom} (${socketsInRoom} sockets)`);
  }

  notifyControlRevoked(deviceId: string, previousDelegatedTo: User | null, revokedBy: User | string) {
    const room = SOCKET_ROOMS.DEVICE(deviceId);
    const revokedByData = typeof revokedBy === 'string' ? revokedBy : {
      id: revokedBy.id,
      displayName: revokedBy.displayName,
    };
    
    this.server.to(room).emit('control-revoked', {
      deviceId,
      previousDelegatedTo: previousDelegatedTo ? {
        id: previousDelegatedTo.id,
        displayName: previousDelegatedTo.displayName,
      } : null,
      revokedBy: revokedByData,
      timestamp: new Date().toISOString(),
    });

    // Also notify the previously delegated user
    if (previousDelegatedTo) {
      const userRoom = SOCKET_ROOMS.USER(previousDelegatedTo.id);
      const socketsInRoom = this.server?.sockets?.adapter?.rooms?.get(userRoom)?.size || 0;
      
      this.server.to(userRoom).emit('device-control-revoked', {
        deviceId,
        revokedBy: revokedByData,
        timestamp: new Date().toISOString(),
      });
      console.log(`⚠️ Control revoked - deviceRoom: ${room}, userRoom: ${userRoom} (${socketsInRoom} sockets), previousUser: ${previousDelegatedTo.id}`);
    } else {
      console.log(`⚠️ Control revoked - deviceRoom: ${room}, no previous delegation`);
    }
  }

  notifyDelegationExtended(deviceId: string, newExpiresAt: Date, extendedBy: string) {
    const room = SOCKET_ROOMS.DEVICE(deviceId);
    this.server.to(room).emit('delegation-extended', {
      deviceId,
      newExpiresAt,
      extendedBy,
      timestamp: new Date().toISOString(),
    });
  }

  sendPlaybackCommand(deviceId: string, command: PlaybackCommand) {
    const room = SOCKET_ROOMS.DEVICE(deviceId);
    this.server.to(room).emit('playback-command', {
      deviceId,
      command: command.command,
      data: command.data,
      sentBy: command.sentBy,
      timestamp: command.timestamp.toISOString(),
    });
  }

  // ==================== DEVICE UTILITY METHODS ====================

  // Utility methods
  async disconnectDeviceConnections(deviceId: string) {
    const room = SOCKET_ROOMS.DEVICE(deviceId);
    const sockets = await this.server.in(room).fetchSockets();
    
    sockets.forEach(socket => {
      socket.emit('device-deleted', {
        deviceId,
        message: 'Device has been deleted',
        timestamp: new Date().toISOString(),
      });
      socket.disconnect();
    });
  }

  async getDeviceConnections(deviceId: string): Promise<DeviceConnectionInfo[]> {
    const room = SOCKET_ROOMS.DEVICE(deviceId);
    const sockets = await this.server.in(room).fetchSockets();
    
    return sockets.map(socket => {
      const authSocket = socket as unknown as AuthenticatedSocket;
      return {
        deviceId,
        deviceName: authSocket.data?.deviceInfo?.name || 'Unknown Device',
        userId: authSocket.userId || 'unknown',
        userAgent: authSocket.data?.deviceInfo?.userAgent,
        connectedAt: authSocket.data?.connectedAt || new Date().toISOString(),
      };
    });
  }
}
