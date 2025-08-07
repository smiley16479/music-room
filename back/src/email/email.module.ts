import { Module } from '@nestjs/common';
import { ConfigModule } from '@nestjs/config';
import { EmailService } from './email.service';
import { EmailController } from './email.controller';
import { MailerModule } from '@nestjs-modules/mailer';
import { ConfigService } from '@nestjs/config';

@Module({
  imports: [
    ConfigModule,
    MailerModule.forRootAsync({
      inject: [ConfigService],
      useFactory: (configService: ConfigService) => {
        const isDev = configService.get('NODE_ENV') !== 'prod';
        return {
          transport: isDev
            ? {
                host: configService.get('MAIL_HOST', 'mailhog'),
                port: configService.get('MAIL_PORT', 1025),
                secure: false,
              }
            : {
                host: configService.get<string>('SMTP_HOST'),
                port: configService.get<number>('SMTP_PORT', 587),
                secure: configService.get<boolean>('SMTP_SECURE', false),
                auth: {
                  user: configService.get<string>('SMTP_USER'),
                  pass: configService.get<string>('SMTP_PASS'),
                },
              },
          defaults: {
            from: `"No Reply" <${configService.get('MAIL_FROM', 'noreply@music-room.com')}>`,
          },
        };
      },
    }),
  ],
  controllers: [EmailController],
  providers: [EmailService],
  exports: [EmailService],
})
export class EmailModule {}
