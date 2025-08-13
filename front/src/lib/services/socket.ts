import { io, Socket } from 'socket.io-client';
import { authService } from './auth';
import { participantsService } from '$lib/stores/participants';

export interface PlaylistParticipant {
  userId: string;
  displayName: string;
  avatarUrl?: string;
  joinedAt: string;
  socketId: string;
}

export interface PlaylistSocketEvents {
  // Incoming events
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
  
  'error': (data: { message: string; details?: string }) => void;
  
  // Collaborative editing events
  'track-added': (data: any) => void;
  'track-removed': (data: any) => void;
  'tracks-reordered': (data: any) => void;
}

class SocketService {
  private socket: Socket | null = null;
  private reconnectAttempts = 0;
  private maxReconnectAttempts = 5;
  
  connect(): Promise<Socket> {
    return new Promise((resolve, reject) => {
      const token = authService.getAuthToken();
      
      if (!token) {
        reject(new Error('No authentication token available'));
        return;
      }

      // Connect to the playlists namespace
      this.socket = io('http://localhost:3000/playlists', {
        auth: {
          token: token
        },
        transports: ['websocket', 'polling']
      });

      this.socket.on('connect', () => {
        console.log('Connected to playlist socket');
        this.reconnectAttempts = 0;
        resolve(this.socket!);
      });

      this.socket.on('connect_error', (error) => {
        console.error('Socket connection error:', error);
        reject(error);
      });

      this.socket.on('disconnect', (reason) => {
        console.log('Socket disconnected:', reason);
        
        if (reason === 'io server disconnect') {
          // Server disconnected us, reconnect manually
          this.reconnect();
        }
      });

      // Set up error handler
      this.socket.on('error', (error) => {
        console.error('Socket error:', error);
      });
    });
  }

  private reconnect() {
    if (this.reconnectAttempts >= this.maxReconnectAttempts) {
      console.error('Max reconnection attempts reached');
      return;
    }

    this.reconnectAttempts++;
    console.log(`Attempting to reconnect (${this.reconnectAttempts}/${this.maxReconnectAttempts})`);
    
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
    
    this.socket.on(event, callback);
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

  isConnected(): boolean {
    return this.socket?.connected ?? false;
  }
}

export const socketService = new SocketService();
