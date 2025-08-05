import { PartialType } from '@nestjs/mapped-types';
import { CreatePlaylistDto } from './create-playlist.dto';

export class UpdatePlaylistDto extends PartialType(CreatePlaylistDto) {}

// src/playlists/dto/add-track.dto.ts
import { IsString, IsOptional, IsNumber, Min } from 'class-validator';

export class AddTrackToPlaylistDto {
  @IsString()
  trackId: string;

  @IsOptional()
  @IsNumber()
  @Min(1)
  position?: number;
}