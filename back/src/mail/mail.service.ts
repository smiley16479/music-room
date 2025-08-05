import { Injectable } from '@nestjs/common';
import { MailerService } from '@nestjs-modules/mailer';

@Injectable()
export class MailService {
  constructor(private readonly mailerService: MailerService) {}

  /**
   * Send a welcome email to a new user
   * @param email The email of the user
   * @param name The name of the user
   */
  async sendWelcomeEmail(email: string, name: string): Promise<void> {
    await this.mailerService.sendMail({
      to: email,
      subject: 'Welcome to Music Room!',
      html: `
        <div style="font-family: Arial, sans-serif; max-width: 600px; margin: 0 auto;">
          <h1 style="color: #4A90E2;">Welcome to Music Room!</h1>
          <p>Hello ${name},</p>
          <p>Thank you for joining Music Room. We're excited to have you on board!</p>
          <p>With Music Room, you can:</p>
          <ul>
            <li>Create and share playlists</li>
            <li>Discover new music</li>
            <li>Connect with friends</li>
            <li>Enjoy music together</li>
          </ul>
          <p>If you have any questions, feel free to reach out to our support team.</p>
          <p>Enjoy your musical journey!</p>
          <p>Best regards,<br>The Music Room Team</p>
        </div>
      `,
    });
  }

  /**
   * Send an email for password reset
   * @param email The email of the user
   * @param name The name of the user
   * @param resetToken The reset token
   */
  async sendPasswordResetEmail(email: string, name: string, resetToken: string): Promise<void> {
    await this.mailerService.sendMail({
      to: email,
      subject: 'Password Reset Request',
      html: `
        <div style="font-family: Arial, sans-serif; max-width: 600px; margin: 0 auto;">
          <h1 style="color: #4A90E2;">Password Reset Request</h1>
          <p>Hello ${name},</p>
          <p>We received a request to reset your password. If you didn't make this request, please ignore this email.</p>
          <p>To reset your password, please click the button below:</p>
          <div style="text-align: center; margin: 30px 0;">
            <a href="https://your-app-url/reset-password?token=${resetToken}" 
              style="background-color: #4A90E2; color: white; padding: 12px 24px; text-decoration: none; border-radius: 4px; font-weight: bold;">
              Reset Password
            </a>
          </div>
          <p>If the button doesn't work, copy and paste this link into your browser:</p>
          <p>https://your-app-url/reset-password?token=${resetToken}</p>
          <p>This link will expire in 24 hours.</p>
          <p>Best regards,<br>The Music Room Team</p>
        </div>
      `,
    });
  }

  /**
   * Send a playlist invitation email
   * @param email The email of the recipient
   * @param senderName The name of the sender
   * @param playlistName The name of the playlist
   * @param inviteUrl The invitation URL
   */
  async sendPlaylistInvitation(
    email: string, 
    senderName: string, 
    playlistName: string, 
    inviteUrl: string
  ): Promise<void> {
    await this.mailerService.sendMail({
      to: email,
      subject: `${senderName} invited you to a playlist on Music Room`,
      html: `
        <div style="font-family: Arial, sans-serif; max-width: 600px; margin: 0 auto;">
          <h1 style="color: #4A90E2;">Playlist Invitation</h1>
          <p>Hello,</p>
          <p>${senderName} has invited you to collaborate on the playlist "${playlistName}" on Music Room.</p>
          <div style="text-align: center; margin: 30px 0;">
            <a href="${inviteUrl}" 
              style="background-color: #4A90E2; color: white; padding: 12px 24px; text-decoration: none; border-radius: 4px; font-weight: bold;">
              View Invitation
            </a>
          </div>
          <p>If the button doesn't work, copy and paste this link into your browser:</p>
          <p>${inviteUrl}</p>
          <p>Best regards,<br>The Music Room Team</p>
        </div>
      `,
    });
  }

  /**
   * Send a test email
   * @param to The recipient email
   */
  async sendTestEmail(to: string): Promise<void> {
    await this.mailerService.sendMail({
      to,
      subject: 'Test Email from Music Room',
      html: `
        <div style="font-family: Arial, sans-serif; max-width: 600px; margin: 0 auto;">
          <h1 style="color: #4A90E2;">Test Email</h1>
          <p>This is a test email from Music Room.</p>
          <p>If you're seeing this, it means the email system is working correctly!</p>
          <p>Best regards,<br>The Music Room Team</p>
        </div>
      `,
    });
  }
}
