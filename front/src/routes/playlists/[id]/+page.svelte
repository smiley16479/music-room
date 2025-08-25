<script lang="ts">
	import { onMount, onDestroy } from "svelte";
	import { page } from "$app/stores";
	import { authStore } from "$lib/stores/auth";
	import type { Collaborator } from "$lib/services/playlists";
	import {
		playlistsService,
		type Playlist,
		type PlaylistTrack,
	} from "$lib/services/playlists";
	import { socketService } from "$lib/services/socket";
	import { musicPlayerService } from "$lib/services/musicPlayer";
	import { musicPlayerStore } from "$lib/stores/musicPlayer";
	import { goto } from "$app/navigation";
	import CollaboratorsList from "$lib/components/CollaboratorsList.svelte";
	import AddCollaboratorModal from "$lib/components/AddCollaboratorModal.svelte";
	import EnhancedMusicSearchModal from "$lib/components/EnhancedMusicSearchModal.svelte";
	import {
		getAvatarColor,
		getAvatarLetter,
		getUserAvatarUrl,
	} from "$lib/utils/avatar";

	// Get initial data from load function
	let { data } = $props();
	let playlist = $state<Playlist | null>(null);
	let loading = $state(true);
	let error = $state("");
	// Use the global auth store
	let user = $derived($authStore);
	let showMusicSearchModal = $state(false);
	let showAddCollaboratorModal = $state(false);
	let draggedIndex: number | null = null;
	let searchQuery = $state("");

	// Socket connection state
	let isSocketConnected = $state(false);

	// Music player state
	let isMusicPlayerInitialized = $state(false);
	const playerState = $derived($musicPlayerStore);

	const playlistId = $derived($page?.params?.id);

	onMount(() => {
		// Async initialization function
		const initializePlaylist = async () => {
			// Load playlist first
			await loadPlaylist();

			// Set up socket connection for real-time collaborative features
			if (playlistId && user) {
				await setupSocketConnection(playlistId);
			} else if (playlistId && !user) {
				// Wait a bit for user to be loaded from auth store
				setTimeout(async () => {
					const currentUser = $authStore;
					if (currentUser && playlistId) {
						await setupSocketConnection(playlistId);
					}
				}, 1000);
			}
		};

		// Call initialization
		initializePlaylist();

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
		if (userId && userId !== user?.id) {
			goto(`/users/${userId}`);
		}
	}

	function viewOwnerProfile() {
		if (user?.id !== playlist?.creator?.id) {
			goto(`/users/${playlist?.creator?.id}`);
		}
	}

	async function setupSocketConnection(playlistId: string) {
		try {
			if (!socketService.isConnected()) {
				await socketService.connect();
			}

			// Join the specific playlist room for collaborative editing
			socketService.joinPlaylist(playlistId);

			// Set up playlist-specific collaboration listeners
			setupPlaylistSocketListeners();

			isSocketConnected = true;
		} catch (err) {
			console.error("Failed to set up socket connection:", err);
			error = "Failed to connect to real-time updates";
		}
	}

	function setupPlaylistSocketListeners() {
		// Listen for real-time playlist updates (metadata changes)
		socketService.on("playlist-updated", handlePlaylistUpdated);

		// Listen for real-time track changes (correct event names from backend)
		socketService.on("track-added", handleTrackAdded);
		socketService.on("track-removed", handleTrackRemoved);
		socketService.on("tracks-reordered", handleTracksReordered);

		// Listen for collaborator changes (correct event names from backend)
		socketService.on("collaborator-added", handleCollaboratorAdded);
		socketService.on("collaborator-removed", handleCollaboratorRemoved);
	}

	function cleanupSocketConnection(playlistId: string) {
		try {
			// Leave the specific playlist room
			socketService.leavePlaylist(playlistId);

			// Clean up event listeners (correct event names from backend)
			socketService.off("playlist-updated", handlePlaylistUpdated);
			socketService.off("track-added", handleTrackAdded);
			socketService.off("track-removed", handleTrackRemoved);
			socketService.off("tracks-reordered", handleTracksReordered);
			socketService.off("collaborator-added", handleCollaboratorAdded);
			socketService.off(
				"collaborator-removed",
				handleCollaboratorRemoved,
			);

			isSocketConnected = false;
		} catch (err) {
			console.error("Failed to clean up socket connection:", err);
		}
	}

	// Socket event handlers for real-time collaboration
	function handlePlaylistUpdated(data: { playlist: Playlist }) {
		if (data.playlist.id === playlistId) {
			// Preserve tracks if they're not included in the update
			if (!data.playlist.tracks && playlist?.tracks) {
				data.playlist.tracks = playlist.tracks;
			}
			playlist = data.playlist;
		}
	}

	function handleTrackAdded(data: {
		playlistId: string;
		track: any;
		addedBy: string;
		timestamp: string;
	}) {
		if (data.playlistId === playlistId && playlist) {
			// Convert the backend track format to PlaylistTrack format
			const newTrack: PlaylistTrack = {
				id: data.track.id,
				position: data.track.position,
				addedAt: data.track.addedAt,
				createdAt: data.track.addedAt,
				playlistId: data.playlistId,
				trackId: data.track.track.id,
				addedById: data.track.addedBy.id,
				track: data.track.track,
				addedBy: data.track.addedBy,
			};

			// Add the track to the playlist in the correct position
			const updatedTracks = [...(playlist.tracks || [])];
			// Insert at correct position based on track.position
			const insertIndex = newTrack.position - 1;
			updatedTracks.splice(insertIndex, 0, newTrack);

			// Update positions for tracks after the inserted one
			for (let i = insertIndex + 1; i < updatedTracks.length; i++) {
				updatedTracks[i].position = i + 1;
			}

			playlist.tracks = updatedTracks;
			playlist.trackCount = (playlist.trackCount || 0) + 1;

			// Force reactivity update
			playlist = { ...playlist };

			// Update music player if initialized
			if (isMusicPlayerInitialized) {
				musicPlayerStore.setPlaylist(
					updatedTracks,
					playerState.currentTrackIndex,
				);
			}
		} else {
			console.log(
				"❌ Track added event ignored - playlist ID mismatch or no playlist",
			);
		}
	}

	function handleTrackRemoved(data: {
		playlistId: string;
		trackId: string;
		removedBy: string;
		timestamp: string;
	}) {
		if (data.playlistId === playlistId && playlist?.tracks) {
			const removedTrackIndex = playlist.tracks.findIndex(
				(t) => t.trackId === data.trackId,
			);
			const removedTrack = playlist.tracks[removedTrackIndex];

			// Remove the track from the playlist
			const updatedTracks = playlist.tracks.filter(
				(t) => t.trackId !== data.trackId,
			);

			// Update positions for remaining tracks
			updatedTracks.forEach((track, index) => {
				track.position = index + 1;
			});

			playlist.tracks = updatedTracks;
			playlist.trackCount = Math.max(0, (playlist.trackCount || 0) - 1);

			// Force reactivity update
			playlist = { ...playlist };

			// Update music player if initialized
			if (isMusicPlayerInitialized) {
				// If the removed track was before or at the current playing track, adjust the index
				let newCurrentIndex = playerState.currentTrackIndex;
				if (
					removedTrackIndex <= playerState.currentTrackIndex &&
					playerState.currentTrackIndex > 0
				) {
					newCurrentIndex = playerState.currentTrackIndex - 1;
				}
				musicPlayerStore.setPlaylist(
					updatedTracks,
					Math.max(0, newCurrentIndex),
				);
			}
		} else {
			console.log(
				"❌ Track removed event ignored - playlist ID mismatch or no playlist",
			);
		}
	}

	function handleTracksReordered(data: {
		playlistId: string;
		trackIds: string[];
		reorderedBy: string;
		timestamp: string;
	}) {
		if (data.playlistId === playlistId && playlist?.tracks) {
			// Reorder tracks based on the trackIds array from backend
			const reorderedTracks: PlaylistTrack[] = [];

			// First, create a map of trackId to track for quick lookup
			const trackMap = new Map<string, PlaylistTrack>();
			playlist.tracks.forEach((track) => {
				trackMap.set(track.trackId, track);
			});

			// Reorder tracks according to the backend's trackIds array
			data.trackIds.forEach((trackId, index) => {
				const track = trackMap.get(trackId);
				if (track) {
					track.position = index + 1; // Update position
					reorderedTracks.push(track);
				}
			});

			// Update the playlist tracks
			playlist.tracks = reorderedTracks;

			// Force reactivity update
			playlist = { ...playlist };

			// Update music player if initialized
			if (isMusicPlayerInitialized) {
				// Find the new index of the currently playing track
				let newCurrentIndex = 0;
				if (playerState.currentTrack) {
					const currentTrackId = playerState.currentTrack.id;
					newCurrentIndex = reorderedTracks.findIndex(
						(t) => t.track.id === currentTrackId,
					);
					if (newCurrentIndex === -1) newCurrentIndex = 0;
				}
				musicPlayerStore.setPlaylist(reorderedTracks, newCurrentIndex);
			}
		} else {
			console.log(
				"❌ Tracks reordered event ignored - playlist ID mismatch or no playlist",
			);
		}
	}

	function handleCollaboratorAdded(data: {
		playlistId: string;
		collaborator: any;
		addedBy: string;
		timestamp: string;
	}) {
		if (data.playlistId === playlistId && playlist) {
			// Convert backend collaborator format to frontend format
			const newCollaborator: Collaborator = {
				id: data.collaborator.id,
				userId: data.collaborator.id,
				displayName: data.collaborator.displayName,
				avatarUrl: data.collaborator.avatarUrl,
			};

			// Add collaborator if not already present
			if (
				!playlist.collaborators.some(
					(c) => c.userId === newCollaborator.userId,
				)
			) {
				playlist.collaborators = [
					...playlist.collaborators,
					newCollaborator,
				];
				// Force reactivity update
				playlist = { ...playlist };
			} else {
				console.log("ℹ️ Collaborator already exists in playlist");
			}
		} else {
			console.log(
				"❌ Collaborator added event ignored - playlist ID mismatch or no playlist",
			);
		}
	}

	function handleCollaboratorRemoved(data: {
		playlistId: string;
		collaborator: any;
		removedBy: string;
		timestamp: string;
	}) {
		if (data.playlistId === playlistId && playlist) {
			const removedCollaborator = playlist.collaborators.find(
				(c) => c.userId === data.collaborator.id,
			);
			playlist.collaborators = playlist.collaborators.filter(
				(c) => c.userId !== data.collaborator.id,
			);
			// Force reactivity update
			playlist = { ...playlist };
		} else {
			console.log(
				"❌ Collaborator removed event ignored - playlist ID mismatch or no playlist",
			);
		}
	}

	async function loadPlaylist() {
		if (!playlistId) return;

		try {
			// Load playlist metadata
			playlist = await playlistsService.getPlaylist(playlistId);
			if (!playlist) {
				error = "Playlist not found";
				loading = false;
				return;
			}

			// Load tracks separately
			const tracks = await playlistsService.getPlaylistTracks(playlistId);

			playlist.tracks = tracks;

			// Initialize music player for this playlist
			await initializeMusicPlayer();

			loading = false;
		} catch (err) {
			console.error("Failed to load playlist:", err);
			error =
				err instanceof Error ? err.message : "Failed to load playlist";
			loading = false;
		}
	}

	async function initializeMusicPlayer() {
		if (!playlist || !user || isMusicPlayerInitialized) return;

		try {
			// Don't initialize if playlist has no tracks
			if (!playlist.tracks || playlist.tracks.length === 0) {
				console.warn(
					"Cannot initialize music player: playlist has no tracks",
				);
				return;
			}

			// Create room context for the music player
			const roomContext = {
				type: "playlist" as const,
				id: playlist.id,
				ownerId: playlist.creatorId || "",
				participants: playlist.collaborators.map((c) => c.id),
				licenseType: playlist.licenseType,
				visibility: playlist.visibility,
			};

			console.log("Initializing music player with context:", roomContext);
			console.log("Playlist tracks:", playlist.tracks.length);

			// Initialize music player with playlist tracks
			await musicPlayerService.initializeForRoom(
				roomContext,
				playlist.tracks || [],
			);
			isMusicPlayerInitialized = true;

			console.log("Music player initialized successfully");
			console.log("Current player state:", $musicPlayerStore);
		} catch (err) {
			console.error("Failed to initialize music player:", err);
		}
	}

	async function playTrack(trackIndex: number) {
		try {
			// Don't try to play if music player isn't initialized
			if (!isMusicPlayerInitialized) {
				console.warn(
					"Music player not initialized, attempting to initialize first...",
				);
				await initializeMusicPlayer();

				if (!isMusicPlayerInitialized) {
					console.error(
						"Failed to initialize music player before playing track",
					);
					error =
						"Music player not available. Please refresh the page.";
					setTimeout(() => (error = ""), 3000);
					return;
				}
			}

			// Check if trackIndex is valid
			if (
				!playlist?.tracks ||
				trackIndex >= playlist.tracks.length ||
				trackIndex < 0
			) {
				console.error("Invalid track index:", {
					trackIndex,
					playlistLength: playlist?.tracks?.length,
				});
				error = `Cannot play track: invalid track position (${trackIndex + 1})`;
				setTimeout(() => (error = ""), 3000);
				return;
			}

			console.log("Playing track at index:", trackIndex);
			console.log("Track data:", playlist.tracks[trackIndex]);

			await musicPlayerService.playTrack(trackIndex);
		} catch (err) {
			console.error("Play track error:", err);
			error = err instanceof Error ? err.message : "Failed to play track";
			setTimeout(() => (error = ""), 3000);
		}
	}

	async function removeTrack(trackId: string) {
		if (!user || !playlistId) return;

		try {
			await playlistsService.removeTrackFromPlaylist(playlistId, trackId);
		} catch (err) {
			error =
				err instanceof Error ? err.message : "Failed to remove track";
		}
	}

	function handleDragStart(event: DragEvent, index: number) {
		draggedIndex = index;
		if (event.dataTransfer) {
			event.dataTransfer.effectAllowed = "move";
		}
	}

	function handleDragOver(event: DragEvent) {
		event.preventDefault();
		if (event.dataTransfer) {
			event.dataTransfer.dropEffect = "move";
		}
	}

	async function handleDrop(event: DragEvent, dropIndex: number) {
		event.preventDefault();
		if (
			draggedIndex === null ||
			draggedIndex === dropIndex ||
			!playlist ||
			!playlistId ||
			!playlist.tracks
		)
			return;

		try {
			// Create new track positions array
			const tracks = [...playlist.tracks];
			const draggedTrack = tracks[draggedIndex];
			tracks.splice(draggedIndex, 1);
			tracks.splice(dropIndex, 0, draggedTrack);

			const trackIds = tracks.map((track) => track.trackId);

			await playlistsService.reorderTracks(playlistId, trackIds);
		} catch (err) {
			error =
				err instanceof Error ? err.message : "Failed to reorder tracks";
		}

		draggedIndex = null;
	}

	function formatDate(dateString: string) {
		return new Date(dateString).toLocaleDateString("en-US", {
			year: "numeric",
			month: "short",
			day: "numeric",
		});
	}

	function formatDuration(seconds: number) {
		const minutes = Math.floor(seconds / 60);
		const remainingSeconds = seconds % 60;
		return `${minutes}:${remainingSeconds.toString().padStart(2, "0")}`;
	}

	const isOwner = $derived(user && playlist?.creatorId === user.id);
	const canEdit = $derived(
		isOwner ||
			(user &&
				playlist?.collaborators?.some((c: any) => c.id === user.id)),
	);
	const canView = $derived(
		playlist?.visibility === "public" ||
			isOwner ||
			(user &&
				playlist?.collaborators?.some((c: any) => c.id === user.id)),
	);

	// Filter tracks based on search query
	const filteredTracks = $derived(() => {
		if (!playlist?.tracks) return [];
		if (!searchQuery.trim()) return playlist.tracks;

		const query = searchQuery.toLowerCase().trim();
		return playlist.tracks.filter(
			(track) =>
				track.track.title.toLowerCase().includes(query) ||
				track.track.artist.toLowerCase().includes(query) ||
				track.track.album?.toLowerCase().includes(query) ||
				track.addedBy.displayName.toLowerCase().includes(query),
		);
	});
</script>

<svelte:head>
	<title>{playlist?.name || "Playlist"} - Music Room</title>
	<meta
		name="description"
		content="Collaborate on music playlists in real-time"
	/>
</svelte:head>

{#if loading}
	<div class="flex justify-center items-center min-h-[400px]">
		<div
			class="animate-spin rounded-full h-12 w-12 border-b-2 border-secondary"
		></div>
	</div>
{:else if error && !playlist}
	<div class="container mx-auto px-4 py-8">
		<div
			class="bg-red-100 border border-red-400 text-red-700 px-4 py-3 rounded"
		>
			{error}
		</div>
	</div>
{:else if playlist && canView}
	<div class="container mx-auto px-4 py-8">
		<!-- Playlist Header -->
		<div class="bg-white rounded-lg shadow-md p-6 mb-8">
			<div class="flex items-start space-x-6">
				{#if playlist.coverImageUrl}
					<img
						src={playlist.coverImageUrl}
						alt={playlist.name}
						class="w-32 h-32 rounded-lg object-cover"
					/>
				{:else}
					<div
						class="w-32 h-32 bg-gradient-to-br from-secondary/20 to-purple-300 rounded-lg flex items-center justify-center"
					>
						<svg
							class="w-16 h-16 text-white"
							fill="none"
							stroke="currentColor"
							viewBox="0 0 24 24"
						>
							<path
								stroke-linecap="round"
								stroke-linejoin="round"
								stroke-width="2"
								d="M9 19V6l12-3v13M9 19c0 1.105-1.343 2-3 2s-3-.895-3-2 1.343-2 3-2 3 .895 3 2z"
							></path>
						</svg>
					</div>
				{/if}

				<div class="flex-1">
					<div class="flex justify-between items-start mb-4">
						<div>
							<h1
								class="font-family-main text-3xl font-bold text-gray-800 mb-2"
							>
								{playlist.name}
							</h1>
							{#if playlist.description}
								<p class="text-gray-600 mb-4">
									{playlist.description}
								</p>
							{/if}
						</div>

						<div class="flex space-x-2">
							<span
								class="px-3 py-1 text-sm rounded-full {playlist.visibility ===
								'public'
									? 'bg-green-100 text-green-800'
									: 'bg-blue-100 text-blue-800'}"
							>
								{playlist.visibility === "public"
									? "Public"
									: "Private"}
							</span>
							{#if playlist.isCollaborative}
								<span
									class="px-3 py-1 text-sm rounded-full bg-purple-100 text-purple-800"
								>
									Collaborative
								</span>
							{/if}
						</div>
					</div>

					<div
						class="grid grid-cols-2 md:grid-cols-4 gap-4 text-sm text-gray-600"
					>
						<div>
							<span class="font-medium">Owner:</span>
							<span class="ml-1"
								>{playlist.creator?.displayName ||
									"Unknown"}</span
							>
						</div>

						<div>
							<span class="font-medium">Tracks:</span>
							<span class="ml-1"
								>{playlist.tracks?.length ||
									playlist.trackCount ||
									0}</span
							>
						</div>

						<div>
							<span class="font-medium">Collaborators:</span>
							<span class="ml-1"
								>{playlist.collaborators.length + 1}</span
							>
						</div>

						<div>
							<span class="font-medium">Created:</span>
							<span class="ml-1"
								>{formatDate(playlist.createdAt)}</span
							>
						</div>
					</div>

					{#if canEdit}
						<div class="flex space-x-3 mt-4">
							<button
								onclick={() => (showMusicSearchModal = true)}
								class="bg-secondary text-white px-4 py-2 rounded-lg hover:bg-secondary/80 transition-colors"
							>
								Search & Add Music
							</button>

							{#if isOwner}
								<button
									onclick={() =>
										(showAddCollaboratorModal = true)}
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
			<div
				class="bg-red-100 border border-red-400 text-red-700 px-4 py-3 rounded mb-6"
			>
				{error}
			</div>
		{/if}

		<!-- Tracks Section -->
		<div class="bg-white rounded-lg shadow-md p-6">
			<div class="flex justify-between items-center mb-6">
				<h2 class="text-xl font-bold text-gray-800">Tracks</h2>
				<div class="flex items-center space-x-4">
					{#if isSocketConnected}
						<div class="flex items-center text-sm text-green-600">
							<div
								class="w-2 h-2 bg-green-500 rounded-full mr-2 animate-pulse"
							></div>
							Live Collaboration Active
						</div>
					{:else}
						<div class="flex items-center text-sm text-red-500">
							<div
								class="w-2 h-2 bg-red-400 rounded-full mr-2"
							></div>
							Collaboration Offline
						</div>
					{/if}

					{#if isMusicPlayerInitialized}
						<div class="flex items-center text-sm text-secondary">
							<svg
								class="w-4 h-4 mr-1"
								fill="none"
								stroke="currentColor"
								viewBox="0 0 24 24"
							>
								<path
									stroke-linecap="round"
									stroke-linejoin="round"
									stroke-width="2"
									d="M9 19V6l12-3v13M9 19c0 1.105-1.343 2-3 2s-3-.895-3-2 1.343-2 3-2 3 .895 3 2zm12-3c0 1.105-1.343 2-3 2s-3-.895-3-2 1.343-2 3-2 3 .895 3 2zM9 10l12-3"
								></path>
							</svg>
							Music Player Active
						</div>
					{/if}
				</div>
			</div>

			<!-- Search for tracks within playlist -->
			{#if playlist?.tracks && playlist.tracks.length > 0}
				<div class="mb-6">
					<div class="relative max-w-md">
						<div
							class="absolute inset-y-0 left-0 pl-3 flex items-center pointer-events-none"
						>
							<svg
								class="h-5 w-5 text-gray-400"
								fill="none"
								stroke="currentColor"
								viewBox="0 0 24 24"
							>
								<path
									stroke-linecap="round"
									stroke-linejoin="round"
									stroke-width="2"
									d="M21 21l-6-6m2-5a7 7 0 11-14 0 7 7 0 0114 0z"
								></path>
							</svg>
						</div>
						<input
							type="text"
							bind:value={searchQuery}
							placeholder="Search tracks in this playlist..."
							class="block w-full pl-10 pr-3 py-2 border border-gray-300 rounded-lg focus:outline-none focus:ring-2 focus:ring-secondary focus:border-transparent"
						/>
					</div>
					{#if searchQuery.trim() && filteredTracks().length !== playlist.tracks.length}
						<p class="text-sm text-gray-600 mt-2">
							Showing {filteredTracks().length} of {playlist
								.tracks.length} tracks
						</p>
					{/if}
				</div>
			{/if}

			{#if !playlist.tracks || playlist.tracks.length === 0}
				<div class="text-center py-8">
					<p class="text-gray-500 mb-4">
						No tracks in this playlist yet
					</p>
					{#if canEdit}
						<button
							onclick={() => (showMusicSearchModal = true)}
							class="bg-secondary text-white px-6 py-2 rounded-lg hover:bg-secondary/80 transition-colors"
						>
							Search & Add Music
						</button>
					{/if}
				</div>
			{:else}
				<div class="space-y-2">
					{#each filteredTracks() as track, index}
						<div
							class="flex items-center space-x-4 p-3 border rounded-lg transition-colors {canEdit
								? 'cursor-move'
								: ''} {playerState.currentTrackIndex ===
								index && !searchQuery.trim()
								? 'border-secondary bg-secondary/5'
								: 'border-gray-200 hover:bg-gray-50'}"
							draggable={canEdit && !searchQuery.trim()}
							role={canEdit ? "listitem" : "none"}
							ondragstart={(e) =>
								!searchQuery.trim() &&
								handleDragStart(e, index)}
							ondragover={handleDragOver}
							ondrop={(e) =>
								!searchQuery.trim() && handleDrop(e, index)}
						>
							<div
								class="w-8 h-8 rounded-full flex items-center justify-center text-sm font-semibold {playerState.currentTrackIndex ===
									index && !searchQuery.trim()
									? 'bg-secondary text-white'
									: 'bg-gray-200 text-gray-600'}"
							>
								{#if playerState.currentTrackIndex === index && playerState.isPlaying && !searchQuery.trim()}
									<!-- Now playing indicator -->
									<svg
										class="w-4 h-4"
										fill="currentColor"
										viewBox="0 0 24 24"
									>
										<path d="M8 5v14l11-7z" />
									</svg>
								{:else}
									{searchQuery.trim()
										? (playlist?.tracks?.indexOf(track) ??
												index) + 1
										: index + 1}
								{/if}
							</div>

							{#if track.track.albumCoverMediumUrl}
								<img
									src={track.track.albumCoverMediumUrl}
									alt={track.track.title}
									class="w-12 h-12 rounded object-cover"
								/>
							{:else}
								<div
									class="w-12 h-12 bg-gray-200 rounded flex items-center justify-center"
								>
									<svg
										class="w-6 h-6 text-gray-400"
										fill="none"
										stroke="currentColor"
										viewBox="0 0 24 24"
									>
										<path
											stroke-linecap="round"
											stroke-linejoin="round"
											stroke-width="2"
											d="M9 19V6l12-3v13M9 19c0 1.105-1.343 2-3 2s-3-.895-3-2 1.343-2 3-2 3 .895 3 2z"
										></path>
									</svg>
								</div>
							{/if}

							<div class="flex-1">
								<h4 class="font-medium text-gray-800">
									{track.track.title}
								</h4>
								<p class="text-sm text-gray-600">
									{track.track.artist}
								</p>
								{#if track.track.album}
									<p class="text-xs text-gray-500">
										{track.track.album}
									</p>
								{/if}
								<p class="text-xs text-gray-400">
									Added by {track.addedBy.displayName} • {formatDate(
										track.addedAt,
									)}
								</p>
							</div>

							<div class="flex items-center space-x-3">
								{#if track.track.duration}
									<span class="text-sm text-gray-500"
										>{formatDuration(
											track.track.duration,
										)}</span
									>
								{/if}

								<!-- Music Player Controls -->
								{#if isMusicPlayerInitialized}
									<div class="flex items-center space-x-2">
										<!-- Play Button -->
										<button
											onclick={() => {
												const actualIndex =
													searchQuery.trim()
														? (playlist?.tracks?.indexOf(
																track,
															) ?? index)
														: index;
												// If this track is currently playing, toggle play/pause
												if (
													playerState.currentTrackIndex ===
														actualIndex &&
													playerState.currentTrack
												) {
													if (playerState.isPlaying) {
														musicPlayerStore.pause();
													} else {
														musicPlayerStore.play();
													}
												} else {
													// Play this track
													playTrack(actualIndex);
												}
											}}
											disabled={!playerState.canControl}
											class="p-1.5 rounded-full {playerState.currentTrackIndex ===
											(searchQuery.trim()
												? (playlist?.tracks?.indexOf(
														track,
													) ?? index)
												: index)
												? 'bg-secondary text-white'
												: 'bg-gray-100 text-gray-600'} hover:bg-secondary hover:text-white disabled:opacity-50 disabled:cursor-not-allowed transition-colors"
											title={playerState.currentTrackIndex ===
											(searchQuery.trim()
												? (playlist?.tracks?.indexOf(
														track,
													) ?? index)
												: index)
												? playerState.isPlaying
													? "Pause (30s preview)"
													: "Resume (30s preview)"
												: "Play 30s preview"}
											aria-label={`${playerState.currentTrackIndex === (searchQuery.trim() ? (playlist?.tracks?.indexOf(track) ?? index) : index) && playerState.isPlaying ? "Pause" : "Play"} ${track.track.title}`}
										>
											{#if playerState.currentTrackIndex === (searchQuery.trim() ? (playlist?.tracks?.indexOf(track) ?? index) : index) && playerState.isPlaying}
												<!-- Pause icon -->
												<svg
													class="w-3 h-3"
													fill="currentColor"
													viewBox="0 0 24 24"
												>
													<path
														d="M6 4h4v16H6V4zm8 0h4v16h-4V4z"
													/>
												</svg>
											{:else}
												<!-- Play icon -->
												<svg
													class="w-3 h-3"
													fill="currentColor"
													viewBox="0 0 24 24"
												>
													<path d="M8 5v14l11-7z" />
												</svg>
											{/if}
										</button>

										<!-- Preview indicator -->
										<span
											class="text-xs text-gray-500 bg-gray-100 px-2 py-0.5 rounded-full"
										>
											30s preview
										</span>
									</div>
								{/if}
								{#if canEdit}
									<button
										onclick={() =>
											removeTrack(track.trackId)}
										aria-label="Remove track"
										class="text-red-500 hover:text-red-700 transition-colors"
										title="Remove track"
									>
										<svg
											class="w-4 h-4"
											fill="none"
											stroke="currentColor"
											viewBox="0 0 24 24"
										>
											<path
												stroke-linecap="round"
												stroke-linejoin="round"
												stroke-width="2"
												d="M19 7l-.867 12.142A2 2 0 0116.138 21H7.862a2 2 0 01-1.995-1.858L5 7m5 4v6m4-6v6m1-10V4a1 1 0 00-1-1h-4a1 1 0 00-1 1v3M4 7h16"
											></path>
										</svg>
									</button>
								{/if}
							</div>
						</div>
					{/each}
				</div>
			{/if}
		</div>

		<!-- Collaborators Section -->
		<div class="mt-8">
			<CollaboratorsList
				{playlist}
				{isOwner}
				onCollaboratorRemoved={() => {
				}}
			/>
		</div>
	</div>

	<!-- Enhanced Music Search Modal -->
	{#if showMusicSearchModal && playlistId}
		<EnhancedMusicSearchModal
			{playlistId}
			onTrackAdded={() => {
				showMusicSearchModal = false;
			}}
			onClose={() => (showMusicSearchModal = false)}
		/>
	{/if}

	<!-- Add Collaborator Modal -->
	{#if showAddCollaboratorModal && playlistId}
		<AddCollaboratorModal
			{playlistId}
			onCollaboratorAdded={() => {
				showAddCollaboratorModal = false;
			}}
			onClose={() => (showAddCollaboratorModal = false)}
		/>
	{/if}
{:else}
	<div class="container mx-auto px-4 py-8">
		<div class="text-center py-12">
			<h3 class="text-xl font-semibold text-gray-700 mb-2">
				Playlist not found or access denied
			</h3>
			<p class="text-gray-500 mb-4">
				This playlist might be private or you don't have permission to
				view it.
			</p>
			<a
				href="/playlists"
				class="bg-secondary text-white px-6 py-2 rounded-lg hover:bg-secondary/80 transition-colors"
			>
				Back to Playlists
			</a>
		</div>
	</div>
{/if}
