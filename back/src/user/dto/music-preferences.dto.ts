import { IsOptional, IsArray, IsString } from 'class-validator';

export class MusicPreferencesDto {
  @IsOptional()
  @IsArray()
  @IsString({ each: true })
  favoriteGenres?: string[];

  @IsOptional()
  @IsArray()
  @IsString({ each: true })
  favoriteArtists?: string[];

  @IsOptional()
  @IsArray()
  @IsString({ each: true })
  dislikedGenres?: string[];
}