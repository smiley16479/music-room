<script lang="ts">
	import { deezerService, type DeezerTrack } from '$lib/services/deezer';
	import { playlistsService } from '$lib/services/playlists';
	import { authStore } from '$lib/stores/auth';
	import { onMount } from 'svelte';

	let { 
		playlistId,
		eventId,
		onTrackAdded = () => {},
		onClose = () => {}
	}: {
		playlistId?: string;
		eventId?: string;
		onTrackAdded?: () => void;
		onClose?: () => void;
	} = $props();

	// Ensure we have either playlistId or eventId, but not both
	if (!playlistId && !eventId) {
		throw new Error('Either playlistId or eventId must be provided');
	}
	if (playlistId && eventId) {
		throw new Error('Cannot provide both playlistId and eventId');
	}

	let searchQuery = $state('');
	let searchResults = $state<DeezerTrack[]>([]);
	let topTracks = $state<DeezerTrack[]>([]);
	let isSearching = $state(false);
	let isLoadingTop = $state(false);
	let searchError = $state('');
	let isAddingTrack = $state<string | null>(null);
	let currentUser = $derived($authStore);
	let activeTab = $state<'search' | 'top' | 'advanced'>('search');

	// Advanced search fields
	let advancedSearch = $state({
		artist: '',
		album: '',
		track: '',
		genre: '',
		durationMin: undefined as number | undefined,
		durationMax: undefined as number | undefined,
		year: undefined as number | undefined
	});

	let searchTimeout: NodeJS.Timeout;

	onMount(() => {
		loadTopTracks();
	});

	// Load top tracks on component mount
	async function loadTopTracks() {
		isLoadingTop = true;
		try {
			const response = await deezerService.getTopTracks(20);
			topTracks = response?.data || [];
		} catch (error) {
			console.error('Failed to load top tracks:', error);
			topTracks = [];
		} finally {
			isLoadingTop = false;
		}
	}

	// Debounced search function
	function handleSearchInput() {
		clearTimeout(searchTimeout);
		if (searchQuery.trim().length < 2) {
			searchResults = [];
			return;
		}

		searchTimeout = setTimeout(() => {
			performSearch();
		}, 800); // Increased delay to 800ms to reduce API requests
	}

	async function performSearch() {
		if (!searchQuery.trim()) {
			searchResults = [];
			return;
		}

		isSearching = true;
		searchError = '';

		try {
			const response = await deezerService.searchTracks({
				query: searchQuery,
				limit: 20
			});
			searchResults = response?.data || [];
		} catch (error) {
			searchError = error instanceof Error ? error.message : 'Failed to search tracks';
			searchResults = [];
		} finally {
			isSearching = false;
		}
	}

	async function performAdvancedSearch() {
		// Build search parameters from advanced search form
		const params: any = {
			limit: 20
		};

		if (advancedSearch.artist) params.artist = advancedSearch.artist;
		if (advancedSearch.album) params.album = advancedSearch.album;
		if (advancedSearch.track) params.track = advancedSearch.track;
		if (advancedSearch.genre) params.genre = advancedSearch.genre;
		if (advancedSearch.durationMin) params.durationMin = advancedSearch.durationMin;
		if (advancedSearch.durationMax) params.durationMax = advancedSearch.durationMax;
		if (advancedSearch.year) params.year = advancedSearch.year;

		// Check if at least one search field is filled
		const hasSearchCriteria = Object.values(params).some(value => 
			value !== undefined && value !== '' && value !== null
		);

		if (!hasSearchCriteria) {
			searchError = 'Please fill in at least one search criteria';
			return;
		}

		isSearching = true;
		searchError = '';

		try {
			const response = await deezerService.searchAdvanced(params);
			searchResults = response?.data || [];
		} catch (error) {
			searchError = error instanceof Error ? error.message : 'Failed to perform advanced search';
			searchResults = [];
		} finally {
			isSearching = false;
		}
	}

	async function addTrackToPlaylist(deezerTrack: DeezerTrack) {
		if (!currentUser || isAddingTrack === deezerTrack.id) return;

		isAddingTrack = deezerTrack.id;
		searchError = '';

		try {
			const trackData = {
				deezerId: deezerTrack.id,
				title: deezerTrack.title,
				artist: deezerTrack.artist,
				album: deezerTrack.album,
				albumCoverUrl: deezerTrack.albumCoverUrl || deezerTrack.albumCoverMediumUrl,
				previewUrl: deezerTrack.previewUrl,
				duration: deezerTrack.duration
			};

			// Add to playlist
			await playlistsService.addTrackToPlaylist(playlistId, trackData);
			
			onTrackAdded();
		} catch (error) {
			searchError = error instanceof Error ? error.message : 'Failed to add track';
		} finally {
			isAddingTrack = null;
		}
	}

	function formatDuration(seconds: number): string {
		const minutes = Math.floor(seconds / 60);
		const remainingSeconds = seconds % 60;
		return `${minutes}:${remainingSeconds.toString().padStart(2, '0')}`;
	}

	function clearSearch() {
		searchQuery = '';
		searchResults = [];
		searchError = '';
	}

	function clearAdvancedSearch() {
		advancedSearch = {
			artist: '',
			album: '',
			track: '',
			genre: '',
			durationMin: undefined,
			durationMax: undefined,
			year: undefined
		};
		searchResults = [];
		searchError = '';
	}

	function switchTab(tab: 'search' | 'top' | 'advanced') {
		activeTab = tab;
		searchError = '';
		if (tab === 'search') {
			searchResults = [];
		} else if (tab === 'advanced') {
			searchResults = [];
		}
	}
</script>

<!-- Enhanced Search Modal -->
<div class="fixed inset-0 bg-black/50 z-51 flex items-start justify-center z-50 p-4">
	<div class="bg-white rounded-lg max-w-5xl w-full max-h-[90vh] overflow-hidden mt-[5vh]">
		<!-- Header -->
		<div class="p-6 border-b border-gray-200">
			<div class="flex justify-between items-center mb-4">
				<h2 class="text-xl font-bold text-gray-800">
					Add Music to {playlistId ? 'Playlist' : 'Event'}
				</h2>
				<button 
					onclick={onClose}
					aria-label="Close modal"
					class="text-gray-400 hover:text-gray-600 transition-colors"
				>
					<svg class="w-6 h-6" fill="none" stroke="currentColor" viewBox="0 0 24 24">
						<path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M6 18L18 6M6 6l12 12"></path>
					</svg>
				</button>
			</div>
			
			<!-- Tab Navigation -->
			<div class="flex space-x-1 bg-gray-100 rounded-lg p-1">
				<button
					onclick={() => switchTab('search')}
					class="flex-1 py-2 px-4 rounded-md text-sm font-medium transition-colors {activeTab === 'search' ? 'bg-white text-gray-900 shadow-sm' : 'text-gray-500 hover:text-gray-700'}"
				>
					Quick Search
				</button>
				<button
					onclick={() => switchTab('top')}
					class="flex-1 py-2 px-4 rounded-md text-sm font-medium transition-colors {activeTab === 'top' ? 'bg-white text-gray-900 shadow-sm' : 'text-gray-500 hover:text-gray-700'}"
				>
					Top Tracks
				</button>
				<button
					onclick={() => switchTab('advanced')}
					class="flex-1 py-2 px-4 rounded-md text-sm font-medium transition-colors {activeTab === 'advanced' ? 'bg-white text-gray-900 shadow-sm' : 'text-gray-500 hover:text-gray-700'}"
				>
					Advanced Search
				</button>
			</div>
		</div>

		<!-- Tab Content -->
		<div class="p-6 overflow-y-auto max-h-[60vh]">
			{#if searchError}
				<div class="bg-red-100 border border-red-400 text-red-700 px-4 py-3 rounded mb-4">
					{searchError}
				</div>
			{/if}

			<!-- Quick Search Tab -->
			{#if activeTab === 'search'}
				<div class="mb-6">
					<div class="relative">
						<div class="absolute inset-y-0 left-0 pl-3 flex items-center pointer-events-none">
							<svg class="h-5 w-5 text-gray-400" fill="none" stroke="currentColor" viewBox="0 0 24 24">
								<path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M21 21l-6-6m2-5a7 7 0 11-14 0 7 7 0 0114 0z"></path>
							</svg>
						</div>
						<input
							type="text"
							bind:value={searchQuery}
							oninput={handleSearchInput}
							placeholder="Search for tracks, artists, or albums..."
							class="w-full pl-10 pr-4 py-3 border border-gray-300 rounded-lg focus:outline-none focus:ring-2 focus:ring-secondary focus:border-transparent"
						/>
						{#if searchQuery}
							<button
								onclick={clearSearch}
								aria-label="Clear search"
								class="absolute inset-y-0 right-0 pr-3 flex items-center"
							>
								<svg class="h-5 w-5 text-gray-400 hover:text-gray-600" fill="none" stroke="currentColor" viewBox="0 0 24 24">
									<path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M6 18L18 6M6 6l12 12"></path>
								</svg>
							</button>
						{/if}
					</div>
				</div>

				{#if isSearching}
					<div class="flex justify-center items-center py-8">
						<div class="animate-spin rounded-full h-8 w-8 border-b-2 border-secondary"></div>
						<span class="ml-2 text-gray-600">Searching...</span>
					</div>
				{:else if searchQuery && searchResults.length === 0 && !isSearching}
					<div class="text-center py-8">
						<p class="text-gray-500">No tracks found for "{searchQuery}"</p>
						<p class="text-gray-400 text-sm mt-2">Try searching with different keywords</p>
					</div>
				{:else if searchResults.length > 0}
					<div class="space-y-3">
						{#each searchResults as track}
							<div class="flex items-center space-x-4 p-3 border border-gray-200 rounded-lg hover:bg-gray-50 transition-colors">
								<img 
									src={track.albumCoverMediumUrl || track.albumCoverUrl} 
									alt={track.album}
									class="w-16 h-16 rounded object-cover"
									loading="lazy"
								/>
								
								<div class="flex-1 min-w-0">
									<h4 class="font-medium text-gray-800 truncate">{track.title}</h4>
									<p class="text-sm text-gray-600 truncate">{track.artist}</p>
									<p class="text-xs text-gray-500 truncate">{track.album}</p>
									<div class="flex items-center space-x-2 mt-1">
										<span class="text-xs text-gray-400">{formatDuration(track.duration)}</span>
									</div>
								</div>
								
								{#if track.previewUrl}
									<audio controls class="w-32" crossorigin="anonymous">
										<source src={track.previewUrl} type="audio/mpeg">
										Your browser does not support the audio element.
									</audio>
								{/if}
								
								<button
									onclick={() => addTrackToPlaylist(track)}
									disabled={isAddingTrack === track.id}
									class="bg-secondary text-white px-4 py-2 rounded-lg hover:bg-secondary/80 transition-colors disabled:opacity-50 disabled:cursor-not-allowed flex items-center space-x-2"
								>
									{#if isAddingTrack === track.id}
										<div class="animate-spin rounded-full h-4 w-4 border-b-2 border-white"></div>
										<span>Adding...</span>
									{:else}
										<svg class="w-4 h-4" fill="none" stroke="currentColor" viewBox="0 0 24 24">
											<path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M12 6v6m0 0v6m0-6h6m-6 0H6"></path>
										</svg>
										<span>Add</span>
									{/if}
								</button>
							</div>
						{/each}
					</div>
				{:else if !searchQuery}
					<div class="text-center py-8">
						<svg class="w-16 h-16 text-gray-300 mx-auto mb-4" fill="none" stroke="currentColor" viewBox="0 0 24 24">
							<path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M21 21l-6-6m2-5a7 7 0 11-14 0 7 7 0 0114 0z"></path>
						</svg>
						<p class="text-gray-500">Start typing to search for music</p>
						<p class="text-gray-400 text-sm mt-2">Search for tracks, artists, or albums</p>
					</div>
				{/if}

			<!-- Top Tracks Tab -->
			{:else if activeTab === 'top'}
				{#if isLoadingTop}
					<div class="flex justify-center items-center py-8">
						<div class="animate-spin rounded-full h-8 w-8 border-b-2 border-secondary"></div>
						<span class="ml-2 text-gray-600">Loading top tracks...</span>
					</div>
				{:else if topTracks.length > 0}
					<div class="space-y-3">
						{#each topTracks as track, index}
							<div class="flex items-center space-x-4 p-3 border border-gray-200 rounded-lg hover:bg-gray-50 transition-colors">
								<div class="w-8 h-8 bg-gradient-to-r from-yellow-400 to-orange-500 rounded-full flex items-center justify-center text-sm font-bold text-white">
									{index + 1}
								</div>
								
								<img 
									src={track.albumCoverMediumUrl || track.albumCoverUrl} 
									alt={track.album}
									class="w-16 h-16 rounded object-cover"
									loading="lazy"
								/>
								
								<div class="flex-1 min-w-0">
									<h4 class="font-medium text-gray-800 truncate">{track.title}</h4>
									<p class="text-sm text-gray-600 truncate">{track.artist}</p>
									<p class="text-xs text-gray-500 truncate">{track.album}</p>
									<div class="flex items-center space-x-2 mt-1">
										<span class="text-xs text-gray-400">{formatDuration(track.duration)}</span>
									</div>
								</div>
								
								{#if track.previewUrl}
									<audio controls class="w-32" crossorigin="anonymous">
										<source src={track.previewUrl} type="audio/mpeg">
										Your browser does not support the audio element.
									</audio>
								{/if}
								
								<button
									onclick={() => addTrackToPlaylist(track)}
									disabled={isAddingTrack === track.id}
									class="bg-secondary text-white px-4 py-2 rounded-lg hover:bg-secondary/80 transition-colors disabled:opacity-50 disabled:cursor-not-allowed flex items-center space-x-2"
								>
									{#if isAddingTrack === track.id}
										<div class="animate-spin rounded-full h-4 w-4 border-b-2 border-white"></div>
										<span>Adding...</span>
									{:else}
										<svg class="w-4 h-4" fill="none" stroke="currentColor" viewBox="0 0 24 24">
											<path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M12 6v6m0 0v6m0-6h6m-6 0H6"></path>
										</svg>
										<span>Add</span>
									{/if}
								</button>
							</div>
						{/each}
					</div>
				{:else}
					<div class="text-center py-8">
						<p class="text-gray-500">No top tracks available</p>
					</div>
				{/if}

			<!-- Advanced Search Tab -->
			{:else if activeTab === 'advanced'}
				<div class="mb-6">
					<div class="grid grid-cols-1 md:grid-cols-2 gap-4 mb-4">
						<div>
							<label for="artistSearch" class="block text-sm font-medium text-gray-700 mb-1">Artist</label>
							<input
								id="artistSearch"
								type="text"
								bind:value={advancedSearch.artist}
								placeholder="e.g. Daft Punk"
								class="w-full px-3 py-2 border border-gray-300 rounded-lg focus:outline-none focus:ring-2 focus:ring-secondary"
							/>
						</div>
						
						<div>
							<label for="albumSearch" class="block text-sm font-medium text-gray-700 mb-1">Album</label>
							<input
								id="albumSearch"
								type="text"
								bind:value={advancedSearch.album}
								placeholder="e.g. Discovery"
								class="w-full px-3 py-2 border border-gray-300 rounded-lg focus:outline-none focus:ring-2 focus:ring-secondary"
							/>
						</div>
						
						<div>
							<label for="trackSearch" class="block text-sm font-medium text-gray-700 mb-1">Track</label>
							<input
								id="trackSearch"
								type="text"
								bind:value={advancedSearch.track}
								placeholder="e.g. One More Time"
								class="w-full px-3 py-2 border border-gray-300 rounded-lg focus:outline-none focus:ring-2 focus:ring-secondary"
							/>
						</div>
						
						<div>
							<label for="yearSearch" class="block text-sm font-medium text-gray-700 mb-1">Year</label>
							<input
								id="yearSearch"
								type="number"
								bind:value={advancedSearch.year}
								placeholder="e.g. 2001"
								min="1900"
								max="2030"
								class="w-full px-3 py-2 border border-gray-300 rounded-lg focus:outline-none focus:ring-2 focus:ring-secondary"
							/>
						</div>
						
						<div>
							<label for="minDuration" class="block text-sm font-medium text-gray-700 mb-1">Min Duration (seconds)</label>
							<input
								id="minDuration"
								type="number"
								bind:value={advancedSearch.durationMin}
								placeholder="e.g. 180"
								min="0"
								class="w-full px-3 py-2 border border-gray-300 rounded-lg focus:outline-none focus:ring-2 focus:ring-secondary"
							/>
						</div>
						
						<div>
							<label for="maxDuration" class="block text-sm font-medium text-gray-700 mb-1">Max Duration (seconds)</label>
							<input
								id="maxDuration"
								type="number"
								bind:value={advancedSearch.durationMax}
								placeholder="e.g. 300"
								min="0"
								class="w-full px-3 py-2 border border-gray-300 rounded-lg focus:outline-none focus:ring-2 focus:ring-secondary"
							/>
						</div>
					</div>
					
					<div class="flex space-x-3">
						<button
							onclick={performAdvancedSearch}
							disabled={isSearching}
							class="bg-secondary text-white px-6 py-2 rounded-lg hover:bg-secondary/80 transition-colors disabled:opacity-50 disabled:cursor-not-allowed flex items-center space-x-2"
						>
							{#if isSearching}
								<div class="animate-spin rounded-full h-4 w-4 border-b-2 border-white"></div>
								<span>Searching...</span>
							{:else}
								<svg class="w-4 h-4" fill="none" stroke="currentColor" viewBox="0 0 24 24">
									<path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M21 21l-6-6m2-5a7 7 0 11-14 0 7 7 0 0114 0z"></path>
								</svg>
								<span>Search</span>
							{/if}
						</button>
						
						<button
							onclick={clearAdvancedSearch}
							class="border border-gray-300 text-gray-700 px-4 py-2 rounded-lg hover:bg-gray-50 transition-colors"
						>
							Clear
						</button>
					</div>
				</div>

				{#if isSearching}
					<div class="flex justify-center items-center py-8">
						<div class="animate-spin rounded-full h-8 w-8 border-b-2 border-secondary"></div>
						<span class="ml-2 text-gray-600">Searching...</span>
					</div>
				{:else if searchResults.length > 0}
					<div class="space-y-3">
						{#each searchResults as track}
							<div class="flex items-center space-x-4 p-3 border border-gray-200 rounded-lg hover:bg-gray-50 transition-colors">
								<img 
									src={track.albumCoverMediumUrl || track.albumCoverUrl} 
									alt={track.album}
									class="w-16 h-16 rounded object-cover"
									loading="lazy"
								/>
								
								<div class="flex-1 min-w-0">
									<h4 class="font-medium text-gray-800 truncate">{track.title}</h4>
									<p class="text-sm text-gray-600 truncate">{track.artist}</p>
									<p class="text-xs text-gray-500 truncate">{track.album}</p>
									<div class="flex items-center space-x-2 mt-1">
										<span class="text-xs text-gray-400">{formatDuration(track.duration)}</span>
									</div>
								</div>
								
								{#if track.previewUrl}
									<audio controls class="w-32" crossorigin="anonymous">
										<source src={track.previewUrl} type="audio/mpeg">
										Your browser does not support the audio element.
									</audio>
								{/if}
								
								<button
									onclick={() => addTrackToPlaylist(track)}
									disabled={isAddingTrack === track.id}
									class="bg-secondary text-white px-4 py-2 rounded-lg hover:bg-secondary/80 transition-colors disabled:opacity-50 disabled:cursor-not-allowed flex items-center space-x-2"
								>
									{#if isAddingTrack === track.id}
										<div class="animate-spin rounded-full h-4 w-4 border-b-2 border-white"></div>
										<span>Adding...</span>
									{:else}
										<svg class="w-4 h-4" fill="none" stroke="currentColor" viewBox="0 0 24 24">
											<path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M12 6v6m0 0v6m0-6h6m-6 0H6"></path>
										</svg>
										<span>Add</span>
									{/if}
								</button>
							</div>
						{/each}
					</div>
				{:else}
					<div class="text-center py-8">
						<svg class="w-16 h-16 text-gray-300 mx-auto mb-4" fill="none" stroke="currentColor" viewBox="0 0 24 24">
							<path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M21 21l-6-6m2-5a7 7 0 11-14 0 7 7 0 0114 0z"></path>
						</svg>
						<p class="text-gray-500">Use the filters above to search for music</p>
						<p class="text-gray-400 text-sm mt-2">Fill in at least one field and click Search</p>
					</div>
				{/if}
			{/if}
		</div>

		<!-- Footer -->
		<div class="p-6 border-t border-gray-200 bg-gray-50">
			<div class="flex justify-between items-center">
				<p class="text-xs text-gray-500">
					Powered by Deezer API • Preview tracks are 30 seconds long
				</p>
				<button
					onclick={onClose}
					class="px-4 py-2 border border-gray-300 text-gray-700 rounded-lg hover:bg-gray-100 transition-colors"
				>
					Close
				</button>
			</div>
		</div>
	</div>
</div>
