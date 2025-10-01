import { config } from '$lib/config';
import { authService } from './auth';

export interface GeocodeResult {
  latitude: number;
  longitude: number;
  city: string;
  country: string;
  displayName: string;
}

export interface GeocodingResponse {
  success: boolean;
  data: GeocodeResult;
  timestamp: string;
}

export interface ValidationResponse {
  success: boolean;
  data: {
    valid: boolean;
    city: string;
  };
  timestamp: string;
}

class GeocodingService {
  /**
   * Convert city name to coordinates
   */
  async geocodeCity(cityName: string): Promise<GeocodeResult> {
    if (!cityName || cityName.trim().length === 0) {
      throw new Error('City name is required');
    }

    const response = await fetch(`${config.apiUrl}/api/geocoding/city?city=${encodeURIComponent(cityName)}`, {
      headers: {
        'Authorization': `Bearer ${authService.getAuthToken()}`,
        'Content-Type': 'application/json',
      },
    });

    if (!response.ok) {
      const errorData = await response.json().catch(() => ({}));
      throw new Error(errorData.message || `Failed to geocode city "${cityName}"`);
    }

    const result: GeocodingResponse = await response.json();
    return result.data;
  }

  /**
   * Convert coordinates to city name
   */
  async reverseGeocode(latitude: number, longitude: number): Promise<GeocodeResult> {
    if (latitude < -90 || latitude > 90 || longitude < -180 || longitude > 180) {
      throw new Error('Invalid coordinates provided');
    }

    const response = await fetch(`${config.apiUrl}/api/geocoding/reverse?lat=${latitude}&lng=${longitude}`, {
      headers: {
        'Authorization': `Bearer ${authService.getAuthToken()}`,
        'Content-Type': 'application/json',
      },
    });

    if (!response.ok) {
      const errorData = await response.json().catch(() => ({}));
      throw new Error(errorData.message || 'Failed to reverse geocode coordinates');
    }

    const result: GeocodingResponse = await response.json();
    return result.data;
  }

  /**
   * Validate that a city name can be geocoded
   */
  async validateCity(cityName: string): Promise<boolean> {
    if (!cityName || cityName.trim().length === 0) {
      return false;
    }

    try {
      const response = await fetch(`${config.apiUrl}/api/geocoding/validate?city=${encodeURIComponent(cityName)}`, {
        headers: {
          'Authorization': `Bearer ${authService.getAuthToken()}`,
          'Content-Type': 'application/json',
        },
      });

      if (!response.ok) {
        return false;
      }

      const result: ValidationResponse = await response.json();
      return result.data.valid;
    } catch (error) {
      console.error('Error validating city:', error);
      return false;
    }
  }

  /**
   * Get suggested cities based on partial input (for autocomplete)
   * This is a simple implementation that could be enhanced with a proper autocomplete API
   */
  async getSuggestedCities(partialName: string): Promise<string[]> {
    if (!partialName || partialName.length < 2) {
      return [];
    }

    // For now, return some common cities that start with the input
    // In a real implementation, you might want to use a proper city search API
    const commonCities = [
      'Paris', 'London', 'New York', 'Tokyo', 'Berlin', 'Madrid', 'Rome', 'Amsterdam',
      'Barcelona', 'Vienna', 'Prague', 'Budapest', 'Warsaw', 'Stockholm', 'Copenhagen',
      'Helsinki', 'Dublin', 'Edinburgh', 'Manchester', 'Liverpool', 'Birmingham',
      'Los Angeles', 'Chicago', 'Houston', 'Phoenix', 'Philadelphia', 'San Antonio',
      'San Diego', 'Dallas', 'San Jose', 'Austin', 'Jacksonville', 'Fort Worth',
      'Columbus', 'San Francisco', 'Charlotte', 'Indianapolis', 'Seattle', 'Denver',
      'Washington', 'Boston', 'El Paso', 'Detroit', 'Nashville', 'Memphis', 'Portland',
      'Oklahoma City', 'Las Vegas', 'Louisville', 'Baltimore', 'Milwaukee', 'Albuquerque',
      'Tucson', 'Fresno', 'Sacramento', 'Kansas City', 'Mesa', 'Atlanta', 'Colorado Springs',
      'Raleigh', 'Omaha', 'Miami', 'Oakland', 'Minneapolis', 'Tulsa', 'Cleveland',
      'Wichita', 'Arlington', 'New Orleans', 'Bakersfield', 'Tampa', 'Honolulu',
      'Aurora', 'Anaheim', 'Santa Ana', 'St. Louis', 'Riverside', 'Corpus Christi',
      'Lexington', 'Pittsburgh', 'Anchorage', 'Stockton', 'Cincinnati', 'St. Paul',
      'Toledo', 'Newark', 'Greensboro', 'Plano', 'Henderson', 'Lincoln', 'Buffalo',
      'Jersey City', 'Chula Vista', 'Fort Wayne', 'Orlando', 'St. Petersburg',
      'Chandler', 'Laredo', 'Norfolk', 'Durham', 'Madison'
    ];

    const lowerInput = partialName.toLowerCase();
    return commonCities
      .filter(city => city.toLowerCase().startsWith(lowerInput))
      .slice(0, 10); // Limit to 10 suggestions
  }
}

export const geocodingService = new GeocodingService();
