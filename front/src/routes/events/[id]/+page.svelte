<svelte:head>
	<title>{event?.title || 'Event'} - Music Room</title>
	<meta name="description" content="Join the music event and vote for tracks" />
</svelte:head>

<script lang="ts">
	import { onMount, onDestroy } from 'svelte';
	import { page } from '$app/stores';
	import { authService } from '$lib/services/auth';
	import { eventsService, type Event, type Track } from '$lib/services/events';
	import { goto } from '$app/navigation';

	let event = $state<Event | null>(null);
	let loading = $state(true);
	let error = $state('');
	let user = $state<any>(null);
	let showAddTrackModal = $state(false);
	let votingCooldown = $state(new Map<string, boolean>());

	// Add track form
	let newTrack = $state({
		title: '',
		artist: '',
		album: '',
		duration: 0,
		thumbnailUrl: '',
		streamUrl: ''
	});

	const eventId = $derived($page.params.id);

	onMount(() => {
		// Initialize user on client side
		user = authService.isAuthenticated();
		
		loadEvent();
		// Set up real-time updates (WebSocket would be ideal here)
		const interval = setInterval(loadEvent, 5000);
		return () => clearInterval(interval);
	});

	async function loadEvent() {
		if (!eventId) return;
		
		try {
			event = await eventsService.getEvent(eventId);
			loading = false;
		} catch (err) {
			error = err instanceof Error ? err.message : 'Failed to load event';
			loading = false;
		}
	}

	async function joinEvent() {
		if (!user || !eventId) {
			goto('/auth/login');
			return;
		}

		try {
			await eventsService.joinEvent(eventId);
			await loadEvent();
		} catch (err) {
			error = err instanceof Error ? err.message : 'Failed to join event';
		}
	}

	async function leaveEvent() {
		if (!user || !eventId) return;

		try {
			await eventsService.leaveEvent(eventId);
			await loadEvent();
		} catch (err) {
			error = err instanceof Error ? err.message : 'Failed to leave event';
		}
	}

	async function voteForTrack(trackId: string) {
		if (!user || !eventId || votingCooldown.get(trackId)) {
			if (!user) goto('/auth/login');
			return;
		}

		// Prevent rapid voting
		votingCooldown.set(trackId, true);
		setTimeout(() => votingCooldown.delete(trackId), 2000);

		try {
			await eventsService.voteForTrack(eventId, trackId);
			await loadEvent();
		} catch (err) {
			error = err instanceof Error ? err.message : 'Failed to vote for track';
		}
	}

	function addTrack(event: SubmitEvent) {
		event.preventDefault();
		if (!user || !eventId) {
			goto('/auth/login');
			return;
		}

		eventsService.addTrackToEvent(eventId, newTrack).then(() => {
			showAddTrackModal = false;
			// Reset form
			newTrack = {
				title: '',
				artist: '',
				album: '',
				duration: 0,
				thumbnailUrl: '',
				streamUrl: ''
			};
			return loadEvent();
		}).catch((err) => {
			error = err instanceof Error ? err.message : 'Failed to add track';
		});
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

	function formatDuration(seconds: number) {
		const minutes = Math.floor(seconds / 60);
		const remainingSeconds = seconds % 60;
		return `${minutes}:${remainingSeconds.toString().padStart(2, '0')}`;
	}

	const isParticipant = $derived(user && event?.participants?.some((p: any) => p.userId === user.id));
	const isHost = $derived(user && event?.hostId === user.id);
	const canVote = $derived(event?.allowsVoting && isParticipant);
	const sortedPlaylist = $derived(event?.playlist?.sort((a: any, b: any) => b.votes - a.votes) || []);
</script>

{#if loading}
<div class="flex justify-center items-center min-h-[400px]">
	<div class="animate-spin rounded-full h-12 w-12 border-b-2 border-secondary"></div>
</div>
{:else if error && !event}
<div class="container mx-auto px-4 py-8">
	<div class="bg-red-100 border border-red-400 text-red-700 px-4 py-3 rounded">
		{error}
	</div>
</div>
{:else if event}
<div class="container mx-auto px-4 py-8">
	<!-- Event Header -->
	<div class="bg-white rounded-lg shadow-md p-6 mb-8">
		<div class="flex justify-between items-start mb-4">
			<div>
				<h1 class="font-family-main text-3xl font-bold text-gray-800 mb-2">{event.title}</h1>
				{#if event.description}
				<p class="text-gray-600 mb-4">{event.description}</p>
				{/if}
			</div>
			
			<div class="flex flex-col items-end space-y-2">
				<div class="flex space-x-2">
					<span class="px-3 py-1 text-sm rounded-full {event.isPublic ? 'bg-green-100 text-green-800' : 'bg-blue-100 text-blue-800'}">
						{event.isPublic ? 'Public' : 'Private'}
					</span>
					{#if event.allowsVoting}
					<span class="px-3 py-1 text-sm rounded-full bg-purple-100 text-purple-800">
						Voting Enabled
					</span>
					{/if}
				</div>
				
				{#if user}
					{#if isParticipant}
						{#if !isHost}
						<button 
							onclick={leaveEvent}
							class="border border-red-500 text-red-500 px-4 py-2 rounded-lg hover:bg-red-50 transition-colors"
						>
							Leave Event
						</button>
						{/if}
					{:else}
						<button 
							onclick={joinEvent}
							class="bg-secondary text-white px-4 py-2 rounded-lg hover:bg-secondary/80 transition-colors"
						>
							Join Event
						</button>
					{/if}
				{/if}
			</div>
		</div>
		
		<div class="grid grid-cols-1 md:grid-cols-4 gap-4 text-sm text-gray-600">
			<div>
				<span class="font-medium">Host:</span>
				<span class="ml-1">{event.hostName}</span>
			</div>
			
			{#if event.location}
			<div>
				<span class="font-medium">Location:</span>
				<span class="ml-1">{event.location}</span>
			</div>
			{/if}
			
			{#if event.startDate}
			<div>
				<span class="font-medium">Start:</span>
				<span class="ml-1">{formatDate(event.startDate)}</span>
			</div>
			{/if}
			
			<div>
				<span class="font-medium">Participants:</span>
				<span class="ml-1">{event.participants.length}</span>
			</div>
		</div>
	</div>

	{#if error}
	<div class="bg-red-100 border border-red-400 text-red-700 px-4 py-3 rounded mb-6">
		{error}
	</div>
	{/if}

	<div class="grid grid-cols-1 lg:grid-cols-3 gap-8">
		<!-- Playlist -->
		<div class="lg:col-span-2">
			<div class="bg-white rounded-lg shadow-md p-6">
				<div class="flex justify-between items-center mb-6">
					<h2 class="text-xl font-bold text-gray-800">Playlist</h2>
					{#if isParticipant}
					<button 
						onclick={() => showAddTrackModal = true}
						class="bg-secondary text-white px-4 py-2 rounded-lg hover:bg-secondary/80 transition-colors"
					>
						Add Track
					</button>
					{/if}
				</div>
				
				{#if event.currentTrack}
				<div class="bg-gradient-to-r from-secondary/10 to-purple-100 rounded-lg p-4 mb-6">
					<h3 class="font-semibold text-gray-800 mb-2">🎵 Now Playing</h3>
					<div class="flex items-center space-x-4">
						{#if event.currentTrack.thumbnailUrl}
						<img src={event.currentTrack.thumbnailUrl} alt="Current track" class="w-12 h-12 rounded object-cover" />
						{/if}
						<div>
							<p class="font-medium text-gray-800">{event.currentTrack.title}</p>
							<p class="text-sm text-gray-600">{event.currentTrack.artist}</p>
						</div>
					</div>
				</div>
				{/if}
				
				{#if sortedPlaylist.length === 0}
				<div class="text-center py-8">
					<p class="text-gray-500 mb-4">No tracks in the playlist yet</p>
					{#if isParticipant}
					<button 
						onclick={() => showAddTrackModal = true}
						class="bg-secondary text-white px-6 py-2 rounded-lg hover:bg-secondary/80 transition-colors"
					>
						Add the first track
					</button>
					{/if}
				</div>
				{:else}
				<div class="space-y-3">
					{#each sortedPlaylist as track, index}
					<div class="flex items-center space-x-4 p-3 border border-gray-200 rounded-lg hover:bg-gray-50 transition-colors">
						<div class="w-8 h-8 bg-gray-200 rounded-full flex items-center justify-center text-sm font-semibold text-gray-600">
							{index + 1}
						</div>
						
						{#if track.thumbnailUrl}
						<img src={track.thumbnailUrl} alt={track.title} class="w-12 h-12 rounded object-cover" />
						{:else}
						<div class="w-12 h-12 bg-gray-200 rounded flex items-center justify-center">
							<svg class="w-6 h-6 text-gray-400" fill="none" stroke="currentColor" viewBox="0 0 24 24">
								<path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M9 19V6l12-3v13M9 19c0 1.105-1.343 2-3 2s-3-.895-3-2 1.343-2 3-2 3 .895 3 2z"></path>
							</svg>
						</div>
						{/if}
						
						<div class="flex-1">
							<h4 class="font-medium text-gray-800">{track.title}</h4>
							<p class="text-sm text-gray-600">{track.artist}</p>
							{#if track.album}
							<p class="text-xs text-gray-500">{track.album}</p>
							{/if}
						</div>
						
						<div class="flex items-center space-x-3">
							{#if track.duration}
							<span class="text-sm text-gray-500">{formatDuration(track.duration)}</span>
							{/if}
							
							{#if canVote}
							<button 
								onclick={() => voteForTrack(track.id)}
								disabled={votingCooldown.get(track.id)}
								class="flex items-center space-x-1 px-3 py-1 bg-purple-100 text-purple-700 rounded-full hover:bg-purple-200 transition-colors disabled:opacity-50"
							>
								<svg class="w-4 h-4" fill="none" stroke="currentColor" viewBox="0 0 24 24">
									<path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M5 15l7-7 7 7"></path>
								</svg>
								<span class="text-sm font-medium">{track.votes}</span>
							</button>
							{:else}
							<div class="flex items-center space-x-1 px-3 py-1 bg-gray-100 text-gray-600 rounded-full">
								<svg class="w-4 h-4" fill="none" stroke="currentColor" viewBox="0 0 24 24">
									<path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M5 15l7-7 7 7"></path>
								</svg>
								<span class="text-sm">{track.votes}</span>
							</div>
							{/if}
						</div>
					</div>
					{/each}
				</div>
				{/if}
			</div>
		</div>
		
		<!-- Participants -->
		<div class="lg:col-span-1">
			<div class="bg-white rounded-lg shadow-md p-6">
				<h2 class="text-xl font-bold text-gray-800 mb-4">Participants ({event.participants.length})</h2>
				
				<div class="space-y-3">
					{#each event.participants as participant}
					<div class="flex items-center space-x-3">
						{#if participant.profilePicture}
						<img src={participant.profilePicture} alt={participant.displayName} class="w-10 h-10 rounded-full object-cover" />
						{:else}
						<div class="w-10 h-10 rounded-full bg-secondary/20 flex items-center justify-center">
							<span class="text-sm font-semibold">{participant.displayName.charAt(0)}</span>
						</div>
						{/if}
						
						<div class="flex-1">
							<p class="font-medium text-gray-800">{participant.displayName}</p>
							<p class="text-xs text-gray-500">
								{participant.role === 'host' ? 'Host' : 'Participant'} • 
								Joined {formatDate(participant.joinedAt)}
							</p>
						</div>
					</div>
					{/each}
				</div>
			</div>
		</div>
	</div>
</div>

<!-- Add Track Modal -->
{#if showAddTrackModal}
<div class="fixed inset-0 bg-black bg-opacity-50 flex items-center justify-center z-50 p-4">
	<div class="bg-white rounded-lg max-w-md w-full">
		<div class="p-6">
			<div class="flex justify-between items-center mb-4">
				<h2 class="text-xl font-bold text-gray-800">Add Track</h2>
				<button 
					onclick={() => showAddTrackModal = false}
					class="text-gray-400 hover:text-gray-600"
					aria-label="Close modal"
				>
					<svg class="w-6 h-6" fill="none" stroke="currentColor" viewBox="0 0 24 24">
						<path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M6 18L18 6M6 6l12 12"></path>
					</svg>
				</button>
			</div>
			
			<form onsubmit={addTrack} class="space-y-4">
				<div>
					<label for="track-title" class="block text-sm font-medium text-gray-700 mb-1">Track Title</label>
					<input 
						id="track-title"
						type="text" 
						bind:value={newTrack.title}
						required
						class="w-full px-3 py-2 border border-gray-300 rounded-lg focus:outline-none focus:ring-2 focus:ring-secondary"
						placeholder="Enter track title"
					/>
				</div>
				
				<div>
					<label for="track-artist" class="block text-sm font-medium text-gray-700 mb-1">Artist</label>
					<input 
						id="track-artist"
						type="text" 
						bind:value={newTrack.artist}
						required
						class="w-full px-3 py-2 border border-gray-300 rounded-lg focus:outline-none focus:ring-2 focus:ring-secondary"
						placeholder="Enter artist name"
					/>
				</div>
				
				<div>
					<label for="track-album" class="block text-sm font-medium text-gray-700 mb-1">Album</label>
					<input 
						id="track-album"
						type="text" 
						bind:value={newTrack.album}
						class="w-full px-3 py-2 border border-gray-300 rounded-lg focus:outline-none focus:ring-2 focus:ring-secondary"
						placeholder="Enter album name (optional)"
					/>
				</div>
				
				<div class="grid grid-cols-2 gap-4">
					<div>
						<label for="track-duration" class="block text-sm font-medium text-gray-700 mb-1">Duration (seconds)</label>
						<input 
							id="track-duration"
							type="number" 
							bind:value={newTrack.duration}
							min="0"
							class="w-full px-3 py-2 border border-gray-300 rounded-lg focus:outline-none focus:ring-2 focus:ring-secondary"
							placeholder="180"
						/>
					</div>
					
					<div>
						<label for="track-thumbnail" class="block text-sm font-medium text-gray-700 mb-1">Thumbnail URL</label>
						<input 
							id="track-thumbnail"
							type="url" 
							bind:value={newTrack.thumbnailUrl}
							class="w-full px-3 py-2 border border-gray-300 rounded-lg focus:outline-none focus:ring-2 focus:ring-secondary"
							placeholder="https://..."
						/>
					</div>
				</div>
				
				<div>
					<label for="track-stream" class="block text-sm font-medium text-gray-700 mb-1">Stream URL</label>
					<input 
						id="track-stream"
						type="url" 
						bind:value={newTrack.streamUrl}
						class="w-full px-3 py-2 border border-gray-300 rounded-lg focus:outline-none focus:ring-2 focus:ring-secondary"
						placeholder="https://..."
					/>
				</div>
				
				<div class="flex space-x-3 pt-4">
					<button 
						type="button"
						onclick={() => showAddTrackModal = false}
						class="flex-1 px-4 py-2 border border-gray-300 text-gray-700 rounded-lg hover:bg-gray-50"
					>
						Cancel
					</button>
					<button 
						type="submit"
						class="flex-1 bg-secondary text-white px-4 py-2 rounded-lg hover:bg-secondary/80"
					>
						Add Track
					</button>
				</div>
			</form>
		</div>
	</div>
</div>
{/if}
{/if}
