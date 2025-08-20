import { userService } from '$lib/services/user';
import { friendsService, type Friend } from '$lib/services/friends';
import { error } from '@sveltejs/kit';

export const load = async ({ params, fetch }: { params: any, fetch: any }) => {
  const userId = params.id;

  if (!userId) {
    throw error(404, 'User not found');
  }

  try {
    // Load user profile and check if we're already friends
    const [userProfile, friends] = await Promise.all([
      userService.getUserProfile(userId, fetch),
      friendsService.getFriends(fetch).catch(() => [] as Friend[]) // Don't fail if not authenticated
    ]);

    const isAlreadyFriend = friends.some((friend: Friend) => friend.id === userId);

    return {
      userProfile,
      isAlreadyFriend,
      userId
    };
  } catch (e: any) {
    if (e.message === 'User not found') {
      throw error(404, 'User not found');
    }
    throw error(500, 'Failed to load user profile');
  }
};
