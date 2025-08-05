import { IsString, IsOptional, IsNumber, Min, Max } from 'class-validator';

export class SearchUsersDto {
  @IsString()
  query: string;

  @IsOptional()
  @IsNumber()
  @Min(1)
  @Max(100)
  limit?: number = 20;

  @IsOptional()
  @IsString()
  genres?: string; // Comma-separated list
}