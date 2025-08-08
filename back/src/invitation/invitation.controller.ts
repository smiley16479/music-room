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

import { InvitationService } from './invitation.service';
import { CreateInvitationDto } from './dto/create-invitation.dto';
import { RespondInvitationDto } from './dto/respond-invitation.dto';
import { PaginationDto } from '../common/dto/pagination.dto';

import { JwtAuthGuard } from '../auth/guards/jwt-auth.guard';
import { CurrentUser } from '../common/decorators/current-user.decorator';

import { User } from 'src/user/entities/user.entity';
import { InvitationStatus, InvitationType } from 'src/invitation/entities/invitation.entity';
import { ApiTags, ApiOperation, ApiBody, ApiParam, ApiQuery } from '@nestjs/swagger';

@ApiTags('Invitations')
@Controller('invitations')
@UseGuards(JwtAuthGuard)
export class InvitationController {
  constructor(private readonly invitationService: InvitationService) {}

  @Post()
  @ApiOperation({
    summary: 'Create invitation',
    description: 'Sends a new invitation to a user for an event, playlist, or friendship',
  })
  @ApiBody({ type: CreateInvitationDto })
  async create(@Body() createInvitationDto: CreateInvitationDto, @CurrentUser() user: User) {
    const invitation = await this.invitationService.create(createInvitationDto, user.id);
    return {
      success: true,
      message: 'Invitation sent successfully',
      data: invitation,
      timestamp: new Date().toISOString(),
    };
  }

  @Get()
  @ApiOperation({
    summary: 'Get all invitations',
    description: 'Returns a paginated list of all invitations related to the current user',
  })
  @ApiQuery({ type: PaginationDto })
  async findAll(@Query() paginationDto: PaginationDto, @CurrentUser() user: User) {
    return this.invitationService.findAll(paginationDto, user.id);
  }

  @Get('received')
  @ApiOperation({
    summary: 'Get received invitations',
    description: 'Returns invitations received by the current user, with optional filtering by status and type',
  })
  @ApiQuery({ type: PaginationDto })
  @ApiQuery({ 
    name: 'status', 
    enum: InvitationStatus,
    required: false,
    description: 'Filter by invitation status'
  })
  @ApiQuery({ 
    name: 'type', 
    enum: InvitationType,
    required: false,
    description: 'Filter by invitation type'
  })
  async getReceivedInvitations(
    @Query() paginationDto: PaginationDto,
    @Query('status') status: InvitationStatus,
    @Query('type') type: InvitationType,
    @CurrentUser() user: User,
  ) {
    return this.invitationService.getReceivedInvitations(user.id, status, type, paginationDto);
  }

  @Get('sent')
  @ApiOperation({
    summary: 'Get sent invitations',
    description: 'Returns invitations sent by the current user, with optional filtering by status and type',
  })
  @ApiQuery({ type: PaginationDto })
  @ApiQuery({ 
    name: 'status', 
    enum: InvitationStatus,
    required: false,
    description: 'Filter by invitation status'
  })
  @ApiQuery({ 
    name: 'type', 
    enum: InvitationType,
    required: false,
    description: 'Filter by invitation type'
  })
  async getSentInvitations(
    @Query() paginationDto: PaginationDto,
    @Query('status') status: InvitationStatus,
    @Query('type') type: InvitationType,
    @CurrentUser() user: User,
  ) {
    return this.invitationService.getSentInvitations(user.id, status, type, paginationDto);
  }

  @Get('pending')
  @ApiOperation({
    summary: 'Get pending invitations',
    description: 'Returns all pending invitations for the current user',
  })
  async getPendingInvitations(@CurrentUser() user: User) {
    return this.invitationService.getPendingInvitations(user.id);
  }

  @Get('stats')
  @ApiOperation({
    summary: 'Get invitation stats',
    description: 'Returns statistics about invitations sent and received in a specific timeframe',
  })
  @ApiQuery({ 
    name: 'timeframe', 
    enum: ['week', 'month', 'year'],
    description: 'Time period for statistics',
    example: 'month'
  })
  async getStats(
    @Query('timeframe') timeframe: 'week' | 'month' | 'year',
    @CurrentUser() user: User,
  ) {
    const stats = await this.invitationService.getInvitationStats(user.id, timeframe);
    return {
      success: true,
      data: stats,
      timestamp: new Date().toISOString(),
    };
  }

  @Get(':id')
  @ApiOperation({
    summary: 'Get invitation by ID',
    description: 'Returns detailed information about a specific invitation',
  })
  @ApiParam({
    name: 'id',
    type: String,
    description: 'The ID of the invitation to retrieve',
    required: true
  })
  async findOne(@Param('id') id: string, @CurrentUser() user: User) {
    const invitation = await this.invitationService.findById(id, user.id);
    return {
      success: true,
      data: invitation,
      timestamp: new Date().toISOString(),
    };
  }

  // Invitation Actions
  @Patch(':id/respond')
  @HttpCode(HttpStatus.OK)
  @ApiOperation({
    summary: 'Respond to invitation',
    description: 'Accepts or declines an invitation',
  })
  @ApiParam({
    name: 'id',
    type: String,
    description: 'The ID of the invitation to respond to',
    required: true
  })
  @ApiBody({ type: RespondInvitationDto })
  async respond(
    @Param('id') id: string,
    @Body() respondDto: RespondInvitationDto,
    @CurrentUser() user: User,
  ) {
    const invitation = await this.invitationService.respond(id, user.id, respondDto);
    const message = respondDto.status === InvitationStatus.ACCEPTED 
      ? 'Invitation accepted successfully' 
      : 'Invitation declined successfully';

    return {
      success: true,
      message,
      data: invitation,
      timestamp: new Date().toISOString(),
    };
  }

  @Delete(':id/cancel')
  @ApiOperation({
    summary: 'Cancel invitation',
    description: 'Cancels an invitation that was previously sent',
  })
  @ApiParam({
    name: 'id',
    type: String,
    description: 'The ID of the invitation to cancel',
    required: true
  })
  async cancel(@Param('id') id: string, @CurrentUser() user: User) {
    await this.invitationService.cancel(id, user.id);
    return {
      success: true,
      message: 'Invitation cancelled successfully',
      timestamp: new Date().toISOString(),
    };
  }

  @Post(':id/resend')
  @HttpCode(HttpStatus.OK)
  @ApiOperation({
    summary: 'Resend invitation',
    description: 'Resends an invitation email to the recipient',
  })
  @ApiParam({
    name: 'id',
    type: String,
    description: 'The ID of the invitation to resend',
    required: true
  })
  async resend(@Param('id') id: string, @CurrentUser() user: User) {
    const invitation = await this.invitationService.resend(id, user.id);
    return {
      success: true,
      message: 'Invitation resent successfully',
      data: invitation,
      timestamp: new Date().toISOString(),
    };
  }

  // Batch Operations
  @Post('bulk-invite')
  @HttpCode(HttpStatus.OK)
  @ApiOperation({
    summary: 'Send bulk invitations',
    description: 'Sends invitations to multiple email addresses at once',
  })
  @ApiBody({
    schema: {
      type: 'object',
      properties: {
        emails: {
          type: 'array',
          items: { type: 'string' },
          description: 'Array of email addresses to invite',
          example: ['user1@example.com', 'user2@example.com']
        },
        type: {
          enum: Object.values(InvitationType),
          description: 'Type of invitation to send'
        },
        resourceId: {
          type: 'string',
          description: 'ID of the resource (playlist, event, etc.) being invited to'
        },
        message: {
          type: 'string',
          description: 'Optional custom message to include in invitation'
        }
      },
      required: ['emails', 'type']
    }
  })
  async bulkInvite(
    @Body() {
      emails,
      type,
      resourceId,
      message
    }: {
      emails: string[];
      type: InvitationType;
      resourceId?: string;
      message?: string;
    },
    @CurrentUser() user: User,
  ) {
    const result = await this.invitationService.inviteMultipleUsers(
      user.id,
      emails,
      type,
      resourceId,
      message
    );

    return {
      success: true,
      message: `Sent ${result.successful.length} invitations, ${result.failed.length} failed`,
      data: {
        successful: result.successful,
        failed: result.failed,
        summary: {
          sent: result.successful.length,
          failed: result.failed.length,
          total: emails.length,
        },
      },
      timestamp: new Date().toISOString(),
    };
  }

  @Post('accept-all')
  @HttpCode(HttpStatus.OK)
  @ApiOperation({
    summary: 'Accept all pending invitations',
    description: 'Accepts all pending invitations, optionally filtered by type',
  })
  @ApiBody({
    schema: {
      type: 'object',
      properties: {
        type: {
          enum: Object.values(InvitationType),
          description: 'Optional filter to accept only invitations of this type'
        }
      }
    }
  })
  async acceptAllPending(
    @Body() { type }: { type?: InvitationType },
    @CurrentUser() user: User,
  ) {
    const acceptedCount = await this.invitationService.acceptAllPendingInvitations(user.id, type);
    return {
      success: true,
      message: `Accepted ${acceptedCount} pending invitations`,
      data: { acceptedCount },
      timestamp: new Date().toISOString(),
    };
  }

  // Quick Actions
  @Post(':id/accept')
  @HttpCode(HttpStatus.OK)
  @ApiOperation({
    summary: 'Accept invitation',
    description: 'Quick action to accept a specific invitation',
  })
  @ApiParam({
    name: 'id',
    type: String,
    description: 'The ID of the invitation to accept',
    required: true
  })
  async accept(@Param('id') id: string, @CurrentUser() user: User) {
    const invitation = await this.invitationService.respond(
      id, 
      user.id, 
      { status: InvitationStatus.ACCEPTED }
    );
    return {
      success: true,
      message: 'Invitation accepted successfully',
      data: invitation,
      timestamp: new Date().toISOString(),
    };
  }

  @Post(':id/decline')
  @HttpCode(HttpStatus.OK)
  @ApiOperation({
    summary: 'Decline invitation',
    description: 'Quick action to decline a specific invitation',
  })
  @ApiParam({
    name: 'id',
    type: String,
    description: 'The ID of the invitation to decline',
    required: true
  })
  async decline(@Param('id') id: string, @CurrentUser() user: User) {
    const invitation = await this.invitationService.respond(
      id, 
      user.id, 
      { status: InvitationStatus.DECLINED }
    );
    return {
      success: true,
      message: 'Invitation declined successfully',
      data: invitation,
      timestamp: new Date().toISOString(),
    };
  }
}