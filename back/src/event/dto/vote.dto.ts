import { IsString, IsOptional, IsEnum, IsNumber, Min, Max, IsUUID } from 'class-validator';
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

/**
 * DTO for changing vote type (toggle between upvote/downvote)
 */
export class ChangeVoteDto {
  @IsString()
  @IsUUID()
  trackId: string;

  @IsEnum(VoteType)
  type: VoteType;
}

/**
 * Response DTO for track vote information
 */
export interface TrackVoteInfo {
  trackId: string;
  playlistTrackId: string;
  upvotes: number;
  downvotes: number;
  score: number; // upvotes - downvotes
  position: number;
  userVote?: {
    type: VoteType;
    userId: string;
  };
}

/**
 * Response DTO for voting results
 */
export interface VotingResultsDto {
  eventId: string;
  tracks: TrackVoteInfo[];
  totalVotes: number;
  currentTrackId?: string;
}