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
import { UseGuards, Logger, Inject, forwardRef } from '@nestjs/common';
import { JwtService } from '@nestjs/jwt';

import { Device, DeviceStatus } from 'src/device/entities/device.entity';
import { User } from 'src/user/entities/user.entity';
import { PlaybackCommand, DeviceService } from './device.service';

import { SOCKET_ROOMS } from '../common/constants/socket-rooms';

interface AuthenticatedSocket extends Socket {
  userId?: string;
  deviceId?: string;
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
    origin: process.env.FRONTEND_URL || 'http://localhost:5173',
    credentials: true,
  },
  namespace: '/devices',
})
export class DeviceGateway implements OnGatewayInit, OnGatewayConnection, OnGatewayDisconnect {
  @WebSocketServer()
  server: Server;

  private readonly logger = new Logger(DeviceGateway.name);

  constructor(
    private jwtService: JwtService,
    @Inject(forwardRef(() => DeviceService))
    private deviceService: DeviceService,
  ) {}

  afterInit(server: Server) {
    this.logger.log('Devices WebSocket Gateway initialized');
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

      this.logger.log(`Client connected: ${client.id} (User: ${client.userId})`);
    } catch (error) {
      this.logger.warn(`Connection rejected: Invalid token - ${error.message}`);
      client.disconnect();
    }
  }

  async handleDisconnect(client: AuthenticatedSocket) {
    try {
      // Unregister device connection if any
      if (client.deviceId) {
        await this.deviceService.unregisterConnection(client.id);
      }
      
      this.logger.log(`Client disconnected: ${client.id} (User: ${client.userId})`);
    } catch (error) {
      this.logger.error(`Error during disconnect: ${error.message}`);
    }
  }

  // Device Connection Management
  @SubscribeMessage('connect-device')
  async handleConnectDevice(
    @ConnectedSocket() client: AuthenticatedSocket,
    @MessageBody() { deviceId, deviceInfo }: { deviceId: string; deviceInfo?: any },
  ) {
    try {
      if (!client.userId) {
        client.emit('error', { message: 'Authentication required' });
        return;
      }

      // Register connection with device service
      await this.deviceService.registerConnection(
        deviceId,
        client.userId,
        client.id,
        deviceInfo?.userAgent,
      );

      // Join device room
      const room = SOCKET_ROOMS.DEVICE(deviceId);
      await client.join(room);
      
      // Store device info in client
      client.deviceId = deviceId;
      client.data.deviceInfo = deviceInfo;
      client.data.connectedAt = new Date().toISOString();

      client.emit('device-connected', {
        deviceId,
        message: 'Successfully connected to device',
        timestamp: new Date().toISOString(),
      });

      this.logger.log(`User ${client.userId} connected to device ${deviceId}`);
    } catch (error) {
      client.emit('error', { message: 'Failed to connect to device', details: error.message });
    }
  }

  @SubscribeMessage('disconnect-device')
  async handleDisconnectDevice(
    @ConnectedSocket() client: AuthenticatedSocket,
    @MessageBody() { deviceId }: { deviceId: string },
  ) {
    try {
      if (!client.userId || client.deviceId !== deviceId) {
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

  // Playback State Synchronization
  @SubscribeMessage('playback-state')
  async handlePlaybackState(
    @ConnectedSocket() client: AuthenticatedSocket,
    @MessageBody() { 
      deviceId, 
      state 
    }: { 
      deviceId: string; 
      state: {
        isPlaying: boolean;
        currentTrack?: any;
        position: number;
        volume: number;
        shuffle: boolean;
        repeat: string;
      };
    },
  ) {
    try {
      if (!client.userId || client.deviceId !== deviceId) {
        return;
      }

      // Update last activity
      await this.deviceService.updateLastActivity(client.id);

      // Broadcast playback state to device room
      const room = SOCKET_ROOMS.DEVICE(deviceId);
      client.to(room).emit('playback-state-updated', {
        deviceId,
        state,
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
    delegatedBy: string
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
      delegatedBy,
      timestamp: new Date().toISOString(),
    });

    // Also notify the delegated user directly
    const userRoom = SOCKET_ROOMS.USER(delegatedTo.id);
    this.server.to(userRoom).emit('device-control-received', {
      deviceId,
      permissions,
      delegatedBy,
      timestamp: new Date().toISOString(),
    });
  }

  notifyControlRevoked(deviceId: string, previousDelegatedTo: User | null, revokedBy: string) {
    const room = SOCKET_ROOMS.DEVICE(deviceId);
    this.server.to(room).emit('control-revoked', {
      deviceId,
      previousDelegatedTo: previousDelegatedTo ? {
        id: previousDelegatedTo.id,
        displayName: previousDelegatedTo.displayName,
      } : null,
      revokedBy,
      timestamp: new Date().toISOString(),
    });

    // Also notify the previously delegated user
    if (previousDelegatedTo) {
      const userRoom = SOCKET_ROOMS.USER(previousDelegatedTo.id);
      this.server.to(userRoom).emit('device-control-revoked', {
        deviceId,
        revokedBy,
        timestamp: new Date().toISOString(),
      });
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