// src/devices/device.controller.ts
import {
  Controller,
  Get,
  Post,
  Body,
  Patch,
  Param,
  Delete,
  Query,
  UseGuards,
  HttpCode,
  HttpStatus,
  BadRequestException,
} from '@nestjs/common';

import { DeviceService, PlaybackCommand } from './device.service';
import { CreateDeviceDto } from './dto/create-device.dto';
import { UpdateDeviceDto } from './dto/update-device.dto';
import { DelegateControlDto } from './dto/delegate-control.dto';
import { PaginationDto } from '../common/dto/pagination.dto';

import { JwtAuthGuard } from '../auth/guards/jwt-auth.guard';
import { CurrentUser } from '../common/decorators/current-user.decorator';

import { User } from 'src/user/entities/user.entity';

@Controller('devices')
@UseGuards(JwtAuthGuard)
export class DeviceController {
  constructor(private readonly deviceService: DeviceService) {}

  @Post()
  async create(@Body() createDeviceDto: CreateDeviceDto, @CurrentUser() user: User) {
    const device = await this.deviceService.create(createDeviceDto, user.id);
    return {
      success: true,
      message: 'Device created successfully',
      data: device,
      timestamp: new Date().toISOString(),
    };
  }

  @Get()
  async findAll(@Query() paginationDto: PaginationDto, @CurrentUser() user: User) {
    return this.deviceService.findAll(paginationDto, user.id);
  }

  @Get('my-devices')
  async getMyDevices(@CurrentUser() user: User) {
    const devices = await this.deviceService.findUserDevices(user.id);
    return {
      success: true,
      data: devices,
      timestamp: new Date().toISOString(),
    };
  }

  @Get('delegated-to-me')
  async getDelegatedDevices(@CurrentUser() user: User) {
    const devices = await this.deviceService.findDelegatedDevices(user.id);
    return {
      success: true,
      data: devices,
      timestamp: new Date().toISOString(),
    };
  }

  @Get('analytics')
  async getAnalytics(
    @Query('deviceId') deviceId: string,
    @CurrentUser() user: User,
  ) {
    const analytics = await this.deviceService.getDeviceAnalytics(user.id, deviceId);
    return {
      success: true,
      data: analytics,
      timestamp: new Date().toISOString(),
    };
  }

  @Get(':id')
  async findOne(@Param('id') id: string, @CurrentUser() user: User) {
    const device = await this.deviceService.findById(id, user.id);
    return {
      success: true,
      data: device,
      timestamp: new Date().toISOString(),
    };
  }

  @Get(':id/status')
  async getStatus(@Param('id') id: string, @CurrentUser() user: User) {
    const status = await this.deviceService.getDeviceStatus(id, user.id);
    return {
      success: true,
      data: status,
      timestamp: new Date().toISOString(),
    };
  }

  @Patch(':id')
  async update(
    @Param('id') id: string,
    @Body() updateDeviceDto: UpdateDeviceDto,
    @CurrentUser() user: User,
  ) {
    const device = await this.deviceService.update(id, updateDeviceDto, user.id);
    return {
      success: true,
      message: 'Device updated successfully',
      data: device,
      timestamp: new Date().toISOString(),
    };
  }

  @Delete(':id')
  async remove(@Param('id') id: string, @CurrentUser() user: User) {
    await this.deviceService.remove(id, user.id);
    return {
      success: true,
      message: 'Device deleted successfully',
      timestamp: new Date().toISOString(),
    };
  }

  // Control Delegation
  @Post(':id/delegate')
  @HttpCode(HttpStatus.OK)
  async delegateControl(
    @Param('id') id: string,
    @Body() delegateDto: DelegateControlDto,
    @CurrentUser() user: User,
  ) {
    const device = await this.deviceService.delegateControl(id, user.id, delegateDto);
    return {
      success: true,
      message: 'Control delegated successfully',
      data: device,
      timestamp: new Date().toISOString(),
    };
  }

  @Post(':id/revoke')
  @HttpCode(HttpStatus.OK)
  async revokeControl(@Param('id') id: string, @CurrentUser() user: User) {
    const device = await this.deviceService.revokeDelegation(id, user.id);
    return {
      success: true,
      message: 'Control revoked successfully',
      data: device,
      timestamp: new Date().toISOString(),
    };
  }

  @Post(':id/extend')
  @HttpCode(HttpStatus.OK)
  async extendDelegation(
    @Param('id') id: string,
    @Body() { hours }: { hours: number },
    @CurrentUser() user: User,
  ) {
    const device = await this.deviceService.extendDelegation(id, user.id, hours);
    return {
      success: true,
      message: 'Delegation extended successfully',
      data: device,
      timestamp: new Date().toISOString(),
    };
  }

  // Playback Control
  @Post(':id/play')
  @HttpCode(HttpStatus.OK)
  async play(
    @Param('id') id: string,
    @Body() data: { trackId?: string },
    @CurrentUser() user: User,
  ) {
    const command: PlaybackCommand = {
      command: 'play',
      data,
      timestamp: new Date(),
      sentBy: user.id,
    };

    await this.deviceService.sendPlaybackCommand(id, user.id, command);
    return {
      success: true,
      message: 'Play command sent',
      timestamp: new Date().toISOString(),
    };
  }

  @Post(':id/pause')
  @HttpCode(HttpStatus.OK)
  async pause(@Param('id') id: string, @CurrentUser() user: User) {
    const command: PlaybackCommand = {
      command: 'pause',
      timestamp: new Date(),
      sentBy: user.id,
    };

    await this.deviceService.sendPlaybackCommand(id, user.id, command);
    return {
      success: true,
      message: 'Pause command sent',
      timestamp: new Date().toISOString(),
    };
  }

  @Post(':id/skip')
  @HttpCode(HttpStatus.OK)
  async skip(@Param('id') id: string, @CurrentUser() user: User) {
    const command: PlaybackCommand = {
      command: 'skip',
      timestamp: new Date(),
      sentBy: user.id,
    };

    await this.deviceService.sendPlaybackCommand(id, user.id, command);
    return {
      success: true,
      message: 'Skip command sent',
      timestamp: new Date().toISOString(),
    };
  }

  @Post(':id/previous')
  @HttpCode(HttpStatus.OK)
  async previous(@Param('id') id: string, @CurrentUser() user: User) {
    const command: PlaybackCommand = {
      command: 'previous',
      timestamp: new Date(),
      sentBy: user.id,
    };

    await this.deviceService.sendPlaybackCommand(id, user.id, command);
    return {
      success: true,
      message: 'Previous command sent',
      timestamp: new Date().toISOString(),
    };
  }

  @Post(':id/volume')
  @HttpCode(HttpStatus.OK)
  async setVolume(
    @Param('id') id: string,
    @Body() { volume }: { volume: number },
    @CurrentUser() user: User,
  ) {
    if (volume < 0 || volume > 100) {
      throw new BadRequestException('Volume must be between 0 and 100');
    }

    const command: PlaybackCommand = {
      command: 'volume',
      data: { volume },
      timestamp: new Date(),
      sentBy: user.id,
    };

    await this.deviceService.sendPlaybackCommand(id, user.id, command);
    return {
      success: true,
      message: 'Volume command sent',
      timestamp: new Date().toISOString(),
    };
  }

  @Post(':id/seek')
  @HttpCode(HttpStatus.OK)
  async seek(
    @Param('id') id: string,
    @Body() { position }: { position: number },
    @CurrentUser() user: User,
  ) {
    if (position < 0) {
      throw new BadRequestException('Position must be positive');
    }

    const command: PlaybackCommand = {
      command: 'seek',
      data: { position },
      timestamp: new Date(),
      sentBy: user.id,
    };

    await this.deviceService.sendPlaybackCommand(id, user.id, command);
    return {
      success: true,
      message: 'Seek command sent',
      timestamp: new Date().toISOString(),
    };
  }

  @Post(':id/shuffle')
  @HttpCode(HttpStatus.OK)
  async shuffle(
    @Param('id') id: string,
    @Body() { shuffle }: { shuffle: boolean },
    @CurrentUser() user: User,
  ) {
    const command: PlaybackCommand = {
      command: 'shuffle',
      data: { shuffle },
      timestamp: new Date(),
      sentBy: user.id,
    };

    await this.deviceService.sendPlaybackCommand(id, user.id, command);
    return {
      success: true,
      message: 'Shuffle command sent',
      timestamp: new Date().toISOString(),
    };
  }

  @Post(':id/repeat')
  @HttpCode(HttpStatus.OK)
  async repeat(
    @Param('id') id: string,
    @Body() { repeat }: { repeat: 'off' | 'track' | 'playlist' },
    @CurrentUser() user: User,
  ) {
    const command: PlaybackCommand = {
      command: 'repeat',
      data: { repeat },
      timestamp: new Date(),
      sentBy: user.id,
    };

    await this.deviceService.sendPlaybackCommand(id, user.id, command);
    return {
      success: true,
      message: 'Repeat command sent',
      timestamp: new Date().toISOString(),
    };
  }
}