import { IsString, IsOptional, IsEnum, IsNumber, Min, Max } from 'class-validator';
import { VoteType } from '../entities/vote.entity';

export class CreateVoteDto {
  @IsString()
  trackId: string;

  @IsOptional()
  @IsEnum(VoteType)
  type?: VoteType = VoteType.UPVOTE;

  @IsOptional()
  @IsNumber()
  @Min(1)
  @Max(5)
  weight?: number = 1;
}

export class UpdateVoteDto {
  @IsOptional()
  @IsEnum(VoteType)
  type?: VoteType;

  @IsOptional()
  @IsNumber()
  @Min(1)
  @Max(5)
  weight?: number;
}