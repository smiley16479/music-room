<svelte:head>
	<title>Playlists - Music Room</title>
	<meta name="description" content="Create and collaborate on music playlists in real-time" />
</svelte:head>

<script lang="ts">
	import { onMount } from 'svelte';
	import { page } from '$app/stores';
	import { authService } from '$lib/services/auth';
	import { playlistsService, type Playlist } from '$lib/services/playlists';
	import { goto } from '$app/navigation';

	// Get initial data from load function
	export let data;
	let playlists: Playlist[] = data.playlists || [];
	let loading = false;
	let error = '';
	let user: any = null;
	let showCreateModal = false;
	let filter: 'all' | 'public' | 'private' | 'mine' = 'all';

	// Create playlist form
	let newPlaylist = {
		title: '',
		description: '',
		isPublic: true,
		isCollaborative: true,
		licenseType: 'free' as const
	};

	// Update filter based on URL parameter
	$: {
		const currentFilter = $page.url.searchParams.get('filter') || 'all';
		if (currentFilter !== filter) {
			filter = currentFilter as typeof filter;
		}
	}

	// Update playlists when data changes
	$: if (data.playlists) {
		playlists = data.playlists;
	}

	onMount(() => {
		// Initialize user on client side
		user = authService.isAuthenticated();
	});

	async function loadPlaylists() {
		loading = true;
		error = '';
		try {
			let publicFilter: boolean | undefined;
			let userId: string | undefined;

			switch (filter) {
				case 'public':
					publicFilter = true;
					break;
				case 'private':
					publicFilter = false;
					break;
				case 'mine':
					userId = user?.id;
					break;
			}

			playlists = await playlistsService.getPlaylists(publicFilter, userId);
		} catch (err) {
			error = 'Failed to load playlists';
			console.error(err);
		} finally {
			loading = false;
		}
	}

	async function createPlaylist(event: SubmitEvent) {
		event.preventDefault();
		if (!user) {
			goto('/auth/login');
			return;
		}

		loading = true;
		error = '';
		try {
			await playlistsService.createPlaylist(newPlaylist);
			showCreateModal = false;
			// Reset form
			newPlaylist = {
				title: '',
				description: '',
				isPublic: true,
				isCollaborative: true,
				licenseType: 'free'
			};
			await loadPlaylists();
		} catch (err) {
			error = err instanceof Error ? err.message : 'Failed to create playlist';
		} finally {
			loading = false;
		}
	}

	function formatDate(dateString: string) {
		return new Date(dateString).toLocaleDateString('en-US', {
			year: 'numeric',
			month: 'short',
			day: 'numeric'
		});
	}

	function handleFilterChange() {
		loadPlaylists();
	}
</script>

<div class="container mx-auto px-4 py-8">
	<div class="flex justify-between items-center mb-8">
		<div>
			<h1 class="font-family-main text-4xl font-bold text-gray-800 mb-2">Music Playlists</h1>
			<p class="text-gray-600">Create and collaborate on playlists in real-time</p>
		</div>
		
		{#if user}
		<button 
			onclick={() => showCreateModal = true}
			class="bg-secondary text-white px-6 py-3 rounded-lg font-semibold hover:bg-secondary/80 transition-colors"
		>
			Create Playlist
		</button>
		{/if}
	</div>

	<!-- Filter Tabs -->
	<div class="flex space-x-4 mb-6">
		<button 
			class="px-4 py-2 rounded-lg font-medium transition-colors {filter === 'all' ? 'bg-secondary text-white' : 'bg-gray-200 text-gray-700 hover:bg-gray-300'}"
			onclick={() => { filter = 'all'; handleFilterChange(); }}
		>
			All Playlists
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
		{#if user}
		<button 
			class="px-4 py-2 rounded-lg font-medium transition-colors {filter === 'mine' ? 'bg-secondary text-white' : 'bg-gray-200 text-gray-700 hover:bg-gray-300'}"
			onclick={() => { filter = 'mine'; handleFilterChange(); }}
		>
			My Playlists
		</button>
		{/if}
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
	{:else if playlists.length === 0}
	<div class="text-center py-12">
		<h3 class="text-xl font-semibold text-gray-700 mb-2">No playlists found</h3>
		<p class="text-gray-500 mb-4">Be the first to create a playlist!</p>
		{#if user}
		<button 
			onclick={() => showCreateModal = true}
			class="bg-secondary text-white px-6 py-2 rounded-lg font-medium hover:bg-secondary/80 transition-colors"
		>
			Create Playlist
		</button>
		{/if}
	</div>
	{:else}
	<div class="grid grid-cols-1 md:grid-cols-2 lg:grid-cols-3 gap-6">
		{#each playlists as playlist}
		<div class="bg-white rounded-lg shadow-md overflow-hidden hover:shadow-lg transition-shadow">
			{#if playlist.thumbnailUrl}
			<div class="h-48 bg-cover bg-center" style="background-image: url('{playlist.thumbnailUrl}')"></div>
			{:else}
			<div class="h-48 bg-gradient-to-br from-secondary/20 to-purple-300 flex items-center justify-center">
				<svg class="w-16 h-16 text-white" fill="none" stroke="currentColor" viewBox="0 0 24 24">
					<path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M9 19V6l12-3v13M9 19c0 1.105-1.343 2-3 2s-3-.895-3-2 1.343-2 3-2 3 .895 3 2z"></path>
				</svg>
			</div>
			{/if}
			
			<div class="p-6">
				<div class="flex items-start justify-between mb-4">
					<h3 class="text-xl font-bold text-gray-800 line-clamp-2">{playlist.title}</h3>
					<div class="flex flex-col items-end space-y-1">
						<span class="px-2 py-1 text-xs rounded-full {playlist.isPublic ? 'bg-green-100 text-green-800' : 'bg-blue-100 text-blue-800'}">
							{playlist.isPublic ? 'Public' : 'Private'}
						</span>
						{#if playlist.isCollaborative}
						<span class="px-2 py-1 text-xs rounded-full bg-purple-100 text-purple-800">
							Collaborative
						</span>
						{/if}
					</div>
				</div>
				
				{#if playlist.description}
				<p class="text-gray-600 text-sm mb-4 line-clamp-3">{playlist.description}</p>
				{/if}
				
				<div class="space-y-2 text-sm text-gray-500 mb-4">
					<div class="flex items-center">
						<span class="font-medium">Owner:</span>
						<span class="ml-2">{playlist.ownerName}</span>
					</div>
					
					<div class="flex items-center">
						<span class="font-medium">Tracks:</span>
						<span class="ml-2">{playlist.tracks.length}</span>
					</div>
					
					<div class="flex items-center">
						<span class="font-medium">Collaborators:</span>
						<span class="ml-2">{playlist.collaborators.length}</span>
					</div>
					
					<div class="flex items-center">
						<span class="font-medium">Created:</span>
						<span class="ml-2">{formatDate(playlist.createdAt)}</span>
					</div>
				</div>
				
				<div class="flex space-x-3">
					<a 
						href="/playlists/{playlist.id}"
						class="flex-1 bg-secondary text-white text-center py-2 px-4 rounded-lg font-medium hover:bg-secondary/80 transition-colors"
					>
						Open Playlist
					</a>
				</div>
			</div>
		</div>
		{/each}
	</div>
	{/if}
</div>

<!-- Create Playlist Modal -->
{#if showCreateModal}
<div class="fixed inset-0 bg-black bg-opacity-50 flex items-center justify-center z-50 p-4">
	<div class="bg-white rounded-lg max-w-md w-full">
		<div class="p-6">
			<div class="flex justify-between items-center mb-4">
				<h2 class="text-xl font-bold text-gray-800">Create New Playlist</h2>
				<button 
					onclick={() => showCreateModal = false}
					aria-label="Close modal"
					class="text-gray-400 hover:text-gray-600"
				>
					<svg class="w-6 h-6" fill="none" stroke="currentColor" viewBox="0 0 24 24">
						<path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M6 18L18 6M6 6l12 12"></path>
					</svg>
				</button>
			</div>
			
			<form onsubmit={createPlaylist} class="space-y-4">
				<div>
					<label for="playlistTitle" class="block text-sm font-medium text-gray-700 mb-1">Playlist Title</label>
					<input 
						id="playlistTitle"
						type="text" 
						bind:value={newPlaylist.title}
						required
						class="w-full px-3 py-2 border border-gray-300 rounded-lg focus:outline-none focus:ring-2 focus:ring-secondary"
						placeholder="Enter playlist title"
					/>
				</div>
				
				<div>
					<label for="playlistDescription" class="block text-sm font-medium text-gray-700 mb-1">Description</label>
					<textarea 
						id="playlistDescription"
						bind:value={newPlaylist.description}
						rows="3"
						class="w-full px-3 py-2 border border-gray-300 rounded-lg focus:outline-none focus:ring-2 focus:ring-secondary"
						placeholder="Playlist description (optional)"
					></textarea>
				</div>
				
				<div class="space-y-3">
					<div class="flex items-center">
						<input 
							type="checkbox" 
							id="isPublic"
							bind:checked={newPlaylist.isPublic}
							class="mr-2"
						/>
						<label for="isPublic" class="text-sm text-gray-700">Public playlist (anyone can find it)</label>
					</div>
					
					<div class="flex items-center">
						<input 
							type="checkbox" 
							id="isCollaborative"
							bind:checked={newPlaylist.isCollaborative}
							class="mr-2"
						/>
						<label for="isCollaborative" class="text-sm text-gray-700">Allow collaboration</label>
					</div>
				</div>
				
				<div>
					<label for="licenseType" class="block text-sm font-medium text-gray-700 mb-1">License Type</label>
					<select 
						id="licenseType"
						bind:value={newPlaylist.licenseType}
						class="w-full px-3 py-2 border border-gray-300 rounded-lg focus:outline-none focus:ring-2 focus:ring-secondary"
					>
						<option value="free">Free (anyone can edit)</option>
						<option value="invited_only">Invited users only</option>
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
						{loading ? 'Creating...' : 'Create Playlist'}
					</button>
				</div>
			</form>
		</div>
	</div>
</div>
{/if}
