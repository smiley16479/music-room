import { authService } from '../services/auth';
import { config } from '../config';

// Enhanced fetch that handles token refresh automatically
export async function apiFetch(url: string, options: RequestInit = {}): Promise<Response> {
  const token = authService.getAuthToken();
  
  // Add authorization header if we have a token
  if (token) {
    options.headers = {
      ...options.headers,
      'Authorization': `Bearer ${token}`
    };
  }

  // Make the request
  let response = await fetch(url, options);

  // If we get a 401 and have a refresh token, try to refresh and retry
  if (response.status === 401 && token) {
    const refreshed = await authService.refreshAccessToken();
    
    if (refreshed) {
      // Update the authorization header with the new token
      const newToken = authService.getAuthToken();
      if (newToken) {
        options.headers = {
          ...options.headers,
          'Authorization': `Bearer ${newToken}`
        };
        
        // Retry the request with the new token
        response = await fetch(url, options);
      }
    }
  }

  return response;
}

// Helper for common API calls
export const apiCall = {
  async get(endpoint: string, options: RequestInit = {}): Promise<Response> {
    return apiFetch(`${config.apiUrl}/api${endpoint}`, {
      ...options,
      method: 'GET'
    });
  },

  async post(endpoint: string, data?: any, options: RequestInit = {}): Promise<Response> {
    return apiFetch(`${config.apiUrl}/api${endpoint}`, {
      ...options,
      method: 'POST',
      headers: {
        'Content-Type': 'application/json',
        ...options.headers
      },
      body: data ? JSON.stringify(data) : undefined
    });
  },

  async put(endpoint: string, data?: any, options: RequestInit = {}): Promise<Response> {
    return apiFetch(`${config.apiUrl}/api${endpoint}`, {
      ...options,
      method: 'PUT',
      headers: {
        'Content-Type': 'application/json',
        ...options.headers
      },
      body: data ? JSON.stringify(data) : undefined
    });
  },

  async delete(endpoint: string, options: RequestInit = {}): Promise<Response> {
    return apiFetch(`${config.apiUrl}/api${endpoint}`, {
      ...options,
      method: 'DELETE'
    });
  }
};
