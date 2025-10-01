import { io, Socket } from 'socket.io-client';
import { authService } from './auth';
import { config } from '$lib/config';
import type { Event, User, Vote, VoteResult, Track } from './events';

export interface EventSocketEvents {
  // Connection events
  'joined-event': (data: { userId: string; displayName: string; avatarUrl?: string; createdAt: string; updatedAt: string }) => void;
  'left-event': (data: { userId: string; }) => void;
  'user-joined': (data: { userId: string; displayName: string; avatarUrl?: string; socketId: string }) => void;
  'user-left': (data: { userId: string; }) => void;
  'current-participants': (data: { eventId: string; participants: any[]; timestamp: string }) => void;

  // Admin changes
  'admin-added': (data: { eventId: string; userId: string; }) => void;
  'admin-removed': (data: { eventId: string; userId: string; }) => void;

  // Event updates
  'event-created': (data: { event: Event }) => void;
  'event-updated': (data: { eventId: string; event: Event }) => void;
  'event-deleted': (data: { eventId: string }) => void;

  // Voting events
  'vote-updated': (data: { eventId: string; vote: { trackId: string; userId: string; type: 'upvote' | 'downvote'; weight: number; }; }) => void;
  'vote-removed': (data: { eventId: string; vote: { trackId: string; userId: string; type: 'upvote' | 'downvote'; weight: number; }; }) => void;
  'vote-optimistic-update': (data: { eventId: string; vote: { trackId: string; userId: string; type: 'upvote' | 'downvote'; }; timestamp: string; }) => void;

  // Track management
  'track-added': (data: { eventId: string; track: Track }) => void;
  'track-removed': (data: { eventId: string; trackId: string }) => void;
  'tracks-reordered': (data: { eventId: string; trackOrder: string[]; playlistOrder?: string[] }) => void;
  'current-track-changed': (data: { eventId: string; track: Track | null; startedAt: string | null }) => void;
  'track-ended': (data: { eventId: string; trackId: string; timestamp: string }) => void;

  // Music synchronization events
  'music-play': (data: { eventId: string; trackId?: string; startTime?: number; controlledBy: string; timestamp: string; syncType?: string }) => void;
  'music-pause': (data: { eventId: string; controlledBy: string; currentTime?: number; timestamp: string; syncType?: string }) => void;
  'music-seek': (data: { eventId: string; seekTime: number; controlledBy: string; timestamp: string; syncType?: string }) => void;
  'music-track-changed': (data: { eventId: string; trackId: string; trackIndex?: number; controlledBy: string; autoSkipped?: boolean; skipReason?: string; continuePlaying?: boolean; playlistOrder?: string[]; timestamp: string; syncType?: string }) => void;
  'music-volume': (data: { eventId: string; volume: number; controlledBy: string; timestamp: string; syncType?: string }) => void;
  'playback-state-updated': (data: { eventId: string; state: any; timestamp: string; syncType?: string }) => void;
  'playback-sync': (data: { eventId: string; currentTrackId: string; currentTrack: Track | null; startTime: number; isPlaying: boolean; timestamp: string; syncType?: string }) => void;
  'time-sync': (data: { eventId: string; trackId: string; currentTime: number; timestamp: string; syncType: string }) => void;

  // Error handling
  'error': (data: { message: string; details?: string }) => void;
}

class EventSocketService {
  private socket: Socket | null = null;
  private isConnecting = false;
  private seekThrottle: NodeJS.Timeout | null = null;
  private lastSeekTime: number = 0;
  private reconnectAttempts = 0;
  private maxReconnectAttempts = 5;
  private authFailures = 0;
  private maxAuthFailures = 3;
  private currentEventId: string | null = null;

  connect(): Promise<Socket> {
    return new Promise((resolve, reject) => {
      const token = authService.getAuthToken();

      if (!token) {
        reject(new Error('No authentication token available'));
        return;
      }

      // Don't try to reconnect if we've had too many auth failures
      if (this.authFailures >= this.maxAuthFailures) {
        reject(new Error('Too many authentication failures'));
        return;
      }

      // Connect to the events namespace
      this.socket = io(`${config.apiUrl}/events`, {
        auth: {
          token: token
        },
        transports: ['websocket', 'polling']
      });

      this.socket.on('connect', () => {
        // Connected to events socket
        this.reconnectAttempts = 0;
        this.authFailures = 0; // Reset auth failures on successful connection
        resolve(this.socket!);
      });

      this.socket.on('connect_error', (error) => {
        // Events socket connection error

        // Check if it's an authentication error
        if (error.message && (
          error.message.includes('Invalid token') ||
          error.message.includes('Authentication failed') ||
          error.message.includes('secret or public key must be provided')
        )) {
          this.authFailures++;

          if (this.authFailures >= this.maxAuthFailures) {
            this.disconnect();
            reject(new Error('Authentication failed too many times'));
            return;
          }
        }

        reject(error);
      });

      this.socket.on('disconnect', (reason) => {
        // Events socket disconnected

        // Only reconnect for non-auth related disconnections
        if (reason === 'io server disconnect' && this.authFailures < this.maxAuthFailures) {
          // Server disconnected us, reconnect manually
          this.reconnect();
        }
      });

      // Set up error handler
      this.socket.on('error', (error) => {
        // Events socket error
      });
    });
  }

  private reconnect() {
    if (this.reconnectAttempts >= this.maxReconnectAttempts) {
      // Max reconnection attempts reached
      return;
    }

    // Don't reconnect if we have too many auth failures
    if (this.authFailures >= this.maxAuthFailures) {
      // Too many authentication failures
      return;
    }

    this.reconnectAttempts++;
    // Attempting to reconnect events socket

    setTimeout(() => {
      this.connect().catch((error) => {
        // Reconnection failed
      });
    }, 1000 * this.reconnectAttempts);
  }

  disconnect() {
    if (this.socket) {
      this.socket.disconnect();
      this.socket = null;
    }
    if (this.seekThrottle) {
      clearTimeout(this.seekThrottle);
      this.seekThrottle = null;
    }
    this.currentEventId = null;
    this.isConnecting = false;
  }

  // Method to reset auth failures when user logs in again
  resetAuthFailures() {
    this.authFailures = 0;
    this.reconnectAttempts = 0;
  }

  joinEvent(eventId: string) {
    if (!this.socket) {
      throw new Error('Socket not connected');
    }

    // Leave current event if any
    if (this.currentEventId && this.currentEventId !== eventId) {
      this.leaveEvent(this.currentEventId);
    }

    this.socket.emit('join-event', { eventId });
    this.currentEventId = eventId;
  }

  leaveEvent(eventId: string) {
    if (!this.socket) {
      throw new Error('Socket not connected');
    }

    this.socket.emit('leave-event', { eventId });

    if (this.currentEventId === eventId) {
      this.currentEventId = null;
    }
  }

  // Vote for a track
  vote(eventId: string, trackId: string, type: 'upvote' | 'downvote' = 'upvote', weight: number = 1) {
    if (!this.socket) {
      throw new Error('Socket not connected');
    }

    this.socket.emit('vote-track', { eventId, trackId, type });
  }

  // Request current voting results
  requestVotingResults(eventId: string) {
    if (!this.socket) {
      throw new Error('Socket not connected');
    }

    this.socket.emit('get-voting-results', { eventId });
  }

  // Add a track to event
  addTrack(eventId: string, trackId: string) {
    if (!this.socket) {
      throw new Error('Socket not connected');
    }

    this.socket.emit('add-track', { eventId, trackId });
  }

  // Control playback (for event creators/admins)
  playTrack(eventId: string, trackId?: string, startTime?: number) {
    if (!this.socket?.connected) {
      return;
    }
    
    this.socket.emit('play-track', { eventId, trackId, startTime });
  }  pauseTrack(eventId: string, currentTime?: number) {
    if (!this.socket?.connected) {
      return;
    }
    
    this.socket.emit('pause-track', { eventId, currentTime });
  }

  seekTrack(eventId: string, seekTime: number) {
    if (!this.socket) {
      throw new Error('Socket not connected');
    }

    // Throttle seek operations to reduce server load during event streaming
    const now = Date.now();
    const minSeekInterval = 500; // Minimum 500ms between seek operations
    
    if (now - this.lastSeekTime < minSeekInterval) {
      // Clear any existing throttled seek
      if (this.seekThrottle) {
        clearTimeout(this.seekThrottle);
      }
      
      // Schedule a throttled seek
      this.seekThrottle = setTimeout(() => {
        this.socket?.emit('seek-track', { eventId, seekTime });
        this.lastSeekTime = Date.now();
      }, minSeekInterval - (now - this.lastSeekTime));
    } else {
      // Execute immediately
      this.socket.emit('seek-track', { eventId, seekTime });
      this.lastSeekTime = now;
    }
  }

  changeTrack(eventId: string, trackId: string, trackIndex?: number) {
    if (!this.socket) {
      throw new Error('Socket not connected');
    }

    this.socket.emit('change-track', { eventId, trackId, trackIndex });
  }

  setVolume(eventId: string, volume: number) {
    if (!this.socket) {
      throw new Error('Socket not connected');
    }

    this.socket.emit('set-volume', { eventId, volume });
  }

  skipTrack(eventId: string) {
    if (!this.socket) {
      throw new Error('Socket not connected');
    }

    this.socket.emit('skip-track', { eventId });
  }

  // Notify when a track has ended (for admins to coordinate next track)
  notifyTrackEnded(eventId: string, trackId: string) {
    if (!this.socket) {
      throw new Error('Socket not connected');
    }

    this.socket.emit('track-ended', { eventId, trackId });
  }

  // Report track accessibility issues for synchronization
  reportTrackAccessibility(eventId: string, trackId: string, canPlay: boolean, reason?: string) {
    if (!this.socket) {
      throw new Error('Socket not connected');
    }

    this.socket.emit('track-accessibility-report', { eventId, trackId, canPlay, reason });
  }

  // Request current playlist order synchronization from server
  requestPlaylistSync(eventId: string) {
    if (!this.socket) {
      throw new Error('Socket not connected');
    }

    this.socket.emit('request-playlist-sync', { eventId });
  }

  // Event listeners
  on<K extends keyof EventSocketEvents>(event: K, callback: EventSocketEvents[K]) {
    if (!this.socket) {
      throw new Error('Socket not connected');
    }

    this.socket.on(event as string, callback as any);
  }

  off<K extends keyof EventSocketEvents>(event: K, callback?: EventSocketEvents[K]) {
    if (!this.socket) {
      return;
    }

    if (callback) {
      this.socket.off(event as string, callback as any);
    } else {
      this.socket.off(event as string);
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

  getCurrentEventId(): string | null {
    return this.currentEventId;
  }
}

export const eventSocketService = new EventSocketService();
