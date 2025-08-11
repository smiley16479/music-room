<svelte:head>
	<title>{playlist?.title || 'Playlist'} - Music Room</title>
	<meta name="description" content="Collaborate on music playlists in real-time" />
</svelte:head>

<script lang="ts">
	import { onMount } from 'svelte';
	import { page } from '$app/stores';
	import { authService } from '$lib/services/auth';
	import { playlistsService, type Playlist, type PlaylistTrack } from '$lib/services/playlists';
	import { goto } from '$app/navigation';

	// Get initial data from load function
	let { data } = $props();
	let playlist = $state<Playlist | null>(null);
	let loading = $state(true);
	let error = $state('');
	let user = $state<any>(null);
	let showAddTrackModal = $state(false);
	let showAddCollaboratorModal = $state(false);
	let draggedIndex: number | null = null;

	// Add track form
	let newTrack = $state({
		title: '',
		artist: '',
		album: '',
		duration: 0,
		thumbnailUrl: '',
		streamUrl: ''
	});

	// Add collaborator form
	let newCollaboratorEmail = $state('');
	let collaboratorRole = $state<'editor' | 'viewer'>('viewer');

	const playlistId = $derived($page.params.id);

	onMount(() => {
		// Initialize user on client side
		user = authService.isAuthenticated();
		
		loadPlaylist();
		// Set up real-time updates
		const interval = setInterval(loadPlaylist, 10000);
		return () => clearInterval(interval);
	});

	async function loadPlaylist() {
		if (!playlistId) return;
		
		try {
			playlist = await playlistsService.getPlaylist(playlistId);
			loading = false;
		} catch (err) {
			error = err instanceof Error ? err.message : 'Failed to load playlist';
			loading = false;
		}
	}

	async function addTrack(event: SubmitEvent) {
		event.preventDefault();
		if (!user || !playlistId) {
			goto('/auth/login');
			return;
		}

		try {
			await playlistsService.addTrackToPlaylist(playlistId, newTrack);
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
			await loadPlaylist();
		} catch (err) {
			error = err instanceof Error ? err.message : 'Failed to add track';
		}
	}

	async function removeTrack(trackId: string) {
		if (!user || !playlistId) return;

		try {
			await playlistsService.removeTrackFromPlaylist(playlistId, trackId);
			await loadPlaylist();
		} catch (err) {
			error = err instanceof Error ? err.message : 'Failed to remove track';
		}
	}

	async function addCollaborator(event: SubmitEvent) {
		event.preventDefault();
		if (!user || !playlistId || !newCollaboratorEmail) return;

		try {
			// In a real app, you'd search for the user by email first
			// For now, assuming we have a user ID
			await playlistsService.addCollaborator(playlistId, newCollaboratorEmail, collaboratorRole);
			showAddCollaboratorModal = false;
			newCollaboratorEmail = '';
			await loadPlaylist();
		} catch (err) {
			error = err instanceof Error ? err.message : 'Failed to add collaborator';
		}
	}

	async function removeCollaborator(userId: string) {
		if (!user || !playlistId) return;

		try {
			await playlistsService.removeCollaborator(playlistId, userId);
			await loadPlaylist();
		} catch (err) {
			error = err instanceof Error ? err.message : 'Failed to remove collaborator';
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
		
		if (draggedIndex === null || draggedIndex === dropIndex || !playlist || !playlistId) return;

		try {
			// Create new track positions array
			const tracks = [...playlist.tracks];
			const draggedTrack = tracks[draggedIndex];
			tracks.splice(draggedIndex, 1);
			tracks.splice(dropIndex, 0, draggedTrack);

			// Update positions
			const trackPositions = tracks.map((track, index) => ({
				trackId: track.id,
				position: index
			}));

			await playlistsService.reorderTracks(playlistId, trackPositions);
			await loadPlaylist();
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

	const isOwner = $derived(user && playlist?.ownerId === user.id);
	const canEdit = $derived(isOwner || (user && playlist?.collaborators?.some((c: any) => c.userId === user.id && c.role === 'editor')));
	const canView = $derived(playlist?.isPublic || isOwner || (user && playlist?.collaborators?.some((c: any) => c.userId === user.id)));
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
			{#if playlist.thumbnailUrl}
			<img src={playlist.thumbnailUrl} alt={playlist.title} class="w-32 h-32 rounded-lg object-cover" />
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
						<h1 class="font-family-main text-3xl font-bold text-gray-800 mb-2">{playlist.title}</h1>
						{#if playlist.description}
						<p class="text-gray-600 mb-4">{playlist.description}</p>
						{/if}
					</div>
					
					<div class="flex space-x-2">
						<span class="px-3 py-1 text-sm rounded-full {playlist.isPublic ? 'bg-green-100 text-green-800' : 'bg-blue-100 text-blue-800'}">
							{playlist.isPublic ? 'Public' : 'Private'}
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
						<span class="ml-1">{playlist.ownerName}</span>
					</div>
					
					<div>
						<span class="font-medium">Tracks:</span>
						<span class="ml-1">{playlist.tracks.length}</span>
					</div>
					
					<div>
						<span class="font-medium">Collaborators:</span>
						<span class="ml-1">{playlist.collaborators.length}</span>
					</div>
					
					<div>
						<span class="font-medium">Created:</span>
						<span class="ml-1">{formatDate(playlist.createdAt)}</span>
					</div>
				</div>
				
				{#if canEdit}
				<div class="flex space-x-3 mt-4">
				<button 
					onclick={() => showAddTrackModal = true}
					class="bg-secondary text-white px-4 py-2 rounded-lg hover:bg-secondary/80 transition-colors"
				>
					Add Track
				</button>
				
				{#if isOwner}
				<button 
					onclick={() => showAddCollaboratorModal = true}
					class="border border-secondary text-secondary px-4 py-2 rounded-lg hover:bg-secondary/10 transition-colors"
				>
					Add Collaborator
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

	<div class="grid grid-cols-1 lg:grid-cols-3 gap-8">
		<!-- Tracks -->
		<div class="lg:col-span-2">
			<div class="bg-white rounded-lg shadow-md p-6">
				<h2 class="text-xl font-bold text-gray-800 mb-6">Tracks</h2>
				
				{#if playlist.tracks.length === 0}
				<div class="text-center py-8">
					<p class="text-gray-500 mb-4">No tracks in this playlist yet</p>
					{#if canEdit}
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
					{#each playlist.tracks as track, index}
					<div 
						class="flex items-center space-x-4 p-3 border border-gray-200 rounded-lg hover:bg-gray-50 transition-colors {canEdit ? 'cursor-move' : ''}"
						draggable={canEdit}
						role={canEdit ? 'listitem' : 'none'}
						ondragstart={(e) => handleDragStart(e, index)}
						ondragover={handleDragOver}
						ondrop={(e) => handleDrop(e, index)}
					>
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
							<p class="text-xs text-gray-400">Added by {track.addedByName} • {formatDate(track.addedAt)}</p>
						</div>
						
						<div class="flex items-center space-x-3">
							{#if track.duration}
							<span class="text-sm text-gray-500">{formatDuration(track.duration)}</span>
							{/if}
							
							{#if canEdit}
							<button 
								onclick={() => removeTrack(track.id)}
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
		
		<!-- Collaborators -->
		<div class="lg:col-span-1">
			<div class="bg-white rounded-lg shadow-md p-6">
				<h2 class="text-xl font-bold text-gray-800 mb-4">Collaborators ({playlist.collaborators.length + 1})</h2>
				
				<div class="space-y-3">
					<!-- Owner -->
					<div class="flex items-center space-x-3">
						<div class="w-10 h-10 rounded-full bg-secondary/20 flex items-center justify-center">
							<span class="text-sm font-semibold">{playlist.ownerName.charAt(0)}</span>
						</div>
						
						<div class="flex-1">
							<p class="font-medium text-gray-800">{playlist.ownerName}</p>
							<p class="text-xs text-gray-500">Owner</p>
						</div>
					</div>
					
					<!-- Collaborators -->
					{#each playlist.collaborators as collaborator}
					<div class="flex items-center space-x-3">
						<div class="w-10 h-10 rounded-full bg-purple-100 flex items-center justify-center">
							<span class="text-sm font-semibold">{collaborator.displayName.charAt(0)}</span>
						</div>
						
						<div class="flex-1">
							<p class="font-medium text-gray-800">{collaborator.displayName}</p>
							<p class="text-xs text-gray-500">
								{collaborator.role === 'editor' ? 'Editor' : 'Viewer'} • 
								Added {formatDate(collaborator.addedAt)}
							</p>
						</div>
						
						{#if isOwner}
						<button 
							onclick={() => removeCollaborator(collaborator.userId)}
							aria-label="Remove collaborator"
							class="text-red-500 hover:text-red-700 transition-colors"
							title="Remove collaborator"
						>
							<svg class="w-4 h-4" fill="none" stroke="currentColor" viewBox="0 0 24 24">
								<path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M6 18L18 6M6 6l12 12"></path>
							</svg>
						</button>
						{/if}
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
					aria-label="Close modal"
					class="text-gray-400 hover:text-gray-600"
				>
					<svg class="w-6 h-6" fill="none" stroke="currentColor" viewBox="0 0 24 24">
						<path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M6 18L18 6M6 6l12 12"></path>
					</svg>
				</button>
			</div>
			
			<form onsubmit={addTrack} class="space-y-4">
				<div>
					<label for="trackTitle" class="block text-sm font-medium text-gray-700 mb-1">Track Title</label>
					<input 
						id="trackTitle"
						type="text" 
						bind:value={newTrack.title}
						required
						class="w-full px-3 py-2 border border-gray-300 rounded-lg focus:outline-none focus:ring-2 focus:ring-secondary"
						placeholder="Enter track title"
					/>
				</div>
				
				<div>
					<label for="trackArtist" class="block text-sm font-medium text-gray-700 mb-1">Artist</label>
					<input 
						id="trackArtist"
						type="text" 
						bind:value={newTrack.artist}
						required
						class="w-full px-3 py-2 border border-gray-300 rounded-lg focus:outline-none focus:ring-2 focus:ring-secondary"
						placeholder="Enter artist name"
					/>
				</div>
				
				<div>
					<label for="trackAlbum" class="block text-sm font-medium text-gray-700 mb-1">Album</label>
					<input 
						id="trackAlbum"
						type="text" 
						bind:value={newTrack.album}
						class="w-full px-3 py-2 border border-gray-300 rounded-lg focus:outline-none focus:ring-2 focus:ring-secondary"
						placeholder="Enter album name (optional)"
					/>
				</div>
				
				<div class="grid grid-cols-2 gap-4">
					<div>
						<label for="trackDuration" class="block text-sm font-medium text-gray-700 mb-1">Duration (seconds)</label>
						<input 
							id="trackDuration"
							type="number" 
							bind:value={newTrack.duration}
							min="0"
							class="w-full px-3 py-2 border border-gray-300 rounded-lg focus:outline-none focus:ring-2 focus:ring-secondary"
							placeholder="180"
						/>
					</div>
					
					<div>
						<label for="trackThumbnail" class="block text-sm font-medium text-gray-700 mb-1">Thumbnail URL</label>
						<input 
							id="trackThumbnail"
							type="url" 
							bind:value={newTrack.thumbnailUrl}
							class="w-full px-3 py-2 border border-gray-300 rounded-lg focus:outline-none focus:ring-2 focus:ring-secondary"
							placeholder="https://..."
						/>
					</div>
				</div>
				
				<div>
					<label for="streamUrl" class="block text-sm font-medium text-gray-700 mb-1">Stream URL</label>
					<input 
						id="streamUrl"
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

<!-- Add Collaborator Modal -->
{#if showAddCollaboratorModal}
<div class="fixed inset-0 bg-black bg-opacity-50 flex items-center justify-center z-50 p-4">
	<div class="bg-white rounded-lg max-w-md w-full">
		<div class="p-6">
			<div class="flex justify-between items-center mb-4">
				<h2 class="text-xl font-bold text-gray-800">Add Collaborator</h2>
				<button 
					onclick={() => showAddCollaboratorModal = false}
					aria-label="Close modal"
					class="text-gray-400 hover:text-gray-600"
				>
					<svg class="w-6 h-6" fill="none" stroke="currentColor" viewBox="0 0 24 24">
						<path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M6 18L18 6M6 6l12 12"></path>
					</svg>
				</button>
			</div>
			
			<form onsubmit={addCollaborator} class="space-y-4">
				<div>
					<label for="userEmail" class="block text-sm font-medium text-gray-700 mb-1">User Email or ID</label>
					<input 
						id="userEmail"
						type="text" 
						bind:value={newCollaboratorEmail}
						required
						class="w-full px-3 py-2 border border-gray-300 rounded-lg focus:outline-none focus:ring-2 focus:ring-secondary"
						placeholder="Enter user email or ID"
					/>
				</div>
				
				<div>
					<label for="collaboratorRole" class="block text-sm font-medium text-gray-700 mb-1">Role</label>
					<select 
						id="collaboratorRole"
						bind:value={collaboratorRole}
						class="w-full px-3 py-2 border border-gray-300 rounded-lg focus:outline-none focus:ring-2 focus:ring-secondary"
					>
						<option value="viewer">Viewer (can view only)</option>
						<option value="editor">Editor (can add/remove tracks)</option>
					</select>
				</div>
				
				<div class="flex space-x-3 pt-4">
					<button 
						type="button"
						onclick={() => showAddCollaboratorModal = false}
						class="flex-1 px-4 py-2 border border-gray-300 text-gray-700 rounded-lg hover:bg-gray-50"
					>
						Cancel
					</button>
					<button 
						type="submit"
						class="flex-1 bg-secondary text-white px-4 py-2 rounded-lg hover:bg-secondary/80"
					>
						Add Collaborator
					</button>
				</div>
			</form>
		</div>
	</div>
</div>
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
