import { IsEmail, IsString } from 'class-validator';

export class LoginDto {
  // ATTENTION POUR DEV
  @IsString()
  // POUR PROD REMMETRE @IsEmail()
  email: string;

  @IsString()
  password: string;
}
