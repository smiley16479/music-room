import { IsEmail, IsString, IsOptional, MaxLength } from 'class-validator';

export class SendEmailDto {
  @IsEmail()
  to: string;

  @IsString()
  @MaxLength(200)
  subject: string;

  @IsString()
  @MaxLength(5000)
  message: string;

  @IsOptional()
  @IsString()
  template?: string;
}