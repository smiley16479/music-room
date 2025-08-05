import { Controller, Post, Body, Get, Param } from '@nestjs/common';
import { MailService } from './mail.service';
import { ApiTags, ApiOperation, ApiParam, ApiBody } from '@nestjs/swagger';

@ApiTags('mail')
@Controller('mail')
export class MailController {
  constructor(private readonly mailService: MailService) {}

  @Post('test')
  @ApiOperation({ summary: 'Send a test email' })
  @ApiBody({
    schema: {
      type: 'object',
      properties: {
        email: { type: 'string', example: 'test@example.com' },
      },
    },
  })
  async sendTestEmail(@Body('email') email: string) {
    await this.mailService.sendTestEmail(email);
    return { message: 'Test email sent successfully' };
  }

  @Post('welcome')
  @ApiOperation({ summary: 'Send a welcome email' })
  @ApiBody({
    schema: {
      type: 'object',
      properties: {
        email: { type: 'string', example: 'user@example.com' },
        name: { type: 'string', example: 'John Doe' },
      },
    },
  })
  async sendWelcomeEmail(
    @Body('email') email: string,
    @Body('name') name: string,
  ) {
    await this.mailService.sendWelcomeEmail(email, name);
    return { message: 'Welcome email sent successfully' };
  }

  @Post('password-reset')
  @ApiOperation({ summary: 'Send a password reset email' })
  @ApiBody({
    schema: {
      type: 'object',
      properties: {
        email: { type: 'string', example: 'user@example.com' },
        name: { type: 'string', example: 'John Doe' },
        resetToken: { type: 'string', example: 'abc123def456' },
      },
    },
  })
  async sendPasswordResetEmail(
    @Body('email') email: string,
    @Body('name') name: string,
    @Body('resetToken') resetToken: string,
  ) {
    await this.mailService.sendPasswordResetEmail(email, name, resetToken);
    return { message: 'Password reset email sent successfully' };
  }

  @Post('playlist-invitation')
  @ApiOperation({ summary: 'Send a playlist invitation email' })
  @ApiBody({
    schema: {
      type: 'object',
      properties: {
        email: { type: 'string', example: 'friend@example.com' },
        senderName: { type: 'string', example: 'Jane Smith' },
        playlistName: { type: 'string', example: 'Summer Hits 2025' },
        inviteUrl: { type: 'string', example: 'https://music-room.com/invitations/123456' },
      },
    },
  })
  async sendPlaylistInvitation(
    @Body('email') email: string,
    @Body('senderName') senderName: string,
    @Body('playlistName') playlistName: string,
    @Body('inviteUrl') inviteUrl: string,
  ) {
    await this.mailService.sendPlaylistInvitation(
      email,
      senderName,
      playlistName,
      inviteUrl,
    );
    return { message: 'Playlist invitation email sent successfully' };
  }
}
