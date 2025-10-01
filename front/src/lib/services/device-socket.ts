import { io, Socket } from 'socket.io-client';
import { authService } from './auth';
import { config } from '$lib/config';
import type { Device, PlaybackCommand } from '../types/device';

export interface DeviceSocketEvents {
  // Connection events
  'device-connected': (data: { deviceId: string; userId: string; deviceInfo: any }) => void;
  'device-disconnected': (data: { deviceId: string; userId: string; reason: string }) => void;
  
  // Device updates
  'device-updated': (data: { deviceId: string; device: Device }) => void;
  'device-status-changed': (data: { deviceId: string; status: string; timestamp: string }) => void;
  
  // Control delegation
  'control-delegated': (data: { deviceId: string; delegatedTo: string; permissions: any; expiresAt?: string }) => void;
  'control-revoked': (data: { deviceId: string; previousDelegate: string; reason: string }) => void;
  
  // Playback events
  'playback-command': (data: { deviceId: string; command: PlaybackCommand; fromUser: string }) => void;
  'playback-state-changed': (data: { deviceId: string; state: any; timestamp: string }) => void;
  
  // Error handling
  'error': (data: { message: string; details?: string }) => void;
}

class DeviceSocketService {
  private socket: Socket | null = null;
  private reconnectAttempts = 0;
  private maxReconnectAttempts = 5;
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

      // Connect to the devices namespace
      this.socket = io(`${config.apiUrl}/devices`, {
        auth: {
          token: token
        },
        transports: ['websocket', 'polling']
      });

      this.socket.on('connect', () => {
        
        this.reconnectAttempts = 0;
        this.authFailures = 0; // Reset auth failures on successful connection
        resolve(this.socket!);
      });

      this.socket.on('connect_error', (error) => {
        
        
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
        
        
        // Only reconnect for non-auth related disconnections
        if (reason === 'io server disconnect' && this.authFailures < this.maxAuthFailures) {
          // Server disconnected us, reconnect manually
          this.reconnect();
        }
      });

      // Set up error handler
      this.socket.on('error', (error) => {
        
      });
    });
  }

  private reconnect() {
    if (this.reconnectAttempts >= this.maxReconnectAttempts) {
      
      return;
    }
    
    // Don't reconnect if we have too many auth failures
    if (this.authFailures >= this.maxAuthFailures) {
      
      return;
    }

    this.reconnectAttempts++;
    
    
    setTimeout(() => {
      this.connect().catch((error) => {
        
      });
    }, 1000 * this.reconnectAttempts);
  }

  disconnect() {
    if (this.socket) {
      this.socket.disconnect();
      this.socket = null;
    }
  }

  // Method to reset auth failures when user logs in again
  resetAuthFailures() {
    this.authFailures = 0;
    this.reconnectAttempts = 0;
  }

  isConnected(): boolean {
    return this.socket?.connected || false;
  }

  // Device management
  registerDevice(deviceData: { name: string; type: string; deviceInfo?: any }) {
    if (!this.socket) {
      throw new Error('Socket not connected');
    }
    this.socket.emit('register-device', deviceData);
  }

  connectDevice(deviceId: string) {
    if (!this.socket) {
      throw new Error('Socket not connected');
    }
    this.socket.emit('connect-device', { deviceId });
  }

  disconnectDevice(deviceId: string, reason = 'User initiated') {
    if (!this.socket) {
      throw new Error('Socket not connected');
    }
    this.socket.emit('disconnect-device', { deviceId, reason });
  }

  updateDeviceStatus(deviceId: string, status: string) {
    if (!this.socket) {
      throw new Error('Socket not connected');
    }
    this.socket.emit('update-device-status', { deviceId, status });
  }

  // Control delegation
  delegateControl(deviceId: string, userId: string, permissions: any, expiresAt?: string) {
    if (!this.socket) {
      throw new Error('Socket not connected');
    }
    this.socket.emit('delegate-control', { deviceId, userId, permissions, expiresAt });
  }

  revokeControl(deviceId: string) {
    if (!this.socket) {
      throw new Error('Socket not connected');
    }
    this.socket.emit('revoke-control', { deviceId });
  }

  // Playback control
  sendPlaybackCommand(deviceId: string, command: PlaybackCommand) {
    if (!this.socket) {
      throw new Error('Socket not connected');
    }
    this.socket.emit('playback-command', { deviceId, command });
  }

  updatePlaybackState(deviceId: string, state: any) {
    if (!this.socket) {
      throw new Error('Socket not connected');
    }
    this.socket.emit('playback-state-update', { deviceId, state });
  }

  // Event listeners
  onDeviceConnected(callback: (data: { deviceId: string; userId: string; deviceInfo: any }) => void) {
    if (!this.socket) return;
    this.socket.on('device-connected', callback);
  }

  onDeviceDisconnected(callback: (data: { deviceId: string; userId: string; reason: string }) => void) {
    if (!this.socket) return;
    this.socket.on('device-disconnected', callback);
  }

  onDeviceUpdated(callback: (data: { deviceId: string; device: Device }) => void) {
    if (!this.socket) return;
    this.socket.on('device-updated', callback);
  }

  onDeviceStatusChanged(callback: (data: { deviceId: string; status: string; timestamp: string }) => void) {
    if (!this.socket) return;
    this.socket.on('device-status-changed', callback);
  }

  onControlDelegated(callback: (data: { deviceId: string; delegatedTo: string; permissions: any; expiresAt?: string }) => void) {
    if (!this.socket) return;
    this.socket.on('control-delegated', callback);
  }

  onControlRevoked(callback: (data: { deviceId: string; previousDelegate: string; reason: string }) => void) {
    if (!this.socket) return;
    this.socket.on('control-revoked', callback);
  }

  onPlaybackCommand(callback: (data: { deviceId: string; command: PlaybackCommand; fromUser: string }) => void) {
    if (!this.socket) return;
    this.socket.on('playback-command', callback);
  }

  onPlaybackStateChanged(callback: (data: { deviceId: string; state: any; timestamp: string }) => void) {
    if (!this.socket) return;
    this.socket.on('playback-state-changed', callback);
  }

  onError(callback: (data: { message: string; details?: string }) => void) {
    if (!this.socket) return;
    this.socket.on('error', callback);
  }

  // Remove listeners
  removeAllListeners() {
    if (!this.socket) return;
    this.socket.removeAllListeners();
  }
}

export const deviceSocketService = new DeviceSocketService();
