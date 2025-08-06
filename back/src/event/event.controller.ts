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
} from '@nestjs/common';

import { EventService } from './event.service';
import { CreateEventDto } from './dto/create-event.dto';
import { UpdateEventDto } from './dto/update-event.dto';
import { CreateVoteDto } from './dto/vote.dto';
import { PaginationDto } from '../common/dto/pagination.dto';
import { LocationDto } from '../common/dto/location.dto';

import { JwtAuthGuard } from '../auth/guards/jwt-auth.guard';
import { CurrentUser } from '../common/decorators/current-user.decorator';
import { Public } from '../auth/decorators/public.decorator';

import { User } from 'src/user/entities/user.entity';

@Controller('event')
@UseGuards(JwtAuthGuard)
export class EventController {
  constructor(private readonly eventService: EventService) {}

  @Post()
  async create(@Body() createEventDto: CreateEventDto, @CurrentUser() user: User) {
    const event = await this.eventService.create(createEventDto, user.id);
    return {
      success: true,
      message: 'Event created successfully',
      data: event,
      timestamp: new Date().toISOString(),
    };
  }

  @Get()
  @Public()
  async findAll(@Query() paginationDto: PaginationDto, @CurrentUser() user?: User) {
    return this.eventService.findAll(paginationDto, user?.id);
  }

  @Get('nearby')
  @Public()
  async findNearby(
    @Query() locationDto: LocationDto,
    @Query('radius') radius: string = '10',
    @CurrentUser() user?: User,
  ) {
    const radiusKm = parseInt(radius, 10);
    return this.eventService.findNearbyEvents(locationDto, radiusKm, user?.id);
  }

  @Get('my-event')
  async getMyEvent(@Query() paginationDto: PaginationDto, @CurrentUser() user: User) {
    const { page, limit, skip } = paginationDto;
    
    // This would be a separate method in the service for user's event
    return {
      success: true,
      message: 'User event retrieved successfully',
      timestamp: new Date().toISOString(),
    };
  }

  @Get(':id')
  @Public()
  async findOne(@Param('id') id: string, @CurrentUser() user?: User) {
    const event = await this.eventService.findById(id, user?.id);
    return {
      success: true,
      data: event,
      timestamp: new Date().toISOString(),
    };
  }

  @Get(':id/voting-results')
  @Public()
  async getVotingResults(@Param('id') id: string, @CurrentUser() user?: User) {
    const results = await this.eventService.getVotingResults(id, user?.id);
    return {
      success: true,
      data: results,
      timestamp: new Date().toISOString(),
    };
  }

  @Patch(':id')
  async update(
    @Param('id') id: string,
    @Body() updateEventDto: UpdateEventDto,
    @CurrentUser() user: User,
  ) {
    const event = await this.eventService.update(id, updateEventDto, user.id);
    return {
      success: true,
      message: 'Event updated successfully',
      data: event,
      timestamp: new Date().toISOString(),
    };
  }

  @Delete(':id')
  async remove(@Param('id') id: string, @CurrentUser() user: User) {
    await this.eventService.remove(id, user.id);
    return {
      success: true,
      message: 'Event deleted successfully',
      timestamp: new Date().toISOString(),
    };
  }

  // Participant Management
  @Post(':id/join')
  @HttpCode(HttpStatus.OK)
  async joinEvent(@Param('id') id: string, @CurrentUser() user: User) {
    await this.eventService.addParticipant(id, user.id);
    return {
      success: true,
      message: 'Successfully joined the event',
      timestamp: new Date().toISOString(),
    };
  }

  @Post(':id/leave')
  @HttpCode(HttpStatus.OK)
  async leaveEvent(@Param('id') id: string, @CurrentUser() user: User) {
    await this.eventService.removeParticipant(id, user.id);
    return {
      success: true,
      message: 'Successfully left the event',
      timestamp: new Date().toISOString(),
    };
  }

  // Voting
  @Post(':id/vote')
  @HttpCode(HttpStatus.OK)
  async vote(
    @Param('id') id: string,
    @Body() voteDto: CreateVoteDto,
    @CurrentUser() user: User,
  ) {
    const results = await this.eventService.voteForTrack(id, user.id, voteDto);
    return {
      success: true,
      message: 'Vote submitted successfully',
      data: results,
      timestamp: new Date().toISOString(),
    };
  }

  @Delete(':id/vote/:trackId')
  async removeVote(
    @Param('id') id: string,
    @Param('trackId') trackId: string,
    @CurrentUser() user: User,
  ) {
    const results = await this.eventService.removeVote(id, user.id, trackId);
    return {
      success: true,
      message: 'Vote removed successfully',
      data: results,
      timestamp: new Date().toISOString(),
    };
  }

  // Event Control
  @Post(':id/start')
  @HttpCode(HttpStatus.OK)
  async startEvent(@Param('id') id: string, @CurrentUser() user: User) {
    const event = await this.eventService.startEvent(id, user.id);
    return {
      success: true,
      message: 'Event started successfully',
      data: event,
      timestamp: new Date().toISOString(),
    };
  }

  @Post(':id/end')
  @HttpCode(HttpStatus.OK)
  async endEvent(@Param('id') id: string, @CurrentUser() user: User) {
    const event = await this.eventService.endEvent(id, user.id);
    return {
      success: true,
      message: 'Event ended successfully',
      data: event,
      timestamp: new Date().toISOString(),
    };
  }

  @Post(':id/next-track')
  @HttpCode(HttpStatus.OK)
  async playNextTrack(@Param('id') id: string, @CurrentUser() user: User) {
    const track = await this.eventService.playNextTrack(id, user.id);
    return {
      success: true,
      message: track ? 'Next track playing' : 'No tracks available',
      data: { track },
      timestamp: new Date().toISOString(),
    };
  }

  // Location-based features
  @Post(':id/check-location')
  @HttpCode(HttpStatus.OK)
  async checkLocationPermission(
    @Param('id') id: string,
    @Body() locationDto: LocationDto,
  ) {
    const hasPermission = await this.eventService.checkLocationPermission(id, locationDto);
    return {
      success: true,
      data: { hasPermission },
      timestamp: new Date().toISOString(),
    };
  }

  // Invitations
  @Post(':id/invite')
  @HttpCode(HttpStatus.OK)
  async inviteUsers(
    @Param('id') id: string,
    @Body() { emails }: { emails: string[] },
    @CurrentUser() user: User,
  ) {
    await this.eventService.inviteUsers(id, user.id, emails);
    return {
      success: true,
      message: 'Invitations sent successfully',
      timestamp: new Date().toISOString(),
    };
  }
}