import { config } from '$lib/config';

export interface RegisterData {
  email: string;
  password: string;
  displayName?: string;
}

export interface LoginData {
  email: string;
  password: string;
}

export interface User {
  id: string;
  email: string;
  displayName?: string;
  profilePicture?: string;
  publicInfo?: {
    displayName: string;
    bio?: string;
    profilePicture?: string;
  };
  friendsInfo?: {
    realName?: string;
    location?: string;
    favoriteGenres?: string[];
  };
  privateInfo?: {
    phoneNumber?: string;
    birthDate?: string;
  };
  musicPreferences?: {
    favoriteGenres?: string[];
    favoriteArtists?: string[];
    listeningHabits?: string;
  };
  connectedAccounts?: {
    google?: boolean;
    facebook?: boolean;
  };
  isEmailVerified?: boolean;
}

export interface AuthResponse {
  success: boolean;
  message: string;
  data?: {
    accessToken: string;
    refreshToken: string;
    user: User;
  };
  timestamp: string;
}

export const authService = {
  async register(data: RegisterData): Promise<AuthResponse> {
    try {
      const response = await fetch(`${config.apiUrl}/api/auth/register`, {
        method: 'POST',
        headers: {
          'Content-Type': 'application/json'
        },
        body: JSON.stringify(data)
      });
      
      const result = await response.json();
      
      if (!response.ok) {
        throw new Error(result.message || 'Registration failed');
      }
      
      return result;
    } catch (error) {
      console.error('Registration error:', error);
      throw error;
    }
  },
  
  async login(data: LoginData): Promise<AuthResponse> {
    try {
      const response = await fetch(`${config.apiUrl}/api/auth/login`, {
        method: 'POST',
        headers: {
          'Content-Type': 'application/json'
        },
        body: JSON.stringify(data)
      });
      
      const result = await response.json();
      
      if (!response.ok) {
        throw new Error(result.message || 'Login failed');
      }
      
      localStorage.setItem('accessToken', result.data.accessToken);
      localStorage.setItem('refreshToken', result.data.refreshToken);
      localStorage.setItem('user', JSON.stringify(result.data.user));
      
      return result;
    } catch (error) {
      console.error('Login error:', error);
      throw error;
    }
  },

  async getCurrentUser(): Promise<User | null> {
    try {
      const token = localStorage.getItem('accessToken');
      if (!token) return null;

      const response = await fetch(`${config.apiUrl}/api/auth/me`, {
        headers: {
          'Authorization': `Bearer ${token}`
        }
      });

      if (!response.ok) {
        this.logout();
        return null;
      }

      const result = await response.json();
      localStorage.setItem('user', JSON.stringify(result.data));
      return result.data;
    } catch (error) {
      console.error('Get current user error:', error);
      return null;
    }
  },

  async updateProfile(profileData: Partial<User>): Promise<User> {
    const token = localStorage.getItem('accessToken');
    if (!token) throw new Error('Not authenticated');

    const response = await fetch(`${config.apiUrl}/api/user/profile`, {
      method: 'PUT',
      headers: {
        'Content-Type': 'application/json',
        'Authorization': `Bearer ${token}`
      },
      body: JSON.stringify(profileData)
    });

    const result = await response.json();
    if (!response.ok) {
      throw new Error(result.message || 'Profile update failed');
    }

    localStorage.setItem('user', JSON.stringify(result.data));
    return result.data;
  },

  async linkSocialAccount(provider: 'google' | 'facebook', token: string): Promise<void> {
    const authToken = localStorage.getItem('accessToken');
    if (!authToken) throw new Error('Not authenticated');

    const response = await fetch(`${config.apiUrl}/api/auth/link-${provider}`, {
      method: 'POST',
      headers: {
        'Content-Type': 'application/json',
        'Authorization': `Bearer ${authToken}`
      },
      body: JSON.stringify({ [`${provider}Token`]: token })
    });

    if (!response.ok) {
      const result = await response.json();
      throw new Error(result.message || `Failed to link ${provider} account`);
    }
  },

  async unlinkSocialAccount(provider: 'google' | 'facebook'): Promise<void> {
    const authToken = localStorage.getItem('accessToken');
    if (!authToken) throw new Error('Not authenticated');

    const response = await fetch(`${config.apiUrl}/api/auth/unlink-${provider}`, {
      method: 'POST',
      headers: {
        'Authorization': `Bearer ${authToken}`
      }
    });

    if (!response.ok) {
      const result = await response.json();
      throw new Error(result.message || `Failed to unlink ${provider} account`);
    }
  },

  async requestPasswordReset(email: string): Promise<void> {
    const response = await fetch(`${config.apiUrl}/api/auth/forgot-password`, {
      method: 'POST',
      headers: {
        'Content-Type': 'application/json'
      },
      body: JSON.stringify({ email })
    });

    if (!response.ok) {
      const result = await response.json();
      throw new Error(result.message || 'Password reset request failed');
    }
  },

  async resetPassword(token: string, password: string, confirmPassword: string): Promise<void> {
    const response = await fetch(`${config.apiUrl}/api/auth/reset-password`, {
      method: 'POST',
      headers: {
        'Content-Type': 'application/json'
      },
      body: JSON.stringify({ token, password, confirmPassword })
    });

    if (!response.ok) {
      const result = await response.json();
      throw new Error(result.message || 'Password reset failed');
    }
  },

  async verifyEmail(token: string): Promise<void> {
    const response = await fetch(`${config.apiUrl}/api/auth/verify-email?token=${token}`);

    if (!response.ok) {
      const result = await response.json();
      throw new Error(result.message || 'Email verification failed');
    }
  },

  async resendVerification(): Promise<void> {
    const authToken = localStorage.getItem('accessToken');
    if (!authToken) throw new Error('Not authenticated');

    const response = await fetch(`${config.apiUrl}/api/auth/resend-verification`, {
      method: 'POST',
      headers: {
        'Authorization': `Bearer ${authToken}`
      }
    });

    if (!response.ok) {
      const result = await response.json();
      throw new Error(result.message || 'Failed to resend verification email');
    }
  },

  isAuthenticated(): User | null {
    if (typeof window === 'undefined') {
      // Return null during SSR
      return null;
    }
    const token = localStorage.getItem('accessToken');
    const userStr = localStorage.getItem('user');
    
    if (!token || !userStr) {
      return null;
    }

    try {
      return JSON.parse(userStr);
    } catch {
      return null;
    }
  },

  logout(): void {
    localStorage.removeItem('accessToken');
    localStorage.removeItem('refreshToken');
    localStorage.removeItem('user');
  },

  getAuthToken(): string | null {
    if (typeof window === 'undefined') {
      // Return null during SSR
      return null;
    }
    return localStorage.getItem('accessToken');
  },
};
