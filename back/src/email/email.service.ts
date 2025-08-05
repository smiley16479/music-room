import { Injectable, Logger } from '@nestjs/common';
import { ConfigService } from '@nestjs/config';
import * as nodemailer from 'nodemailer';
import { SendMailOptions } from 'nodemailer';

export interface EmailTemplate {
  subject: string;
  html: string;
  text?: string;
}

@Injectable()
export class EmailService {
  private readonly logger = new Logger(EmailService.name);
  private transporter: nodemailer.Transporter;

  constructor(private readonly configService: ConfigService) {
    this.createTransporter();
  }

  private createTransporter() {
    const smtpConfig = {
      host: this.configService.get<string>('SMTP_HOST'),
      port: this.configService.get<number>('SMTP_PORT', 587),
      secure: this.configService.get<boolean>('SMTP_SECURE', false),
      auth: {
        user: this.configService.get<string>('SMTP_USER'),
        pass: this.configService.get<string>('SMTP_PASS'),
      },
    };

    this.transporter = nodemailer.createTransport(smtpConfig);

    // Verify connection configuration
    this.transporter.verify((error, success) => {
      if (error) {
        this.logger.error('SMTP connection failed:', error);
      } else {
        this.logger.log('SMTP server is ready to send emails');
      }
    });
  }

  async sendEmail(options: SendMailOptions): Promise<void> {
    try {
      const defaultOptions = {
        from: this.configService.get<string>('SMTP_FROM', this.configService.get<string>('SMTP_USER') || "COUCOU C NOUS"),
      };

      const mailOptions = { ...defaultOptions, ...options };
      
      const result = await this.transporter.sendMail(mailOptions);
      this.logger.log(`Email sent successfully to ${options.to}: ${result.messageId}`);
    } catch (error) {
      this.logger.error(`Failed to send email to ${options.to}:`, error);
      throw error;
    }
  }

  async sendEmailVerification(email: string, token: string): Promise<void> {
    const frontendUrl = this.configService.get<string>('FRONTEND_URL');
    const verificationUrl = `${frontendUrl}/auth/verify-email?token=${token}`;

    const template = this.getEmailVerificationTemplate(verificationUrl);

    await this.sendEmail({
      to: email,
      subject: template.subject,
      html: template.html,
      text: template.text,
    });
  }

  async sendPasswordResetEmail(email: string, token: string): Promise<void> {
    const frontendUrl = this.configService.get<string>('FRONTEND_URL');
    const resetUrl = `${frontendUrl}/auth/reset-password?token=${token}`;

    const template = this.getPasswordResetTemplate(resetUrl);

    await this.sendEmail({
      to: email,
      subject: template.subject,
      html: template.html,
      text: template.text,
    });
  }

  async sendPasswordResetConfirmation(email: string): Promise<void> {
    const template = this.getPasswordResetConfirmationTemplate();

    await this.sendEmail({
      to: email,
      subject: template.subject,
      html: template.html,
      text: template.text,
    });
  }

  async sendWelcomeEmail(email: string, displayName: string): Promise<void> {
    const template = this.getWelcomeTemplate(displayName);

    await this.sendEmail({
      to: email,
      subject: template.subject,
      html: template.html,
      text: template.text,
    });
  }

  async sendEventInvitation(
    email: string,
    eventName: string,
    inviterName: string,
    eventUrl: string,
  ): Promise<void> {
    const template = this.getEventInvitationTemplate(eventName, inviterName, eventUrl);

    await this.sendEmail({
      to: email,
      subject: template.subject,
      html: template.html,
      text: template.text,
    });
  }

  async sendPlaylistInvitation(
    email: string,
    playlistName: string,
    inviterName: string,
    playlistUrl: string,
  ): Promise<void> {
    const template = this.getPlaylistInvitationTemplate(playlistName, inviterName, playlistUrl);

    await this.sendEmail({
      to: email,
      subject: template.subject,
      html: template.html,
      text: template.text,
    });
  }

  async sendFriendRequest(
    email: string,
    requesterName: string,
    profileUrl: string,
  ): Promise<void> {
    const template = this.getFriendRequestTemplate(requesterName, profileUrl);

    await this.sendEmail({
      to: email,
      subject: template.subject,
      html: template.html,
      text: template.text,
    });
  }

  // Email Templates
  private getEmailVerificationTemplate(verificationUrl: string): EmailTemplate {
    return {
      subject: 'Verify your Music Room account',
      html: `
        <div style="font-family: Arial, sans-serif; max-width: 600px; margin: 0 auto; padding: 20px;">
          <div style="text-align: center; margin-bottom: 30px;">
            <h1 style="color: #1DB954; margin: 0;">🎵 Music Room</h1>
          </div>
          
          <h2 style="color: #333; text-align: center;">Welcome to Music Room!</h2>
          
          <p style="color: #666; font-size: 16px; line-height: 1.5;">
            Thank you for signing up! Please verify your email address by clicking the button below:
          </p>
          
          <div style="text-align: center; margin: 30px 0;">
            <a href="${verificationUrl}" 
               style="background-color: #1DB954; color: white; padding: 15px 30px; text-decoration: none; border-radius: 25px; display: inline-block; font-weight: bold; font-size: 16px;">
              Verify Email Address
            </a>
          </div>
          
          <p style="color: #999; font-size: 14px; margin-top: 30px;">
            If the button doesn't work, copy and paste this link into your browser:<br>
            <a href="${verificationUrl}" style="color: #1DB954;">${verificationUrl}</a>
          </p>
          
          <p style="color: #999; font-size: 14px;">
            This link will expire in 24 hours. If you didn't create this account, please ignore this email.
          </p>
          
          <div style="text-align: center; margin-top: 40px; padding-top: 20px; border-top: 1px solid #eee;">
            <p style="color: #999; font-size: 12px;">
              © 2024 Music Room. All rights reserved.
            </p>
          </div>
        </div>
      `,
      text: `
        Welcome to Music Room!
        
        Please verify your email address by clicking on this link:
        ${verificationUrl}
        
        This link will expire in 24 hours.
        
        If you didn't create this account, please ignore this email.
      `,
    };
  }

  private getPasswordResetTemplate(resetUrl: string): EmailTemplate {
    return {
      subject: 'Reset your Music Room password',
      html: `
        <div style="font-family: Arial, sans-serif; max-width: 600px; margin: 0 auto; padding: 20px;">
          <div style="text-align: center; margin-bottom: 30px;">
            <h1 style="color: #1DB954; margin: 0;">🎵 Music Room</h1>
          </div>
          
          <h2 style="color: #333; text-align: center;">Reset your password</h2>
          
          <p style="color: #666; font-size: 16px; line-height: 1.5;">
            You requested to reset your password. Click the button below to set a new password:
          </p>
          
          <div style="text-align: center; margin: 30px 0;">
            <a href="${resetUrl}" 
               style="background-color: #E22134; color: white; padding: 15px 30px; text-decoration: none; border-radius: 25px; display: inline-block; font-weight: bold; font-size: 16px;">
              Reset Password
            </a>
          </div>
          
          <p style="color: #999; font-size: 14px; margin-top: 30px;">
            If the button doesn't work, copy and paste this link into your browser:<br>
            <a href="${resetUrl}" style="color: #E22134;">${resetUrl}</a>
          </p>
          
          <p style="color: #999; font-size: 14px;">
            This link will expire in 1 hour. If you didn't request this, please ignore this email.
          </p>
          
          <div style="text-align: center; margin-top: 40px; padding-top: 20px; border-top: 1px solid #eee;">
            <p style="color: #999; font-size: 12px;">
              © 2024 Music Room. All rights reserved.
            </p>
          </div>
        </div>
      `,
      text: `
        Reset your Music Room password
        
        Click on this link to reset your password:
        ${resetUrl}
        
        This link will expire in 1 hour.
        
        If you didn't request this, please ignore this email.
      `,
    };
  }

  private getPasswordResetConfirmationTemplate(): EmailTemplate {
    return {
      subject: 'Password successfully reset - Music Room',
      html: `
        <div style="font-family: Arial, sans-serif; max-width: 600px; margin: 0 auto; padding: 20px;">
          <div style="text-align: center; margin-bottom: 30px;">
            <h1 style="color: #1DB954; margin: 0;">🎵 Music Room</h1>
          </div>
          
          <h2 style="color: #28a745; text-align: center;">Password Reset Successful ✅</h2>
          
          <p style="color: #666; font-size: 16px; line-height: 1.5;">
            Your password has been successfully reset. You can now log in with your new password.
          </p>
          
          <div style="text-align: center; margin: 30px 0;">
            <a href="${this.configService.get<string>('FRONTEND_URL')}/auth/login" 
               style="background-color: #1DB954; color: white; padding: 15px 30px; text-decoration: none; border-radius: 25px; display: inline-block; font-weight: bold; font-size: 16px;">
              Login to Music Room
            </a>
          </div>
          
          <p style="color: #999; font-size: 14px;">
            If you didn't make this change, please contact our support team immediately.
          </p>
          
          <div style="text-align: center; margin-top: 40px; padding-top: 20px; border-top: 1px solid #eee;">
            <p style="color: #999; font-size: 12px;">
              © 2024 Music Room. All rights reserved.
            </p>
          </div>
        </div>
      `,
      text: `
        Password Reset Successful
        
        Your password has been successfully reset. You can now log in with your new password.
        
        If you didn't make this change, please contact our support team immediately.
      `,
    };
  }

  private getWelcomeTemplate(displayName: string): EmailTemplate {
    return {
      subject: 'Welcome to Music Room! 🎵',
      html: `
        <div style="font-family: Arial, sans-serif; max-width: 600px; margin: 0 auto; padding: 20px;">
          <div style="text-align: center; margin-bottom: 30px;">
            <h1 style="color: #1DB954; margin: 0;">🎵 Music Room</h1>
          </div>
          
          <h2 style="color: #333; text-align: center;">Welcome ${displayName}!</h2>
          
          <p style="color: #666; font-size: 16px; line-height: 1.5;">
            Your account has been successfully verified! You're now ready to explore the world of collaborative music with Music Room.
          </p>
          
          <div style="background-color: #f8f9fa; padding: 20px; border-radius: 10px; margin: 20px 0;">
            <h3 style="color: #333; margin-top: 0;">What you can do:</h3>
            <ul style="color: #666; line-height: 1.8;">
              <li>🗳️ <strong>Vote for tracks</strong> in live music events</li>
              <li>🎶 <strong>Create collaborative playlists</strong> with friends</li>
              <li>📱 <strong>Control music</strong> across your devices</li>
              <li>👥 <strong>Connect with friends</strong> who share your musical taste</li>
            </ul>
          </div>
          
          <div style="text-align: center; margin: 30px 0;">
            <a href="${this.configService.get<string>('FRONTEND_URL')}/dashboard" 
               style="background-color: #1DB954; color: white; padding: 15px 30px; text-decoration: none; border-radius: 25px; display: inline-block; font-weight: bold; font-size: 16px;">
              Start Exploring
            </a>
          </div>
          
          <div style="text-align: center; margin-top: 40px; padding-top: 20px; border-top: 1px solid #eee;">
            <p style="color: #999; font-size: 12px;">
              © 2024 Music Room. All rights reserved.
            </p>
          </div>
        </div>
      `,
      text: `
        Welcome to Music Room, ${displayName}!
        
        Your account has been successfully verified! You're now ready to explore collaborative music.
        
        What you can do:
        - Vote for tracks in live music events
        - Create collaborative playlists with friends  
        - Control music across your devices
        - Connect with friends who share your musical taste
        
        Visit: ${this.configService.get<string>('FRONTEND_URL')}/dashboard
      `,
    };
  }

  private getEventInvitationTemplate(eventName: string, inviterName: string, eventUrl: string): EmailTemplate {
    return {
      subject: `You're invited to "${eventName}" on Music Room!`,
      html: `
        <div style="font-family: Arial, sans-serif; max-width: 600px; margin: 0 auto; padding: 20px;">
          <div style="text-align: center; margin-bottom: 30px;">
            <h1 style="color: #1DB954; margin: 0;">🎵 Music Room</h1>
          </div>
          
          <h2 style="color: #333; text-align: center;">You're Invited! 🎉</h2>
          
          <p style="color: #666; font-size: 16px; line-height: 1.5;">
            <strong>${inviterName}</strong> has invited you to join the music event:
          </p>
          
          <div style="background-color: #f8f9fa; padding: 20px; border-radius: 10px; margin: 20px 0; text-align: center;">
            <h3 style="color: #1DB954; margin: 0; font-size: 24px;">"${eventName}"</h3>
          </div>
          
          <p style="color: #666; font-size: 16px; line-height: 1.5;">
            Join the event to vote for your favorite tracks and help create the perfect playlist together!
          </p>
          
          <div style="text-align: center; margin: 30px 0;">
            <a href="${eventUrl}" 
               style="background-color: #1DB954; color: white; padding: 15px 30px; text-decoration: none; border-radius: 25px; display: inline-block; font-weight: bold; font-size: 16px;">
              Join Event
            </a>
          </div>
          
          <div style="text-align: center; margin-top: 40px; padding-top: 20px; border-top: 1px solid #eee;">
            <p style="color: #999; font-size: 12px;">
              © 2024 Music Room. All rights reserved.
            </p>
          </div>
        </div>
      `,
      text: `
        You're invited to "${eventName}" on Music Room!
        
        ${inviterName} has invited you to join this music event.
        
        Join the event to vote for your favorite tracks: ${eventUrl}
      `,
    };
  }

  private getPlaylistInvitationTemplate(playlistName: string, inviterName: string, playlistUrl: string): EmailTemplate {
    return {
      subject: `Collaborate on "${playlistName}" playlist!`,
      html: `
        <div style="font-family: Arial, sans-serif; max-width: 600px; margin: 0 auto; padding: 20px;">
          <div style="text-align: center; margin-bottom: 30px;">
            <h1 style="color: #1DB954; margin: 0;">🎵 Music Room</h1>
          </div>
          
          <h2 style="color: #333; text-align: center;">Playlist Collaboration! 🎶</h2>
          
          <p style="color: #666; font-size: 16px; line-height: 1.5;">
            <strong>${inviterName}</strong> has invited you to collaborate on the playlist:
          </p>
          
          <div style="background-color: #f8f9fa; padding: 20px; border-radius: 10px; margin: 20px 0; text-align: center;">
            <h3 style="color: #1DB954; margin: 0; font-size: 24px;">"${playlistName}"</h3>
          </div>
          
          <p style="color: #666; font-size: 16px; line-height: 1.5;">
            Add your favorite tracks and help create an amazing collaborative playlist!
          </p>
          
          <div style="text-align: center; margin: 30px 0;">
            <a href="${playlistUrl}" 
               style="background-color: #1DB954; color: white; padding: 15px 30px; text-decoration: none; border-radius: 25px; display: inline-block; font-weight: bold; font-size: 16px;">
              View Playlist
            </a>
          </div>
          
          <div style="text-align: center; margin-top: 40px; padding-top: 20px; border-top: 1px solid #eee;">
            <p style="color: #999; font-size: 12px;">
              © 2024 Music Room. All rights reserved.
            </p>
          </div>
        </div>
      `,
      text: `
        Playlist Collaboration Invitation!
        
        ${inviterName} has invited you to collaborate on "${playlistName}".
        
        View and edit the playlist: ${playlistUrl}
      `,
    };
  }

  private getFriendRequestTemplate(requesterName: string, profileUrl: string): EmailTemplate {
    return {
      subject: `${requesterName} wants to be your friend on Music Room!`,
      html: `
        <div style="font-family: Arial, sans-serif; max-width: 600px; margin: 0 auto; padding: 20px;">
          <div style="text-align: center; margin-bottom: 30px;">
            <h1 style="color: #1DB954; margin: 0;">🎵 Music Room</h1>
          </div>
          
          <h2 style="color: #333; text-align: center;">New Friend Request! 👋</h2>
          
          <p style="color: #666; font-size: 16px; line-height: 1.5; text-align: center;">
            <strong>${requesterName}</strong> wants to connect with you on Music Room!
          </p>
          
          <div style="text-align: center; margin: 30px 0;">
            <a href="${profileUrl}" 
               style="background-color: #1DB954; color: white; padding: 15px 30px; text-decoration: none; border-radius: 25px; display: inline-block; font-weight: bold; font-size: 16px;">
              View Profile & Respond
            </a>
          </div>
          
          <p style="color: #666; font-size: 14px; text-align: center;">
            Connect with friends to share playlists, discover new music, and join events together!
          </p>
          
          <div style="text-align: center; margin-top: 40px; padding-top: 20px; border-top: 1px solid #eee;">
            <p style="color: #999; font-size: 12px;">
              © 2024 Music Room. All rights reserved.
            </p>
          </div>
        </div>
      `,
      text: `
        New Friend Request!
        
        ${requesterName} wants to connect with you on Music Room.
        
        View their profile and respond: ${profileUrl}
      `,
    };
  }
}