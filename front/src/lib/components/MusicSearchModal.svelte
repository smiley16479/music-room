<script lang="ts">
	import { deezerService, type DeezerTrack } from '$lib/services/deezer';
	import { playlistsService } from '$lib/services/playlists';
	import { authStore } from '$lib/stores/auth';

	let { 
		playlistId,
		onTrackAdded = () => {},
		onClose = () => {}
	}: {
		playlistId: string;
		onTrackAdded?: () => void;
		onClose?: () => void;
	} = $props();

	let searchQuery = $state('');
	let searchResults = $state<DeezerTrack[]>([]);
	let isSearching = $state(false);
	let searchError = $state('');
	let isAddingTrack = $state<string | null>(null);
	let currentUser = $derived($authStore);

	let searchTimeout: NodeJS.Timeout;

	// Debounced search function
	function handleSearchInput() {
		clearTimeout(searchTimeout);
		if (searchQuery.trim().length < 2) {
			searchResults = [];
			return;
		}

		searchTimeout = setTimeout(() => {
			performSearch();
		}, 300);
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
			searchResults = response.data;
		} catch (error) {
			searchError = error instanceof Error ? error.message : 'Failed to search tracks';
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
			// Use the same approach as EnhancedMusicSearchModal
			await playlistsService.addTrackToPlaylist(playlistId, { trackId: deezerTrack.id });
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
</script>

<!-- Search Modal -->
<div class="fixed inset-0 bg-black bg-opacity-50 flex items-center justify-center z-50 p-4">
	<div class="bg-white rounded-lg max-w-4xl w-full max-h-[90vh] overflow-hidden">
		<!-- Header -->
		<div class="p-6 border-b border-gray-200">
			<div class="flex justify-between items-center mb-4">
				<h2 class="text-xl font-bold text-gray-800">Search Music</h2>
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
			
			<!-- Search Input -->
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

		<!-- Search Results -->
		<div class="p-6 overflow-y-auto max-h-[60vh]">
			{#if searchError}
				<div class="bg-red-100 border border-red-400 text-red-700 px-4 py-3 rounded mb-4">
					{searchError}
				</div>
			{/if}

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
							<!-- Album Cover -->
							<img 
								src={track.albumCoverMediumUrl || track.albumCoverUrl} 
								alt={track.title}
								class="w-16 h-16 rounded object-cover"
								loading="lazy"
							/>
							
							<!-- Track Info -->
							<div class="flex-1 min-w-0">
								<h4 class="font-medium text-gray-800 truncate">{track.title}</h4>
								<p class="text-sm text-gray-600 truncate">{track.artist}</p>
								<p class="text-xs text-gray-500 truncate">{track.album}</p>
								<div class="flex items-center space-x-2 mt-1">
									<span class="text-xs text-gray-400">{formatDuration(track.duration)}</span>
								</div>
							</div>
							
							<!-- Preview Audio -->
							{#if track.previewUrl}
								<audio controls class="w-32">
									<source src={track.previewUrl} type="audio/mpeg">
									Your browser does not support the audio element.
								</audio>
							{/if}
							
							<!-- Add Button -->
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
					<p class="text-gray-400 text-sm mt-2">Search for tracks, artists, or albums from Deezer</p>
				</div>
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
