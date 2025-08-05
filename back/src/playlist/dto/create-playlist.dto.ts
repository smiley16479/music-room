import {
  IsString,
  IsOptional,
  IsEnum,
  IsBoolean,
  MaxLength,
  IsUrl,
} from 'class-validator';
import {
  PlaylistVisibility,
  PlaylistLicenseType,
} from 'src/playlist/entities/playlist.entity';

export class CreatePlaylistDto {
  @IsString()
  @MaxLength(200)
  name: string;

  @IsOptional()
  @IsString()
  @MaxLength(1000)
  description?: string;

  @IsOptional()
  @IsEnum(PlaylistVisibility)
  visibility?: PlaylistVisibility;

  @IsOptional()
  @IsEnum(PlaylistLicenseType)
  licenseType?: PlaylistLicenseType;

  @IsOptional()
  @IsUrl()
  coverImageUrl?: string;

  @IsOptional()
  @IsBoolean()
  isCollaborative?: boolean;
}