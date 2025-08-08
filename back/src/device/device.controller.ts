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
import { ApiTags, ApiOperation, ApiBody, ApiParam, ApiQuery } from '@nestjs/swagger';

@ApiTags('Devices')
@Controller('devices')
@UseGuards(JwtAuthGuard)
export class DeviceController {
  constructor(private readonly deviceService: DeviceService) {}

  @Post()
  @ApiOperation({
    summary: 'Register a new device',
    description: 'Creates a new device associated with the current user',
  })
  @ApiBody({ type: CreateDeviceDto })
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
  @ApiOperation({
    summary: 'Get all devices',
    description: 'Returns a paginated list of all devices accessible to the current user',
  })
  @ApiQuery({ type: PaginationDto })
  async findAll(@Query() paginationDto: PaginationDto, @CurrentUser() user: User) {
    return this.deviceService.findAll(paginationDto, user.id);
  }

  @Get('my-devices')
  @ApiOperation({
    summary: 'Get user devices',
    description: 'Returns all devices owned by the current user',
  })
  async getMyDevices(@CurrentUser() user: User) {
    const devices = await this.deviceService.findUserDevices(user.id);
    return {
      success: true,
      data: devices,
      timestamp: new Date().toISOString(),
    };
  }

  @Get('delegated-to-me')
  @ApiOperation({
    summary: 'Get delegated devices',
    description: 'Returns all devices where control has been delegated to the current user',
  })
  async getDelegatedDevices(@CurrentUser() user: User) {
    const devices = await this.deviceService.findDelegatedDevices(user.id);
    return {
      success: true,
      data: devices,
      timestamp: new Date().toISOString(),
    };
  }

  @Get('analytics')
  @ApiOperation({
    summary: 'Get device analytics',
    description: 'Returns usage analytics for a specific device',
  })
  @ApiQuery({ 
    name: 'deviceId', 
    type: String, 
    required: true,
    description: 'The ID of the device to get analytics for'
  })
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
  @ApiOperation({
    summary: 'Get device by ID',
    description: 'Returns a specific device by its ID if accessible to the current user',
  })
  @ApiParam({
    name: 'id',
    type: String,
    description: 'The ID of the device to retrieve',
    required: true
  })
  async findOne(@Param('id') id: string, @CurrentUser() user: User) {
    const device = await this.deviceService.findById(id, user.id);
    return {
      success: true,
      data: device,
      timestamp: new Date().toISOString(),
    };
  }

  @Get(':id/status')
  @ApiOperation({
    summary: 'Get device status',
    description: 'Returns the current status of a specific device',
  })
  @ApiParam({
    name: 'id',
    type: String,
    description: 'The ID of the device to check status',
    required: true
  })
  async getStatus(@Param('id') id: string, @CurrentUser() user: User) {
    const status = await this.deviceService.getDeviceStatus(id, user.id);
    return {
      success: true,
      data: status,
      timestamp: new Date().toISOString(),
    };
  }

  @Patch(':id')
  @ApiOperation({
    summary: 'Update a device',
    description: 'Updates a device\'s information',
  })
  @ApiParam({
    name: 'id',
    type: String,
    description: 'The ID of the device to update',
    required: true
  })
  @ApiBody({ type: UpdateDeviceDto })
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
  @ApiOperation({
    summary: 'Delete a device',
    description: 'Deletes a device owned by the current user',
  })
  @ApiParam({
    name: 'id',
    type: String,
    description: 'The ID of the device to delete',
    required: true
  })
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
  @ApiOperation({
    summary: 'Delegate device control',
    description: 'Delegates control of a device to another user for a limited time',
  })
  @ApiParam({
    name: 'id',
    type: String,
    description: 'The ID of the device to delegate',
    required: true
  })
  @ApiBody({ type: DelegateControlDto })
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
  @ApiOperation({
    summary: 'Revoke device control',
    description: 'Revokes delegated control of a device from another user',
  })
  @ApiParam({
    name: 'id',
    type: String,
    description: 'The ID of the device to revoke delegation',
    required: true
  })
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
  @ApiOperation({
    summary: 'Extend delegation',
    description: 'Extends the duration of a device control delegation',
  })
  @ApiParam({
    name: 'id',
    type: String,
    description: 'The ID of the device',
    required: true
  })
  @ApiBody({
    schema: {
      type: 'object',
      properties: {
        hours: {
          type: 'number',
          description: 'Number of hours to extend the delegation',
          example: 2
        }
      },
      required: ['hours']
    }
  })
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
  @ApiOperation({
    summary: 'Play music',
    description: 'Sends a play command to the device, optionally with a specific track',
  })
  @ApiParam({
    name: 'id',
    type: String,
    description: 'The ID of the device',
    required: true
  })
  @ApiBody({
    schema: {
      type: 'object',
      properties: {
        trackId: {
          type: 'string',
          description: 'Optional track ID to play specifically',
          example: 'track123'
        }
      }
    }
  })
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
  @ApiOperation({
    summary: 'Pause music',
    description: 'Sends a pause command to the device',
  })
  @ApiParam({
    name: 'id',
    type: String,
    description: 'The ID of the device',
    required: true
  })
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
  @ApiOperation({
    summary: 'Skip to next track',
    description: 'Sends a skip command to play the next track',
  })
  @ApiParam({
    name: 'id',
    type: String,
    description: 'The ID of the device',
    required: true
  })
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
  @ApiOperation({
    summary: 'Play previous track',
    description: 'Sends a command to play the previous track',
  })
  @ApiParam({
    name: 'id',
    type: String,
    description: 'The ID of the device',
    required: true
  })
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
  @ApiOperation({
    summary: 'Set volume',
    description: 'Changes the device volume (0-100)',
  })
  @ApiParam({
    name: 'id',
    type: String,
    description: 'The ID of the device',
    required: true
  })
  @ApiBody({
    schema: {
      type: 'object',
      properties: {
        volume: {
          type: 'number',
          minimum: 0,
          maximum: 100,
          description: 'Volume level from 0 to 100',
          example: 75
        }
      },
      required: ['volume']
    }
  })
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
  @ApiOperation({
    summary: 'Seek to position',
    description: 'Seeks to a specific position in the current track',
  })
  @ApiParam({
    name: 'id',
    type: String,
    description: 'The ID of the device',
    required: true
  })
  @ApiBody({
    schema: {
      type: 'object',
      properties: {
        position: {
          type: 'number',
          minimum: 0,
          description: 'Position in seconds to seek to',
          example: 120
        }
      },
      required: ['position']
    }
  })
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
  @ApiOperation({
    summary: 'Toggle shuffle mode',
    description: 'Enables or disables shuffle mode for the device',
  })
  @ApiParam({
    name: 'id',
    type: String,
    description: 'The ID of the device',
    required: true
  })
  @ApiBody({
    schema: {
      type: 'object',
      properties: {
        shuffle: {
          type: 'boolean',
          description: 'Whether to enable shuffle mode',
          example: true
        }
      },
      required: ['shuffle']
    }
  })
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
  @ApiOperation({
    summary: 'Set repeat mode',
    description: 'Sets the repeat mode for the device (off, track, or playlist)',
  })
  @ApiParam({
    name: 'id',
    type: String,
    description: 'The ID of the device',
    required: true
  })
  @ApiBody({
    schema: {
      type: 'object',
      properties: {
        repeat: {
          type: 'string',
          enum: ['off', 'track', 'playlist'],
          description: 'Repeat mode setting',
          example: 'playlist'
        }
      },
      required: ['repeat']
    }
  })
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