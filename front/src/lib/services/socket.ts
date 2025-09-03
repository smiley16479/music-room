import { io, Socket } from 'socket.io-client';
import { authService } from './auth';
import { participantsService } from '$lib/stores/participants';
import { config } from '$lib/config';

export interface PlaylistParticipant {
  userId: string;
  displayName: string;
  avatarUrl?: string;
  joinedAt: string;
  socketId: string;
}

export interface PlaylistSocketEvents {
  // Incoming events for participants
  'collaborator-joined': (data: { 
    playlistId: string; 
    userId: string; 
    user?: { displayName: string; avatarUrl?: string }; 
    socketId: string; 
    timestamp: string; 
  }) => void;
  
  'collaborator-left': (data: { 
    playlistId: string; 
    userId: string; 
    socketId: string; 
    timestamp: string; 
  }) => void;
  
  'participants-list': (data: { 
    playlistId: string; 
    participants: PlaylistParticipant[]; 
  }) => void;
  
  // Playlist management events
  'playlist-created': (data: { playlist: any }) => void;
  'playlist-updated': (data: { playlist: any }) => void;
  'playlist-deleted': (data: { playlistId: string }) => void;
  
  // Collaborative editing events for tracks
  'track-added': (data: { playlistId: string; track: any; addedBy: string; timestamp: string }) => void;
  'track-removed': (data: { playlistId: string; trackId: string; trackCount: number }) => void;
  'tracks-reordered': (data: { playlistId: string; tracks: any[] }) => void;
  
  // Collaborator management events
  'playlist-collaborator-added': (data: { playlistId: string; collaborator: any; playlist?: any }) => void;
  'playlist-collaborator-removed': (data: { playlistId: string; userId: string }) => void;
  
  'error': (data: { message: string; details?: string }) => void;
}

class SocketService {
  private socket: Socket | null = null;
  private reconnectAttempts = 0;
  private maxReconnectAttempts = 5;
  
  connect(): Promise<Socket> {
    return new Promise((resolve, reject) => {
      const token = authService.getAuthToken();
      
      if (!token) {
        console.error('❌ No authentication token available');
        reject(new Error('No authentication token available'));
        return;
      }

      // Connect to the playlists namespace
      this.socket = io(`${config.apiUrl}/playlists`, {
        auth: {
          token: token
        },
        transports: ['websocket', 'polling']
      });

      this.socket.on('connect', () => {
        this.reconnectAttempts = 0;
        
        resolve(this.socket!);
      });

      this.socket.on('connect_error', (error) => {
        console.error('❌ Socket connection error:', error);
        reject(error);
      });

      this.socket.on('disconnect', (reason) => {
        console.log('❌ Socket disconnected:', reason);
        
        if (reason === 'io server disconnect') {
          // Server disconnected us, reconnect manually
          this.reconnect();
        }
      });

      // Set up error handler
      this.socket.on('error', (error) => {
        console.error('❌ Socket error:', error);
      });
    });
  }

  private reconnect() {
    if (this.reconnectAttempts >= this.maxReconnectAttempts) {
      console.error('Max reconnection attempts reached');
      return;
    }

    this.reconnectAttempts++;
    
    setTimeout(() => {
      this.connect().catch(console.error);
    }, 1000 * this.reconnectAttempts);
  }

  disconnect() {
    if (this.socket) {
      this.socket.disconnect();
      this.socket = null;
    }
  }

  joinPlaylist(playlistId: string) {
    if (!this.socket) {
      throw new Error('Socket not connected');
    }
    
    this.socket.emit('join-playlist', { playlistId });
    
    // Listen for join confirmation
    this.socket.once('joined-playlist', (data) => {
      console.log('✅ Successfully joined playlist room:', data);
    });

    this.socket.once('error', (error) => {
      console.error('❌ Error joining playlist:', error);
    });
  }

  leavePlaylist(playlistId: string) {
    if (!this.socket) {
      throw new Error('Socket not connected');
    }
    
    this.socket.emit('leave-playlist', { playlistId });
  }

  requestParticipantsList(playlistId: string) {
    if (!this.socket) {
      throw new Error('Socket not connected');
    }
    
    this.socket.emit('get-participants', { playlistId });
  }

  setupParticipantListeners(playlistId: string) {
    if (!this.socket) {
      throw new Error('Socket not connected');
    }

    // Listen for participants list updates
    this.socket.on('participants-list', (data: { playlistId: string; participants: PlaylistParticipant[] }) => {
      if (data.playlistId === playlistId) {
        participantsService.setParticipants(playlistId, data.participants);
      }
    });

    // Listen for individual collaborator events
    this.socket.on('collaborator-joined', (data: { 
      playlistId: string; 
      userId: string; 
      socketId: string; 
      timestamp: string; 
    }) => {
      if (data.playlistId === playlistId) {
        // Request updated participants list when someone joins
        this.requestParticipantsList(playlistId);
      }
    });

    this.socket.on('collaborator-left', (data: { 
      playlistId: string; 
      userId: string; 
      socketId: string; 
      timestamp: string; 
    }) => {
      if (data.playlistId === playlistId) {
        // Remove the participant from the store
        participantsService.removeParticipant(playlistId, data.userId);
      }
    });
  }

  cleanupParticipantListeners() {
    if (!this.socket) {
      return;
    }

    this.socket.off('participants-list');
    this.socket.off('collaborator-joined');
    this.socket.off('collaborator-left');
  }

  on(event: string, callback: (...args: any[]) => void) {
    if (!this.socket) {
      throw new Error('Socket not connected');
    }
    
    this.socket.on(event, (...args) => {
      callback(...args);
    });
  }

  off(event: string, callback?: (...args: any[]) => void) {
    if (!this.socket) {
      return;
    }
    
    if (callback) {
      this.socket.off(event, callback);
    } else {
      this.socket.off(event);
    }
  }

  emit(event: string, data: any) {
    if (!this.socket) {
      throw new Error('Socket not connected');
    }
    
    this.socket.emit(event, data);
  }

  // Track management methods
  emitTrackAdded(playlistId: string, track: any) {
    this.emit('track-added', { playlistId, track });
  }

  emitTrackRemoved(playlistId: string, trackId: string) {
    this.emit('track-removed', { playlistId, trackId });
  }

  emitTracksReordered(playlistId: string, trackIds: string[]) {
    this.emit('tracks-reordered', { playlistId, trackIds });
  }

  // Collaborator management methods
  emitCollaboratorAdded(playlistId: string, userId: string) {
    this.emit('collaborator-added', { playlistId, userId });
  }

  emitCollaboratorRemoved(playlistId: string, userId: string) {
    this.emit('collaborator-removed', { playlistId, userId });
  }

  isConnected(): boolean {
    return this.socket?.connected ?? false;
  }
}

export const socketService = new SocketService();
