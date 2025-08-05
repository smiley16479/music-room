import {
  IsString,
  IsOptional,
  IsEnum,
  IsNumber,
  IsDateString,
  Min,
  Max,
  MaxLength,
  IsPositive,
} from 'class-validator';
import {
  EventVisibility,
  EventLicenseType,
} from 'src/event/entities/event.entity';

export class CreateEventDto {
  @IsString()
  @MaxLength(200)
  name: string;

  @IsOptional()
  @IsString()
  @MaxLength(1000)
  description?: string;

  @IsOptional()
  @IsEnum(EventVisibility)
  visibility?: EventVisibility;

  @IsOptional()
  @IsEnum(EventLicenseType)
  licenseType?: EventLicenseType;

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
  @Max(10000) // 10km max radius
  locationRadius?: number;

  @IsOptional()
  @IsString()
  @MaxLength(200)
  locationName?: string;

  @IsOptional()
  @IsString()
  votingStartTime?: string; // Format: "HH:MM"

  @IsOptional()
  @IsString()
  votingEndTime?: string; // Format: "HH:MM"

  @IsOptional()
  @IsDateString()
  eventDate?: string;

  @IsOptional()
  @IsDateString()
  eventEndDate?: string;

  @IsOptional()
  @IsNumber()
  @IsPositive()
  @Min(1)
  @Max(10)
  maxVotesPerUser?: number;
}
