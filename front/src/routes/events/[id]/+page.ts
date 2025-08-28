import type { PageLoad } from './$types';
import { getEvent } from '$lib/services/events';
import { error } from '@sveltejs/kit';

export const load: PageLoad = async ({ params, fetch }) => {
  try {
    const event = await getEvent(params.id, fetch);
    
    return {
      event
    };
  } catch (err) {
    console.error('Failed to load event:', err);
    throw error(404, 'Event not found');
  }
};
