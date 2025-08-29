import type { PageLoad } from './$types';
import { getEvents } from '$lib/services/events';

export const load: PageLoad = async ({ url, fetch }) => {
  try {
    const isPublic = url.searchParams.get('public');
    // Only handle explicit public filter during SSR
    const publicFilter = isPublic === 'true' ? true : undefined;
    
    // Load regular events (public + user's own events)
    // The collaborative events will be loaded on the client side
    const events = await getEvents(fetch);
    
    return {
      events
    };
  } catch (error) {
    console.error('Failed to load events:', error);
    return {
      events: []
    };
  }
};
