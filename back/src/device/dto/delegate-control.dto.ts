import {
  IsString,
  IsOptional,
  IsDateString,
  IsObject,
  IsBoolean,
} from 'class-validator';

export class DelegateControlDto {
  @IsString()
  delegatedToId: string;

  @IsOptional()
  @IsDateString()
  expiresAt?: string;

  @IsOptional()
  @IsObject()
  permissions?: {
    canPlay?: boolean;
    canPause?: boolean;
    canSkip?: boolean;
    canChangeVolume?: boolean;
    canChangePlaylist?: boolean;
  };
}