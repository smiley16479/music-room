import { config } from '$lib/config';
import { authService } from './auth';

export interface User {
  id: string;
  displayName: string;
  email: string;
  avatarUrl?: string;
  bio?: string;
  createdAt: string;
}

export const userService = {
  async searchUsers(query: string, limit = 20): Promise<User[]> {
    const token = authService.getAuthToken();
    if (!token) throw new Error('Authentication required');

    const response = await fetch(`${config.apiUrl}/api/users/search?q=${encodeURIComponent(query)}&limit=${limit}`, {
      headers: {
        'Authorization': `Bearer ${token}`
      }
    });

    if (!response.ok) {
      const result = await response.json();
      throw new Error(result.message || 'Failed to search users');
    }

    const result = await response.json();
    return result.data || [];
  },

  async getUserById(userId: string): Promise<User> {
    const token = authService.getAuthToken();
    if (!token) throw new Error('Authentication required');

    const response = await fetch(`${config.apiUrl}/api/users/${userId}`, {
      headers: {
        'Authorization': `Bearer ${token}`
      }
    });

    if (!response.ok) {
      const result = await response.json();
      throw new Error(result.message || 'Failed to get user');
    }

    const result = await response.json();
    return result.data;
  },

  async getUserByEmail(email: string): Promise<User | null> {
    try {
      // Try searching for exact email match
      const users = await this.searchUsers(email, 1);
      return users.find(user => user.email.toLowerCase() === email.toLowerCase()) || null;
    } catch (error) {
      console.error('Error searching user by email:', error);
      return null;
    }
  }
};
