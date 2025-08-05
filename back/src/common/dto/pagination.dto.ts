import { IsOptional, IsPositive, Max, Min } from 'class-validator';
import { Type } from 'class-transformer';

export class PaginationDto {
  @IsOptional()
  @Type(() => Number)
  @IsPositive()
  @Min(1)
  page?: number = 1;

  @IsOptional()
  @Type(() => Number)
  @IsPositive()
  @Min(1)
  @Max(100)
  limit?: number = 20;

  get skip(): number {
    if (this.limit && this.page)
      return (this.page - 1) * this.limit;
    else
      return -1; // Si page || limit => undefined return -1
  }
}
