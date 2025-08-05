import { IsEnum } from 'class-validator';
import { InvitationStatus } from 'src/invitation/entities/invitation.entity';

export class RespondInvitationDto {
  @IsEnum([InvitationStatus.ACCEPTED, InvitationStatus.DECLINED])
  status: InvitationStatus.ACCEPTED | InvitationStatus.DECLINED;
}