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
import { ConfigService } from '@nestjs/config';

import { Device, DeviceStatus } from 'src/device/entities/device.entity';
import { User } from 'src/user/entities/user.entity';
import { PlaybackCommand, DeviceService } from './device.service';

import { SOCKET_ROOMS } from '../common/constants/socket-rooms';
import { log } from 'console';

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
    private configService: ConfigService,
    @Inject(forwardRef(() => DeviceService))
    private deviceService: DeviceService,
  ) {

  }

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
      const payload = this.jwtService.verify(token, { 
        secret: this.configService.get<string>('JWT_SECRET') 
      });
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
    // @MessageBody() { deviceId, deviceInfo }: { deviceId: string; deviceInfo?: any },
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
        undefined, // je ne sais pas comment avoir le deviceId sans faire d'appel API superflux depuis le client
        deviceIdentifier,
        // deviceInfo?.userAgent,
      );

      // Join device room
      const room = SOCKET_ROOMS.DEVICE(deviceIdentifier);
      this.logger.debug(`Joining DEVICE room ${room} for device ${deviceIdentifier}`);
      await client.join(room);
      const userRoom = SOCKET_ROOMS.USER(client.userId);
      await client.join(userRoom);
      
      // Store device info in client
      client.deviceIdentifier = deviceIdentifier;
      // client.data.deviceInfo = deviceInfo;
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

  // Playback State Synchronization
  @SubscribeMessage('playback-state')
  async handlePlaybackState(
    @ConnectedSocket() client: AuthenticatedSocket,
/*     @MessageBody() { 
      deviceIdentifier, 
      state 
    }: { 
      deviceIdentifier: string; 
      state: {
        isPlaying?: boolean;
        volume?: number;
        prevNext?: number;
        // currentTrack?: any;
        // position: number;
        // shuffle: boolean;
        // repeat: string;
      };
    }, */
      @MessageBody() data?: any,
  ) {

    const { deviceIdentifier, command } = data[0];  // Extraction depuis l'array

    this.logger.debug(`SubscribeMessage('playback-state') Device ${deviceIdentifier} state comand: ${command}`);

    try {
      // if (!client.userId || client.deviceIdentifier !== deviceIdentifier) {
      //   return;
      // }

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

  // Récupérer les connexions en temps réel pour un device
  @SubscribeMessage('get-device-connections')
  async handleGetDeviceConnections(
    @ConnectedSocket() client: AuthenticatedSocket,
    // @MessageBody() { deviceId }: { deviceId: string },
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
    // @MessageBody() { deviceId }: { deviceId: string },
    @MessageBody() data?: any,
  ) {
    console.log('Rooms du client:', Array.from(client.rooms));
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
    let userRoom = "";
    if (previousDelegatedTo) {
      userRoom = SOCKET_ROOMS.USER(previousDelegatedTo.id);
      this.server.to(userRoom).emit('device-control-revoked', {
        deviceId,
        revokedBy,
        timestamp: new Date().toISOString(),
      });
    }

    console.log(`Control revoked room ${userRoom} & ${room}`);
    
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