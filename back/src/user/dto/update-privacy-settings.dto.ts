import { IsEnum, IsOptional } from 'class-validator';
import { ApiProperty } from '@nestjs/swagger';
import { VisibilityLevel } from '../entities/user.entity';

export class UpdatePrivacySettingsDto {
  @ApiProperty({
    description: 'Visibility level for display name',
    enum: VisibilityLevel,
    example: VisibilityLevel.PUBLIC,
    required: false,
  })
  @IsOptional()
  @IsEnum(VisibilityLevel)
  displayNameVisibility?: VisibilityLevel;

  @ApiProperty({
    description: 'Visibility level for bio',
    enum: VisibilityLevel,
    example: VisibilityLevel.FRIENDS,
    required: false,
  })
  @IsOptional()
  @IsEnum(VisibilityLevel)
  bioVisibility?: VisibilityLevel;

  @ApiProperty({
    description: 'Visibility level for birth date',
    enum: VisibilityLevel,
    example: VisibilityLevel.PRIVATE,
    required: false,
  })
  @IsOptional()
  @IsEnum(VisibilityLevel)
  birthDateVisibility?: VisibilityLevel;

  @ApiProperty({
    description: 'Visibility level for location',
    enum: VisibilityLevel,
    example: VisibilityLevel.FRIENDS,
    required: false,
  })
  @IsOptional()
  @IsEnum(VisibilityLevel)
  locationVisibility?: VisibilityLevel;

  @ApiProperty({
    description: 'Visibility level for music preferences',
    enum: VisibilityLevel,
    example: VisibilityLevel.PUBLIC,
    required: false,
  })
  @IsOptional()
  @IsEnum(VisibilityLevel)
  musicPreferenceVisibility?: VisibilityLevel;
}