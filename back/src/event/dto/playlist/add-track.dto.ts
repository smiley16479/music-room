import { IsString, IsOptional, IsNumber, Min } from 'class-validator';
import { ApiProperty, ApiPropertyOptional } from '@nestjs/swagger';

export class AddTrackToPlaylistDto {
  @ApiProperty({
    description: 'Deezer track ID',
    example: '3135556',
  })
  @IsString()
  deezerId: string;

  @ApiProperty({
    description: 'Track title',
    example: 'Shape of You',
  })
  @IsString()
  title: string;

  @ApiProperty({
    description: 'Artist name',
    example: 'Ed Sheeran',
  })
  @IsString()
  artist: string;

  @ApiProperty({
    description: 'Album name',
    example: '÷ (Deluxe)',
  })
  @IsString()
  album: string;

  @ApiPropertyOptional({
    description: 'Album cover image URL',
    example: 'https://e-cdns-images.dzcdn.net/images/cover/b1b5f8f6f6e9a9f9f9f9f9f9f9f9f9f9/250x250-000000-80-0-0.jpg',
  })
  @IsOptional()
  @IsString()
  albumCoverUrl?: string;

  @ApiPropertyOptional({
    description: 'Preview audio URL (30 seconds)',
    example: 'https://cdns-preview-e.dzcdn.net/stream/c-e77d23e0c8ed7567a507a6d1b6a9c.mp3',
  })
  @IsOptional()
  @IsString()
  previewUrl?: string;

  @ApiPropertyOptional({
    description: 'Track duration in seconds',
    example: 233,
  })
  @IsOptional()
  @IsNumber()
  duration?: number;

  @ApiPropertyOptional({
    description: 'Position in the playlist (1-based)',
    example: 1,
    minimum: 1,
  })
  @IsOptional()
  @IsNumber()
  @Min(1)
  position?: number;
}