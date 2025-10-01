import type { PageLoad } from './$types';
import { getEvents } from '$lib/services/events';

export const load: PageLoad = async ({ url, fetch }) => {
  try {
    const isPublic = url.searchParams.get('public');
    // Only handle explicit public filter during SSR
    const publicFilter = isPublic === 'true' ? true : undefined;
    
    // Load regular events (public + user's own events) without location data during SSR
    // Location-based filtering will be handled on the client side after location permission is granted
    const events = await getEvents(fetch);
    
    return {
      events
    };
  } catch (error) {
    
    return {
      events: []
    };
  }
};
