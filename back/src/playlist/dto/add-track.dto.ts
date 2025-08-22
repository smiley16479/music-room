import { IsString, IsOptional, IsNumber, Min } from 'class-validator';

export class AddTrackToPlaylistDto {
  @IsString()
  deezerId: string;

  @IsString()
  title: string;

  @IsString()
  artist: string;

  @IsString()
  album: string;

  @IsOptional()
  @IsString()
  albumCoverUrl?: string;

  @IsOptional()
  @IsString()
  previewUrl?: string;

  @IsOptional()
  @IsNumber()
  duration?: number;

  @IsOptional()
  @IsNumber()
  @Min(1)
  position?: number;
}