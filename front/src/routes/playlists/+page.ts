import type { PageLoad } from './$types';
import { playlistsService } from '$lib/services/playlists';

export const load: PageLoad = async ({ url, fetch }) => {
  try {
    const tab = url.searchParams.get('tab') || 'all';
    
    // Only fetch public data during SSR for the "all" tab
    // For "mine" tab, we'll load the data client-side since we need user authentication
    if (tab === 'all') {
      const playlists = await playlistsService.getPlaylists(undefined, undefined, fetch);
      return {
        playlists
      };
    } else {
      // Return empty array for "mine" tab - will be loaded client-side
      return {
        playlists: []
      };
    }
  } catch (error) {
    console.error('Failed to load playlists:', error);
    return {
      playlists: []
    };
  }
};
