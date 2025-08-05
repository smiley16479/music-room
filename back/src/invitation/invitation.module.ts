import { Module } from '@nestjs/common';
import { InvitationService } from './invitation.service';
import { InvitationController } from './invitation.controller';
import { MailModule } from '../mail/mail.module';

@Module({
  imports: [MailModule],
  controllers: [InvitationController],
  providers: [InvitationService],
})
export class InvitationModule {}
