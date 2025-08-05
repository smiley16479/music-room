import { IsString, IsOptional, IsNumber, Min, Max } from 'class-validator';

export class SearchTrackDto {
  @IsString()
  query: string;

  @IsOptional()
  @IsString()
  artist?: string;

  @IsOptional()
  @IsString()
  album?: string;

  @IsOptional()
  @IsNumber()
  @Min(1)
  @Max(100)
  limit?: number = 25;
}