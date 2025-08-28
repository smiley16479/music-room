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
  'vote-added': (data: { eventId: string; vote: Vote; results: VoteResult[] }) => void;
  'vote-updated': (data: { eventId: string; vote: Vote; results: VoteResult[] }) => void;
  'vote-removed': (data: { eventId: string; trackId: string; results: VoteResult[] }) => void;

  // Track management
  'track-added': (data: { eventId: string; track: Track }) => void;
  'track-removed': (data: { eventId: string; trackId: string }) => void;
  'tracks-reordered': (data: { eventId: string; trackOrder: string[] }) => void;
  'current-track-changed': (data: { eventId: string; track: Track | null; startedAt: string | null }) => void;

  // Error handling
  'error': (data: { message: string; details?: string }) => void;
}

class EventSocketService {
  private socket: Socket | null = null;
  private reconnectAttempts = 0;
  private maxReconnectAttempts = 5;
  private currentEventId: string | null = null;
  private authFailures = 0;
  private maxAuthFailures = 3;

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
        console.log('Connected to events socket');
        this.reconnectAttempts = 0;
        this.authFailures = 0; // Reset auth failures on successful connection
        resolve(this.socket!);
      });

      this.socket.on('connect_error', (error) => {
        console.error('Events socket connection error:', error);

        // Check if it's an authentication error
        if (error.message && (
          error.message.includes('Invalid token') ||
          error.message.includes('Authentication failed') ||
          error.message.includes('secret or public key must be provided')
        )) {
          this.authFailures++;
          console.warn(`Authentication failure ${this.authFailures}/${this.maxAuthFailures}`);

          if (this.authFailures >= this.maxAuthFailures) {
            console.error('Max authentication failures reached, stopping reconnection attempts');
            this.disconnect();
            reject(new Error('Authentication failed too many times'));
            return;
          }
        }

        reject(error);
      });

      this.socket.on('disconnect', (reason) => {
        console.log('Events socket disconnected:', reason);

        // Only reconnect for non-auth related disconnections
        if (reason === 'io server disconnect' && this.authFailures < this.maxAuthFailures) {
          // Server disconnected us, reconnect manually
          this.reconnect();
        }
      });

      // Set up error handler
      this.socket.on('error', (error) => {
        console.error('Events socket error:', error);
      });
    });
  }

  private reconnect() {
    if (this.reconnectAttempts >= this.maxReconnectAttempts) {
      console.error('Max reconnection attempts reached');
      return;
    }

    // Don't reconnect if we have too many auth failures
    if (this.authFailures >= this.maxAuthFailures) {
      console.error('Too many authentication failures, not attempting to reconnect');
      return;
    }

    this.reconnectAttempts++;
    console.log(`Attempting to reconnect events socket (${this.reconnectAttempts}/${this.maxReconnectAttempts})`);

    setTimeout(() => {
      this.connect().catch((error) => {
        console.error('Reconnection failed:', error);
      });
    }, 1000 * this.reconnectAttempts);
  }

  disconnect() {
    if (this.socket) {
      this.socket.disconnect();
      this.socket = null;
    }
    this.currentEventId = null;
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

    this.socket.emit('vote', { eventId, trackId, type, weight });
  }

  // Remove a vote
  removeVote(eventId: string, trackId: string) {
    if (!this.socket) {
      throw new Error('Socket not connected');
    }

    this.socket.emit('remove-vote', { eventId, trackId });
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
  playTrack(eventId: string, trackId: string) {
    if (!this.socket) {
      throw new Error('Socket not connected');
    }

    this.socket.emit('play-track', { eventId, trackId });
  }

  pauseTrack(eventId: string) {
    if (!this.socket) {
      throw new Error('Socket not connected');
    }

    this.socket.emit('pause-track', { eventId });
  }

  skipTrack(eventId: string) {
    if (!this.socket) {
      throw new Error('Socket not connected');
    }

    this.socket.emit('skip-track', { eventId });
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
