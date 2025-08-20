<svelte:head>
	<title>{event?.name || event?.title || 'Event'} - Music Room</title>
	<meta name="description" content="Join the live music event and vote for tracks" />
</svelte:head>

<script lang="ts">
	import { onMount, onDestroy } from 'svelte';
	import { page } from '$app/stores';
	import { goto } from '$app/navigation';
	import { authStore } from '$lib/stores/auth';
	import { authService } from '$lib/services/auth';
	import { 
		getEvent, 
		joinEvent as joinEventAPI, 
		leaveEvent as leaveEventAPI,
		voteForTrackSimple,
		removeVote,
		getVotingResults,
		addTrackToEvent,
		inviteToEvent,
		type Event,
		type VoteResult 
	} from '$lib/services/events';
	import { eventSocketService } from '$lib/services/event-socket';

	interface PageData {
		event?: Event;
	}

	let { data }: { data: PageData } = $props();
	let event: Event | null = $state(data.event || null);
	let user = $derived($authStore);
	let loading = $state(false);
	let error = $state('');
	let votingResults: VoteResult[] = $state([]);
	let showInviteModal = $state(false);
	let showAddTrackModal = $state(false);
	let inviteEmails = $state('');
	let votingCooldown = new Set<string>();
	
	let newTrack = $state({
		title: '',
		artist: '',
		album: '',
		duration: 0,
		thumbnailUrl: '',
		streamUrl: ''
	});

	let eventId = $derived($page.params.id);
	let isParticipating = $derived(
		user && event && event.participants?.some((p: any) => p.id === user.id)
	);
	let isCreator = $derived(user && event && event.creatorId === user.id);

	// Real-time connection status
	let socketConnected = $state(false);

	// Initialize event data and socket connections
	onMount(async () => {
		// Load initial event data from props or fetch it
		if (data?.event) {
			event = data.event;
		} else {
			await loadEvent();
		}

		// Connect to socket if user is authenticated and has a valid token
		if (user && eventId && authService.getAuthToken()) {
			try {
				await eventSocketService.connect();
				eventSocketService.joinEventRoom(eventId);
				socketConnected = true;

				// Setup socket listeners
				eventSocketService.onEventUpdated((updatedEvent) => {
					event = updatedEvent;
				});

				eventSocketService.onVotingUpdated((results) => {
					votingResults = results;
				});

				eventSocketService.onParticipantJoined((participant) => {
					if (event && !event.participants.find(p => p.id === participant.id)) {
						event.participants = [...event.participants, participant];
					}
				});

				eventSocketService.onParticipantLeft((user) => {
					if (event) {
						event.participants = event.participants.filter(p => p.id !== user.id);
					}
				});

				eventSocketService.onTrackAdded((track) => {
					if (event && !event.playlist.find(t => t.id === track.id)) {
						event.playlist = [...event.playlist, track];
					}
				});

				eventSocketService.onTrackVoted((vote) => {
					if (event) {
						const track = event.playlist.find(t => t.id === vote.trackId);
						if (track) {
							track.voteCount = (track.voteCount || 0) + 1;
							event.playlist = [...event.playlist];
						}
					}
				});
			} catch (error) {
				console.error('Failed to connect to socket:', error);
				socketConnected = false;
				// Continue without real-time features
			}
		} else {
			console.warn('Socket connection skipped: user not authenticated or no event ID');
		}
	});

	onDestroy(() => {
		if (eventId) {
			eventSocketService.leaveEventRoom(eventId);
		}
		eventSocketService.disconnect();
	});

	// Load event data
	async function loadEvent() {
		if (!eventId) return;
		
		loading = true;
		error = '';
		
		try {
			const loadedEvent = await getEvent(eventId);
			
			// Transform event data to ensure compatibility
			event = {
				...loadedEvent,
				title: loadedEvent.title || loadedEvent.name,
				isPublic: loadedEvent.visibility === 'public',
				hostId: loadedEvent.hostId || loadedEvent.creatorId,
				hostName: loadedEvent.creator?.displayName || 'Unknown Host',
				startDate: loadedEvent.startDate || loadedEvent.eventDate,
				location: loadedEvent.location || loadedEvent.locationName,
				allowsVoting: loadedEvent.allowsVoting !== false, // Default to true
				playlist: (loadedEvent.playlist || []).map(track => ({
					...track,
					voteCount: track.voteCount || track.votes || 0,
					votes: track.voteCount || track.votes || 0
				})),
				participants: (loadedEvent.participants || []).map(participant => ({
					...participant,
					userId: participant.userId || participant.id,
					username: participant.username || participant.displayName
				}))
			};
			
			// Load voting results if user can vote
			if (user && isParticipant && event.allowsVoting) {
				votingResults = await getVotingResults(eventId);
			}
		} catch (err) {
			error = err instanceof Error ? err.message : 'Failed to load event';
		} finally {
			loading = false;
		}
	}

	async function joinEvent() {
		if (!user || !eventId) {
			goto('/auth/login');
			return;
		}

		try {
			await joinEventAPI(eventId);
			await loadEvent();
		} catch (err) {
			error = err instanceof Error ? err.message : 'Failed to join event';
		}
	}

	async function leaveEvent() {
		if (!user || !eventId) return;

		try {
			await leaveEventAPI(eventId);
			await loadEvent();
		} catch (err) {
			error = err instanceof Error ? err.message : 'Failed to leave event';
		}
	}

	async function handleVoteForTrack(trackId: string) {
		if (!user || !eventId || votingCooldown.has(trackId)) {
			if (!user) goto('/auth/login');
			return;
		}

		// Prevent rapid voting
		votingCooldown.add(trackId);
		setTimeout(() => votingCooldown.delete(trackId), 2000);

		try {
			await voteForTrackSimple(eventId, trackId);
			await loadEvent();
		} catch (err) {
			error = err instanceof Error ? err.message : 'Failed to vote for track';
		}
	}

	async function addTrack(event: SubmitEvent) {
		event.preventDefault();
		if (!user || !eventId) {
			goto('/auth/login');
			return;
		}

		try {
			await addTrackToEvent(eventId, newTrack);
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
			await loadEvent();
		} catch (err) {
			error = err instanceof Error ? err.message : 'Failed to add track';
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

	function formatDuration(seconds: number) {
		const minutes = Math.floor(seconds / 60);
		const remainingSeconds = seconds % 60;
		return `${minutes}:${remainingSeconds.toString().padStart(2, '0')}`;
	}

	// Helper functions for avatar colors
	function getAvatarColor(name: string): string {
		const colors = [
			'#FF6B6B', '#4ECDC4', '#45B7D1', '#96CEB4', '#FFEAA7',
			'#DDA0DD', '#98D8C8', '#F7DC6F', '#BB8FCE', '#85C1E9'
		];
		let hash = 0;
		for (let i = 0; i < name.length; i++) {
			hash = name.charCodeAt(i) + ((hash << 5) - hash);
		}
		return colors[Math.abs(hash) % colors.length];
	}

	function getAvatarColorSecondary(name: string): string {
		const colors = [
			'#FF5252', '#26A69A', '#2196F3', '#66BB6A', '#FFD54F',
			'#BA68C8', '#4DB6AC', '#FDD835', '#AB47BC', '#42A5F5'
		];
		let hash = 0;
		for (let i = 0; i < name.length; i++) {
			hash = name.charCodeAt(i) + ((hash << 5) - hash);
		}
		return colors[Math.abs(hash) % colors.length];
	}

	function getAvatarLetter(name: string): string {
		return name.charAt(0).toUpperCase();
	}

	// Update computed properties to work with both old and new data structures
	const isParticipant = $derived(user && event?.participants?.some((p: any) => (p.id || p.userId) === user.id));
	const isHost = $derived(user && event && ((event as any).hostId === user.id || event.creatorId === user.id));
	const canVote = $derived(event && ((event as any).allowsVoting !== false) && isParticipant); // Default to true if not specified
	const sortedPlaylist = $derived(event?.playlist?.sort((a: any, b: any) => (b.voteCount || b.votes || 0) - (a.voteCount || a.votes || 0)) || []);
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
		<div class="flex items-start space-x-6">
			{#if event.coverImageUrl}
			<img src={event.coverImageUrl} alt={event.title} class="w-32 h-32 rounded-lg object-cover" />
			{:else}
			<div class="w-32 h-32 bg-gradient-to-br from-secondary/20 to-purple-300 rounded-lg flex items-center justify-center">
				<svg class="w-16 h-16 text-white" fill="none" stroke="currentColor" viewBox="0 0 24 24">
					<path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M19 11a7 7 0 01-7 7m0 0a7 7 0 01-7-7m7 7v4m0 0H8m4 0h4m-4-8a3 3 0 01-3-3V5a3 3 0 116 0v6a3 3 0 01-3 3z"></path>
				</svg>
			</div>
			{/if}
			
			<div class="flex-1">
				<div class="flex justify-between items-start mb-4">
					<div>
						<h1 class="font-family-main text-3xl font-bold text-gray-800 mb-2">{event.title}</h1>
						{#if event.description}
						<p class="text-gray-600 mb-4">{event.description}</p>
						{/if}
					</div>
					
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
				</div>
				
				<div class="grid grid-cols-2 md:grid-cols-4 gap-4 text-sm text-gray-600 mb-4">
					<div>
						<span class="font-medium">Host:</span>
						<span class="ml-1">{event?.hostName}</span>
					</div>
					
					{#if event?.location}
					<div>
						<span class="font-medium">Location:</span>
						<span class="ml-1">{event.location}</span>
					</div>
					{/if}
					
					{#if event?.startDate}
					<div>
						<span class="font-medium">Start:</span>
						<span class="ml-1">{formatDate(event.startDate)}</span>
					</div>
					{/if}
					
					<div>
						<span class="font-medium">Participants:</span>
						<span class="ml-1">{event?.participants?.length || 0}</span>
					</div>
				</div>
				
				{#if user}
				<div class="flex space-x-3">
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
				</div>
				{/if}
			</div>
		</div>
		
		<!-- Event Status -->
		{#if isParticipant}
			<div class="mt-6 p-4 bg-gradient-to-r from-secondary/5 to-secondary/10 rounded-lg border border-secondary/20">
				<div class="flex items-center justify-between mb-3">
					<h3 class="font-semibold text-secondary">Event Status</h3>
					{#if event?.status === 'live'}
						<div class="flex items-center text-sm text-green-600">
							<div class="w-2 h-2 bg-green-500 rounded-full mr-2"></div>
							Live
						</div>
					{/if}
				</div>
				
				{#if event?.currentTrack}
					<div class="text-sm text-gray-600">
						<span class="font-medium">Now Playing:</span>
						<span class="ml-2">{event.currentTrack.title} by {event.currentTrack.artist}</span>
					</div>
				{:else}
					<p class="text-sm text-gray-600">No track currently playing. Add some music to get started! 🎵</p>
				{/if}
				
				<div class="mt-2 text-xs text-gray-500">
					💡 {canVote ? 'You can vote for tracks to influence the playlist order.' : 'Join the event to participate in voting!'}
				</div>
			</div>
		{/if}
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
					<div>
						<h2 class="text-xl font-bold text-gray-800">Event Playlist</h2>
						<p class="text-sm text-gray-600">
							{sortedPlaylist.length} track{sortedPlaylist.length !== 1 ? 's' : ''} 
							{canVote ? '• Vote to prioritize tracks' : '• Join to participate in voting'}
						</p>
					</div>
					{#if isParticipant}
					<button 
						onclick={() => showAddTrackModal = true}
						class="bg-secondary text-white px-4 py-2 rounded-lg hover:bg-secondary/80 transition-colors flex items-center space-x-2"
					>
						<svg class="w-4 h-4" fill="none" stroke="currentColor" viewBox="0 0 24 24">
							<path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M12 4v16m8-8H4"></path>
						</svg>
						<span>Add Track</span>
					</button>
					{/if}
				</div>
				
				{#if sortedPlaylist.length === 0}
				<div class="text-center py-12">
					<div class="w-16 h-16 bg-gray-100 rounded-full flex items-center justify-center mx-auto mb-4">
						<svg class="w-8 h-8 text-gray-400" fill="none" stroke="currentColor" viewBox="0 0 24 24">
							<path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M9 19V6l12-3v13M9 19c0 1.105-1.343 2-3 2s-3-.895-3-2 1.343-2 3-2 3 .895 3 2z"></path>
						</svg>
					</div>
					<h3 class="text-lg font-semibold text-gray-700 mb-2">No tracks yet</h3>
					<p class="text-gray-500 mb-4">Be the first to add music to this event!</p>
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
				<div class="space-y-2">
					{#each sortedPlaylist as track, index}
					<div class="flex items-center space-x-4 p-4 border border-gray-200 rounded-lg hover:bg-gray-50 transition-colors {event?.currentTrack?.id === track.id ? 'border-secondary bg-secondary/5' : ''}">
						<div class="w-8 h-8 rounded-full flex items-center justify-center text-sm font-semibold {event?.currentTrack?.id === track.id ? 'bg-secondary text-white' : 'bg-gray-200 text-gray-600'}">
							{#if event?.currentTrack?.id === track.id}
								<!-- Now playing indicator -->
								<svg class="w-4 h-4" fill="currentColor" viewBox="0 0 24 24">
									<path d="M8 5v14l11-7z"/>
								</svg>
							{:else}
								{index + 1}
							{/if}
						</div>
						
						{#if track.thumbnailUrl}
						<img src={track.thumbnailUrl} alt={track.title} class="w-12 h-12 rounded object-cover" />
						{:else}
						<div class="w-12 h-12 bg-gradient-to-br from-gray-200 to-gray-300 rounded flex items-center justify-center">
							<svg class="w-6 h-6 text-gray-500" fill="none" stroke="currentColor" viewBox="0 0 24 24">
								<path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M9 19V6l12-3v13M9 19c0 1.105-1.343 2-3 2s-3-.895-3-2 1.343-2 3-2 3 .895 3 2z"></path>
							</svg>
						</div>
						{/if}
						
						<div class="flex-1 min-w-0">
							<h4 class="font-medium text-gray-800 truncate">{track.title}</h4>
							<p class="text-sm text-gray-600 truncate">{track.artist}</p>
							{#if track.album}
							<p class="text-xs text-gray-500 truncate">{track.album}</p>
							{/if}
							{#if track.addedBy}
							<p class="text-xs text-gray-400 mt-1">Added by {track.addedBy}</p>
							{/if}
						</div>
						
						<div class="flex items-center space-x-4">
							{#if track.duration}
							<span class="text-sm text-gray-500">{formatDuration(track.duration)}</span>
							{/if}
							
							<!-- Vote count -->
							<div class="flex items-center space-x-2">
								<span class="text-sm font-medium text-gray-700">{track.votes || 0}</span>
								<svg class="w-4 h-4 text-gray-400" fill="none" stroke="currentColor" viewBox="0 0 24 24">
									<path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M5 15l7-7 7 7"></path>
								</svg>
							</div>
							
							{#if canVote}
							<button 
								onclick={() => handleVoteForTrack(track.id)}
								disabled={votingCooldown.has(track.id)}
								class="bg-secondary/10 text-secondary px-3 py-1 rounded-full text-sm hover:bg-secondary/20 disabled:opacity-50 transition-colors flex items-center space-x-1"
								title="Vote for this track"
							>
								<svg class="w-3 h-3" fill="none" stroke="currentColor" viewBox="0 0 24 24">
									<path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M5 15l7-7 7 7"></path>
								</svg>
								<span>Vote</span>
							</button>
							{/if}
						</div>
					</div>
					{/each}
				</div>
				{/if}
			</div>

		<!-- Participants Sidebar -->
		<div class="lg:col-span-1 space-y-6">
			<div class="bg-white rounded-lg shadow-md p-6">
				<div class="flex items-center justify-between mb-4">
					<h2 class="text-xl font-bold text-gray-800">Participants</h2>
					<span class="bg-secondary/10 text-secondary px-2 py-1 rounded-full text-sm font-medium">
						{event.participants.length}
					</span>
				</div>
				
				<div class="space-y-3">
					{#each event.participants as participant}
					<div class="flex items-center space-x-3 p-3 rounded-lg hover:bg-gray-50 transition-colors">
						{#if participant.avatarUrl}
							<img src={participant.avatarUrl} alt={participant.displayName} class="w-10 h-10 rounded-full object-cover" />
						{:else}
							<div 
								class="w-10 h-10 rounded-full flex items-center justify-center text-white font-semibold text-sm"
								style="background: linear-gradient(135deg, {getAvatarColor(participant.displayName || participant.username || 'User')}, {getAvatarColorSecondary(participant.displayName || participant.username || 'User')})"
							>
								{getAvatarLetter(participant.displayName || participant.username || 'U')}
							</div>
						{/if}

						<div class="flex-1 min-w-0">
							<p class="font-medium text-gray-800 truncate">{participant.displayName || participant.username}</p>
							<div class="flex items-center space-x-2 text-xs text-gray-500">
								{#if participant.id === event?.hostId || participant.userId === event?.hostId}
									<span class="bg-yellow-100 text-yellow-800 px-2 py-0.5 rounded-full font-medium">Host</span>
								{:else}
									<span>Participant</span>
								{/if}
								{#if participant.joinedAt}
									<span>• Joined {new Date(participant.joinedAt).toLocaleDateString()}</span>
								{/if}
							</div>
						</div>

						{#if participant.id !== user?.id && participant.userId !== user?.id}
						<button
							onclick={() => goto(`/users/${participant.id || participant.userId}`)}
							class="text-gray-400 hover:text-gray-600 p-1"
							title="View profile"
							aria-label="View profile"
						>
							<svg class="w-4 h-4" fill="none" stroke="currentColor" viewBox="0 0 24 24">
								<path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M9 5l7 7-7 7" />
							</svg>
						</button>
						{:else}
						<div class="text-secondary">
							<svg class="w-4 h-4" fill="none" stroke="currentColor" viewBox="0 0 24 24">
								<path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M16 7a4 4 0 11-8 0 4 4 0 018 0zM12 14a7 7 0 00-7 7h14a7 7 0 00-7-7z" />
							</svg>
						</div>
						{/if}
					</div>
					{/each}
				</div>

				{#if !isParticipant && user && event?.visibility === 'public'}
				<div class="mt-4 pt-4 border-t border-gray-200">
					<button 
						onclick={joinEvent}
						class="w-full bg-secondary text-white py-2 px-4 rounded-lg hover:bg-secondary/80 transition-colors font-medium"
					>
						Join Event
					</button>
				</div>
				{/if}
			</div>

			<!-- Event Stats -->
			<div class="bg-white rounded-lg shadow-md p-6">
				<h3 class="text-lg font-semibold text-gray-800 mb-4">Event Stats</h3>
				<div class="space-y-3">
					<div class="flex justify-between items-center">
						<span class="text-gray-600">Total Tracks</span>
						<span class="font-medium text-gray-800">{sortedPlaylist.length}</span>
					</div>
					<div class="flex justify-between items-center">
						<span class="text-gray-600">Total Votes</span>
						<span class="font-medium text-gray-800">{sortedPlaylist.reduce((sum: number, track: any) => sum + (track.voteCount || 0), 0)}</span>
					</div>
					<div class="flex justify-between items-center">
						<span class="text-gray-600">Participants</span>
						<span class="font-medium text-gray-800">{event.participants.length}</span>
					</div>
					{#if event.startDate}
					<div class="flex justify-between items-center">
						<span class="text-gray-600">Started</span>
						<span class="font-medium text-gray-800">{formatDate(event.startDate)}</span>
					</div>
					{/if}
				</div>
			</div>
		</div>
	</div>
</div>

<!-- Add Track Modal -->
{#if showAddTrackModal}
<div class="fixed inset-0 bg-black bg-opacity-50 flex items-center justify-center z-50 p-4">
	<div class="bg-white rounded-lg max-w-lg w-full max-h-[90vh] overflow-y-auto">
		<div class="p-6">
			<div class="flex justify-between items-center mb-6">
				<h2 class="text-xl font-bold text-gray-800">Add Track to Event</h2>
				<button 
					onclick={() => showAddTrackModal = false}
					class="text-gray-400 hover:text-gray-600 transition-colors"
					aria-label="Close modal"
				>
					<svg class="w-6 h-6" fill="none" stroke="currentColor" viewBox="0 0 24 24">
						<path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M6 18L18 6M6 6l12 12"></path>
					</svg>
				</button>
			</div>
			
			<form onsubmit={(e) => { e.preventDefault(); addTrack(e); }} class="space-y-6">
				<!-- Basic Track Information -->
				<div class="space-y-4">
					<h3 class="text-lg font-semibold text-gray-800 border-b border-gray-200 pb-2">Track Information</h3>
					
					<div>
						<label for="track-title" class="block text-sm font-medium text-gray-700 mb-2">Track Title *</label>
						<input 
							id="track-title"
							type="text" 
							bind:value={newTrack.title}
							required
							class="w-full px-4 py-3 border border-gray-300 rounded-lg focus:outline-none focus:ring-2 focus:ring-secondary focus:border-transparent"
							placeholder="Enter the track title"
						/>
					</div>
					
					<div>
						<label for="track-artist" class="block text-sm font-medium text-gray-700 mb-2">Artist *</label>
						<input 
							id="track-artist"
							type="text" 
							bind:value={newTrack.artist}
							required
							class="w-full px-4 py-3 border border-gray-300 rounded-lg focus:outline-none focus:ring-2 focus:ring-secondary focus:border-transparent"
							placeholder="Enter the artist name"
						/>
					</div>
					
					<div>
						<label for="track-album" class="block text-sm font-medium text-gray-700 mb-2">Album</label>
						<input 
							id="track-album"
							type="text" 
							bind:value={newTrack.album}
							class="w-full px-4 py-3 border border-gray-300 rounded-lg focus:outline-none focus:ring-2 focus:ring-secondary focus:border-transparent"
							placeholder="Enter the album name (optional)"
						/>
					</div>
				</div>

				<!-- Media Information -->
				<div class="space-y-4">
					<h3 class="text-lg font-semibold text-gray-800 border-b border-gray-200 pb-2">Media Details</h3>
					
					<div class="grid grid-cols-1 sm:grid-cols-2 gap-4">
						<div>
							<label for="track-duration" class="block text-sm font-medium text-gray-700 mb-2">Duration (seconds)</label>
							<input 
								id="track-duration"
								type="number" 
								bind:value={newTrack.duration}
								min="0"
								max="3600"
								class="w-full px-4 py-3 border border-gray-300 rounded-lg focus:outline-none focus:ring-2 focus:ring-secondary focus:border-transparent"
								placeholder="180"
							/>
							<p class="text-xs text-gray-500 mt-1">Duration in seconds (e.g., 180 for 3 minutes)</p>
						</div>
						
						<div>
							<label for="track-thumbnail" class="block text-sm font-medium text-gray-700 mb-2">Thumbnail URL</label>
							<input 
								id="track-thumbnail"
								type="url" 
								bind:value={newTrack.thumbnailUrl}
								class="w-full px-4 py-3 border border-gray-300 rounded-lg focus:outline-none focus:ring-2 focus:ring-secondary focus:border-transparent"
								placeholder="https://example.com/image.jpg"
							/>
							<p class="text-xs text-gray-500 mt-1">Album cover or track image URL</p>
						</div>
					</div>
					
					<div>
						<label for="track-stream" class="block text-sm font-medium text-gray-700 mb-2">Stream URL</label>
						<input 
							id="track-stream"
							type="url" 
							bind:value={newTrack.streamUrl}
							class="w-full px-4 py-3 border border-gray-300 rounded-lg focus:outline-none focus:ring-2 focus:ring-secondary focus:border-transparent"
							placeholder="https://example.com/track.mp3"
						/>
						<p class="text-xs text-gray-500 mt-1">Direct link to the audio file (optional)</p>
					</div>
				</div>

				<!-- Note about music integration -->
				<div class="bg-blue-50 p-4 rounded-lg">
					<div class="flex items-start space-x-3">
						<svg class="w-5 h-5 text-blue-500 mt-0.5" fill="none" stroke="currentColor" viewBox="0 0 24 24">
							<path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M13 16h-1v-4h-1m1-4h.01M21 12a9 9 0 11-18 0 9 9 0 0118 0z"></path>
						</svg>
						<div>
							<h4 class="font-medium text-blue-800">Music Integration</h4>
							<p class="text-sm text-blue-700 mt-1">
								In the future, you'll be able to search and add tracks directly from Spotify, Deezer, and other music services. 
								For now, you can manually add track information.
							</p>
						</div>
					</div>
				</div>
				
				<div class="flex space-x-4 pt-6 border-t border-gray-200">
					<button 
						type="button"
						onclick={() => showAddTrackModal = false}
						class="flex-1 px-6 py-3 border border-gray-300 text-gray-700 rounded-lg hover:bg-gray-50 transition-colors font-medium"
					>
						Cancel
					</button>
					<button 
						type="submit"
						class="flex-1 bg-secondary text-white px-6 py-3 rounded-lg hover:bg-secondary/80 transition-colors font-medium"
					>
						Add Track
					</button>
				</div>
			</form>
		</div>
	</div>
</div>
{/if}

<!-- Invite Users Modal -->
{#if showInviteModal}
<div class="fixed inset-0 bg-black bg-opacity-50 flex items-center justify-center z-50 p-4">
	<div class="bg-white rounded-lg max-w-md w-full max-h-[90vh] overflow-y-auto">
		<div class="p-6">
			<div class="flex justify-between items-center mb-6">
				<h2 class="text-xl font-bold text-gray-800">Invite Users</h2>
				<button 
					onclick={() => showInviteModal = false}
					class="text-gray-400 hover:text-gray-600 transition-colors"
					aria-label="Close modal"
				>
					<svg class="w-6 h-6" fill="none" stroke="currentColor" viewBox="0 0 24 24">
						<path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M6 18L18 6M6 6l12 12"></path>
					</svg>
				</button>
			</div>
			
			<div class="space-y-6">
				<!-- Invite Link -->
				<div>
					<label for="invite-link" class="block text-sm font-medium text-gray-700 mb-2">Share Event Link</label>
					<div class="flex space-x-2">
						<input 
							id="invite-link"
							type="text" 
							readonly
							value={`${$page.url.origin}/events/${eventId}`}
							class="flex-1 px-4 py-3 border border-gray-300 rounded-lg bg-gray-50 text-gray-600"
						/>
						<button 
							onclick={() => {
								navigator.clipboard.writeText(`${$page.url.origin}/events/${eventId}`);
								// Show toast notification
							}}
							class="bg-secondary text-white px-4 py-3 rounded-lg hover:bg-secondary/80 transition-colors"
							title="Copy link"
							aria-label="Copy invite link"
						>
							<svg class="w-5 h-5" fill="none" stroke="currentColor" viewBox="0 0 24 24">
								<path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M8 16H6a2 2 0 01-2-2V6a2 2 0 012-2h8a2 2 0 012 2v2m-6 12h8a2 2 0 002-2v-8a2 2 0 00-2-2h-8a2 2 0 00-2 2v8a2 2 0 002 2z"></path>
							</svg>
						</button>
					</div>
					<p class="text-xs text-gray-500 mt-2">Share this link to invite people to your event</p>
				</div>

				<!-- QR Code -->
				<div class="text-center">
					<div class="bg-gray-100 p-4 rounded-lg inline-block">
						<div class="w-32 h-32 bg-white border-2 border-dashed border-gray-300 rounded flex items-center justify-center">
							<span class="text-gray-500 text-sm">QR Code</span>
						</div>
					</div>
					<p class="text-xs text-gray-500 mt-2">QR code for easy mobile sharing</p>
				</div>

				<!-- Social Share Buttons -->
				<div>
					<h3 class="block text-sm font-medium text-gray-700 mb-3">Share on Social Media</h3>
					<div class="grid grid-cols-2 gap-3">
						<button 
							onclick={() => {
								const text = `Join me at "${event?.title || event?.name}" music event!`;
								const url = `${$page.url.origin}/events/${eventId}`;
								window.open(`https://twitter.com/intent/tweet?text=${encodeURIComponent(text)}&url=${encodeURIComponent(url)}`, '_blank');
							}}
							class="flex items-center justify-center space-x-2 bg-blue-500 text-white px-4 py-3 rounded-lg hover:bg-blue-600 transition-colors"
							aria-label="Share on Twitter"
						>
							<svg class="w-5 h-5" fill="currentColor" viewBox="0 0 24 24">
								<path d="M23.953 4.57a10 10 0 01-2.825.775 4.958 4.958 0 002.163-2.723c-.951.555-2.005.959-3.127 1.184a4.92 4.92 0 00-8.384 4.482C7.69 8.095 4.067 6.13 1.64 3.162a4.822 4.822 0 00-.666 2.475c0 1.71.87 3.213 2.188 4.096a4.904 4.904 0 01-2.228-.616v.06a4.923 4.923 0 003.946 4.827 4.996 4.996 0 01-2.212.085 4.936 4.936 0 004.604 3.417 9.867 9.867 0 01-6.102 2.105c-.39 0-.779-.023-1.17-.067a13.995 13.995 0 007.557 2.209c9.053 0 13.998-7.496 13.998-13.985 0-.21 0-.42-.015-.63A9.935 9.935 0 0024 4.59z"/>
							</svg>
							<span>Twitter</span>
						</button>
						
						<button 
							onclick={() => {
								const text = `Join me at "${event?.title || event?.name}" music event!`;
								const url = `${$page.url.origin}/events/${eventId}`;
								window.open(`https://www.facebook.com/sharer/sharer.php?u=${encodeURIComponent(url)}&quote=${encodeURIComponent(text)}`, '_blank');
							}}
							class="flex items-center justify-center space-x-2 bg-blue-600 text-white px-4 py-3 rounded-lg hover:bg-blue-700 transition-colors"
							aria-label="Share on Facebook"
						>
							<svg class="w-5 h-5" fill="currentColor" viewBox="0 0 24 24">
								<path d="M24 12.073c0-6.627-5.373-12-12-12s-12 5.373-12 12c0 5.99 4.388 10.954 10.125 11.854v-8.385H7.078v-3.47h3.047V9.43c0-3.007 1.792-4.669 4.533-4.669 1.312 0 2.686.235 2.686.235v2.953H15.83c-1.491 0-1.956.925-1.956 1.874v2.25h3.328l-.532 3.47h-2.796v8.385C19.612 23.027 24 18.062 24 12.073z"/>
							</svg>
							<span>Facebook</span>
						</button>
					</div>
				</div>
			</div>
			
			<div class="flex justify-end pt-6 border-t border-gray-200 mt-6">
				<button 
					onclick={() => showInviteModal = false}
					class="px-6 py-3 bg-gray-100 text-gray-700 rounded-lg hover:bg-gray-200 transition-colors font-medium"
				>
					Close
				</button>
			</div>
		</div>
	</div>
</div>
{/if}
</div>
{/if}
