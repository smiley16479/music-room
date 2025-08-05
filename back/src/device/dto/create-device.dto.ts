import {
  IsString,
  IsOptional,
  IsEnum,
  IsObject,
  IsBoolean,
  MaxLength,
} from 'class-validator';
import { DeviceType } from 'src/device/entities/device.entity';

export class CreateDeviceDto {
  @IsString()
  @MaxLength(100)
  name: string;

  @IsOptional()
  @IsEnum(DeviceType)
  type?: DeviceType;

  @IsOptional()
  @IsObject()
  deviceInfo?: {
    userAgent?: string;
    platform?: string;
    browser?: string;
    version?: string;
  };

  @IsOptional()
  @IsBoolean()
  canBeControlled?: boolean;
}