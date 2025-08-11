<svelte:head>
	<title>Events - Music Room</title>
	<meta name="description" content="Join live music events and vote for tracks" />
</svelte:head>

<script lang="ts">
	import { onMount } from 'svelte';
	import { page } from '$app/stores';
	import { authService } from '$lib/services/auth';
	import { eventsService, type Event } from '$lib/services/events';
	import { goto } from '$app/navigation';

	let { data } = $props();
	let events: Event[] = $state(data?.events || []);
	let loading = $state(false);
	let error = $state('');
	let user = $state<any>(null);
	let showCreateModal = $state(false);
	let filter: 'all' | 'public' | 'private' = $state('all');

	// Create event form
	let newEvent = $state({
		title: '',
		description: '',
		isPublic: true,
		allowsVoting: true,
		licenseType: 'free' as const,
		startDate: '',
		endDate: '',
		location: ''
	});

	// Update filter based on URL parameter
	$effect(() => {
		const currentFilter = $page.url.searchParams.get('public');
		if (currentFilter === 'true') {
			filter = 'public';
		} else if (currentFilter === 'false') {
			filter = 'private';
		} else {
			filter = 'all';
		}
	});

	// Update events when data changes
	$effect(() => {
		if (data?.events) {
			events = data.events;
		}
	});

	onMount(() => {
		// Initialize user on client side
		user = authService.isAuthenticated();
	});

	async function loadEvents() {
		loading = true;
		error = '';
		try {
			const publicFilter = filter === 'public' ? true : filter === 'private' ? false : undefined;
			events = await eventsService.getEvents(publicFilter);
		} catch (err) {
			error = 'Failed to load events';
			console.error(err);
		} finally {
			loading = false;
		}
	}

	function createEvent(event: SubmitEvent) {
		event.preventDefault();
		if (!user) {
			goto('/auth/login');
			return;
		}

		loading = true;
		error = '';
		eventsService.createEvent(newEvent).then(() => {
			showCreateModal = false;
			// Reset form
			newEvent = {
				title: '',
				description: '',
				isPublic: true,
				allowsVoting: true,
				licenseType: 'free',
				startDate: '',
				endDate: '',
				location: ''
			};
			return loadEvents();
		}).catch((err) => {
			error = err instanceof Error ? err.message : 'Failed to create event';
		}).finally(() => {
			loading = false;
		});
	}

	async function joinEvent(eventId: string) {
		if (!user) {
			goto('/auth/login');
			return;
		}

		try {
			await eventsService.joinEvent(eventId);
			await loadEvents();
		} catch (err) {
			error = err instanceof Error ? err.message : 'Failed to join event';
		}
	}

	function formatDate(dateString: string) {
		return new Date(dateString).toLocaleDateString('en-US', {
			year: 'numeric',
			month: 'short',
			day: 'numeric',
			hour: '2-digit',
			minute: '2-digit'
		});
	}

	function handleFilterChange() {
		loadEvents();
	}
</script>

<div class="container mx-auto px-4 py-8">
	<div class="flex justify-between items-center mb-8">
		<div>
			<h1 class="font-family-main text-4xl font-bold text-gray-800 mb-2">Music Events</h1>
			<p class="text-gray-600">Join live music events and vote for the next tracks</p>
		</div>
		
		{#if user}
		<button 
			onclick={() => showCreateModal = true}
			class="bg-secondary text-white px-6 py-3 rounded-lg font-semibold hover:bg-secondary/80 transition-colors"
		>
			Create Event
		</button>
		{/if}
	</div>

	<!-- Filter Tabs -->
	<div class="flex space-x-4 mb-6">
		<button 
			class="px-4 py-2 rounded-lg font-medium transition-colors {filter === 'all' ? 'bg-secondary text-white' : 'bg-gray-200 text-gray-700 hover:bg-gray-300'}"
			onclick={() => { filter = 'all'; handleFilterChange(); }}
		>
			All Events
		</button>
		<button 
			class="px-4 py-2 rounded-lg font-medium transition-colors {filter === 'public' ? 'bg-secondary text-white' : 'bg-gray-200 text-gray-700 hover:bg-gray-300'}"
			onclick={() => { filter = 'public'; handleFilterChange(); }}
		>
			Public
		</button>
		<button 
			class="px-4 py-2 rounded-lg font-medium transition-colors {filter === 'private' ? 'bg-secondary text-white' : 'bg-gray-200 text-gray-700 hover:bg-gray-300'}"
			onclick={() => { filter = 'private'; handleFilterChange(); }}
		>
			Private
		</button>
	</div>

	{#if error}
	<div class="bg-red-100 border border-red-400 text-red-700 px-4 py-3 rounded mb-6">
		{error}
	</div>
	{/if}

	{#if loading}
	<div class="flex justify-center items-center py-12">
		<div class="animate-spin rounded-full h-8 w-8 border-b-2 border-secondary"></div>
	</div>
	{:else if events.length === 0}
	<div class="text-center py-12">
		<h3 class="text-xl font-semibold text-gray-700 mb-2">No events found</h3>
		<p class="text-gray-500 mb-4">Be the first to create an event!</p>
		{#if user}
		<button 
			onclick={() => showCreateModal = true}
			class="bg-secondary text-white px-6 py-2 rounded-lg font-medium hover:bg-secondary/80 transition-colors"
		>
			Create Event
		</button>
		{/if}
	</div>
	{:else}
	<div class="grid grid-cols-1 md:grid-cols-2 lg:grid-cols-3 gap-6">
		{#each events as event}
		<div class="bg-white rounded-lg shadow-md overflow-hidden hover:shadow-lg transition-shadow">
			<div class="p-6">
				<div class="flex items-start justify-between mb-4">
					<h3 class="text-xl font-bold text-gray-800 line-clamp-2">{event.title}</h3>
					<div class="flex flex-col items-end space-y-1">
						<span class="px-2 py-1 text-xs rounded-full {event.isPublic ? 'bg-green-100 text-green-800' : 'bg-blue-100 text-blue-800'}">
							{event.isPublic ? 'Public' : 'Private'}
						</span>
						{#if event.allowsVoting}
						<span class="px-2 py-1 text-xs rounded-full bg-purple-100 text-purple-800">
							Voting Enabled
						</span>
						{/if}
					</div>
				</div>
				
				{#if event.description}
				<p class="text-gray-600 text-sm mb-4 line-clamp-3">{event.description}</p>
				{/if}
				
				<div class="space-y-2 text-sm text-gray-500 mb-4">
					<div class="flex items-center">
						<span class="font-medium">Host:</span>
						<span class="ml-2">{event.hostName}</span>
					</div>
					
					{#if event.location}
					<div class="flex items-center">
						<span class="font-medium">Location:</span>
						<span class="ml-2">{event.location}</span>
					</div>
					{/if}
					
					{#if event.startDate}
					<div class="flex items-center">
						<span class="font-medium">Starts:</span>
						<span class="ml-2">{formatDate(event.startDate)}</span>
					</div>
					{/if}
					
					<div class="flex items-center">
						<span class="font-medium">Participants:</span>
						<span class="ml-2">{event.participants.length}</span>
					</div>
					
					<div class="flex items-center">
						<span class="font-medium">Tracks:</span>
						<span class="ml-2">{event.playlist.length}</span>
					</div>
				</div>
				
				<div class="flex space-x-3">
					<a 
						href="/events/{event.id}"
						class="flex-1 bg-secondary text-white text-center py-2 px-4 rounded-lg font-medium hover:bg-secondary/80 transition-colors"
					>
						View Event
					</a>
					
					{#if user && !event.participants.some(p => p.userId === user.id)}
					<button 
						onclick={() => joinEvent(event.id)}
						class="flex-1 border border-secondary text-secondary text-center py-2 px-4 rounded-lg font-medium hover:bg-secondary/10 transition-colors"
					>
						Join
					</button>
					{/if}
				</div>
			</div>
		</div>
		{/each}
	</div>
	{/if}
</div>

<!-- Create Event Modal -->
{#if showCreateModal}
<div class="fixed inset-0 bg-black bg-opacity-50 flex items-center justify-center z-50 p-4">
	<div class="bg-white rounded-lg max-w-md w-full max-h-[90vh] overflow-y-auto">
		<div class="p-6">
			<div class="flex justify-between items-center mb-4">
				<h2 class="text-xl font-bold text-gray-800">Create New Event</h2>
				<button 
					onclick={() => showCreateModal = false}
					class="text-gray-400 hover:text-gray-600"
					aria-label="Close modal"
				>
					<svg class="w-6 h-6" fill="none" stroke="currentColor" viewBox="0 0 24 24">
						<path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M6 18L18 6M6 6l12 12"></path>
					</svg>
				</button>
			</div>
			
			<form onsubmit={createEvent} class="space-y-4">
				<div>
					<label for="event-title" class="block text-sm font-medium text-gray-700 mb-1">Event Title</label>
					<input 
						id="event-title"
						type="text" 
						bind:value={newEvent.title}
						required
						class="w-full px-3 py-2 border border-gray-300 rounded-lg focus:outline-none focus:ring-2 focus:ring-secondary"
						placeholder="Enter event title"
					/>
				</div>
				
				<div>
					<label for="event-description" class="block text-sm font-medium text-gray-700 mb-1">Description</label>
					<textarea 
						id="event-description"
						bind:value={newEvent.description}
						rows="3"
						class="w-full px-3 py-2 border border-gray-300 rounded-lg focus:outline-none focus:ring-2 focus:ring-secondary"
						placeholder="Event description (optional)"
					></textarea>
				</div>
				
				<div>
					<label for="event-location" class="block text-sm font-medium text-gray-700 mb-1">Location</label>
					<input 
						id="event-location"
						type="text" 
						bind:value={newEvent.location}
						class="w-full px-3 py-2 border border-gray-300 rounded-lg focus:outline-none focus:ring-2 focus:ring-secondary"
						placeholder="Event location (optional)"
					/>
				</div>
				
				<div class="grid grid-cols-2 gap-4">
					<div>
						<label for="event-start" class="block text-sm font-medium text-gray-700 mb-1">Start Date</label>
						<input 
							id="event-start"
							type="datetime-local" 
							bind:value={newEvent.startDate}
							class="w-full px-3 py-2 border border-gray-300 rounded-lg focus:outline-none focus:ring-2 focus:ring-secondary"
						/>
					</div>
					
					<div>
						<label for="event-end" class="block text-sm font-medium text-gray-700 mb-1">End Date</label>
						<input 
							id="event-end"
							type="datetime-local" 
							bind:value={newEvent.endDate}
							class="w-full px-3 py-2 border border-gray-300 rounded-lg focus:outline-none focus:ring-2 focus:ring-secondary"
						/>
					</div>
				</div>
				
				<div class="space-y-3">
					<div class="flex items-center">
						<input 
							type="checkbox" 
							id="isPublic"
							bind:checked={newEvent.isPublic}
							class="mr-2"
						/>
						<label for="isPublic" class="text-sm text-gray-700">Public event (anyone can find and join)</label>
					</div>
					
					<div class="flex items-center">
						<input 
							type="checkbox" 
							id="allowsVoting"
							bind:checked={newEvent.allowsVoting}
							class="mr-2"
						/>
						<label for="allowsVoting" class="text-sm text-gray-700">Allow track voting</label>
					</div>
				</div>
				
				<div>
					<label for="event-license" class="block text-sm font-medium text-gray-700 mb-1">License Type</label>
					<select 
						id="event-license"
						bind:value={newEvent.licenseType}
						class="w-full px-3 py-2 border border-gray-300 rounded-lg focus:outline-none focus:ring-2 focus:ring-secondary"
					>
						<option value="free">Free (anyone can vote)</option>
						<option value="invited_only">Invited users only</option>
						<option value="location_time">Location & time restricted</option>
					</select>
				</div>
				
				<div class="flex space-x-3 pt-4">
					<button 
						type="button"
						onclick={() => showCreateModal = false}
						class="flex-1 px-4 py-2 border border-gray-300 text-gray-700 rounded-lg hover:bg-gray-50"
					>
						Cancel
					</button>
					<button 
						type="submit"
						disabled={loading}
						class="flex-1 bg-secondary text-white px-4 py-2 rounded-lg hover:bg-secondary/80 disabled:opacity-50"
					>
						{loading ? 'Creating...' : 'Create Event'}
					</button>
				</div>
			</form>
		</div>
	</div>
</div>
{/if}
