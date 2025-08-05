import {
  IsString,
  IsOptional,
  IsEnum,
  IsDateString,
  MaxLength,
} from 'class-validator';
import { InvitationType } from 'src/invitation/entities/invitation.entity';

export class CreateInvitationDto {
  @IsString()
  inviteeId: string;

  @IsEnum(InvitationType)
  type: InvitationType;

  @IsOptional()
  @IsString()
  eventId?: string;

  @IsOptional()
  @IsString()
  playlistId?: string;

  @IsOptional()
  @IsString()
  @MaxLength(500)
  message?: string;

  @IsOptional()
  @IsDateString()
  expiresAt?: string;
}