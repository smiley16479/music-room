<svelte:head>
	<title>{playlist?.name || 'Playlist'} - Music Room</title>
	<meta name="description" content="Collaborate on music playlists in real-time" />
</svelte:head>

<script lang="ts">
	import { onMount, onDestroy } from 'svelte';
	import { page } from '$app/stores';
	import { authStore } from '$lib/stores/auth';
	import type { Collaborator } from '$lib/services/playlists';
	import { playlistsService, type Playlist, type PlaylistTrack } from '$lib/services/playlists';
	import { socketService } from '$lib/services/socket';
	import { participantsService } from '$lib/stores/participants';
	import { musicPlayerService } from '$lib/services/musicPlayer';
	import { musicPlayerStore } from '$lib/stores/musicPlayer';
	import { goto } from '$app/navigation';
	import ParticipantsList from '$lib/components/ParticipantsList.svelte';
	import CollaboratorsList from '$lib/components/CollaboratorsList.svelte';
	import AddCollaboratorModal from '$lib/components/AddCollaboratorModal.svelte';
	import EnhancedMusicSearchModal from '$lib/components/EnhancedMusicSearchModal.svelte';
	import { getAvatarColor, getAvatarLetter, getUserAvatarUrl } from '$lib/utils/avatar';

	// Get initial data from load function
	let { data } = $props();
	let playlist = $state<Playlist | null>(null);
	let loading = $state(true);
	let error = $state('');
	// Use the global auth store instead of local user variable
	let user = $derived($authStore);
	let showMusicSearchModal = $state(false);
	let showAddCollaboratorModal = $state(false);
	let draggedIndex: number | null = null;
	const currentUser = $derived($authStore);

	// Socket connection state
	let isSocketConnected = $state(false);
	
	// Music player state
	let isMusicPlayerInitialized = $state(false);
	const playerState = $derived($musicPlayerStore);

	const playlistId = $derived($page.params.id);

	onMount(() => {
		// Async initialization function
		const initializePlaylist = async () => {
			// Load playlist first
			await loadPlaylist();

			// Set up socket connection for real-time features
			if (playlistId && user) {
				await setupSocketConnection(playlistId);
			}
		};

		// Call initialization
		initializePlaylist();

		// Set up real-time updates via WebSocket only
		// Polling removed - real-time updates handled by socket events
		
		// Return cleanup function
		return () => {
			if (playlistId && isSocketConnected) {
				cleanupSocketConnection(playlistId);
			}
			
			// Cleanup music player
			if (isMusicPlayerInitialized) {
				musicPlayerService.leaveRoom();
				isMusicPlayerInitialized = false;
			}
		};
	});

	onDestroy(() => {
		// Clean up socket connection when leaving the page
		if (playlistId && isSocketConnected) {
			cleanupSocketConnection(playlistId);
		}
		
		// Cleanup music player
		if (isMusicPlayerInitialized) {
			musicPlayerService.leaveRoom();
			isMusicPlayerInitialized = false;
		}
	});

	// Navigate to user profile
	function viewUserProfile(userId: string) {
		if (userId && userId !== currentUser?.id) {
			goto(`/users/${userId}`);
		}
	}

	function viewOwnerProfile() {
		if (currentUser?.id !== playlist?.creator?.id) {
			goto(`/users/${playlist?.creator?.id}`);
		}
	}

	async function setupSocketConnection(playlistId: string) {
		try {
			if (!socketService.isConnected()) {
				await socketService.connect();
			}

			// Set up participant listeners
			socketService.setupParticipantListeners(playlistId);

			// Join the playlist room
			socketService.joinPlaylist(playlistId);

			// Request current participants list
			socketService.requestParticipantsList(playlistId);

			isSocketConnected = true;
			console.log('Socket connected and joined playlist room');
		} catch (err) {
			console.error('Failed to set up socket connection:', err);
			error = 'Failed to connect to real-time updates';
		}
	}

	function cleanupSocketConnection(playlistId: string) {
		try {
			// Leave the playlist room
			socketService.leavePlaylist(playlistId);

			// Clean up event listeners
			socketService.cleanupParticipantListeners();

			// Clear participants from store
			participantsService.clearParticipants(playlistId);

			isSocketConnected = false;
			console.log('Socket connection cleaned up');
		} catch (err) {
			console.error('Failed to clean up socket connection:', err);
		}
	}

	async function loadPlaylist() {
		if (!playlistId) return;
		
		try {
			console.log('Loading playlist with ID:', playlistId);
			
			// Load playlist metadata
			playlist = await playlistsService.getPlaylist(playlistId);
			console.log('Playlist metadata loaded:', {
				id: playlist.id,
				name: playlist.name,
				tracksCount: playlist.tracks?.length || 0
			});
			
			// Load tracks separately
			const tracks = await playlistsService.getPlaylistTracks(playlistId);
			console.log('Tracks loaded from API:', {
				tracksCount: tracks.length,
				tracks: tracks
			});
			
			playlist.tracks = tracks;
			
			// Initialize music player for this playlist
			await initializeMusicPlayer();
			
			loading = false;
		} catch (err) {
			console.error('Failed to load playlist:', err);
			error = err instanceof Error ? err.message : 'Failed to load playlist';
			loading = false;
		}
	}

	async function initializeMusicPlayer() {
		if (!playlist || !user || isMusicPlayerInitialized) return;

		try {
			console.log('Initializing music player with playlist:', {
				id: playlist.id,
				name: playlist.name,
				tracksCount: playlist.tracks?.length || 0,
				tracks: playlist.tracks
			});

			// Don't initialize if playlist has no tracks
			if (!playlist.tracks || playlist.tracks.length === 0) {
				console.warn('Cannot initialize music player: playlist has no tracks');
				return;
			}

			// Create room context for the music player
			const roomContext = {
				type: 'playlist' as const,
				id: playlist.id,
				ownerId: playlist.creatorId || '',
				participants: playlist.collaborators.map(c => c.id),
				licenseType: playlist.licenseType,
				visibility: playlist.visibility
			};

			// Initialize music player with playlist tracks
			await musicPlayerService.initializeForRoom(roomContext, playlist.tracks || []);
			isMusicPlayerInitialized = true;
			
			console.log('Music player initialized successfully for playlist:', playlist.name);
		} catch (err) {
			console.error('Failed to initialize music player:', err);
		}
	}

	async function playTrack(trackIndex: number) {
		try {
			console.log('playTrack called with:', {
				trackIndex,
				playlistTracksCount: playlist?.tracks?.length || 0,
				isMusicPlayerInitialized,
				playerStatePlaylistLength: playerState.playlist.length,
				canControl: playerState.canControl,
				currentPlaylist: playlist
			});

			// Don't try to play if music player isn't initialized
			if (!isMusicPlayerInitialized) {
				console.warn('Music player not initialized, attempting to initialize first...');
				await initializeMusicPlayer();
				
				if (!isMusicPlayerInitialized) {
					console.error('Failed to initialize music player before playing track');
					error = 'Music player not available. Please refresh the page.';
					setTimeout(() => error = '', 3000);
					return;
				}
			}

			// Check if trackIndex is valid
			if (!playlist?.tracks || trackIndex >= playlist.tracks.length || trackIndex < 0) {
				console.error('Invalid track index:', { trackIndex, playlistLength: playlist?.tracks?.length });
				error = `Cannot play track: invalid track position (${trackIndex + 1})`;
				setTimeout(() => error = '', 3000);
				return;
			}

			console.log('Attempting to play track:', {
				trackIndex,
				track: playlist.tracks[trackIndex]?.track?.title || 'unknown'
			});
			
			await musicPlayerService.playTrack(trackIndex);
		} catch (err) {
			console.error('Play track error:', err);
			error = err instanceof Error ? err.message : 'Failed to play track';
			setTimeout(() => error = '', 3000);
		}
	}

	async function voteForTrack(trackId: string) {
		try {
			await musicPlayerService.voteForTrack(trackId);
			// You could add visual feedback here for successful voting
		} catch (err) {
			error = err instanceof Error ? err.message : 'Failed to vote for track';
			setTimeout(() => error = '', 3000);
		}
	}

	async function removeTrack(trackId: string) {
		if (!user || !playlistId) return;

		try {
			await playlistsService.removeTrackFromPlaylist(playlistId, trackId);
			await loadPlaylist();
			
			// Update music player with new track list
			if (isMusicPlayerInitialized && playlist?.tracks) {
				musicPlayerStore.setPlaylist(playlist.tracks, Math.max(0, playerState.currentTrackIndex));
			}
		} catch (err) {
			error = err instanceof Error ? err.message : 'Failed to remove track';
		}
	}

	function handleDragStart(event: DragEvent, index: number) {
		draggedIndex = index;
		if (event.dataTransfer) {
			event.dataTransfer.effectAllowed = 'move';
		}
	}

	function handleDragOver(event: DragEvent) {
		event.preventDefault();
		if (event.dataTransfer) {
			event.dataTransfer.dropEffect = 'move';
		}
	}

	async function handleDrop(event: DragEvent, dropIndex: number) {
		event.preventDefault();
		if (draggedIndex === null || draggedIndex === dropIndex || !playlist || !playlistId || !playlist.tracks) return;

		try {
			// Create new track positions array
			const tracks = [...playlist.tracks];
			const draggedTrack = tracks[draggedIndex];
			tracks.splice(draggedIndex, 1);
			tracks.splice(dropIndex, 0, draggedTrack);

			// Update positions - send array of track IDs in the new order
			const trackIds = tracks.map(track => track.trackId);

			await playlistsService.reorderTracks(playlistId, trackIds);
			await loadPlaylist();
			
			// Update music player with new track order
			if (isMusicPlayerInitialized && playlist.tracks) {
				musicPlayerStore.setPlaylist(playlist.tracks, playerState.currentTrackIndex);
			}
		} catch (err) {
			error = err instanceof Error ? err.message : 'Failed to reorder tracks';
		}
		
		draggedIndex = null;
	}

	function formatDate(dateString: string) {
		return new Date(dateString).toLocaleDateString('en-US', {
			year: 'numeric',
			month: 'short',
			day: 'numeric'
		});
	}

	function formatDuration(seconds: number) {
		const minutes = Math.floor(seconds / 60);
		const remainingSeconds = seconds % 60;
		return `${minutes}:${remainingSeconds.toString().padStart(2, '0')}`;
	}

	const isOwner = $derived(user && playlist?.creatorId === user.id);
	const canEdit = $derived(isOwner || (user && playlist?.collaborators?.some((c: any) => c.id === user.id)));
	const canView = $derived(playlist?.visibility === 'public' || isOwner || (user && playlist?.collaborators?.some((c: any) => c.id === user.id)));
</script>

{#if loading}
<div class="flex justify-center items-center min-h-[400px]">
	<div class="animate-spin rounded-full h-12 w-12 border-b-2 border-secondary"></div>
</div>
{:else if error && !playlist}
<div class="container mx-auto px-4 py-8">
	<div class="bg-red-100 border border-red-400 text-red-700 px-4 py-3 rounded">
		{error}
	</div>
</div>
{:else if playlist && canView}
<div class="container mx-auto px-4 py-8">
	<!-- Playlist Header -->
	<div class="bg-white rounded-lg shadow-md p-6 mb-8">
		<div class="flex items-start space-x-6">
			{#if playlist.coverImageUrl}
			<img src={playlist.coverImageUrl} alt={playlist.name} class="w-32 h-32 rounded-lg object-cover" />
			{:else}
			<div class="w-32 h-32 bg-gradient-to-br from-secondary/20 to-purple-300 rounded-lg flex items-center justify-center">
				<svg class="w-16 h-16 text-white" fill="none" stroke="currentColor" viewBox="0 0 24 24">
					<path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M9 19V6l12-3v13M9 19c0 1.105-1.343 2-3 2s-3-.895-3-2 1.343-2 3-2 3 .895 3 2z"></path>
				</svg>
			</div>
			{/if}
			
			<div class="flex-1">
				<div class="flex justify-between items-start mb-4">
					<div>
						<h1 class="font-family-main text-3xl font-bold text-gray-800 mb-2">{playlist.name}</h1>
						{#if playlist.description}
						<p class="text-gray-600 mb-4">{playlist.description}</p>
						{/if}
					</div>
					
					<div class="flex space-x-2">
						<span class="px-3 py-1 text-sm rounded-full {playlist.visibility === 'public' ? 'bg-green-100 text-green-800' : 'bg-blue-100 text-blue-800'}">
							{playlist.visibility === 'public' ? 'Public' : 'Private'}
						</span>
						{#if playlist.isCollaborative}
						<span class="px-3 py-1 text-sm rounded-full bg-purple-100 text-purple-800">
							Collaborative
						</span>
						{/if}
					</div>
				</div>
				
				<div class="grid grid-cols-2 md:grid-cols-4 gap-4 text-sm text-gray-600">
					<div>
						<span class="font-medium">Owner:</span>
						<span class="ml-1">{playlist.creator?.displayName || 'Unknown'}</span>
					</div>
					
					<div>
						<span class="font-medium">Tracks:</span>
						<span class="ml-1">{playlist.tracks?.length || playlist.trackCount || 0}</span>
					</div>
					
					<div>
						<span class="font-medium">Collaborators:</span>
						<span class="ml-1">{playlist.collaborators.length + 1}</span>
					</div>
					
					<div>
						<span class="font-medium">Created:</span>
						<span class="ml-1">{formatDate(playlist.createdAt)}</span>
					</div>
				</div>
				
				{#if canEdit}
				<div class="flex space-x-3 mt-4">
				<button 
					onclick={() => showMusicSearchModal = true}
					class="bg-secondary text-white px-4 py-2 rounded-lg hover:bg-secondary/80 transition-colors"
				>
					Search & Add Music
				</button>
				
				{#if isOwner}
				<button 
					onclick={() => showAddCollaboratorModal = true}
					class="border border-secondary text-secondary px-4 py-2 rounded-lg hover:bg-secondary/10 transition-colors"
				>
					Invite Collaborators
				</button>
				{/if}
				</div>
				{/if}
			</div>
		</div>
	</div>

	{#if error}
	<div class="bg-red-100 border border-red-400 text-red-700 px-4 py-3 rounded mb-6">
		{error}
	</div>
	{/if}

	<div class="grid grid-cols-1 lg:grid-cols-4 gap-8">
		<!-- Tracks -->
		<div class="lg:col-span-3">
			<div class="bg-white rounded-lg shadow-md p-6">
				<div class="flex justify-between items-center mb-6">
					<h2 class="text-xl font-bold text-gray-800">Tracks</h2>
					<div class="flex items-center space-x-4">
						{#if isSocketConnected}
							<div class="flex items-center text-sm text-green-600">
								<div class="w-2 h-2 bg-green-500 rounded-full mr-2"></div>
								Live
							</div>
						{/if}
						
						{#if isMusicPlayerInitialized}
							<div class="flex items-center text-sm text-secondary">
								<svg class="w-4 h-4 mr-1" fill="none" stroke="currentColor" viewBox="0 0 24 24">
									<path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M9 19V6l12-3v13M9 19c0 1.105-1.343 2-3 2s-3-.895-3-2 1.343-2 3-2 3 .895 3 2zm12-3c0 1.105-1.343 2-3 2s-3-.895-3-2 1.343-2 3-2 3 .895 3 2zM9 10l12-3"></path>
								</svg>
								Music Player Active
							</div>
						{/if}
					</div>
				</div>
				
				<!-- Music Player Status -->
				{#if isMusicPlayerInitialized}
					<div class="mb-6 p-4 bg-gradient-to-r from-secondary/5 to-secondary/10 rounded-lg border border-secondary/20">
						<div class="flex items-center justify-between mb-3">
							<h3 class="font-semibold text-gray-800">🎵 Music Player Status</h3>
							<div class="text-sm {playerState.canControl ? 'text-green-600' : 'text-orange-600'}">
								{playerState.canControl ? '🎛️ Can Control' : '👂 Listen Only'}
							</div>
						</div>
						
					{#if playerState.currentTrack}
						<div class="flex items-center space-x-3 text-sm">
							<div class="flex items-center space-x-2">
								<span class="font-medium">Now Playing:</span>
								<span class="text-secondary font-semibold">{playerState.currentTrack.title}</span>
								<span class="text-gray-600">by {playerState.currentTrack.artist}</span>
								<span class="text-xs bg-blue-100 text-blue-700 px-2 py-0.5 rounded-full">30s Preview</span>
							</div>
							<div class="flex items-center space-x-1 text-gray-500">
								{#if playerState.isPlaying}
									<svg class="w-3 h-3" fill="currentColor" viewBox="0 0 24 24">
										<path d="M8 5v14l11-7z"/>
									</svg>
									<span>Playing</span>
								{:else}
									<svg class="w-3 h-3" fill="currentColor" viewBox="0 0 24 24">
										<path d="M6 4h4v16H6V4zm8 0h4v16h-4V4z"/>
									</svg>
									<span>Paused</span>
								{/if}
							</div>
						</div>
					{:else}
						<p class="text-sm text-gray-600">Click play on any track to start listening! 🎵</p>
					{/if}						<div class="mt-2 text-xs text-gray-500">
							💡 Use the controls at the bottom of the page for playback. 
							{#if !playerState.canControl}
								You can listen but need permission to control playback.
							{:else}
								You can control playback and vote for tracks.
							{/if}
							<br />
							🎵 Playing 30-second previews from Deezer. For full tracks, connect a premium streaming device in the <a href="/devices" class="text-secondary hover:underline">Devices</a> section.
						</div>
					</div>
				{/if}
				
				{#if !playlist.tracks || playlist.tracks.length === 0}
				<div class="text-center py-8">
					<p class="text-gray-500 mb-4">No tracks in this playlist yet</p>
					{#if canEdit}
					<button 
						onclick={() => showMusicSearchModal = true}
						class="bg-secondary text-white px-6 py-2 rounded-lg hover:bg-secondary/80 transition-colors"
					>
						Search & Add Music
					</button>
					{/if}
				</div>
				{:else}
				<div class="space-y-2">
					{#each playlist.tracks as track, index}
					<div 
						class="flex items-center space-x-4 p-3 border rounded-lg transition-colors {canEdit ? 'cursor-move' : ''} {playerState.currentTrackIndex === index ? 'border-secondary bg-secondary/5' : 'border-gray-200 hover:bg-gray-50'}"
						draggable={canEdit}
						role={canEdit ? 'listitem' : 'none'}
						ondragstart={(e) => handleDragStart(e, index)}
						ondragover={handleDragOver}
						ondrop={(e) => handleDrop(e, index)}
					>
						<div class="w-8 h-8 rounded-full flex items-center justify-center text-sm font-semibold {playerState.currentTrackIndex === index ? 'bg-secondary text-white' : 'bg-gray-200 text-gray-600'}">
							{#if playerState.currentTrackIndex === index && playerState.isPlaying}
								<!-- Now playing indicator -->
								<svg class="w-4 h-4" fill="currentColor" viewBox="0 0 24 24">
									<path d="M8 5v14l11-7z"/>
								</svg>
							{:else}
								{index + 1}
							{/if}
						</div>
						
						{#if track.track.albumCoverMediumUrl}
						<img src={track.track.albumCoverMediumUrl} alt={track.track.title} class="w-12 h-12 rounded object-cover" />
						{:else}
						<div class="w-12 h-12 bg-gray-200 rounded flex items-center justify-center">
							<svg class="w-6 h-6 text-gray-400" fill="none" stroke="currentColor" viewBox="0 0 24 24">
								<path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M9 19V6l12-3v13M9 19c0 1.105-1.343 2-3 2s-3-.895-3-2 1.343-2 3-2 3 .895 3 2z"></path>
							</svg>
						</div>
						{/if}
						
						<div class="flex-1">
							<h4 class="font-medium text-gray-800">{track.track.title}</h4>
							<p class="text-sm text-gray-600">{track.track.artist}</p>
							{#if track.track.album}
							<p class="text-xs text-gray-500">{track.track.album}</p>
							{/if}
							<p class="text-xs text-gray-400">Added by {track.addedBy.displayName} • {formatDate(track.addedAt)}</p>
						</div>
						
						<div class="flex items-center space-x-3">
							{#if track.track.duration}
							<span class="text-sm text-gray-500">{formatDuration(track.track.duration)}</span>
							{/if}
							
							<!-- Music Player Controls -->
						{#if isMusicPlayerInitialized}
							<div class="flex items-center space-x-2">
								<!-- Play Button -->
								<button 
									onclick={() => playTrack(index)}
									disabled={!playerState.canControl}
									class="p-1.5 rounded-full {playerState.currentTrackIndex === index ? 'bg-secondary text-white' : 'bg-gray-100 text-gray-600'} hover:bg-secondary hover:text-white disabled:opacity-50 disabled:cursor-not-allowed transition-colors"
									title={playerState.currentTrackIndex === index ? 'Currently playing (30s preview)' : 'Play 30s preview'}
									aria-label={`Play ${track.track.title}`}
								>
									{#if playerState.currentTrackIndex === index && playerState.isPlaying}
										<!-- Pause icon -->
										<svg class="w-3 h-3" fill="currentColor" viewBox="0 0 24 24">
											<path d="M6 4h4v16H6V4zm8 0h4v16h-4V4z"/>
										</svg>
									{:else}
										<!-- Play icon -->
										<svg class="w-3 h-3" fill="currentColor" viewBox="0 0 24 24">
											<path d="M8 5v14l11-7z"/>
										</svg>
									{/if}
								</button>
								
								<!-- Preview indicator -->
								<span class="text-xs text-gray-500 bg-gray-100 px-2 py-0.5 rounded-full">
									30s preview
								</span>
								
								<!-- Vote Button -->
								<button 
									onclick={() => voteForTrack(track.track.id)}
									disabled={!playerState.canControl}
									class="p-1.5 rounded-full bg-yellow-100 text-yellow-600 hover:bg-yellow-200 disabled:opacity-50 disabled:cursor-not-allowed transition-colors"
									title="Vote to move this track up"
									aria-label={`Vote for ${track.track.title}`}
								>
									<svg class="w-3 h-3" fill="none" stroke="currentColor" viewBox="0 0 24 24">
										<path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M5 15l7-7 7 7"/>
									</svg>
								</button>
							</div>
						{/if}							{#if canEdit}
							<button 
								onclick={() => removeTrack(track.trackId)}
								aria-label="Remove track"
								class="text-red-500 hover:text-red-700 transition-colors"
								title="Remove track"
							>
								<svg class="w-4 h-4" fill="none" stroke="currentColor" viewBox="0 0 24 24">
									<path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M19 7l-.867 12.142A2 2 0 0116.138 21H7.862a2 2 0 01-1.995-1.858L5 7m5 4v6m4-6v6m1-10V4a1 1 0 00-1-1h-4a1 1 0 00-1 1v3M4 7h16"></path>
								</svg>
							</button>
							{/if}
						</div>
					</div>
					{/each}
				</div>
				{/if}
			</div>
		</div>
		
		<!-- Sidebar -->
		<div class="lg:col-span-1 space-y-6">
			<!-- Real-time Participants -->
			{#if isSocketConnected && playlistId}
				<ParticipantsList {playlistId} />
			{/if}
			
			<!-- Static Collaborators -->
			<CollaboratorsList 
				{playlist} 
				{isOwner} 
				onCollaboratorRemoved={() => loadPlaylist()}
			/>
		</div>
	</div>
</div>

<!-- Enhanced Music Search Modal -->
{#if showMusicSearchModal && playlistId}
	<EnhancedMusicSearchModal 
		{playlistId}
		onTrackAdded={() => {
			showMusicSearchModal = false;
			loadPlaylist();
		}}
		onClose={() => showMusicSearchModal = false}
	/>
{/if}

<!-- Add Collaborator Modal -->
{#if showAddCollaboratorModal && playlistId}
	<AddCollaboratorModal 
		{playlistId}
		onCollaboratorAdded={() => {
			showAddCollaboratorModal = false;
			loadPlaylist();
		}}
		onClose={() => showAddCollaboratorModal = false}
	/>
{/if}
{:else}
<div class="container mx-auto px-4 py-8">
	<div class="text-center py-12">
		<h3 class="text-xl font-semibold text-gray-700 mb-2">Playlist not found or access denied</h3>
		<p class="text-gray-500 mb-4">This playlist might be private or you don't have permission to view it.</p>
		<a href="/playlists" class="bg-secondary text-white px-6 py-2 rounded-lg hover:bg-secondary/80 transition-colors">
			Back to Playlists
		</a>
	</div>
</div>
{/if}
