import { ArrayNotEmpty, IsArray, IsOptional, IsString, IsUUID } from 'class-validator';

export class InviteUsersDto {
  @IsArray()
  @ArrayNotEmpty()
  @IsUUID('4', { each: true })
  userIds: string[];

  @IsOptional()
  @IsString()
  message?: string;
}
