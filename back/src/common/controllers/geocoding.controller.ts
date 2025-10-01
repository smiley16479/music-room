import { Controller, Get, Query, HttpStatus, BadRequestException } from '@nestjs/common';
import { ApiTags, ApiOperation, ApiQuery, ApiResponse } from '@nestjs/swagger';
import { Public } from '../../auth/decorators/public.decorator';
import { GeocodingService, GeocodeResult } from '../services/geocoding.service';

@ApiTags('Geocoding')
@Controller('geocoding')
@Public()
export class GeocodingController {
  constructor(private readonly geocodingService: GeocodingService) {}

  @Get('city')
  @ApiOperation({
    summary: 'Geocode city name',
    description: 'Convert a city name to latitude/longitude coordinates',
  })
  @ApiQuery({
    name: 'city',
    type: String,
    description: 'Name of the city to geocode (e.g., "Paris", "New York", "Tokyo")',
    required: true,
    example: 'Paris'
  })
  @ApiResponse({
    status: HttpStatus.OK,
    description: 'Successfully geocoded city',
    schema: {
      type: 'object',
      properties: {
        success: { type: 'boolean', example: true },
        data: {
          type: 'object',
          properties: {
            latitude: { type: 'number', example: 48.8566 },
            longitude: { type: 'number', example: 2.3522 },
            city: { type: 'string', example: 'Paris' },
            country: { type: 'string', example: 'France' },
            displayName: { type: 'string', example: 'Paris, France' },
          }
        },
        timestamp: { type: 'string', example: '2024-01-01T00:00:00.000Z' }
      }
    }
  })
  @ApiResponse({
    status: HttpStatus.BAD_REQUEST,
    description: 'City not found or invalid input',
  })
  async geocodeCity(@Query('city') cityName: string): Promise<{
    success: boolean;
    data: GeocodeResult;
    timestamp: string;
  }> {
    if (!cityName) {
      throw new BadRequestException('City parameter is required');
    }

    const result = await this.geocodingService.geocodeCity(cityName);

    return {
      success: true,
      data: result,
      timestamp: new Date().toISOString(),
    };
  }

  @Get('reverse')
  @ApiOperation({
    summary: 'Reverse geocode coordinates',
    description: 'Convert latitude/longitude coordinates to city name',
  })
  @ApiQuery({
    name: 'lat',
    type: Number,
    description: 'Latitude coordinate',
    required: true,
    example: 48.8566
  })
  @ApiQuery({
    name: 'lng',
    type: Number,
    description: 'Longitude coordinate',
    required: true,
    example: 2.3522
  })
  @ApiResponse({
    status: HttpStatus.OK,
    description: 'Successfully reverse geocoded coordinates',
  })
  @ApiResponse({
    status: HttpStatus.BAD_REQUEST,
    description: 'Invalid coordinates',
  })
  async reverseGeocode(
    @Query('lat') latitude: string,
    @Query('lng') longitude: string
  ): Promise<{
    success: boolean;
    data: GeocodeResult;
    timestamp: string;
  }> {
    const lat = parseFloat(latitude);
    const lng = parseFloat(longitude);

    if (isNaN(lat) || isNaN(lng)) {
      throw new BadRequestException('Valid latitude and longitude parameters are required');
    }

    const result = await this.geocodingService.reverseGeocode(lat, lng);

    return {
      success: true,
      data: result,
      timestamp: new Date().toISOString(),
    };
  }

  @Get('validate')
  @ApiOperation({
    summary: 'Validate city name',
    description: 'Check if a city name can be geocoded without returning full results',
  })
  @ApiQuery({
    name: 'city',
    type: String,
    description: 'Name of the city to validate',
    required: true,
    example: 'Paris'
  })
  @ApiResponse({
    status: HttpStatus.OK,
    description: 'City validation result',
    schema: {
      type: 'object',
      properties: {
        success: { type: 'boolean', example: true },
        data: {
          type: 'object',
          properties: {
            valid: { type: 'boolean', example: true },
            city: { type: 'string', example: 'Paris' }
          }
        },
        timestamp: { type: 'string', example: '2024-01-01T00:00:00.000Z' }
      }
    }
  })
  async validateCity(@Query('city') cityName: string): Promise<{
    success: boolean;
    data: { valid: boolean; city: string };
    timestamp: string;
  }> {
    if (!cityName) {
      throw new BadRequestException('City parameter is required');
    }

    const isValid = await this.geocodingService.validateCity(cityName);

    return {
      success: true,
      data: {
        valid: isValid,
        city: cityName,
      },
      timestamp: new Date().toISOString(),
    };
  }
}
