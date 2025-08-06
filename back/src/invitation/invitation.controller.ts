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

@Controller('invitations')
@UseGuards(JwtAuthGuard)
export class InvitationController {
  constructor(private readonly invitationService: InvitationService) {}

  @Post()
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
  async findAll(@Query() paginationDto: PaginationDto, @CurrentUser() user: User) {
    return this.invitationService.findAll(paginationDto, user.id);
  }

  @Get('received')
  async getReceivedInvitations(
    @Query() paginationDto: PaginationDto,
    @Query('status') status: InvitationStatus,
    @Query('type') type: InvitationType,
    @CurrentUser() user: User,
  ) {
    return this.invitationService.getReceivedInvitations(user.id, status, type, paginationDto);
  }

  @Get('sent')
  async getSentInvitations(
    @Query() paginationDto: PaginationDto,
    @Query('status') status: InvitationStatus,
    @Query('type') type: InvitationType,
    @CurrentUser() user: User,
  ) {
    return this.invitationService.getSentInvitations(user.id, status, type, paginationDto);
  }

  @Get('pending')
  async getPendingInvitations(@CurrentUser() user: User) {
    return this.invitationService.getPendingInvitations(user.id);
  }

  @Get('stats')
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