import { getEvent } from '$lib/services/events.js';
import { error } from '@sveltejs/kit';

export async function load({ params }) {
	try {
		const event = await getEvent(params.id);
		
		return {
			event
		};
	} catch (err) {
		console.error('Failed to load event:', err);
		throw error(404, 'Event not found');
	}
}
