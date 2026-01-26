import { PartialType } from '@nestjs/mapped-types';
import {
  IsString,
  IsOptional,
  IsEnum,
  IsNumber,
  IsDateString,
  IsBoolean,
  Min,
  Max,
  MaxLength,
  IsPositive,
} from 'class-validator';
import { EventType } from '../../entities/event-type.enum';
import {
  EventVisibility,
  EventLicenseType,
} from '../../entities/event.entity';

export class UpdateEventDto extends PartialType({
  name: String,
  description: String,
  type: String,
  visibility: String,
  licenseType: String,
  votingEnabled: Boolean,
  coverImageUrl: String,
  latitude: Number,
  longitude: Number,
  locationRadius: Number,
  locationName: String,
  votingStartTime: String,
  votingEndTime: String,
  eventDate: String,
  startDate: String,
  endDate: String,
  playlistName: String,
  selectedPlaylistId: String,
} as any) {
  @IsOptional()
  @IsString()
  @MaxLength(200)
  name?: string;

  @IsOptional()
  @IsString()
  @MaxLength(1000)
  description?: string;

  @IsOptional()
  @IsEnum(EventType)
  type?: EventType;

  @IsOptional()
  @IsEnum(EventVisibility)
  visibility?: EventVisibility;

  @IsOptional()
  @IsEnum(EventLicenseType)
  licenseType?: EventLicenseType;

  @IsOptional()
  @IsBoolean()
  votingEnabled?: boolean;

  @IsOptional()
  @IsString()
  @MaxLength(500)
  coverImageUrl?: string;

  @IsOptional()
  @IsNumber()
  @Min(-90)
  @Max(90)
  latitude?: number;

  @IsOptional()
  @IsNumber()
  @Min(-180)
  @Max(180)
  longitude?: number;

  @IsOptional()
  @IsNumber()
  @IsPositive()
  @Max(10000)
  locationRadius?: number;

  @IsOptional()
  @IsString()
  @MaxLength(200)
  locationName?: string;

  @IsOptional()
  @IsString()
  votingStartTime?: string;

  @IsOptional()
  @IsString()
  votingEndTime?: string;

  @IsOptional()
  @IsDateString()
  eventDate?: string;

  @IsOptional()
  @IsDateString()
  startDate?: string;

  @IsOptional()
  @IsDateString()
  endDate?: string;

  @IsOptional()
  @IsString()
  @MaxLength(200)
  playlistName?: string;

  @IsOptional()
  @IsString()
  selectedPlaylistId?: string;

  @IsOptional()
  @IsString()
  cityName?: string;

  @IsOptional()
  @IsNumber()
  @Min(0)
  @Max(10)
  maxVotesPerUser?: number;
}