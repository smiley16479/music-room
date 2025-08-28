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
	import BackNavBtn from "$lib/components/BackNavBtn.svelte";

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
	let showEditModal = $state(false);
	let editPlaylistData = $state<{
		name: string;
		description: string;
		visibility: "public" | "private";
		licenseType: "open" | "invited";
	}>({
		name: "",
		description: "",
		visibility: "public",
		licenseType: "open",
	});
	let showDeleteConfirm = $state(false);

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

	function initializeEditForm() {
		if (playlist) {
			editPlaylistData = {
				name: playlist.name,
				description: playlist.description || "",
				licenseType: playlist.licenseType,
				visibility: playlist.visibility,
			};
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

	function handleDeletePlaylist() {
		if (!playlistId) return;

		playlistsService
			.deletePlaylist(playlistId)
			.then(() => {
				goto("/playlists");
			})
			.catch((err) => {
				error =
					err instanceof Error
						? err.message
						: "Failed to delete playlist";
			});
	}

	function handleEditPlaylist() {
		if (!playlistId || !editPlaylistData.name.trim()) {
			error = "Playlist name cannot be empty";
			return;
		}

		playlistsService
			.updatePlaylist(playlistId, {
				name: editPlaylistData.name,
				description: editPlaylistData.description,
				visibility: editPlaylistData.visibility,
				licenseType: editPlaylistData.licenseType,
			})
			.then((updated) => {
				playlist = updated;
				showEditModal = false;
			})
			.catch((err) => {
				error =
					err instanceof Error
						? err.message
						: "Failed to update playlist";
			});
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
			if (
				!playlist.collaborators.some(
					(c) => c.userId === data.collaborator.id,
				)
			) {
				playlist.collaborators.push({
					id: data.collaborator.id,
					userId: data.collaborator.id,
					displayName: data.collaborator.displayName,
					avatarUrl: data.collaborator.avatarUrl,
				});
				// Force reactivity update
				playlist = { ...playlist };
			}
		}
	}

	function handleCollaboratorRemoved(data: {
		playlistId: string;
		collaborator: any;
		removedBy: string;
		timestamp: string;
	}) {
		if (playlist && data.playlistId === playlistId) {
			const remainingCollaborators = playlist.collaborators.filter(
				(c) =>
					c.userId !== data.collaborator.id &&
					c.id !== data.collaborator.id,
			);
			if (
				remainingCollaborators.length !== playlist.collaborators.length
			) {
				playlist.collaborators = remainingCollaborators;
				// Force reactivity update
				playlist = { ...playlist };
			}
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
			initializeEditForm();

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

	function sortedPlaylistTracks() {
		if (!playlist?.tracks) return [];
		return [...playlist.tracks].sort((a, b) => a.position - b.position);
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

	const isOwner = $derived(!!(user && playlist?.creatorId === user.id));
	const canEdit = $derived(
		isOwner ||
			(user &&
				playlist?.collaborators?.some((c: any) => c.id === user.id)) ||
			playlist?.licenseType === "open",
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
		<div class="flex items-center justify-between w-full">
			<BackNavBtn />
			<button
				onclick={() => (showEditModal = true)}
				class="clickable"
				aria-label="Edit Playlist"
			>
				<svg
					viewBox="-2.4 -2.4 28.80 28.80"
					class="w-8 mb-2 hover:rotate-180 transition-transform duration-100 ease-in-out origin-center"
					fill="none"
					xmlns="http://www.w3.org/2000/svg"
					><g id="SVGRepo_bgCarrier" stroke-width="0"
						><rect
							x="-2.4"
							y="-2.4"
							width="28.80"
							height="28.80"
							rx="14.4"
							fill="#ffffff"
						></rect></g
					><g
						id="SVGRepo_tracerCarrier"
						stroke-linecap="round"
						stroke-linejoin="round"
					></g><g id="SVGRepo_iconCarrier">
						<circle
							cx="12"
							cy="12"
							r="3"
							stroke="#f6a437"
							stroke-width="1.5"
						></circle>
						<path
							d="M13.7654 2.15224C13.3978 2 12.9319 2 12 2C11.0681 2 10.6022 2 10.2346 2.15224C9.74457 2.35523 9.35522 2.74458 9.15223 3.23463C9.05957 3.45834 9.0233 3.7185 9.00911 4.09799C8.98826 4.65568 8.70226 5.17189 8.21894 5.45093C7.73564 5.72996 7.14559 5.71954 6.65219 5.45876C6.31645 5.2813 6.07301 5.18262 5.83294 5.15102C5.30704 5.08178 4.77518 5.22429 4.35436 5.5472C4.03874 5.78938 3.80577 6.1929 3.33983 6.99993C2.87389 7.80697 2.64092 8.21048 2.58899 8.60491C2.51976 9.1308 2.66227 9.66266 2.98518 10.0835C3.13256 10.2756 3.3397 10.437 3.66119 10.639C4.1338 10.936 4.43789 11.4419 4.43786 12C4.43783 12.5581 4.13375 13.0639 3.66118 13.3608C3.33965 13.5629 3.13248 13.7244 2.98508 13.9165C2.66217 14.3373 2.51966 14.8691 2.5889 15.395C2.64082 15.7894 2.87379 16.193 3.33973 17C3.80568 17.807 4.03865 18.2106 4.35426 18.4527C4.77508 18.7756 5.30694 18.9181 5.83284 18.8489C6.07289 18.8173 6.31632 18.7186 6.65204 18.5412C7.14547 18.2804 7.73556 18.27 8.2189 18.549C8.70224 18.8281 8.98826 19.3443 9.00911 19.9021C9.02331 20.2815 9.05957 20.5417 9.15223 20.7654C9.35522 21.2554 9.74457 21.6448 10.2346 21.8478C10.6022 22 11.0681 22 12 22C12.9319 22 13.3978 22 13.7654 21.8478C14.2554 21.6448 14.6448 21.2554 14.8477 20.7654C14.9404 20.5417 14.9767 20.2815 14.9909 19.902C15.0117 19.3443 15.2977 18.8281 15.781 18.549C16.2643 18.2699 16.8544 18.2804 17.3479 18.5412C17.6836 18.7186 17.927 18.8172 18.167 18.8488C18.6929 18.9181 19.2248 18.7756 19.6456 18.4527C19.9612 18.2105 20.1942 17.807 20.6601 16.9999C21.1261 16.1929 21.3591 15.7894 21.411 15.395C21.4802 14.8691 21.3377 14.3372 21.0148 13.9164C20.8674 13.7243 20.6602 13.5628 20.3387 13.3608C19.8662 13.0639 19.5621 12.558 19.5621 11.9999C19.5621 11.4418 19.8662 10.9361 20.3387 10.6392C20.6603 10.4371 20.8675 10.2757 21.0149 10.0835C21.3378 9.66273 21.4803 9.13087 21.4111 8.60497C21.3592 8.21055 21.1262 7.80703 20.6602 7C20.1943 6.19297 19.9613 5.78945 19.6457 5.54727C19.2249 5.22436 18.693 5.08185 18.1671 5.15109C17.9271 5.18269 17.6837 5.28136 17.3479 5.4588C16.8545 5.71959 16.2644 5.73002 15.7811 5.45096C15.2977 5.17191 15.0117 4.65566 14.9909 4.09794C14.9767 3.71848 14.9404 3.45833 14.8477 3.23463C14.6448 2.74458 14.2554 2.35523 13.7654 2.15224Z"
							stroke="#f6a437"
							stroke-width="1.5"
						></path>
					</g></svg
				>
			</button>
		</div>
		<!-- Playlist Header -->
		<div class="bg-white rounded-lg shadow-md p-6 mb-8">
			<div class="flex flex-col md:flex-row items-center md:items-start md:space-x-6 text-center md:text-left">
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

				<div class="flex-1 min-w-0 w-full overflow-hidden">
					<div class="flex flex-col sm:flex-row sm:justify-between sm:items-start my-4">
						<div id="here" class="w-full min-w-0 max-w-full overflow-hidden">
							<h1
								class="font-family-main text-2xl sm:text-3xl font-bold text-gray-800 mb-2 truncate w-full"
							>
								{playlist.name}
							</h1>
							{#if playlist.description}
								<p class="text-gray-600 mb-4 text-sm sm:text-base break-words truncate w-full">
									{playlist.description}
								</p>
							{/if}
						</div>
					</div>

					<div
						class="grid grid-cols-1 md:grid-cols-2 lg:grid-cols-4 gap-4 text-sm text-gray-600"
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
						{#if playlist.licenseType === "invited"}
							<div>
								<span class="font-medium">Collaborators:</span>
								<span class="ml-1"
									>{playlist.collaborators.length}</span
								>
							</div>
						{/if}

						<div>
							<span class="font-medium">Created:</span>
							<span class="ml-1"
								>{formatDate(playlist.createdAt)}</span
							>
						</div>
					</div>

					{#if canEdit && playlist.licenseType === "invited"}
						<div class="flex space-x-3 mt-4 justify-center md:justify-start">
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
				<div class="flex space-x-2 mt-4 md:mt-0">
					{#if user && playlist.collaborators.some((collab) => collab.id === user!.id)}
						<span
							class="px-2 py-1 text-xs rounded-full bg-amber-100 text-amber-800"
						>
							Collaborator
						</span>
					{/if}
					{#if playlist.visibility === "private"}
						<span
							class="px-2 py-1 text-xs rounded-full bg-red-100 text-red-800"
						>
							Private
						</span>
					{/if}
					{#if playlist.visibility !== "private" && playlist.licenseType === "invited"}
						<span
							class="px-2 py-1 text-xs rounded-full bg-blue-100 text-blue-800"
						>
							Closed
						</span>
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
		<div class="flex flex-col lg:flex-row gap-8">
			<div class="w-full bg-white rounded-lg shadow-md p-6">
				<div class="flex justify-between items-center mb-6">
					<div>
						<h2 class="text-xl font-bold text-gray-800">
							Playlist Tracks
						</h2>
						<p class="text-sm text-gray-600">
							{sortedPlaylistTracks().length} track{sortedPlaylistTracks()
								.length !== 1
								? "s"
								: ""}
						</p>
					</div>
					{#if canEdit}
						<div class="flex space-x-3">
							<button
								onclick={() => (showMusicSearchModal = true)}
								class="bg-secondary text-white px-4 py-2 rounded-lg hover:bg-secondary/80 transition-colors"
							>
								Search & Add Music
							</button>
						</div>
					{/if}
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
											? (playlist?.tracks?.indexOf(
													track,
												) ?? index) + 1
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
										<div
											class="flex items-center space-x-2"
										>
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
														if (
															playerState.isPlaying
														) {
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
														<path
															d="M8 5v14l11-7z"
														/>
													</svg>
												{/if}
											</button>
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
			{#if playlist.licenseType === "invited"}
				<CollaboratorsList
					{playlist}
					{isOwner}
					onCollaboratorRemoved={() => {}}
				/>
			{/if}
		</div>
	</div>

	<!-- Edit Playlist Modal -->
	{#if showEditModal}
		<div
			class="fixed inset-0 bg-black/50 z-51 flex items-center justify-center z-50 p-4 w-full"
		>
			<div
				class="bg-white rounded-lg max-w-2xl w-full max-h-[90vh] overflow-y-auto"
			>
				<div class="p-6">
					<div class="flex justify-between items-center mb-6">
						<h2 class="text-2xl font-bold text-gray-800">
							Edit Playlist
						</h2>
						<button
							onclick={() => (showEditModal = false)}
							class="text-gray-400 hover:text-gray-600 transition-colors"
							aria-label="Close modal"
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

					<form onsubmit={handleEditPlaylist} class="space-y-6">
						<div class="space-y-4">
							<h3
								class="text-lg font-semibold text-gray-800 border-b border-gray-200 pb-2"
							>
								Basic Information
							</h3>

							<div>
								<label
									for="edit-playlist-name"
									class="block text-sm font-medium text-gray-700 mb-2"
									>Playlist Name *</label
								>
								<input
									id="edit-playlist-name"
									type="text"
									bind:value={editPlaylistData.name}
									required
									class="w-full px-4 py-3 border border-gray-300 rounded-lg focus:outline-none focus:ring-2 focus:ring-secondary focus:border-transparent"
								/>
							</div>

							<div>
								<label
									for="edit-playlist-description"
									class="block text-sm font-medium text-gray-700 mb-2"
									>Description</label
								>
								<textarea
									id="edit-playlist-description"
									bind:value={editPlaylistData.description}
									rows="4"
									class="w-full px-4 py-3 border border-gray-300 rounded-lg focus:outline-none focus:ring-2 focus:ring-secondary focus:border-transparent"
								></textarea>
							</div>
						</div>

						<div class="space-y-4">
							<h3
								class="text-lg font-semibold text-gray-800 border-b border-gray-200 pb-2"
							>
								Playlist Settings
							</h3>

							<div>
								<label
									for="edit-playlist-visibility"
									class="block text-sm font-medium text-gray-700 mb-2"
									>Visibility</label
								>
								<select
									id="edit-playlist-visibility"
									bind:value={editPlaylistData.visibility}
									class="w-full px-4 py-3 border border-gray-300 rounded-lg focus:outline-none focus:ring-2 focus:ring-secondary focus:border-transparent"
								>
									<option value="public">Public</option>
									<option value="private">Private</option>
								</select>
							</div>

							<div>
								<label
									for="edit-playlist-license"
									class="block text-sm font-medium text-gray-700 mb-2"
									>License Type</label
								>
								<select
									id="edit-playlist-license"
									bind:value={editPlaylistData.licenseType}
									class="w-full px-4 py-3 border border-gray-300 rounded-lg focus:outline-none focus:ring-2 focus:ring-secondary focus:border-transparent"
								>
									<option value="open">Open</option>
									<option value="invited">Invited Only</option
									>
								</select>
							</div>
							{#if isOwner}
								<button
									onclick={() => (
										(showEditModal = false),
										(showDeleteConfirm = true)
									)}
									class="bg-red-500 text-white px-4 py-2 rounded-lg hover:bg-red-600 transition-colors"
								>
									Delete Playlist
								</button>
							{/if}
						</div>

						<div
							class="flex flex-col sm:flex-row space-y-4 sm:space-y-0 sm:space-x-4 pt-6 border-t border-gray-200"
						>
							<button
								type="button"
								onclick={() => (showEditModal = false)}
								class="flex-1 px-6 py-3 border border-gray-300 text-gray-700 rounded-lg hover:bg-gray-50 transition-colors font-medium"
							>
								Cancel
							</button>
							<button
								type="submit"
								disabled={loading}
								class="flex-1 bg-secondary text-white px-6 py-3 rounded-lg hover:bg-secondary/80 disabled:opacity-50 transition-colors font-medium"
							>
								{loading ? "Updating..." : "Update Playlist"}
							</button>
						</div>
					</form>
				</div>
			</div>
		</div>
	{/if}

	<!-- Delete Confirmation Modal -->
	{#if showDeleteConfirm}
		<div
			class="fixed inset-0 bg-black/50 z-51 flex items-center justify-center z-50 p-4"
		>
			<div class="bg-white rounded-lg max-w-md w-full">
				<div class="p-6">
					<div class="flex items-center space-x-3 mb-4">
						<div
							class="w-10 h-10 bg-red-100 rounded-full flex items-center justify-center"
						>
							<svg
								class="w-5 h-5 text-red-600"
								fill="none"
								stroke="currentColor"
								viewBox="0 0 24 24"
							>
								<path
									stroke-linecap="round"
									stroke-linejoin="round"
									stroke-width="2"
									d="M12 9v2m0 4h.01m-6.938 4h13.856c1.54 0 2.502-1.667 1.732-2.5L13.732 4c-.77-.833-1.732-.833-2.464 0L3.34 16.5c-.77.833.192 2.5 1.732 2.5z"
								/>
							</svg>
						</div>
						<h3 class="text-lg font-semibold text-gray-800">
							Delete Playlist
						</h3>
					</div>

					<p class="text-gray-600 mb-6">
						Are you sure you want to delete "{playlist?.name}"? This
						action cannot be undone and all playlist data will be
						permanently lost.
					</p>

					<div class="flex space-x-4">
						<button
							onclick={() => (showDeleteConfirm = false)}
							class="flex-1 px-4 py-2 border border-gray-300 text-gray-700 rounded-lg hover:bg-gray-50 transition-colors"
						>
							Cancel
						</button>
						<button
							onclick={handleDeletePlaylist}
							class="flex-1 bg-red-600 text-white px-4 py-2 rounded-lg hover:bg-red-700 transition-colors"
						>
							Delete Playlist
						</button>
					</div>
				</div>
			</div>
		</div>
	{/if}

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
