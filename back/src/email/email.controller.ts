import {
  Controller,
  Post,
  Body,
  UseGuards,
  HttpCode,
  HttpStatus,
} from '@nestjs/common';
import { EmailService } from './email.service';
import { JwtAuthGuard } from '../auth/guards/jwt-auth.guard';
// import { CurrentUser } from '../common/decorators/current-user.decorator';
// import { User } from 'src/user/entities/user.entity';
import { ApiTags, ApiOperation, ApiParam, ApiBody } from '@nestjs/swagger';

@Controller('email')
@UseGuards(JwtAuthGuard)
export class EmailController {
  constructor(private readonly emailService: EmailService) {}

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
    await this.emailService.sendWelcomeEmail(email, name);
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
    @Body('resetToken') resetToken: string,
  ) {
    await this.emailService.sendPasswordResetEmail(email, resetToken);
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
    @Body('playlistName') playlistName: string,
    @Body('inviterName') inviterName: string,
    @Body('playlistUrl') playlistUrl: string,
  ) {
    await this.emailService.sendPlaylistInvitation(
      email,
      playlistName,
      inviterName,
      playlistUrl,
    );
    return { message: 'Playlist invitation email sent successfully' };
  }

/*
  @Post('test')
  @HttpCode(HttpStatus.OK)
  async sendTestEmail(
    @Body() dto: SendTestEmailDto,
    @CurrentUser() user: User,
  ) {
    // Only allow admins to send test emails in production
    await this.emailService.sendEmail({
      to: dto.to,
      subject: `[TEST] ${dto.subject}`,
      html: `
        <div style="font-family: Arial, sans-serif; padding: 20px;">
          <h2>Test Email from Music Room</h2>
          <p><strong>Sent by:</strong> ${user.email}</p>
          <p><strong>Message:</strong></p>
          <div style="background-color: #f5f5f5; padding: 15px; border-radius: 5px;">
            ${dto.message}
          </div>
        </div>
      `,
      text: `Test Email from Music Room\nSent by: ${user.email}\nMessage: ${dto.message}`,
    });

    return {
      success: true,
      message: 'Test email sent successfully',
      timestamp: new Date().toISOString(),
    };
  }

  @Post('resend-welcome')
  @HttpCode(HttpStatus.OK)
  async resendWelcomeEmail(@CurrentUser() user: User) {
    if (!user.emailVerified) {
      return {
        success: false,
        message: 'Email must be verified first',
        timestamp: new Date().toISOString(),
      };
    }

    await this.emailService.sendWelcomeEmail(user.email, user.displayName || 'User');

    return {
      success: true,
      message: 'Welcome email sent successfully',
      timestamp: new Date().toISOString(),
    };
  }
    */
}