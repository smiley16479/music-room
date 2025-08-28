<script lang="ts">
	import { onMount, onDestroy } from "svelte";
	import { page } from "$app/stores";
	import { authStore } from "$lib/stores/auth";
	import { playlistsService, type Playlist } from "$lib/services/playlists";
	import { socketService } from "$lib/services/socket";
	import { goto, replaceState } from "$app/navigation";

	// Svelte 5 runes - using correct syntax for state and reactivity
	let { data } = $props();
	let playlists = $state<Playlist[]>(data.playlists || []);
	let filteredPlaylists = $state<Playlist[]>([]);
	let loading = $state(false);
	let error = $state("");
	// Use the global auth store
	let user = $derived($authStore);
	let isSocketConnected = $state(false);
	let socketRetryAttempts = $state(0);
	let maxSocketRetries = 3;

	let showCreateModal = $state(false);
	let activeTab = $state<"all" | "mine">("all");
	let searchQuery = $state("");
	let sortBy = $state<"date" | "name" | "owner" | "tracks" | "collaborators">("date");
	let sortOrder = $state<"asc" | "desc">("desc");

	// Create playlist form
	let newPlaylist = $state({
		name: "",
		description: "",
		visibility: "public" as "public" | "private",
		licenseType: "open" as "open" | "invited",
	});

	// Automatically set licenseType to 'invited' when visibility is 'private'
	$effect(() => {
		if (newPlaylist.visibility === 'private') {
			newPlaylist.licenseType = 'invited';
		}
	});

	// Update tab based on URL parameter on initial load only
	let initialTabFromURL = $derived($page.url.searchParams.get("tab") || "all");
	let hasInitialized = $state(false);
	
	$effect(() => {
		if (!hasInitialized) {
			activeTab = initialTabFromURL as typeof activeTab;
			hasInitialized = true;
		}
	});

	$effect(() => {
		if (data.playlists) {
			playlists = data.playlists;
		}
	});

	onMount(async () => {
		await setupSocketConnection();
		
		loadPlaylists();
	});

	onDestroy(() => {
		cleanupSocketConnection();
	});

	async function setupSocketConnection() {
		try {
			if (!socketService.isConnected()) {
				await socketService.connect();
			}

			setupPlaylistSocketListeners();
			
			socketService.emit('join-playlists-room', {});
			
			isSocketConnected = true;
			socketRetryAttempts = 0;
			console.log('Socket connected for playlists page - listening for global playlist events');
		} catch (err) {
			console.error('Failed to set up socket connection:', err);
			isSocketConnected = false;
			
			if (socketRetryAttempts < maxSocketRetries) {
				socketRetryAttempts++;
				console.log(`Retrying socket connection (${socketRetryAttempts}/${maxSocketRetries}) in 3 seconds...`);
				setTimeout(() => {
					setupSocketConnection();
				}, 3000);
			} else {
				console.error('Max socket retry attempts reached. Operating in offline mode.');
				error = 'Real-time updates unavailable. Please refresh the page to retry.';
			}
		}
	}

	function setupPlaylistSocketListeners() {
		socketService.on('playlist-created', handlePlaylistCreated);
		socketService.on('playlist-updated', handlePlaylistUpdated);
		socketService.on('playlist-deleted', handlePlaylistDeleted);
	}

	function cleanupSocketConnection() {
		if (isSocketConnected) {
			socketService.emit('leave-playlists-room', {});
			
			socketService.off('playlist-created', handlePlaylistCreated);
			socketService.off('playlist-updated', handlePlaylistUpdated);
			socketService.off('playlist-deleted', handlePlaylistDeleted);
			isSocketConnected = false;
			console.log('Cleaned up socket connection for playlists page');
		}
	}

	// Socket event handlers for real-time updates
	function handlePlaylistCreated(data: { playlist: Playlist }) {
		console.log('Playlist created:', data.playlist);
		// Only add if it's not an event playlist
		if (!data.playlist.eventId) {
			playlists = [...playlists, data.playlist];
		}
	}

	function handlePlaylistUpdated(data: { playlist: Playlist }) {
		console.log('Playlist updated:', data.playlist);
		// Update if it exists and is not an event playlist
		if (!data.playlist.eventId) {
			playlists = playlists.map(p => p.id === data.playlist.id ? data.playlist : p);
		} else {
			// If it became an event playlist, remove it from the list
			playlists = playlists.filter(p => p.id !== data.playlist.id);
		}
	}

	function handlePlaylistDeleted(data: { playlistId: string }) {
		console.log('Playlist deleted:', data.playlistId);
		playlists = playlists.filter(p => p.id !== data.playlistId);
	}

	// Filter and sort playlists
	$effect(() => {
		let filtered = [...playlists];

		// First, filter out event playlists (playlists with eventId)
		filtered = filtered.filter(playlist => !playlist.eventId);

		// Apply search filter
		if (searchQuery.trim()) {
			const query = searchQuery.toLowerCase().trim();
			filtered = filtered.filter(playlist => 
				playlist.name.toLowerCase().includes(query) ||
				playlist.creator?.displayName?.toLowerCase().includes(query) ||
				playlist.description?.toLowerCase().includes(query)
			);
		}

		// Apply tab filter
		if (activeTab === "mine" && user) {
			filtered = filtered.filter(playlist => 
				playlist.creatorId === user!.id || 
				playlist.collaborators.some(collab => collab.userId === user!.id)
			);
		} else if (activeTab === "all") {
			// For "all" tab, show only public playlists and private ones user has access to
			filtered = filtered.filter(playlist => 
				playlist.visibility === "public" || 
				(user && (playlist.creatorId === user.id || 
					playlist.collaborators.some(collab => collab.userId === user!.id)))
			);
		}

		// Apply sorting
		filtered.sort((a, b) => {
			let compareValue = 0;
			
			switch (sortBy) {
				case "name":
					compareValue = a.name.localeCompare(b.name);
					break;
				case "owner":
					compareValue = (a.creator?.displayName || "").localeCompare(b.creator?.displayName || "");
					break;
				case "tracks":
					compareValue = (a.trackCount || 0) - (b.trackCount || 0);
					break;
				case "collaborators":
					compareValue = a.collaborators.length - b.collaborators.length;
					break;
				case "date":
				default:
					compareValue = new Date(a.createdAt).getTime() - new Date(b.createdAt).getTime();
					break;
			}
			
			return sortOrder === "asc" ? compareValue : -compareValue;
		});

		filteredPlaylists = filtered;
	});

	// No need for onMount to initialize user, it's handled by the store
	// Watch for activeTab changes specifically
	$effect(() => {
		// Track activeTab to trigger when it changes
		activeTab;
		
		// Only load if we've initialized and user state is resolved
		if (hasInitialized && user !== null) {
			loadPlaylists();
		}
	});

	async function loadPlaylists() {
		loading = true;
		error = "";
		try {
			if (activeTab === "mine" && user) {
				playlists = await playlistsService.getPlaylists(undefined, user.id);
			} else {
				playlists = await playlistsService.getPlaylists();
			}
		} catch (err) {
			error = "Failed to load playlists";
			console.error(err);
		} finally {
			loading = false;
		}
	}

	async function createPlaylist(event: SubmitEvent) {
		event.preventDefault();
		if (!user) {
			goto("/auth/login");
			return;
		}

		loading = true;
		error = "";
		try {
			await playlistsService.createPlaylist(newPlaylist);
			showCreateModal = false;
			// Reset form
			newPlaylist = {
				name: "",
				description: "",
				visibility: "public",
				licenseType: "open",
			};
			await loadPlaylists();
		} catch (err) {
			error =
				err instanceof Error
					? err.message
					: "Failed to create playlist";
		} finally {
			loading = false;
		}
	}

	function handleTabChange(newTab: "all" | "mine") {
		// Only change if it's actually different
		if (activeTab !== newTab) {
			activeTab = newTab;
			
			// Update URL to reflect current tab
			const url = new URL(window.location.href);
			if (activeTab === "all") {
				url.searchParams.delete("tab");
			} else {
				url.searchParams.set("tab", activeTab);
			}
			replaceState(url.href, {});
			
			// The effect will automatically load playlists when activeTab changes
		}
	}

	function handleSort(newSortBy: typeof sortBy) {
		if (sortBy === newSortBy) {
			sortOrder = sortOrder === "asc" ? "desc" : "asc";
		} else {
			sortBy = newSortBy;
			sortOrder = "desc";
		}
	}

	function formatDate(dateString: string) {
		return new Date(dateString).toLocaleDateString("en-US", {
			year: "numeric",
			month: "short",
			day: "numeric",
		});
	}

	function getSortIcon(column: typeof sortBy) {
		if (sortBy !== column) return "↕";
		return sortOrder === "asc" ? "↑" : "↓";
	}
</script>

<svelte:head>
	<title>Playlists - Music Room</title>
	<meta
		name="description"
		content="Create and collaborate on music playlists in real-time"
	/>
</svelte:head>

<div class="container mx-auto px-4 py-8">
	<div class="flex flex-col md:flex-row text-center md:text-start justify-between items-center mb-8">
		<div>
			<h1 class="font-family-main text-4xl font-bold text-gray-800 mb-2">
				Music Playlists
			</h1>
			<p class="text-gray-600">
				Create and collaborate on playlists in real-time
			</p>
		</div>

		{#if user}
			<button
				onclick={() => (showCreateModal = true)}
				class="bg-secondary text-white px-6 py-3 rounded-lg font-semibold hover:bg-secondary/80 transition-colors mt-4 md:mt-0"
			>
				Create Playlist
			</button>
		{/if}
	</div>

	<!-- Tab Navigation -->
	<div class="flex space-x-4 mb-6">
		<button
			class="px-4 py-2 rounded-lg font-medium transition-colors {activeTab === 'all'
				? 'bg-secondary text-white'
				: 'bg-gray-200 text-gray-700 hover:bg-gray-300'}"
			onclick={() => handleTabChange("all")}
		>
			All Playlists
		</button>
		{#if user}
			<button
				class="px-4 py-2 rounded-lg font-medium transition-colors {activeTab === 'mine'
					? 'bg-secondary text-white'
					: 'bg-gray-200 text-gray-700 hover:bg-gray-300'}"
				onclick={() => handleTabChange("mine")}
			>
				My Playlists
			</button>
		{/if}
	</div>

	<!-- Search and Sort Controls -->
	<div class="bg-white rounded-lg shadow-sm border border-gray-200 p-4 mb-6">
		<div class="flex flex-col sm:flex-row gap-4 items-start sm:items-center justify-between">
			<!-- Search -->
			<div class="flex-1 w-full sm:max-w-md">
				<label for="search" class="sr-only">Search playlists</label>
				<div class="relative">
					<div class="absolute inset-y-0 left-0 pl-3 flex items-center pointer-events-none">
						<svg class="h-5 w-5 text-gray-400" fill="none" stroke="currentColor" viewBox="0 0 24 24">
							<path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M21 21l-6-6m2-5a7 7 0 11-14 0 7 7 0 0114 0z"></path>
						</svg>
					</div>
					<input
						id="search"
						type="text"
						bind:value={searchQuery}
						placeholder="Search playlists by name, owner, or description..."
						class="block w-full pl-10 pr-3 py-2 border border-gray-300 rounded-lg focus:outline-none focus:ring-2 focus:ring-secondary focus:border-transparent"
					/>
				</div>
			</div>

			<!-- Sort Controls -->
			<div class="flex items-center space-x-4">
				<span class="text-sm text-gray-600 font-medium hidden sm:block">Sort by:</span>
				<button
					onclick={() => handleSort("date")}
					class="px-3 py-1 text-sm rounded-md transition-colors {sortBy === 'date' ? 'bg-secondary text-white' : 'bg-gray-100 text-gray-700 hover:bg-gray-200'}"
				>
					Date {getSortIcon("date")}
				</button>
				<button
					onclick={() => handleSort("tracks")}
					class="px-3 py-1 text-sm rounded-md transition-colors {sortBy === 'tracks' ? 'bg-secondary text-white' : 'bg-gray-100 text-gray-700 hover:bg-gray-200'}"
				>
					Tracks {getSortIcon("tracks")}
				</button>
				<button
					onclick={() => handleSort("collaborators")}
					class="px-3 py-1 text-sm rounded-md transition-colors {sortBy === 'collaborators' ? 'bg-secondary text-white' : 'bg-gray-100 text-gray-700 hover:bg-gray-200'}"
				>
					Collaborators {getSortIcon("collaborators")}
				</button>
			</div>
		</div>
	</div>

	{#if error}
		<div
			class="bg-red-100 border border-red-400 text-red-700 px-4 py-3 rounded mb-6"
		>
			{error}
		</div>
	{/if}

	{#if loading}
		<div class="flex justify-center items-center py-12">
			<div
				class="animate-spin rounded-full h-8 w-8 border-b-2 border-secondary"
			></div>
		</div>
	{:else if filteredPlaylists.length === 0}
		<div class="text-center py-12">
			<h3 class="text-xl font-semibold text-gray-700 mb-2">
				{#if searchQuery.trim()}
					No playlists found matching "{searchQuery.trim()}"
				{:else}
					No playlists found
				{/if}
			</h3>
			<p class="text-gray-500 mb-4">
				{#if activeTab === "mine"}
					You haven't created any playlists yet, and you haven't been invited to any.
				{:else}
					Be the first to create a playlist!
				{/if}
			</p>
			{#if user}
				<button
					onclick={() => (showCreateModal = true)}
					class="bg-secondary text-white px-6 py-2 rounded-lg font-medium hover:bg-secondary/80 transition-colors"
				>
					Create Playlist
				</button>
			{/if}
		</div>
	{:else}
		<!-- Playlists List -->
		<div class="bg-white rounded-lg shadow-sm border border-gray-200 overflow-hidden">
			{#each filteredPlaylists as playlist, index}
				<div class="border-b border-gray-200 last:border-b-0 hover:bg-gray-50 transition-colors">
					<a 
						href="/playlists/{playlist.id}"
						class="block p-4 hover:no-underline"
					>
						<div class="flex items-start sm:space-x-4 space-x-2">
							<!-- Playlist Cover -->
							<div class="flex-shrink-0">
								{#if playlist.coverImageUrl}
									<div class="w-16 h-16 bg-cover bg-center rounded-lg" style="background-image: url('{playlist.coverImageUrl}')"></div>
								{:else}
									<div class="w-16 h-16 bg-gradient-to-br from-secondary/20 to-purple-300 rounded-lg flex items-center justify-center">
										<svg class="w-8 h-8 text-white" fill="none" stroke="currentColor" viewBox="0 0 24 24">
											<path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M9 19V6l12-3v13M9 19c0 1.105-1.343 2-3 2s-3-.895-3-2 1.343-2 3-2 3 .895 3 2z"></path>
										</svg>
									</div>
								{/if}
							</div>
 
							<!-- Playlist Info -->
							<div class="flex-1 min-w-0">
								<div class="flex items-start justify-between mb-2">
									<div class="flex-1 min-w-0">
										<h3 class="text-lg font-semibold text-gray-900 truncate">{playlist.name}</h3>
										<p class="text-sm text-gray-600">by {playlist.creator?.displayName || 'Unknown'}</p>
									</div>
									<div class="flex flex-col space-y-2 md:flex-row md:space-x-2 md:space-y-0 items-center ml-4">
										{#if user && playlist.collaborators.some(collab => collab.id === user!.id)}
											<span class="px-2 py-1 text-xs rounded-full bg-amber-100 text-amber-800">
												Collaborator
											</span>
										{/if}
										{#if playlist.visibility === 'private'}
											<span class="px-2 py-1 text-xs rounded-full bg-red-100 text-red-800">
												Private
											</span>
										{/if}
										{#if playlist.visibility !== 'private' && playlist.licenseType === 'invited'}
											<span class="px-2 py-1 text-xs rounded-full bg-blue-100 text-blue-800">
												Closed
											</span>
										{/if}
									</div>
								</div>

								{#if playlist.description}
									<p class="text-sm text-gray-600 mb-2 line-clamp-2 hidden sm:block hyphens-auto break-all truncate">{playlist.description}</p>
								{/if}

								<div class="flex items-center space-x-6 text-sm text-gray-500 hidden sm:flex">
									<div class="flex items-center">
										<svg class="w-4 h-4 mr-1" fill="none" stroke="currentColor" viewBox="0 0 24 24">
											<path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M9 19V6l12-3v13M9 19c0 1.105-1.343 2-3 2s-3-.895-3-2 1.343-2 3-2 3 .895 3 2z"></path>
										</svg>
										<span>{playlist.trackCount || 0} tracks</span>
									</div>
									{#if playlist.licenseType === "invited"}
										<div class="flex items-center">
											<svg class="w-4 h-4 mr-1" fill="none" stroke="currentColor" viewBox="0 0 24 24">
												<path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M12 4.354a4 4 0 110 5.292M15 21H3v-1a6 6 0 0112 0v1zm0 0h6v-1a6 6 0 00-9-5.197m13.5-9a2.5 2.5 0 11-5 0 2.5 2.5 0 015 0z"></path>
											</svg>
											<span>{playlist.collaborators.length + 1} collaborators</span>
										</div>
									{/if}
									<div class="flex items-center">
										<svg class="w-4 h-4 mr-1" fill="none" stroke="currentColor" viewBox="0 0 24 24">
											<path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M8 7V3m8 4V3m-9 8h10M5 21h14a2 2 0 002-2V7a2 2 0 00-2-2H5a2 2 0 00-2 2v12a2 2 0 002 2z"></path>
										</svg>
										<span>{formatDate(playlist.createdAt)}</span>
									</div>
								</div>
							</div>

							<!-- Arrow indicator -->
							<div class="flex-shrink-0 hidden sm:flex items-center">
								<svg class="w-5 h-5 text-gray-400" fill="none" stroke="currentColor" viewBox="0 0 24 24">
									<path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M9 5l7 7-7 7"></path>
								</svg>
							</div>
						</div>
					</a>
				</div>
			{/each}
		</div>

		<!-- Results count -->
		<div class="mt-4 text-sm text-gray-600 text-center">
			Showing {filteredPlaylists.length} playlist{filteredPlaylists.length !== 1 ? 's' : ''}
			{#if searchQuery.trim()}
				matching "{searchQuery.trim()}"
			{/if}
		</div>
	{/if}
</div>

<!-- Create Playlist Modal -->
{#if showCreateModal}
	<div
		class="fixed inset-0 bg-black/50 z-51 flex items-center justify-center z-50 p-4"
	>
		<div class="bg-white rounded-lg max-w-md w-full">
			<div class="p-6">
				<div class="flex justify-between items-center mb-4">
					<h2 class="text-xl font-bold text-gray-800">
						Create New Playlist
					</h2>
					<button
						onclick={() => (showCreateModal = false)}
						aria-label="Close modal"
						class="text-gray-400 hover:text-gray-600"
					>
						<svg
							class="w-6 h-6"
							fill="none"
							stroke="currentColor"
							viewBox="0 0 24 24"
						>
							<path
								stroke-linecap="round"
								stroke-linejoin="round"
								stroke-width="2"
								d="M6 18L18 6M6 6l12 12"
							></path>
						</svg>
					</button>
				</div>

				<form
					onsubmit={(e) => {
						e.preventDefault();
						createPlaylist(e);
					}}
					class="space-y-4"
				>
					<div>
						<label
							for="playlistTitle"
							class="block text-sm font-medium text-gray-700 mb-1"
							>Playlist Name</label
						>
						<input
							id="playlistTitle"
							type="text"
							bind:value={newPlaylist.name}
							required
							class="w-full px-3 py-2 border border-gray-300 rounded-lg focus:outline-none focus:ring-2 focus:ring-secondary"
							placeholder="Enter playlist name"
						/>
					</div>

					<div>
						<label
							for="playlistDescription"
							class="block text-sm font-medium text-gray-700 mb-1"
							>Description</label
						>
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
								type="radio"
								id="public"
								name="visibility"
								value="public"
								bind:group={newPlaylist.visibility}
								class="mr-2"
							/>
							<label for="public" class="text-sm text-gray-700"
								>Public playlist - Anyone can find it</label
							>
						</div>

						<div class="flex items-center">
							<input
								type="radio"
								id="private"
								name="visibility"
								value="private"
								bind:group={newPlaylist.visibility}
								class="mr-2"
							/>
							<label for="private" class="text-sm text-gray-700"
								>Private playlist - Invitation only</label
							>
						</div>

					</div>

					<div>
						<label
							for="licenseType"
							class="block text-sm font-medium text-gray-700 mb-1"
							>License Type</label
						>
						<select
							id="licenseType"
							bind:value={newPlaylist.licenseType}
							class="w-full px-3 py-2 border border-gray-300 rounded-lg focus:outline-none focus:ring-2 focus:ring-secondary"
						>
							<option value="open" disabled={newPlaylist.visibility === 'private'}>Open - anyone can edit (public only)</option>
							<option value="invited">Invited users only</option>
						</select>
					</div>

					<div class="flex space-x-3 pt-4">
						<button
							type="button"
							onclick={() => (showCreateModal = false)}
							class="flex-1 px-4 py-2 border border-gray-300 text-gray-700 rounded-lg hover:bg-gray-50"
						>
							Cancel
						</button>
						<button
							type="submit"
							disabled={loading}
							class="flex-1 bg-secondary text-white px-4 py-2 rounded-lg hover:bg-secondary/80 disabled:opacity-50"
						>
							{loading ? "Creating..." : "Create Playlist"}
						</button>
					</div>
				</form>
			</div>
		</div>
	</div>
{/if}
