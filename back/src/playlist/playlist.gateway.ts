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

import { Playlist } from 'src/playlist/entities/playlist.entity';
import { PlaylistTrackWithDetails } from './playlist.service';
import { Track } from 'src/music/entities/track.entity';
import { User } from 'src/user/entities/user.entity';
import { UserService } from 'src/user/user.service';

import { SOCKET_ROOMS } from '../common/constants/socket-rooms';

interface AuthenticatedSocket extends Socket {
  userId?: string;
  user?: User;
}

interface CollaborativeAction {
  type: 'add' | 'remove' | 'reorder' | 'update';
  data: any;
  userId: string;
  timestamp: string;
}

@WebSocketGateway({
  cors: {
    origin: process.env.FRONTEND_URL || 'http://localhost:5173',
    credentials: true,
  },
  namespace: '/playlists',
})
export class PlaylistGateway implements OnGatewayInit, OnGatewayConnection, OnGatewayDisconnect {
  @WebSocketServer()
  server: Server;

  private readonly logger = new Logger(PlaylistGateway.name);

  constructor(
    private jwtService: JwtService,
    private userService: UserService,
  ) {}

  afterInit(server: Server) {
    this.logger.log('Playlists WebSocket Gateway initialized');
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
      const payload = this.jwtService.verify(token);
      client.userId = payload.sub;

      // Fetch user data
      if (client.userId) {
        try {
          const user = await this.userService.findById(client.userId);
          client.user = user;
        } catch (error) {
          this.logger.warn(`Could not fetch user data for ${client.userId}: ${error.message}`);
          // Continue without user data - we have the userId at least
        }
      }

      this.logger.log(`Client connected: ${client.id} (User: ${client.userId})`);
    } catch (error) {
      this.logger.warn(`Connection rejected: Invalid token - ${error.message}`);
      client.disconnect();
    }
  }

  handleDisconnect(client: AuthenticatedSocket) {
    // If the client was in a playlist room, notify others and update participants list
    if (client.data?.playlistId) {
      const playlistId = client.data.playlistId;
      const room = SOCKET_ROOMS.PLAYLIST(playlistId);
      
      // Notify other collaborators
      client.to(room).emit('collaborator-left', {
        playlistId,
        userId: client.userId,
        socketId: client.id,
        timestamp: new Date().toISOString(),
      });

      // Send updated participants list
      this.sendParticipantsList(playlistId);
    }

    this.logger.log(`Client disconnected: ${client.id} (User: ${client.userId})`);
  }

  // Playlist Room Management
  @SubscribeMessage('join-playlist')
  async handleJoinPlaylist(
    @ConnectedSocket() client: AuthenticatedSocket,
    @MessageBody() { playlistId }: { playlistId: string },
  ) {
    try {
      if (!client.userId) {
        client.emit('error', { message: 'Authentication required' });
        return;
      }

      const room = SOCKET_ROOMS.PLAYLIST(playlistId);
      await client.join(room);

      // Store playlist info in client data
      client.data.playlistId = playlistId;
      client.data.joinedAt = new Date().toISOString();

      // Notify other collaborators
      client.to(room).emit('collaborator-joined', {
        playlistId,
        userId: client.userId,
        socketId: client.id,
        timestamp: new Date().toISOString(),
      });

      // Send updated participants list to all users in the room
      await this.sendParticipantsList(playlistId);

      client.emit('joined-playlist', { playlistId, room });
      this.logger.log(`User ${client.userId} joined playlist ${playlistId}`);
    } catch (error) {
      client.emit('error', { message: 'Failed to join playlist', details: error.message });
    }
  }

  @SubscribeMessage('leave-playlist')
  async handleLeavePlaylist(
    @ConnectedSocket() client: AuthenticatedSocket,
    @MessageBody() { playlistId }: { playlistId: string },
  ) {
    try {
      const room = SOCKET_ROOMS.PLAYLIST(playlistId);
      await client.leave(room);

      // Clear playlist info from client data
      delete client.data.playlistId;
      delete client.data.joinedAt;

      // Notify other collaborators
      client.to(room).emit('collaborator-left', {
        playlistId,
        userId: client.userId,
        socketId: client.id,
        timestamp: new Date().toISOString(),
      });

      // Send updated participants list to remaining users
      await this.sendParticipantsList(playlistId);

      client.emit('left-playlist', { playlistId });
      this.logger.log(`User ${client.userId} left playlist ${playlistId}`);
    } catch (error) {
      client.emit('error', { message: 'Failed to leave playlist', details: error.message });
    }
  }

  @SubscribeMessage('join-playlists-room')
  async handleJoinPlaylistsRoom(
    @ConnectedSocket() client: AuthenticatedSocket,
    @MessageBody() data?: any,
  ) {
    try {
      if (!client.userId) {
        client.emit('error', { message: 'Authentication required' });
        return;
      }

      await client.join(SOCKET_ROOMS.PLAYLISTS);
      client.emit('joined-playlists-room', { room: SOCKET_ROOMS.PLAYLISTS });
      this.logger.log(`User ${client.userId} joined global playlists room`);
    } catch (error) {
      client.emit('error', { message: 'Failed to join playlists room', details: error.message });
    }
  }

  @SubscribeMessage('leave-playlists-room')
  async handleLeavePlaylistsRoom(
    @ConnectedSocket() client: AuthenticatedSocket,
    @MessageBody() data?: any,
  ) {
    try {
      await client.leave(SOCKET_ROOMS.PLAYLISTS);
      client.emit('left-playlists-room', { room: SOCKET_ROOMS.PLAYLISTS });
      this.logger.log(`User ${client.userId} left global playlists room`);
    } catch (error) {
      client.emit('error', { message: 'Failed to leave playlists room', details: error.message });
    }
  }

  @SubscribeMessage('get-participants')
  async handleGetParticipants(
    @ConnectedSocket() client: AuthenticatedSocket,
    @MessageBody() { playlistId }: { playlistId: string },
  ) {
    try {
      if (!client.userId) {
        client.emit('error', { message: 'Authentication required' });
        return;
      }

      await this.sendParticipantsList(playlistId, client);
    } catch (error) {
      client.emit('error', { message: 'Failed to get participants', details: error.message });
    }
  }

  // Real-time Track Operations
  @SubscribeMessage('start-track-operation')
  async handleStartTrackOperation(
    @ConnectedSocket() client: AuthenticatedSocket,
    @MessageBody() { 
      playlistId, 
      operation, 
      trackId, 
      position 
    }: { 
      playlistId: string; 
      operation: string; 
      trackId?: string; 
      position?: number; 
    },
  ) {
    try {
      if (!client.userId) {
        client.emit('error', { message: 'Authentication required' });
        return;
      }

      const room = SOCKET_ROOMS.PLAYLIST(playlistId);
      
      // Broadcast operation start to prevent conflicts
      client.to(room).emit('track-operation-started', {
        playlistId,
        operation,
        trackId,
        position,
        userId: client.userId,
        timestamp: new Date().toISOString(),
      });

      this.logger.log(`User ${client.userId} started ${operation} operation on playlist ${playlistId}`);
    } catch (error) {
      client.emit('error', { message: 'Failed to start operation', details: error.message });
    }
  }

  @SubscribeMessage('track-drag-preview')
  async handleTrackDragPreview(
    @ConnectedSocket() client: AuthenticatedSocket,
    @MessageBody() { 
      playlistId, 
      trackId, 
      fromPosition, 
      toPosition 
    }: { 
      playlistId: string; 
      trackId: string; 
      fromPosition: number; 
      toPosition: number; 
    },
  ) {
    try {
      if (!client.userId) {
        return;
      }

      const room = SOCKET_ROOMS.PLAYLIST(playlistId);
      
      // Show drag preview to other collaborators
      client.to(room).emit('track-drag-preview', {
        playlistId,
        trackId,
        fromPosition,
        toPosition,
        userId: client.userId,
        timestamp: new Date().toISOString(),
      });
    } catch (error) {
      // Silently handle drag preview errors
    }
  }

  @SubscribeMessage('cancel-track-operation')
  async handleCancelTrackOperation(
    @ConnectedSocket() client: AuthenticatedSocket,
    @MessageBody() { playlistId, operation }: { playlistId: string; operation: string },
  ) {
    try {
      if (!client.userId) {
        return;
      }

      const room = SOCKET_ROOMS.PLAYLIST(playlistId);
      
      // Notify operation cancellation
      client.to(room).emit('track-operation-cancelled', {
        playlistId,
        operation,
        userId: client.userId,
        timestamp: new Date().toISOString(),
      });
    } catch (error) {
      // Silently handle cancellation errors
    }
  }

  // Collaborative Cursor/Selection
  @SubscribeMessage('track-selection')
  async handleTrackSelection(
    @ConnectedSocket() client: AuthenticatedSocket,
    @MessageBody() { 
      playlistId, 
      selectedTrackIds 
    }: { 
      playlistId: string; 
      selectedTrackIds: string[]; 
    },
  ) {
    try {
      if (!client.userId) {
        return;
      }

      const room = SOCKET_ROOMS.PLAYLIST(playlistId);
      
      // Show user's selection to other collaborators
      client.to(room).emit('collaborator-selection', {
        playlistId,
        userId: client.userId,
        selectedTrackIds,
        timestamp: new Date().toISOString(),
      });
    } catch (error) {
      // Silently handle selection errors
    }
  }

  // Playlist Chat
  @SubscribeMessage('send-playlist-message')
  async handleSendPlaylistMessage(
    @ConnectedSocket() client: AuthenticatedSocket,
    @MessageBody() { playlistId, message }: { playlistId: string; message: string },
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

      const room = SOCKET_ROOMS.PLAYLIST(playlistId);
      
      // Broadcast message to all collaborators
      this.server.to(room).emit('new-playlist-message', {
        playlistId,
        message: message.trim(),
        senderId: client.userId,
        timestamp: new Date().toISOString(),
        messageId: `${client.userId}-${Date.now()}`,
      });

      this.logger.log(`User ${client.userId} sent message in playlist ${playlistId}`);
    } catch (error) {
      client.emit('error', { message: 'Failed to send message', details: error.message });
    }
  }

  // Presence indication
  @SubscribeMessage('update-editing-status')
  async handleUpdateEditingStatus(
    @ConnectedSocket() client: AuthenticatedSocket,
    @MessageBody() { 
      playlistId, 
      isEditing, 
      editingTrackId 
    }: { 
      playlistId: string; 
      isEditing: boolean; 
      editingTrackId?: string; 
    },
  ) {
    try {
      if (!client.userId) {
        return;
      }

      const room = SOCKET_ROOMS.PLAYLIST(playlistId);
      
      // Update client editing status
      client.data.isEditing = isEditing;
      client.data.editingTrackId = editingTrackId;
      client.data.lastActivity = new Date().toISOString();

      // Notify other collaborators
      client.to(room).emit('collaborator-editing-status', {
        playlistId,
        userId: client.userId,
        isEditing,
        editingTrackId,
        timestamp: new Date().toISOString(),
      });
    } catch (error) {
      // Silently handle editing status errors
    }
  }

  // Server-side notification methods (called by PlaylistService)
  notifyPlaylistCreated(playlist: Playlist, userId: string) {
    // Notify all users in the general playlists room for public playlists
    if (playlist.visibility === 'public') {
      this.server.to(SOCKET_ROOMS.PLAYLISTS).emit('playlist-created', {
        playlist: {
          id: playlist.id,
          name: playlist.name,
          description: playlist.description,
          visibility: playlist.visibility,
          licenseType: playlist.licenseType,
          coverImageUrl: playlist.coverImageUrl,
          createdAt: playlist.createdAt,
          updatedAt: playlist.updatedAt,
          creatorId: playlist.creatorId,
          trackCount: playlist.trackCount,
          collaborators: [],
        },
        createdBy: userId,
        timestamp: new Date().toISOString(),
      });
    }
  }

  notifyPlaylistUpdated(playlistId: string, playlist: Playlist, userId: string) {
    // Notify playlist-specific room
    const room = SOCKET_ROOMS.PLAYLIST(playlistId);
    this.server.to(room).emit('playlist-updated', {
      playlistId,
      playlist: {
        id: playlist.id,
        name: playlist.name,
        description: playlist.description,
        visibility: playlist.visibility,
        licenseType: playlist.licenseType,
        coverImageUrl: playlist.coverImageUrl,
        updatedAt: playlist.updatedAt,
      },
      updatedBy: userId,
      timestamp: new Date().toISOString(),
    });

    // Also notify global playlists room for public playlists
    if (playlist.visibility === 'public') {
      this.server.to(SOCKET_ROOMS.PLAYLISTS).emit('playlist-updated', {
        playlist: {
          id: playlist.id,
          name: playlist.name,
          description: playlist.description,
          visibility: playlist.visibility,
          licenseType: playlist.licenseType,
          coverImageUrl: playlist.coverImageUrl,
          updatedAt: playlist.updatedAt,
          creatorId: playlist.creatorId,
          trackCount: playlist.trackCount,
        },
        updatedBy: userId,
        timestamp: new Date().toISOString(),
      });
    }
  }

  notifyTrackAdded(playlistId: string, track: PlaylistTrackWithDetails, userId: string, updatedTrackCount?: number) {
    const room = SOCKET_ROOMS.PLAYLIST(playlistId);
    this.server.to(room).emit('track-added', {
      playlistId,
      track: {
        id: track.id,
        position: track.position,
        addedAt: track.addedAt,
        track: {
          id: track.track.id,
          title: track.track.title,
          artist: track.track.artist,
          album: track.track.album,
          duration: track.track.duration,
          albumCoverUrl: track.track.albumCoverUrl,
          previewUrl: track.track.previewUrl,
        },
        addedBy: {
          id: track.addedBy.id,
          displayName: track.addedBy.displayName,
          avatarUrl: track.addedBy.avatarUrl,
        },
      },
      addedBy: userId,
      timestamp: new Date().toISOString(),
    });

    // Also notify global playlists room with track count update
    if (updatedTrackCount !== undefined) {
      this.server.to(SOCKET_ROOMS.PLAYLISTS).emit('playlist-track-added', {
        playlistId,
        trackCount: updatedTrackCount,
        timestamp: new Date().toISOString(),
      });
    }
  }

  notifyTrackRemoved(playlistId: string, trackId: string, userId: string, updatedTrackCount?: number) {
    const room = SOCKET_ROOMS.PLAYLIST(playlistId);
    this.server.to(room).emit('track-removed', {
      playlistId,
      trackId,
      removedBy: userId,
      timestamp: new Date().toISOString(),
    });

    // Also notify global playlists room with track count update
    if (updatedTrackCount !== undefined) {
      this.server.to(SOCKET_ROOMS.PLAYLISTS).emit('playlist-track-removed', {
        playlistId,
        trackCount: updatedTrackCount,
        timestamp: new Date().toISOString(),
      });
    }
  }

  notifyTracksReordered(playlistId: string, trackIds: string[], userId: string) {
    const room = SOCKET_ROOMS.PLAYLIST(playlistId);
    this.server.to(room).emit('tracks-reordered', {
      playlistId,
      trackIds,
      reorderedBy: userId,
      timestamp: new Date().toISOString(),
    });

    // Also notify global playlists room
    this.server.to(SOCKET_ROOMS.PLAYLISTS).emit('playlist-tracks-reordered', {
      playlistId,
      timestamp: new Date().toISOString(),
    });
  }

  notifyCollaboratorAdded(playlistId: string, collaborator: User, addedBy: string) {
    const room = SOCKET_ROOMS.PLAYLIST(playlistId);
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

    // Also notify global playlists room
    this.server.to(SOCKET_ROOMS.PLAYLISTS).emit('playlist-collaborator-added', {
      playlistId,
      collaborator: {
        userId: collaborator.id,
        displayName: collaborator.displayName,
        avatarUrl: collaborator.avatarUrl,
      },
      timestamp: new Date().toISOString(),
    });
  }

  notifyCollaboratorRemoved(playlistId: string, collaborator: User, removedBy: string) {
    const room = SOCKET_ROOMS.PLAYLIST(playlistId);
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

    // Also notify global playlists room
    this.server.to(SOCKET_ROOMS.PLAYLISTS).emit('playlist-collaborator-removed', {
      playlistId,
      userId: collaborator.id,
      timestamp: new Date().toISOString(),
    });
  }

  notifyPlaylistDeleted(playlistId: string, deletedBy: string) {
    // Notify all users in the general playlists room
    this.server.to(SOCKET_ROOMS.PLAYLISTS).emit('playlist-deleted', {
      playlistId,
      deletedBy,
      timestamp: new Date().toISOString(),
    });

    const room = SOCKET_ROOMS.PLAYLIST(playlistId);
    this.server.to(room).emit('playlist-deleted', {
      playlistId,
      deletedBy,
      timestamp: new Date().toISOString(),
    });

    // Force disconnect all clients from this playlist
    this.server.in(room).disconnectSockets();
  }

  // Utility methods
  async sendParticipantsList(playlistId: string, targetClient?: AuthenticatedSocket) {
    try {
      const room = SOCKET_ROOMS.PLAYLIST(playlistId);
      const sockets = await this.server.in(room).fetchSockets();
      
      // Get unique user IDs from sockets
      const userIds = Array.from(new Set(
        sockets
          .map(socket => (socket as unknown as AuthenticatedSocket).userId)
          .filter(userId => userId !== undefined)
      ));
      
      // Fetch complete user data from database for all participants
      const participantPromises = userIds.map(async (userId) => {
        try {
          const user = await this.userService.findById(userId);
          const userSockets = sockets.filter(s => (s as unknown as AuthenticatedSocket).userId === userId);
          
          return userSockets.map(socket => {
            const authSocket = socket as unknown as AuthenticatedSocket;
            return {
              userId: authSocket.userId,
              socketId: authSocket.id,
              joinedAt: authSocket.data?.joinedAt || new Date().toISOString(),
              displayName: user.displayName || user.email?.split('@')[0] || `User ${userId.slice(-8)}`,
              avatarUrl: user.avatarUrl || null,
            };
          });
        } catch (error) {
          // If user not found, create fallback data
          const userSockets = sockets.filter(s => (s as unknown as AuthenticatedSocket).userId === userId);
          return userSockets.map(socket => {
            const authSocket = socket as unknown as AuthenticatedSocket;
            return {
              userId: authSocket.userId,
              socketId: authSocket.id,
              joinedAt: authSocket.data?.joinedAt || new Date().toISOString(),
              displayName: `User ${userId.slice(-8)}`,
              avatarUrl: null,
            };
          });
        }
      });
      
      const participantArrays = await Promise.all(participantPromises);
      const participants = participantArrays.flat();

      const participantsData = {
        playlistId,
        participants,
      };

      if (targetClient) {
        // Send to specific client
        targetClient.emit('participants-list', participantsData);
      } else {
        // Send to all clients in the room
        this.server.to(room).emit('participants-list', participantsData);
      }

      this.logger.log(`Sent participants list for playlist ${playlistId}: ${participants.length} participants`);
    } catch (error) {
      this.logger.error(`Failed to send participants list for playlist ${playlistId}:`, error);
    }
  }

  async getPlaylistCollaborators(playlistId: string): Promise<string[]> {
    const room = SOCKET_ROOMS.PLAYLIST(playlistId);
    const sockets = await this.server.in(room).fetchSockets();
    return sockets
      .map(socket => (socket as unknown as AuthenticatedSocket).userId)
      .filter(userId => userId !== undefined) as string[];
  }

  async getActiveEditingSessions(playlistId: string): Promise<any[]> {
    const room = SOCKET_ROOMS.PLAYLIST(playlistId);
    const sockets = await this.server.in(room).fetchSockets();
    
    return sockets
      .filter(socket => (socket as unknown as AuthenticatedSocket).data?.isEditing)
      .map(socket => ({
        userId: (socket as unknown as AuthenticatedSocket).userId,
        editingTrackId: (socket as unknown as AuthenticatedSocket).data?.editingTrackId,
        lastActivity: (socket as unknown as AuthenticatedSocket).data?.lastActivity,
      }));
  }
}