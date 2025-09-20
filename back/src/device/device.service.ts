import {
  Injectable,
  NotFoundException,
  BadRequestException,
  ForbiddenException,
  ConflictException,
  Inject,
  forwardRef,
} from '@nestjs/common';
import { InjectRepository } from '@nestjs/typeorm';
import { Repository, LessThan } from 'typeorm';
import { Cron, CronExpression } from '@nestjs/schedule';

import { 
  Device, 
  DeviceType, 
  DeviceStatus 
} from 'src/device/entities/device.entity';
import { User } from 'src/user/entities/user.entity';

import { CreateDeviceDto } from './dto/create-device.dto';
import { UpdateDeviceDto } from './dto/update-device.dto';
import { DelegateControlDto } from './dto/delegate-control.dto';
import { PaginationDto } from '../common/dto/pagination.dto';

import { DeviceGateway } from './device.gateway';

export interface DeviceWithStats extends Device {
  stats: {
    isOnline: boolean;
    isDelegated: boolean;
    delegationTimeLeft?: number; // seconds
    connectionCount: number;
  };
}

export interface PlaybackCommand {
  command: 'play' | 'pause' | 'skip' | 'previous' | 'volume' | 'seek' | 'shuffle' | 'repeat';
  data?: {
    volume?: number; // 0-100
    position?: number; // seconds
    trackId?: string;
    shuffle?: boolean;
    repeat?: 'off' | 'track' | 'playlist';
  };
  timestamp: Date;
  sentBy: string;
}

export interface DeviceConnection {
  deviceId: string;
  userId: string;
  socketId: string;
  connectedAt: Date;
  lastActivity: Date;
  deviceIdentifier?: string;
  userAgent?: string;
}

@Injectable()
export class DeviceService {
  private activeConnections = new Map<string, DeviceConnection[]>();
  
  constructor(
    @InjectRepository(Device)
    private readonly deviceRepository: Repository<Device>,
    @InjectRepository(User)
    private readonly userRepository: Repository<User>,
    @Inject(forwardRef(() => DeviceGateway))
    private readonly deviceGateway: DeviceGateway,
  ) {}

  // Device CRUD Operations
  async create(createDeviceDto: CreateDeviceDto, ownerId: string): Promise<DeviceWithStats> {
    const owner = await this.userRepository.findOne({ where: { id: ownerId } });
    if (!owner) {
      throw new NotFoundException('Owner not found');
    }

    // Check if device name is unique for this user
    const existingDevice = await this.deviceRepository.findOne({
      where: { name: createDeviceDto.name, ownerId },
    });

    if (existingDevice) {
      throw new ConflictException('Device name already exists for this user');
    }

    const device = this.deviceRepository.create({
      ...createDeviceDto,
      ownerId,
      status: DeviceStatus.OFFLINE,
      lastSeen: new Date(),
    });

    const savedDevice = await this.deviceRepository.save(device);
    return this.addDeviceStats(savedDevice);
  }

  async findAll(paginationDto: PaginationDto, userId?: string) {
    const { page, limit, skip } = paginationDto;

    let queryBuilder = this.deviceRepository.createQueryBuilder('device')
      .leftJoinAndSelect('device.owner', 'owner')
      .leftJoinAndSelect('device.delegatedTo', 'delegatedTo');

    if (userId) {
      // Show user's devices + devices delegated to them
      queryBuilder = queryBuilder.where(
        'device.ownerId = :userId OR device.delegatedToId = :userId',
        { userId }
      );
    }

    const [devices, total] = await queryBuilder
      .orderBy('device.lastSeen', 'DESC')
      .skip(skip)
      .take(limit)
      .getManyAndCount();

    const devicesWithStats = await Promise.all(
      devices.map(device => this.addDeviceStats(device)),
    );

    const totalPages = Math.ceil(total / limit);

    return {
      success: true,
      data: devicesWithStats,
      pagination: {
        page,
        limit,
        total,
        totalPages,
        hasNext: page < totalPages,
        hasPrev: page > 1,
      },
      timestamp: new Date().toISOString(),
    };
  }

  async findById(id: string, userId?: string): Promise<DeviceWithStats> {
    const device = await this.deviceRepository.findOne({
      where: { id },
      relations: ['owner', 'delegatedTo'],
    });

    if (!device) {
      throw new NotFoundException('Device not found');
    }

    // Check if user has access to this device
    const hasAccess = device.ownerId === userId || 
                     device.delegatedToId === userId ||
                     !userId; // Public access for some endpoints

    if (userId && !hasAccess) {
      throw new ForbiddenException('You do not have access to this device');
    }

    return this.addDeviceStats(device);
  }

    async findByDeviceIdentifier(identifier: string, userId?: string): Promise<DeviceWithStats> {
    const device = await this.deviceRepository.findOne({
      where: { identifier },
      relations: ['owner', 'delegatedTo'],
    });

    if (!device) {
      throw new NotFoundException('Device not found');
    }

    // Check if user has access to this device
    const hasAccess = device.ownerId === userId || 
                     device.delegatedToId === userId ||
                     !userId; // Public access for some endpoints

    if (userId && !hasAccess) {
      throw new ForbiddenException('You do not have access to this device');
    }

    return this.addDeviceStats(device);
  }

  async findUserDevices(userId: string): Promise<DeviceWithStats[]> {
    const devices = await this.deviceRepository.find({
      where: { ownerId: userId },
      relations: ['delegatedTo'],
      order: { lastSeen: 'DESC' },
    });

    return Promise.all(devices.map(device => this.addDeviceStats(device)));
  }

  async findDelegatedDevices(userId: string): Promise<DeviceWithStats[]> {
    const devices = await this.deviceRepository.find({
      where: { delegatedToId: userId },
      relations: ['owner'],
      order: { lastSeen: 'DESC' },
    });

    return Promise.all(devices.map(device => this.addDeviceStats(device)));
  }

  async getControlPermissions(userId: string, deviceId?: string): Promise<any[]> {
    const query = this.deviceRepository.createQueryBuilder('device')
      .leftJoinAndSelect('device.owner', 'owner')
      .leftJoinAndSelect('device.delegatedTo', 'delegatedTo')
      .where('device.delegatedToId IS NOT NULL')
      .andWhere('(device.ownerId = :userId OR device.delegatedToId = :userId)', { userId });

    if (deviceId) {
      query.andWhere('device.id = :deviceId', { deviceId });
    }

    const devices = await query.getMany();

    return devices.map(device => ({
      id: `${device.id}-${device.delegatedToId}`,
      grantedTo: device.delegatedTo?.id,
      grantedToName: device.delegatedTo?.displayName || device.delegatedTo?.email,
      deviceId: device.id,
      deviceName: device.name,
      grantedAt: device.delegationExpiresAt ? new Date(Date.now() - 24 * 60 * 60 * 1000).toISOString() : new Date().toISOString(), // Approximate
      expiresAt: device.delegationExpiresAt?.toISOString(),
      isActive: device.delegationExpiresAt ? device.delegationExpiresAt > new Date() : true,
      permissions: device.delegationPermissions,
      deviceOwner: device.owner?.displayName || device.owner?.email,
      isGrantedByMe: device.ownerId === userId,
      isGrantedToMe: device.delegatedToId === userId,
    })).filter(permission => permission.isActive);
  }

  async update(id: string, updateDeviceDto: UpdateDeviceDto, userId: string): Promise<DeviceWithStats> {
    const device = await this.findById(id, userId);

    // Only device owner can update device info
    if (device.ownerId !== userId) {
      throw new ForbiddenException('Only the device owner can update device information');
    }

    // If changing name, check uniqueness
    if (updateDeviceDto.name && updateDeviceDto.name !== device.name) {
      const existingDevice = await this.deviceRepository.findOne({
        where: { name: updateDeviceDto.name, ownerId: userId },
      });

      if (existingDevice) {
        throw new ConflictException('Device name already exists');
      }
    }

    Object.assign(device, updateDeviceDto);
    const updatedDevice = await this.deviceRepository.save(device);

    // Notify connections about device update
    this.deviceGateway.notifyDeviceUpdated(id, updatedDevice);

    return this.addDeviceStats(updatedDevice);
  }

  async remove(id: string, userId: string): Promise<void> {
    const device = await this.findById(id, userId);

    // Only device owner can delete device
    if (device.ownerId !== userId) {
      throw new ForbiddenException('Only the device owner can delete this device');
    }

    // Revoke any active delegations
    if (device.delegatedToId) {
      await this.revokeDelegation(id, userId);
    }

    // Disconnect all active connections
    this.deviceGateway.disconnectDeviceConnections(id);

    await this.deviceRepository.remove(device);
  }

  // Device Connection Management
  async registerConnection(
    userId: string, 
    socketId: string, 
    deviceId?: string,
    deviceIdentifier?: string,
    userAgent?: string
  ): Promise<void> {
    let device: DeviceWithStats | undefined;

    if (deviceId) {
      device = await this.findById(deviceId);
    } else if (deviceIdentifier) {
      device = await this.findByDeviceIdentifier(deviceIdentifier);
    } else {
      throw new BadRequestException('deviceId or deviceIdentifier is required');
    }

    // Check if user can connect to this device
    const canConnect = device.ownerId === userId || device.delegatedToId === userId;
    if (!canConnect) {
      throw new ForbiddenException('You cannot connect to this device');
    }

    // Update device status
    await this.updateDeviceStatus(device.id, DeviceStatus.ONLINE);

    // Register connection
    const connection: DeviceConnection = {
      deviceId: device.id,
      userId,
      socketId,
      connectedAt: new Date(),
      lastActivity: new Date(),
      deviceIdentifier,
      userAgent,
    };

    if (!this.activeConnections.has(device.id)) {
      this.activeConnections.set(device.id, []);
    }

    this.activeConnections.get(device.id)!.push(connection);

    // Notify about device connection
    this.deviceGateway.notifyDeviceConnected(device.id, userId);
  }

  async unregisterConnection(socketId: string): Promise<void> {

    this.logActiveConnections();

    for (const [deviceId, connections] of this.activeConnections.entries()) {
      const connectionIndex = connections.findIndex(conn => conn.socketId === socketId);
      
      if (connectionIndex !== -1) {
        const connection = connections[connectionIndex];
        connections.splice(connectionIndex, 1);

        // If no more connections, update device status
        if (connections.length === 0) {
          await this.updateDeviceStatus(deviceId, DeviceStatus.OFFLINE);
          this.activeConnections.delete(deviceId);
        }

        // Notify about disconnection
        this.deviceGateway.notifyDeviceDisconnected(deviceId, connection.userId);
        break;
      }
    }
  }

  logActiveConnections() {
    console.log('--- Active Device Connections ---');
    for (const [deviceId, connections] of this.activeConnections.entries()) {
      console.log(`Device: ${deviceId}`);
      connections.forEach((conn, idx) => {
        console.log(`  [${idx}] userId: ${conn.userId}, socketId: ${conn.socketId}, connectedAt: ${conn.connectedAt.toISOString()}, lastActivity: ${conn.lastActivity.toISOString()}, deviceIdentifier: ${conn.deviceIdentifier}, userAgent: ${conn.userAgent}`);
      });
    }
    console.log('--------------------------------');
  }

  async updateLastActivity(socketId: string): Promise<void> {
    for (const connections of this.activeConnections.values()) {
      const connection = connections.find(conn => conn.socketId === socketId);
      if (connection) {
        connection.lastActivity = new Date();
        break;
      }
    }
  }

  // Device Control Delegation
  async delegateControl(
    deviceId: string, 
    requesterId: string, 
    delegateDto: DelegateControlDto
  ): Promise<DeviceWithStats> {
    const device = await this.findById(deviceId, requesterId);

    // Only device owner can delegate control
    if (device.ownerId !== requesterId) {
      throw new ForbiddenException('Only the device owner can delegate control');
    }

    // Check if target user exists
    const targetUser = await this.userRepository.findOne({
      where: { id: delegateDto.delegatedToId },
    });

    if (!targetUser) {
      throw new NotFoundException('Target user not found');
    }

    // Cannot delegate to self
    if (delegateDto.delegatedToId === requesterId) {
      throw new BadRequestException('Cannot delegate control to yourself');
    }

    // Set default expiration if not provided (24 hours)
    const expiresAt = delegateDto.expiresAt ? 
      new Date(delegateDto.expiresAt) : 
      new Date(Date.now() + 24 * 60 * 60 * 1000);

    // Set default permissions if not provided
    const defaultPermissions = {
      canPlay: true,
      canPause: true,
      canSkip: true,
      canChangeVolume: true,
      canChangePlaylist: false,
    };

    // Update device with delegation info
    device.delegatedToId = delegateDto.delegatedToId;
    device.delegationExpiresAt = expiresAt;
    device.delegationPermissions = { ...defaultPermissions, ...delegateDto.permissions };

    const updatedDevice = await this.deviceRepository.save(device);

    // Notify about delegation
    this.deviceGateway.notifyControlDelegated(
      deviceId, 
      targetUser, 
      device.delegationPermissions,
      requesterId
    );

    return this.addDeviceStats(updatedDevice);
  }

  async revokeDelegation(deviceId: string, requesterId: string): Promise<DeviceWithStats> {
    const device = await this.findById(deviceId, requesterId);
    /* const device = await this.deviceRepository.findOne({
      where: { id: deviceId },
      relations: ['owner', 'delegatedTo'],
    });

    if (!device) {
      throw new NotFoundException('Device not found');
    } */

    console.log('Revoking delegation for device:', device);
    
    // Only owner or delegated user can revoke
    const canRevoke = device.ownerId === requesterId || device.delegatedToId === requesterId;
    if (!canRevoke) {
      throw new ForbiddenException('You cannot revoke control for this device');
    }

    const previousDelegatedTo = device.delegatedTo;

    // Notify about revocation
    this.deviceGateway.notifyControlRevoked(device.identifier, previousDelegatedTo, requesterId);

    // Clear delegation
    device.delegatedTo = null;
    device.delegatedToId = null;
    device.delegationExpiresAt = null;
    device.delegationPermissions = null;

    const updatedDevice = await this.deviceRepository.save(device);

    console.log('Revoking delegation for updatedDevice:', updatedDevice);

    return this.addDeviceStats(updatedDevice);
  }

  async extendDelegation(
    deviceId: string, 
    requesterId: string, 
    additionalHours: number
  ): Promise<DeviceWithStats> {
    const device = await this.findById(deviceId, requesterId);

    // Only device owner can extend delegation
    if (device.ownerId !== requesterId) {
      throw new ForbiddenException('Only the device owner can extend delegation');
    }

    if (!device.delegatedToId || !device.delegationExpiresAt) {
      throw new BadRequestException('No active delegation to extend');
    }

    // Extend expiration time
    const currentExpiry = new Date(device.delegationExpiresAt);
    const newExpiry = new Date(currentExpiry.getTime() + additionalHours * 60 * 60 * 1000);

    device.delegationExpiresAt = newExpiry;
    const updatedDevice = await this.deviceRepository.save(device);

    // Notify about extension
    this.deviceGateway.notifyDelegationExtended(deviceId, newExpiry, requesterId);

    return this.addDeviceStats(updatedDevice);
  }

  // Playback Control
  async sendPlaybackCommand(
    deviceId: string, 
    userId: string, 
    command: PlaybackCommand
  ): Promise<void> {
    const device = await this.findById(deviceId, userId);

    // Check permissions
    await this.checkPlaybackPermissions(device, userId, command.command);

    // Check if device is online
    if (device.status === DeviceStatus.OFFLINE) {
      throw new BadRequestException('Device is offline');
    }

    // Send command to device
    this.deviceGateway.sendPlaybackCommand(deviceId, {
      ...command,
      sentBy: userId,
      timestamp: new Date(),
    });

    // Update device status based on command
    if (command.command === 'play') {
      await this.updateDeviceStatus(deviceId, DeviceStatus.PLAYING);
    } else if (command.command === 'pause') {
      await this.updateDeviceStatus(deviceId, DeviceStatus.PAUSED);
    }
  }

  async getDeviceStatus(deviceId: string, userId: string): Promise<{
    device: DeviceWithStats;
    connections: number;
    lastCommand?: PlaybackCommand;
  }> {
    const device = await this.findById(deviceId, userId);
    const connections = this.activeConnections.get(deviceId)?.length || 0;

    return {
      device,
      connections,
      // lastCommand would be stored in a separate collection in production
    };
  }

  // Helper Methods
  private async addDeviceStats(device: Device): Promise<DeviceWithStats> {
    const connections = this.activeConnections.get(device.id) || [];
    const isOnline = connections.length > 0;
    const isDelegated = !!device.delegatedToId && 
      (!device.delegationExpiresAt || device.delegationExpiresAt > new Date());

    let delegationTimeLeft: number | undefined;
    if (isDelegated && device.delegationExpiresAt) {
      delegationTimeLeft = Math.max(0, 
        Math.floor((device.delegationExpiresAt.getTime() - Date.now()) / 1000)
      );
    }

    return {
      ...device,
      stats: {
        isOnline,
        isDelegated,
        delegationTimeLeft,
        connectionCount: connections.length,
      },
    };
  }

  private async updateDeviceStatus(deviceId: string, status: DeviceStatus): Promise<void> {
    await this.deviceRepository.update(deviceId, {
      status,
      lastSeen: new Date(),
    });

    // Notify status change
    this.deviceGateway.notifyDeviceStatusChanged(deviceId, status);
  }

  private async checkPlaybackPermissions(
    device: Device, 
    userId: string, 
    command: string
  ): Promise<void> {
    // Device owner has all permissions
    if (device.ownerId === userId) {
      return;
    }

    // Check if user has delegation
    if (device.delegatedToId !== userId) {
      throw new ForbiddenException('You do not have control over this device');
    }

    // Check if delegation is still valid
    if (device.delegationExpiresAt && device.delegationExpiresAt < new Date()) {
      throw new ForbiddenException('Device control delegation has expired');
    }

    // Check specific command permissions
    const permissions = device.delegationPermissions;
    if (!permissions) {
      throw new ForbiddenException('No delegation permissions set');
    }

    const commandPermissionMap: Record<string, keyof typeof permissions> = {
      play: 'canPlay',
      pause: 'canPause',
      skip: 'canSkip',
      previous: 'canSkip', // Use same permission as skip
      volume: 'canChangeVolume',
      seek: 'canPlay', // Use same permission as play
      shuffle: 'canChangePlaylist',
      repeat: 'canChangePlaylist',
    };

    const requiredPermission = commandPermissionMap[command];
    if (requiredPermission && !permissions[requiredPermission]) {
      throw new ForbiddenException(`You do not have permission to ${command}`);
    }
  }

  // Automated Cleanup
  @Cron(CronExpression.EVERY_MINUTE)
  async cleanupExpiredDelegations(): Promise<void> {
    const expiredDelegations = await this.deviceRepository.find({
      where: {
        delegationExpiresAt: LessThan(new Date()),
        delegatedToId: { $ne: null } as any,
      },
      relations: ['delegatedTo'],
    });

    for (const device of expiredDelegations) {
      const previousDelegatedTo = device.delegatedTo;
      
      device.delegatedToId = null;
      device.delegationExpiresAt = null;
      device.delegationPermissions = null;
      
      await this.deviceRepository.save(device);

      // Notify about automatic revocation
      this.deviceGateway.notifyControlRevoked(
        device.identifier, 
        previousDelegatedTo, 
        'system' // System-initiated revocation
      );
    }

    if (expiredDelegations.length > 0) {
      console.log(`Cleaned up ${expiredDelegations.length} expired delegations`);
    }
  }

  @Cron(CronExpression.EVERY_5_MINUTES)
  async cleanupInactiveConnections(): Promise<void> {
    const fiveMinutesAgo = new Date(Date.now() - 5 * 60 * 1000);
    
    for (const [deviceId, connections] of this.activeConnections.entries()) {
      const activeConnections = connections.filter(
        conn => conn.lastActivity > fiveMinutesAgo
      );
      
      if (activeConnections.length !== connections.length) {
        if (activeConnections.length === 0) {
          await this.updateDeviceStatus(deviceId, DeviceStatus.OFFLINE);
          this.activeConnections.delete(deviceId);
        } else {
          this.activeConnections.set(deviceId, activeConnections);
        }
      }
    }
  }

  // Statistics and Analytics
  async getDeviceAnalytics(userId: string, deviceId?: string): Promise<any> {
    let whereClause: any = { ownerId: userId };
    if (deviceId) {
      whereClause.id = deviceId;
    }

    const devices = await this.deviceRepository.find({
      where: whereClause,
      relations: ['delegatedTo'],
    });

    const totalDevices = devices.length;
    const onlineDevices = devices.filter(d => d.status !== DeviceStatus.OFFLINE).length;
    const delegatedDevices = devices.filter(d => d.delegatedToId).length;
    
    const devicesByType = devices.reduce((acc, device) => {
      acc[device.type] = (acc[device.type] || 0) + 1;
      return acc;
    }, {} as Record<DeviceType, number>);

    return {
      totalDevices,
      onlineDevices,
      delegatedDevices,
      devicesByType,
      averageConnectionsPerDevice: totalDevices > 0 ? 
        Array.from(this.activeConnections.values()).flat().length / totalDevices : 0,
    };
  }
}