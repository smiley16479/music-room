import { config } from '$lib/config';
import { authService } from './auth';

export interface Device {
  id: string;
  name: string;
  type: 'mobile' | 'desktop' | 'speaker' | 'other';
  isActive: boolean;
  isControlled: boolean;
  controlledBy?: string;
  controlledByName?: string;
  connectedAt: string;
  lastActiveAt: string;
}

export interface ControlPermission {
  id: string;
  grantedTo: string;
  grantedToName: string;
  deviceId: string;
  deviceName: string;
  grantedAt: string;
  expiresAt?: string;
  isActive: boolean;
}

export interface MusicControl {
  isPlaying: boolean;
  currentTrack?: {
    title: string;
    artist: string;
    album?: string;
    thumbnailUrl?: string;
    duration?: number;
    position?: number;
  };
  volume: number;
  shuffle: boolean;
  repeat: 'none' | 'track' | 'playlist';
}

export const devicesService = {
  async getDevices(): Promise<Device[]> {
    const token = authService.getAuthToken();
    if (!token) throw new Error('Authentication required');

    const response = await fetch(`${config.apiUrl}/api/devices`, {
      headers: {
        'Authorization': `Bearer ${token}`
      }
    });

    if (!response.ok) {
      throw new Error('Failed to fetch devices');
    }

    const result = await response.json();
    return result.data;
  },

  async registerDevice(deviceData: { name: string; type: string }): Promise<Device> {
    const token = authService.getAuthToken();
    if (!token) throw new Error('Authentication required');

    const response = await fetch(`${config.apiUrl}/api/devices`, {
      method: 'POST',
      headers: {
        'Content-Type': 'application/json',
        'Authorization': `Bearer ${token}`
      },
      body: JSON.stringify(deviceData)
    });

    if (!response.ok) {
      const result = await response.json();
      throw new Error(result.message || 'Failed to register device');
    }

    const result = await response.json();
    return result.data;
  },

  async updateDevice(deviceId: string, updates: { name?: string; isActive?: boolean }): Promise<Device> {
    const token = authService.getAuthToken();
    if (!token) throw new Error('Authentication required');

    const response = await fetch(`${config.apiUrl}/api/devices/${deviceId}`, {
      method: 'PUT',
      headers: {
        'Content-Type': 'application/json',
        'Authorization': `Bearer ${token}`
      },
      body: JSON.stringify(updates)
    });

    if (!response.ok) {
      const result = await response.json();
      throw new Error(result.message || 'Failed to update device');
    }

    const result = await response.json();
    return result.data;
  },

  async deleteDevice(deviceId: string): Promise<void> {
    const token = authService.getAuthToken();
    if (!token) throw new Error('Authentication required');

    const response = await fetch(`${config.apiUrl}/api/devices/${deviceId}`, {
      method: 'DELETE',
      headers: {
        'Authorization': `Bearer ${token}`
      }
    });

    if (!response.ok) {
      const result = await response.json();
      throw new Error(result.message || 'Failed to delete device');
    }
  },

  async grantControlPermission(deviceId: string, userId: string, expiresAt?: string): Promise<ControlPermission> {
    const token = authService.getAuthToken();
    if (!token) throw new Error('Authentication required');

    const response = await fetch(`${config.apiUrl}/api/devices/${deviceId}/control`, {
      method: 'POST',
      headers: {
        'Content-Type': 'application/json',
        'Authorization': `Bearer ${token}`
      },
      body: JSON.stringify({ userId, expiresAt })
    });

    if (!response.ok) {
      const result = await response.json();
      throw new Error(result.message || 'Failed to grant control permission');
    }

    const result = await response.json();
    return result.data;
  },

  async revokeControlPermission(deviceId: string, userId: string): Promise<void> {
    const token = authService.getAuthToken();
    if (!token) throw new Error('Authentication required');

    const response = await fetch(`${config.apiUrl}/api/devices/${deviceId}/control/${userId}`, {
      method: 'DELETE',
      headers: {
        'Authorization': `Bearer ${token}`
      }
    });

    if (!response.ok) {
      const result = await response.json();
      throw new Error(result.message || 'Failed to revoke control permission');
    }
  },

  async getControlPermissions(deviceId?: string): Promise<ControlPermission[]> {
    const token = authService.getAuthToken();
    if (!token) throw new Error('Authentication required');

    const queryString = deviceId ? `?deviceId=${deviceId}` : '';
    
    const response = await fetch(`${config.apiUrl}/api/devices/control-permissions${queryString}`, {
      headers: {
        'Authorization': `Bearer ${token}`
      }
    });

    if (!response.ok) {
      throw new Error('Failed to fetch control permissions');
    }

    const result = await response.json();
    return result.data;
  },

  async getMusicControl(deviceId: string): Promise<MusicControl> {
    const token = authService.getAuthToken();
    if (!token) throw new Error('Authentication required');

    const response = await fetch(`${config.apiUrl}/api/devices/${deviceId}/music-control`, {
      headers: {
        'Authorization': `Bearer ${token}`
      }
    });

    if (!response.ok) {
      throw new Error('Failed to get music control state');
    }

    const result = await response.json();
    return result.data;
  },

  async updateMusicControl(deviceId: string, control: Partial<MusicControl>): Promise<void> {
    const token = authService.getAuthToken();
    if (!token) throw new Error('Authentication required');

    const response = await fetch(`${config.apiUrl}/api/devices/${deviceId}/music-control`, {
      method: 'PUT',
      headers: {
        'Content-Type': 'application/json',
        'Authorization': `Bearer ${token}`
      },
      body: JSON.stringify(control)
    });

    if (!response.ok) {
      const result = await response.json();
      throw new Error(result.message || 'Failed to update music control');
    }
  }
};
