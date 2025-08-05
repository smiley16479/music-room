import { PartialType } from '@nestjs/mapped-types';
import { CreateEventDto } from './create-event.dto';

export class UpdateEventDto extends PartialType(CreateEventDto) {
  id: number
}

// src/events/dto/vote.dto.ts
import { IsString, IsOptional, IsEnum, IsNumber, Min, Max } from 'class-validator';
import { VoteType } from 'src/vote/entities/vote.entity';

export class CreateVoteDto {
  @IsString()
  trackId: string;

  @IsOptional()
  @IsEnum(VoteType)
  type?: VoteType;

  @IsOptional()
  @IsNumber()
  @Min(1)
  @Max(5)
  weight?: number;
}