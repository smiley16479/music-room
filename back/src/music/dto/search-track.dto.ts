import { IsString, IsOptional, IsNumber, Min, Max, IsBoolean } from 'class-validator';
import { Type } from 'class-transformer';

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
  @Type(() => Number)
  @IsNumber()
  @Min(1)
  @Max(100)
  limit?: number = 25;

  @IsOptional()
  @Type(() => Boolean)
  @IsBoolean()
  includeLocal?: boolean = false;
}