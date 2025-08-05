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
import { CurrentUser } from '../common/decorators/current-user.decorator';
import { User } from 'src/user/entities/user.entity';

interface SendTestEmailDto {
  to: string;
  subject: string;
  message: string;
}

@Controller('email')
@UseGuards(JwtAuthGuard)
export class EmailController {
  constructor(private readonly emailService: EmailService) {}

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
}