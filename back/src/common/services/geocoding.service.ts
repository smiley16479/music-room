import { Injectable, Logger, BadRequestException } from '@nestjs/common';
import { ConfigService } from '@nestjs/config';

export interface GeocodeResult {
  latitude: number;
  longitude: number;
  city: string;
  country: string;
  displayName: string;
}

@Injectable()
export class GeocodingService {
  private readonly logger = new Logger(GeocodingService.name);

  constructor(private configService: ConfigService) {}

  /**
   * Convert city name to coordinates using OpenStreetMap Nominatim API
   * This is a free geocoding service that doesn't require an API key
   */
  async geocodeCity(cityName: string): Promise<GeocodeResult> {
    if (!cityName || cityName.trim().length === 0) {
      throw new BadRequestException('City name is required');
    }

    const cleanCityName = cityName.trim();
    
    try {
      // Use Nominatim API (OpenStreetMap's geocoding service)
      const url = `https://nominatim.openstreetmap.org/search?format=json&q=${encodeURIComponent(cleanCityName)}&limit=1&addressdetails=1`;
      
      const response = await fetch(url, {
        headers: {
          'User-Agent': 'MusicRoom/1.0 (https://github.com/smiley16479/music-room)', // Required by Nominatim
        },
      });

      if (!response.ok) {
        throw new Error(`Geocoding API returned status ${response.status}`);
      }

      const data = await response.json() as any[];

      if (!data || data.length === 0) {
        throw new BadRequestException(`City "${cleanCityName}" not found. Please check the spelling or try a more specific name.`);
      }

      const result = data[0];
      
      // Validate the result has coordinates
      if (!result.lat || !result.lon) {
        throw new BadRequestException(`Unable to get coordinates for "${cleanCityName}"`);
      }

      const latitude = parseFloat(result.lat);
      const longitude = parseFloat(result.lon);

      // Validate coordinates are within valid ranges
      if (latitude < -90 || latitude > 90 || longitude < -180 || longitude > 180) {
        throw new BadRequestException(`Invalid coordinates received for "${cleanCityName}"`);
      }

      // Extract city and country information
      const address = result.address || {};
      const city = address.city || address.town || address.village || address.municipality || cleanCityName;
      const country = address.country || 'Unknown';
      const displayName = result.display_name || `${city}, ${country}`;

      this.logger.log(`Successfully geocoded "${cleanCityName}" to ${latitude}, ${longitude}`);

      return {
        latitude,
        longitude,
        city,
        country,
        displayName,
      };
    } catch (error) {
      this.logger.error(`Failed to geocode city "${cleanCityName}": ${error.message}`);
      
      if (error instanceof BadRequestException) {
        throw error;
      }
      
      throw new BadRequestException(`Unable to find location for "${cleanCityName}". Please try a different city name.`);
    }
  }

  /**
   * Reverse geocoding: convert coordinates to city name
   * Useful for displaying readable location names
   */
  async reverseGeocode(latitude: number, longitude: number): Promise<GeocodeResult> {
    if (latitude < -90 || latitude > 90 || longitude < -180 || longitude > 180) {
      throw new BadRequestException('Invalid coordinates provided');
    }

    try {
      const url = `https://nominatim.openstreetmap.org/reverse?format=json&lat=${latitude}&lon=${longitude}&addressdetails=1`;
      
      const response = await fetch(url, {
        headers: {
          'User-Agent': 'MusicRoom/1.0 (https://github.com/smiley16479/music-room)',
        },
      });

      if (!response.ok) {
        throw new Error(`Reverse geocoding API returned status ${response.status}`);
      }

      const result = await response.json() as any;

      if (!result || !result.address) {
        throw new BadRequestException('Unable to determine location from coordinates');
      }

      const address = result.address;
      const city = address.city || address.town || address.village || address.municipality || 'Unknown Location';
      const country = address.country || 'Unknown';
      const displayName = result.display_name || `${city}, ${country}`;

      return {
        latitude,
        longitude,
        city,
        country,
        displayName,
      };
    } catch (error) {
      this.logger.error(`Failed to reverse geocode coordinates ${latitude}, ${longitude}: ${error.message}`);
      
      if (error instanceof BadRequestException) {
        throw error;
      }
      
      throw new BadRequestException('Unable to determine location from coordinates');
    }
  }

  /**
   * Validate that a city name can be geocoded
   * Useful for form validation without storing the result
   */
  async validateCity(cityName: string): Promise<boolean> {
    try {
      await this.geocodeCity(cityName);
      return true;
    } catch (error) {
      return false;
    }
  }
}
