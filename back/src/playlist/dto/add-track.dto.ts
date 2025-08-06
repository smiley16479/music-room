import { IsString, IsOptional, IsNumber, Min } from 'class-validator';

export class AddTrackToPlaylistDto {
  @IsString()
  trackId: string;

  @IsOptional()
  @IsNumber()
  @Min(1)
  position?: number;
}