# Music Room Mail System

This document provides information about the mail system implementation in the Music Room application.

## Overview

The Music Room application uses a mail system based on MailHog for development and testing. MailHog is an email testing tool that captures outgoing emails without actually sending them to real recipients, making it perfect for development and testing environments.

## Components

1. **MailModule**: The main module that configures the mail service.
2. **MailService**: Provides methods for sending different types of emails.
3. **MailController**: Exposes endpoints for testing email functionality.

## Configuration

The mail system is configured to use MailHog as the SMTP server. The configuration is defined in the `MailModule` and uses the following environment variables:

- `MAIL_HOST`: The hostname of the mail server (default: 'mailhog')
- `MAIL_PORT`: The port of the mail server (default: 1025)
- `MAIL_FROM`: The default sender email address (default: 'noreply@music-room.com')

## Available Email Templates

The mail service provides several email templates:

1. **Welcome Email**: Sent to new users after registration.
2. **Password Reset Email**: Sent when a user requests a password reset.
3. **Playlist Invitation Email**: Sent when a user invites another user to a playlist.
4. **Test Email**: A simple email for testing the mail system.

## Integration with Other Services

The mail system is integrated with several services in the application:

1. **User Service**: Sends welcome emails to new users.
2. **Invitation Service**: Sends playlist invitation emails.

## Testing the Mail System

You can test the mail system using the endpoints exposed by the `MailController`:

1. **Send Test Email**: `POST /mail/test`
   ```
   curl -X POST http://localhost:3000/api/mail/test -H "Content-Type: application/json" -d '{"email":"friend2@example.com"}'
   ```

2. **Send Welcome Email**: `POST /mail/welcome`
   ```
   curl -X POST http://localhost:3000/api/mail/welcome -H "Content-Type: application/json" -d '{"email":"user@example.com","name":"John Doe"}'
   ```

3. **Send Password Reset Email**: `POST /mail/password-reset`
   ```
   curl -X POST http://localhost:3000/api/mail/password-reset -H "Content-Type: application/json" -d '{"email":"friend@example.com","name":"Jane Smith","resetToken":"abc123def456"}'
   ```

4. **Send Playlist Invitation Email**: `POST /mail/playlist-invitation`
   ```
    curl -X POST http://localhost:3000/api/mail/playlist-invitation -H "Content-Type: application/json" -d '{"email":"friend@example.com","senderName":"Jane Smith","playlistName":"Summer Hits 2025" "inviteUrl":"https://music-room.com/invitations/123456"}'
   ```

## Viewing Emails

You can view all sent emails in the MailHog web interface, which is available at:

```
http://localhost:8025
```

This interface allows you to view, search, and inspect all emails sent by the application.

## Production Deployment

For production deployment, you should:

1. Update the environment variables to use a real SMTP server.
2. Consider using a transactional email service like SendGrid, Mailgun, or Amazon SES.
3. Implement email templates using a template engine like Handlebars or Pug.
4. Add more security features like SPF, DKIM, and DMARC.

## Extending the Mail System

To add a new email template:

1. Add a new method to the `MailService` class.
2. Implement the HTML template for the email.
3. If needed, add a new endpoint to the `MailController` for testing.
4. Integrate the new email functionality with the relevant service.
