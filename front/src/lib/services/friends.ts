import { config } from '$lib/config';
import { authService } from './auth';

export interface Friend {
	id: string;
	displayName: string;
	avatarUrl?: string;
	bio?: string;
	status: 'accepted' | 'pending' | 'blocked';
	since?: string;
}

export interface Invitation {
	id: string;
	type: 'event' | 'playlist' | 'friend';
	status: 'pending' | 'accepted' | 'declined' | 'expired';
	message?: string;
	inviter: {
		id: string;
		displayName?: string;
		avatarUrl?: string;
	};
	invitee: {
		id: string;
		displayName?: string;
		avatarUrl?: string;
	};
	createdAt: string;
	updatedAt: string;
	expiresAt?: string;
}

export const friendsService = {
	async getFriends(customFetch?: typeof fetch): Promise<Friend[]> {
		const token = authService.getAuthToken();
		if (!token) throw new Error('Authentication required');
		
		const fetchFn = customFetch || fetch;
		try {
			const response = await fetchFn(`${config.apiUrl}/api/users/me/friends`, {
				headers: { 'Authorization': `Bearer ${token}` }
			});
			if (!response.ok) {
				if (response.status === 404) {
					console.warn('Friends API not available, returning empty list');
					return [];
				}
				throw new Error('Failed to fetch friends');
			}
			const result = await response.json();
			return result.data || [];
		} catch (error) {
			console.error('Error fetching friends:', error);
			return [];
		}
	},

	async getPendingInvitations(customFetch?: typeof fetch): Promise<Invitation[]> {
		const token = authService.getAuthToken();
		if (!token) throw new Error('Authentication required');
		
		const fetchFn = customFetch || fetch;
		try {
			const response = await fetchFn(`${config.apiUrl}/api/invitations/received?type=friend&status=pending`, {
				headers: { 'Authorization': `Bearer ${token}` }
			});
			if (!response.ok) {
				if (response.status === 404) {
					console.warn('Invitations API not available, returning empty list');
					return [];
				}
				throw new Error('Failed to fetch pending invitations');
			}
			const result = await response.json();
			return result.data || [];
		} catch (error) {
			console.error('Error fetching pending invitations:', error);
			return [];
		}
	},

	async getSentInvitations(customFetch?: typeof fetch): Promise<Invitation[]> {
		const token = authService.getAuthToken();
		if (!token) throw new Error('Authentication required');
		
		const fetchFn = customFetch || fetch;
		try {
			const response = await fetchFn(`${config.apiUrl}/api/invitations/sent?type=friend&status=pending`, {
				headers: { 'Authorization': `Bearer ${token}` }
			});
			if (!response.ok) {
				if (response.status === 404) {
					console.warn('Invitations API not available, returning empty list');
					return [];
				}
				throw new Error('Failed to fetch sent invitations');
			}
			const result = await response.json();
			return result.data || [];
		} catch (error) {
			console.error('Error fetching sent invitations:', error);
			return [];
		}
	},

	async sendInvitation(receiverId: string, message?: string, customFetch?: typeof fetch): Promise<Invitation> {
		const token = authService.getAuthToken();
		if (!token) throw new Error('Authentication required');
		
		const fetchFn = customFetch || fetch;
		const response = await fetchFn(`${config.apiUrl}/api/invitations`, {
			method: 'POST',
			headers: {
				'Content-Type': 'application/json',
				'Authorization': `Bearer ${token}`
			},
			body: JSON.stringify({ 
				inviteeId: receiverId,
				type: 'friend',
				message
			})
		});
		if (!response.ok) {
			const result = await response.json();
			throw new Error(result.message || 'Failed to send invitation');
		}
		const result = await response.json();
		return result.data;
	},

	async respondToInvitation(invitationId: string, accept: boolean, customFetch?: typeof fetch): Promise<void> {
		const token = authService.getAuthToken();
		if (!token) throw new Error('Authentication required');
		
		const fetchFn = customFetch || fetch;
		const response = await fetchFn(`${config.apiUrl}/api/invitations/${invitationId}/respond`, {
			method: 'PATCH',
			headers: {
				'Content-Type': 'application/json',
				'Authorization': `Bearer ${token}`
			},
			body: JSON.stringify({ status: accept ? 'accepted' : 'declined' })
		});
		if (!response.ok) {
			const result = await response.json();
			throw new Error(result.message || 'Failed to respond to invitation');
		}
	},

	async removeFriend(friendId: string, customFetch?: typeof fetch): Promise<void> {
		const token = authService.getAuthToken();
		if (!token) throw new Error('Authentication required');
		
		const fetchFn = customFetch || fetch;
		const response = await fetchFn(`${config.apiUrl}/api/users/me/friends/${friendId}`, {
			method: 'DELETE',
			headers: {
				'Authorization': `Bearer ${token}`
			}
		});
		if (!response.ok) {
			const result = await response.json();
			throw new Error(result.message || 'Failed to remove friend');
		}
	},

	async cancelInvitation(invitationId: string, customFetch?: typeof fetch): Promise<void> {
		const token = authService.getAuthToken();
		if (!token) throw new Error('Authentication required');
		
		const fetchFn = customFetch || fetch;
		const response = await fetchFn(`${config.apiUrl}/api/invitations/${invitationId}/cancel`, {
			method: 'DELETE',
			headers: {
				'Authorization': `Bearer ${token}`
			}
		});
		if (!response.ok) {
			const result = await response.json();
			throw new Error(result.message || 'Failed to cancel invitation');
		}
	}
};