import { ArrayNotEmpty, IsArray, IsOptional, IsString, IsUUID, ValidateIf } from 'class-validator';

export class InviteCollaboratorsDto {
  @ValidateIf((payload) => !payload.userId)
  @IsArray()
  @ArrayNotEmpty()
  @IsUUID('4', { each: true })
  userIds?: string[];

  @ValidateIf((payload) => !payload.userIds?.length)
  @IsUUID('4')
  userId?: string;

  @IsOptional()
  @IsString()
  message?: string;
}
