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
import { ApiTags, ApiOperation, ApiBody, ApiParam, ApiQuery } from '@nestjs/swagger';
import { log } from 'console';

@ApiTags('Events')
@Controller('events')
@UseGuards(JwtAuthGuard)
export class EventController {
  constructor(private readonly eventService: EventService) {}

  @Post()
  @ApiOperation({
    summary: 'Create an event',
    description: 'Creates a new music event with settings for voting, location, and participants',
  })
  @ApiBody({ type: CreateEventDto })
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
  @ApiOperation({
    summary: 'Get all events',
    description: 'Returns a paginated list of all accessible events',
  })
  @ApiQuery({ type: PaginationDto })
  async findAll(@Query() paginationDto: PaginationDto, @CurrentUser() user?: User) {
    return this.eventService.findAll(paginationDto, user?.id);
  }

  @Get('nearby')
  @Public()
  @ApiOperation({
    summary: 'Find nearby events',
    description: 'Returns events within a specified radius of a location',
  })
  @ApiQuery({ type: LocationDto })
  @ApiQuery({ 
    name: 'radius', 
    type: String, 
    description: 'Radius in kilometers to search for events',
    required: false,
    example: '10'
  })
  async findNearby(
    @Query() locationDto: LocationDto,
    @Query('radius') radius: string = '10',
    @CurrentUser() user?: User,
  ) {
    const radiusKm = parseInt(radius, 10);
    return this.eventService.findNearbyEvents(locationDto, radiusKm, user?.id);
  }

  @Get('my-event')
  @ApiOperation({
    summary: 'Get user events',
    description: 'Returns events created by or participated in by the current user',
  })
  @ApiQuery({ type: PaginationDto })
  async getMyEvent(@Query() paginationDto: PaginationDto, @CurrentUser() user: User) {
    const { page, limit, skip } = paginationDto;
    // Récupère les events avec les admins
    const events = await this.eventService.getEventsUserCanInviteWithAdmins(user.id);
    
    return {
      success: true,
      message: 'User event retrieved successfully',
      timestamp: new Date().toISOString(),
      data: events
    };
  }

  @Get(':id')
  @Public()
  @ApiOperation({
    summary: 'Get event by ID',
    description: 'Returns detailed information about a specific event',
  })
  @ApiParam({
    name: 'id',
    type: String,
    description: 'The ID of the event to retrieve',
    required: true
  })
  async findOne(@Param('id') id: string, @CurrentUser() user?: User) {
    const event = await this.eventService.findById(id, user?.id);
    return {
      success: true,
      data: event,
      timestamp: new Date().toISOString(),
    };
  }

  @Get(':id/voting-results')
  @ApiOperation({
    summary: 'Get voting results',
    description: 'Returns the current voting results for tracks in an event',
  })
  @ApiParam({
    name: 'id',
    type: String,
    description: 'The ID of the event to get voting results for',
    required: true
  })
  async getVotingResults(@Param('id') id: string, @CurrentUser() user?: User) {
    const results = await this.eventService.getVotingResults(id, user?.id);
    return {
      success: true,
      data: results,
      timestamp: new Date().toISOString(),
    };
  }

  @Get(':id/results')
  @ApiOperation({
    summary: 'Get voting results (alias)',
    description: 'Returns the current voting results for tracks in an event (alias for voting-results)',
  })
  @ApiParam({
    name: 'id',
    type: String,
    description: 'The ID of the event to get voting results for',
    required: true
  })
  async getResults(@Param('id') id: string, @CurrentUser() user?: User) {
    // This is an alias for getVotingResults
    const results = await this.eventService.getVotingResults(id, user?.id);
    return {
      success: true,
      data: results,
      timestamp: new Date().toISOString(),
    };
  }

  @Patch(':id')
  @ApiOperation({
    summary: 'Update event',
    description: 'Updates an event\'s information and settings',
  })
  @ApiParam({
    name: 'id',
    type: String,
    description: 'The ID of the event to update',
    required: true
  })
  @ApiBody({ type: UpdateEventDto })
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
  @ApiOperation({
    summary: 'Delete event',
    description: 'Permanently deletes an event and all its data',
  })
  @ApiParam({
    name: 'id',
    type: String,
    description: 'The ID of the event to delete',
    required: true
  })
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
  @ApiOperation({
    summary: 'Join event',
    description: 'Adds the current user as a participant to the event',
  })
  @ApiParam({
    name: 'id',
    type: String,
    description: 'The ID of the event to join',
    required: true
  })
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
  @ApiOperation({
    summary: 'Leave event',
    description: 'Removes the current user as a participant from the event',
  })
  @ApiParam({
    name: 'id',
    type: String,
    description: 'The ID of the event to leave',
    required: true
  })
  async leaveEvent(@Param('id') id: string, @CurrentUser() user: User) {
    await this.eventService.removeParticipant(id, user.id);
    return {
      success: true,
      message: 'Successfully left the event',
      timestamp: new Date().toISOString(),
    };
  }

  @Post(':id/admins/:userId')
  @ApiOperation({
    summary: 'Promote user to admin',
    description: 'Adds a user as admin to the event (creator or admin only)',
  })
  @ApiParam({
    name: 'id',
    type: String,
    description: 'The ID of the event',
    required: true
  })
  @ApiParam({
    name: 'userId',
    type: String,
    description: 'The ID of the user to promote',
    required: true
  })
  async promoteAdmin(
    @Param('id') eventId: string,
    @Param('userId') userId: string,
    @CurrentUser() user: User,
  ) {
    await this.eventService.promoteAdmin(eventId, user.id, userId);
    
    // Return updated event data with new admin list
    const updatedEvent = await this.eventService.findById(eventId, user.id);
    
    return {
      success: true,
      message: 'User promoted to admin',
      data: updatedEvent,
      timestamp: new Date().toISOString(),
    };
  }

  @Post(':id/participant/:userId')
  @ApiOperation({
    summary: 'Add participant to event',
    description: 'Allows an event admin to add a specific user as participant to the event',
  })
  @ApiParam({
    name: 'id',
    type: String,
    description: 'The ID of the event',
    required: true
  })
  @ApiParam({
    name: 'userId',
    type: String,
    description: 'The ID of the user to add as participant',
    required: true
  })
  async addParticipantByAdmin(
    @Param('id') eventId: string,
    @Param('userId') userId: string,
    @CurrentUser() admin: User,
  ) {
    await this.eventService.addParticipant(eventId, userId);
    
    // Return updated event data with new participant list
    const updatedEvent = await this.eventService.findById(eventId, admin.id);
    
    return {
      success: true,
      message: 'Participant added successfully',
      data: updatedEvent,
      timestamp: new Date().toISOString(),
    };
  }

  @Delete(':id/participant/:userId')
  @ApiOperation({
    summary: 'Remove participant from event',
    description: 'Allows an event admin to remove a participant from the event',
  })
  @ApiParam({
    name: 'id',
    type: String,
    description: 'The ID of the event',
    required: true
  })
  @ApiParam({
    name: 'userId',
    type: String,
    description: 'The ID of the user to remove',
    required: true
  })
  async removeParticipantByAdmin(
    @Param('id') eventId: string,
    @Param('userId') userId: string,
    @CurrentUser() admin: User,
  ) {
    await this.eventService.removeParticipant(eventId, userId);
    
    // Return updated event data with updated participant list
    const updatedEvent = await this.eventService.findById(eventId, admin.id);
    
    return {
      success: true,
      message: 'Participant removed successfully',
      data: updatedEvent,
      timestamp: new Date().toISOString(),
    };
  }

  @Delete(':id/admins/:userId')
  @ApiOperation({
    summary: 'Remove admin from event',
    description: 'Removes a user from the admins of the event (creator or admin only)',
  })
  @ApiParam({
    name: 'id',
    type: String,
    description: 'The ID of the event',
    required: true
  })
  @ApiParam({
    name: 'userId',
    type: String,
    description: 'The ID of the admin to remove',
    required: true
  })
  async removeAdmin(
    @Param('id') eventId: string,
    @Param('userId') userId: string,
    @CurrentUser() user: User,
  ) {
    await this.eventService.removeAdmin(eventId, user.id, userId);
    
    // Return updated event data with updated admin list
    const updatedEvent = await this.eventService.findById(eventId, user.id);
    
    return {
      success: true,
      message: 'Admin removed from event',
      data: updatedEvent,
      timestamp: new Date().toISOString(),
    };
  }

  // Voting
  @Post(':id/vote')
  @HttpCode(HttpStatus.OK)
  @ApiOperation({
    summary: 'Vote for track',
    description: 'Submits a vote for a track in the event',
  })
  @ApiParam({
    name: 'id',
    type: String,
    description: 'The ID of the event',
    required: true
  })
  @ApiBody({ type: CreateVoteDto })
  async vote(
    @Param('id') id: string,
    @Body() voteDto: CreateVoteDto,
    @CurrentUser() user: User,
  ) {
    const results = await this.eventService.voteForTrack(id, user.id, voteDto);
    return {
      success: true,
      message: 'Vote submitted successfully',
      data: [],
      timestamp: new Date().toISOString(),
    };
  }

  @Delete(':id/vote/:trackId')
  @HttpCode(HttpStatus.OK)
  @ApiOperation({
    summary: 'Remove vote',
    description: 'Removes the user\'s vote for a specific track in the event',
  })
  @ApiParam({
    name: 'id',
    type: String,
    description: 'The ID of the event',
    required: true
  })
  @ApiParam({
    name: 'trackId',
    type: String,
    description: 'The ID of the track to remove vote from',
    required: true
  })
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

  @Delete(':id/votes/:trackId')
  @HttpCode(HttpStatus.OK)
  @ApiOperation({
    summary: 'Remove all votes for track',
    description: 'Removes all votes for a specific track in the event (admin only)',
  })
  @ApiParam({
    name: 'id',
    type: String,
    description: 'The ID of the event',
    required: true
  })
  @ApiParam({
    name: 'trackId',
    type: String,
    description: 'The ID of the track to remove all votes from',
    required: true
  })
  async removeVotesOfTrack(
    @Param('id') id: string,
    @Param('trackId') trackId: string,
    @CurrentUser() user: User,
  ) {
    await this.eventService.removeVotesOfTrack(id, trackId);
    return {
      success: true,
      message: 'All votes for track removed successfully',
      timestamp: new Date().toISOString(),
    };
  }

  // Event Control
  @Post(':id/start')
  @HttpCode(HttpStatus.OK)
  @ApiOperation({
    summary: 'Start event',
    description: 'Starts the event and begins music playback (event owner only)',
  })
  @ApiParam({
    name: 'id',
    type: String,
    description: 'The ID of the event to start',
    required: true
  })
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
  @ApiOperation({
    summary: 'End event',
    description: 'Ends the event and stops music playback (event owner only)',
  })
  @ApiParam({
    name: 'id',
    type: String,
    description: 'The ID of the event to end',
    required: true
  })
  async endEvent(@Param('id') id: string, @CurrentUser() user: User) {
    const event = await this.eventService.endEvent(id, user.id);
    return {
      success: true,
      message: 'Event ended successfully',
      data: event,
      timestamp: new Date().toISOString(),
    };
  }

/*   @Post(':id/next-track')
  @HttpCode(HttpStatus.OK)
  @ApiOperation({
    summary: 'Play next track',
    description: 'Skips to the next track in the event queue based on voting results',
  })
  @ApiParam({
    name: 'id',
    type: String,
    description: 'The ID of the event',
    required: true
  })
  async playNextTrack(@Param('id') id: string, @CurrentUser() user: User) {
    const track = await this.eventService.playNextTrack(id, user.id);
    return {
      success: true,
      message: track ? 'Next track playing' : 'No tracks available',
      data: { track },
      timestamp: new Date().toISOString(),
    };
  } */

  // Location-based features
  @Post(':id/check-location')
  @HttpCode(HttpStatus.OK)
  @ApiOperation({
    summary: 'Check location permission',
    description: 'Verifies if a user\'s location allows them to participate in the event',
  })
  @ApiParam({
    name: 'id',
    type: String,
    description: 'The ID of the event',
    required: true
  })
  @ApiBody({ type: LocationDto })
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
  @ApiOperation({
    summary: 'Invite users to event',
    description: 'Sends email invitations to multiple users to join the event',
  })
  @ApiParam({
    name: 'id',
    type: String,
    description: 'The ID of the event',
    required: true
  })
  @ApiBody({
    schema: {
      type: 'object',
      properties: {
        emails: {
          type: 'array',
          items: { type: 'string' },
          description: 'Array of email addresses to invite',
          example: ['friend1@example.com', 'friend2@example.com']
        }
      },
      required: ['emails']
    }
  })
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