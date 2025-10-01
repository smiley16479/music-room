import type { PageLoad } from './$types';
import { getEvent } from '$lib/services/events';
import { error } from '@sveltejs/kit';

// Disable SSR for this page to avoid authentication issues on page reload
export const ssr = false;

export const load: PageLoad = async ({ params, fetch }) => {
  try {
    const event = await getEvent(params.id, fetch);
    
    return {
      event
    };
  } catch (err) {
    
    throw error(404, 'Event not found');
  }
};
