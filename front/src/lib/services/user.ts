import { config } from '$lib/config';
import { authService } from './auth';

export interface UserSearchResult {
	id: string;
	displayName?: string;
	avatarUrl?: string;
	bio?: string;
	musicPreferences?: {
		favoriteGenres?: string[];
		favoriteArtists?: string[];
	};
}

export interface PublicUserProfile {
	id: string;
	displayName?: string;
	avatarUrl?: string;
	bio?: string;
	location?: string;
	birthDate?: string;
	musicPreferences?: {
		favoriteGenres?: string[];
		favoriteArtists?: string[];
	};
	createdAt?: string;
	lastSeen?: string;
}

export const userService = {
	async searchUsers(query: string, limit = 20, customFetch?: typeof fetch): Promise<UserSearchResult[]> {
		const token = authService.getAuthToken();
		if (!token) throw new Error('Authentication required');
		
		const fetchFn = customFetch || fetch;
		const params = new URLSearchParams({
			q: query,
			limit: limit.toString()
		});
		
		try {
			const response = await fetchFn(`${config.apiUrl}/api/users/search?${params}`, {
				headers: { 'Authorization': `Bearer ${token}` }
			});
			
			if (!response.ok) {
				if (response.status === 404) {
					
					return [];
				}
				throw new Error('Failed to search users');
			}
			
			const result = await response.json();
			return result.data || [];
		} catch (error) {
			
			return [];
		}
	},

	async getUserProfile(userId: string, customFetch?: typeof fetch): Promise<PublicUserProfile> {
		const token = authService.getAuthToken();
		const fetchFn = customFetch || fetch;
		
		const headers: Record<string, string> = {};
		if (token) {
			headers['Authorization'] = `Bearer ${token}`;
		}
		
		try {
			const response = await fetchFn(`${config.apiUrl}/api/users/${userId}`, {
				headers
			});
			
			if (!response.ok) {
				if (response.status === 404) {
					throw new Error('User not found');
				}
				throw new Error('Failed to load user profile');
			}
			
			const result = await response.json();
			return result.data;
		} catch (error) {
			
			throw error;
		}
	}
};
