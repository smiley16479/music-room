import {
  IsEmail,
  IsString,
  MinLength,
  MaxLength,
  IsOptional,
  IsEnum,
  IsDateString,
  IsObject,
  IsArray,
  IsBoolean,
  IsUrl,
} from 'class-validator';
import { VisibilityLevel } from 'src/user/entities/user.entity';

export class CreateUserDto {
  @IsEmail()
  email: string;

  @IsOptional()
  @IsString()
  @MinLength(8)
  @MaxLength(100)
  password?: string;

  @IsOptional()
  @IsString()
  @MaxLength(100)
  displayName?: string;

  @IsOptional()
  @IsString()
  @MaxLength(500)
  bio?: string;

  @IsOptional()
  @IsDateString()
  birthDate?: string;

  @IsOptional()
  @IsString()
  @MaxLength(200)
  location?: string;

  @IsOptional()
  @IsEnum(VisibilityLevel)
  displayNameVisibility?: VisibilityLevel;

  @IsOptional()
  @IsEnum(VisibilityLevel)
  bioVisibility?: VisibilityLevel;

  @IsOptional()
  @IsEnum(VisibilityLevel)
  birthDateVisibility?: VisibilityLevel;

  @IsOptional()
  @IsEnum(VisibilityLevel)
  locationVisibility?: VisibilityLevel;

  @IsOptional()
  @IsString()
  googleId?: string;

  @IsOptional()
  @IsString()
  facebookId?: string;

  @IsOptional()
  @IsBoolean()
  emailVerified?: boolean;

  @IsOptional()
  @IsUrl()
  avatarUrl?: string;

  // Et probablement aussi :
  @IsOptional()
  @IsString()
  resetPasswordToken?: string;

  @IsOptional()
  @IsDateString()
  resetPasswordExpires?: Date;

  @IsOptional()
  @IsObject()
  musicPreferences?: {
    favoriteGenres?: string[];
    favoriteArtists?: string[];
    dislikedGenres?: string[];
  };
}
