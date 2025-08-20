import type { PageLoad } from './$types';
import { friendsService } from '$lib/services/friends';
import type { Friend, Invitation } from '$lib/services/friends';

export const load: PageLoad = async ({ url, fetch }) => {
  let friends: Friend[] = [];
  let pendingInvitations: Invitation[] = [];
  let sentInvitations: Invitation[] = [];
  let error: string | null = null;

  try {
    // Load friends data by default since we need it for notifications/counts
    [friends, pendingInvitations, sentInvitations] = await Promise.all([
      friendsService.getFriends(fetch),
      friendsService.getPendingInvitations(fetch),
      friendsService.getSentInvitations(fetch)
    ]);
  } catch (e: any) {
    // Don't show error for API unavailability during development
    if (e.message !== 'Authentication required') {
      error = null; // Suppress API errors for now
      console.warn('Friends API not available:', e.message);
    } else {
      error = e.message;
    }
  }

  return {
    friends,
    pendingInvitations,
    sentInvitations,
    error
  };
};