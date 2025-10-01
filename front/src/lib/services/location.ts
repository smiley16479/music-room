export interface UserLocation {
  latitude: number;
  longitude: number;
}

export interface GeolocationError {
  code: number;
  message: string;
}

/**
 * Service for handling user geolocation
 */
export class LocationService {
  private static instance: LocationService;
  private currentLocation: UserLocation | null = null;
  private watchId: number | null = null;
  private locationCallbacks: ((location: UserLocation) => void)[] = [];
  private errorCallbacks: ((error: GeolocationError) => void)[] = [];

  private constructor() {}

  static getInstance(): LocationService {
    if (!LocationService.instance) {
      LocationService.instance = new LocationService();
    }
    return LocationService.instance;
  }

  /**
   * Check if geolocation is supported by the browser
   */
  isSupported(): boolean {
    return 'geolocation' in navigator;
  }

  /**
   * Get user's current location (one-time request)
   */
  async getCurrentLocation(): Promise<UserLocation> {
    if (!this.isSupported()) {
      throw new Error('Geolocation is not supported by this browser');
    }

    return new Promise((resolve, reject) => {
      navigator.geolocation.getCurrentPosition(
        (position) => {
          const location: UserLocation = {
            latitude: position.coords.latitude,
            longitude: position.coords.longitude,
          };
          this.currentLocation = location;
          resolve(location);
        },
        (error) => {
          const geolocationError: GeolocationError = {
            code: error.code,
            message: this.getErrorMessage(error.code),
          };
          reject(geolocationError);
        },
        {
          enableHighAccuracy: true,
          timeout: 10000,
          maximumAge: 300000, // 5 minutes
        }
      );
    });
  }

  /**
   * Start watching user's location (continuous updates)
   */
  startWatching(): void {
    if (!this.isSupported()) {
      this.notifyError({
        code: 0,
        message: 'Geolocation is not supported by this browser',
      });
      return;
    }

    if (this.watchId !== null) {
      // Already watching
      return;
    }

    this.watchId = navigator.geolocation.watchPosition(
      (position) => {
        const location: UserLocation = {
          latitude: position.coords.latitude,
          longitude: position.coords.longitude,
        };
        this.currentLocation = location;
        this.notifyLocationUpdate(location);
      },
      (error) => {
        const geolocationError: GeolocationError = {
          code: error.code,
          message: this.getErrorMessage(error.code),
        };
        this.notifyError(geolocationError);
      },
      {
        enableHighAccuracy: true,
        timeout: 10000,
        maximumAge: 300000, // 5 minutes
      }
    );
  }

  /**
   * Stop watching user's location
   */
  stopWatching(): void {
    if (this.watchId !== null) {
      navigator.geolocation.clearWatch(this.watchId);
      this.watchId = null;
    }
  }

  /**
   * Get the last known location
   */
  getLastKnownLocation(): UserLocation | null {
    return this.currentLocation;
  }

  /**
   * Add callback for location updates
   */
  onLocationUpdate(callback: (location: UserLocation) => void): void {
    this.locationCallbacks.push(callback);
  }

  /**
   * Add callback for location errors
   */
  onLocationError(callback: (error: GeolocationError) => void): void {
    this.errorCallbacks.push(callback);
  }

  /**
   * Remove location update callback
   */
  removeLocationCallback(callback: (location: UserLocation) => void): void {
    const index = this.locationCallbacks.indexOf(callback);
    if (index > -1) {
      this.locationCallbacks.splice(index, 1);
    }
  }

  /**
   * Remove location error callback
   */
  removeErrorCallback(callback: (error: GeolocationError) => void): void {
    const index = this.errorCallbacks.indexOf(callback);
    if (index > -1) {
      this.errorCallbacks.splice(index, 1);
    }
  }

  private notifyLocationUpdate(location: UserLocation): void {
    this.locationCallbacks.forEach(callback => callback(location));
  }

  private notifyError(error: GeolocationError): void {
    this.errorCallbacks.forEach(callback => callback(error));
  }

  private getErrorMessage(code: number): string {
    switch (code) {
      case 1:
        return 'Location access denied by user';
      case 2:
        return 'Location information unavailable';
      case 3:
        return 'Location request timeout';
      default:
        return 'Unknown location error';
    }
  }

  /**
   * Calculate distance between two points in kilometers
   */
  static calculateDistance(
    lat1: number,
    lon1: number,
    lat2: number,
    lon2: number
  ): number {
    const R = 6371; // Earth's radius in kilometers
    const dLat = (lat2 - lat1) * (Math.PI / 180);
    const dLon = (lon2 - lon1) * (Math.PI / 180);
    const a =
      Math.sin(dLat / 2) * Math.sin(dLat / 2) +
      Math.cos(lat1 * (Math.PI / 180)) *
        Math.cos(lat2 * (Math.PI / 180)) *
        Math.sin(dLon / 2) *
        Math.sin(dLon / 2);
    const c = 2 * Math.atan2(Math.sqrt(a), Math.sqrt(1 - a));
    return R * c;
  }
}

// Export singleton instance
export const locationService = LocationService.getInstance();
