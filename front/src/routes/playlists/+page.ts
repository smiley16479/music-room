import type { PageLoad } from './$types';
import { playlistsService } from '$lib/services/playlists';

export const load: PageLoad = async ({ url, fetch }) => {
  try {
    const filter = url.searchParams.get('filter') || 'all';
    
    // Only fetch public data during SSR to avoid localStorage issues
    let publicFilter: boolean | undefined = undefined;
    
    if (filter === 'public') publicFilter = true;
    if (filter === 'private') publicFilter = false;
    // Skip 'mine' filter during SSR since we can't access user data
    
    const playlists = await playlistsService.getPlaylists(publicFilter, undefined, fetch);
    
    return {
      playlists
    };
  } catch (error) {
    console.error('Failed to load playlists:', error);
    return {
      playlists: []
    };
  }
};
