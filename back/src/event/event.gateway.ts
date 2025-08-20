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
import { User } from 'src/user/entities/user.entity';
import { VoteResult } from './event.service';

import { SOCKET_ROOMS } from '../common/constants/socket-rooms';

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
  ) {}

  afterInit(server: Server) {
    this.logger.log('Events WebSocket Gateway initialized');
  }

  async handleConnection(client: AuthenticatedSocket) {
    try {
      // Extract token from handshake
      const token = client.handshake.auth?.token || client.handshake.headers?.authorization?.split(' ')[1];
      
      if (!token) {
        this.logger.warn(`Connection rejected: No token provided`);
        client.disconnect();
        return;
      }

      // Verify JWT token
      const payload = this.jwtService.verify(token, {
        secret: this.configService.get<string>('JWT_SECRET'),
      });
      client.userId = payload.sub;

      this.logger.log(`Client connected: ${client.id} (User: ${client.userId})`);
    } catch (error) {
      this.logger.warn(`Connection rejected: Invalid token - ${error.message}`);
      client.disconnect();
    }
  }

  handleDisconnect(client: AuthenticatedSocket) {
    this.logger.log(`Client disconnected: ${client.id} (User: ${client.userId})`);
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

      // Notify other participants
      client.to(room).emit('user-joined', {
        userId: client.userId,
        socketId: client.id,
        timestamp: new Date().toISOString(),
      });

      client.emit('joined-event', { eventId, room });
      this.logger.log(`User ${client.userId} joined event ${eventId}`);
    } catch (error) {
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

      // Notify other participants
      client.to(room).emit('user-left', {
        userId: client.userId,
        socketId: client.id,
        timestamp: new Date().toISOString(),
      });

      client.emit('left-event', { eventId });
      this.logger.log(`User ${client.userId} left event ${eventId}`);
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
  notifyEventUpdated(eventId: string, event: Event) {
    const room = SOCKET_ROOMS.EVENT(eventId);
    this.server.to(room).emit('event-updated', {
      eventId,
      event,
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
}