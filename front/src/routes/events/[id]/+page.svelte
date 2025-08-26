<script lang="ts">
	import { onMount, onDestroy } from "svelte";
	import { page } from "$app/stores";
	import { goto } from "$app/navigation";
	import { authStore } from "$lib/stores/auth";
	import { authService } from "$lib/services/auth";
	import { config } from "$lib/config";
	import {
		getEvent,
		leaveEvent as leaveEventAPI,
		voteForTrackSimple,
		removeVote,
		getVotingResults,
		addTrackToEvent,
		inviteToEvent,
		updateEvent,
		deleteEvent,
		startEvent,
		endEvent,
		playNextTrack as playNextTrackAPI,
		promoteUserToAdmin,
		removeUserFromAdmin,
		type Event,
		type VoteResult,
		type Track,
		type User,
	} from "$lib/services/events";
	import { eventSocketService } from "$lib/services/event-socket";
	import { playlistsService, type Playlist } from "$lib/services/playlists";
	import { deezerService, type DeezerTrack } from "$lib/services/deezer";
	import { musicPlayerService } from "$lib/services/musicPlayer";
	import { musicPlayerStore } from "$lib/stores/musicPlayer";
	import EnhancedMusicSearchModal from "$lib/components/EnhancedMusicSearchModal.svelte";
	import BackNavBtn from "$lib/components/BackNavBtn.svelte";

	interface PageData {
		event?: Event;
	}

	let { data }: { data: PageData } = $props();
	let event: Event | null = $state(data.event || null);
	let user = $derived($authStore);
	let loading = $state(false);
	let error = $state("");
	let votingResults: VoteResult[] = $state([]);
	let showInviteModal = $state(false);
	let showAddTrackModal = $state(false);
	let showPlaylistModal = $state(false);
	let showEditModal = $state(false);
	let showDeleteConfirm = $state(false);
	let showPromoteModal = $state(false);
	let showAddAdminModal = $state(false);
	let addAdminEmail = $state("");
	let userPlaylists: Playlist[] = $state([]);
	let selectedUserId = $state("");
	let isSocketConnected = $state(false);

	// Music search state
	let searchQuery = $state("");
	let searchResults = $state<DeezerTrack[]>([]);
	let topTracks = $state<DeezerTrack[]>([]);
	let isSearching = $state(false);
	let isLoadingTop = $state(false);
	let searchError = $state("");
	let isAddingTrack = $state<string | null>(null);
	let activeTab = $state<"search" | "top">("search");

	// Music player state
	let isPlaying = $state(false);
	let currentPlayingTrack: string | null = $state(null);
	let audioElement: HTMLAudioElement | null = null;
	let isMusicPlayerInitialized = $state(false);
	let showMusicSearchModal = $state(false);
	let draggedIndex: number | null = null;

	// Music player store state
	const playerState = $derived($musicPlayerStore);

	let newTrack = $state({
		title: "",
		artist: "",
		album: "",
		duration: 0,
		thumbnailUrl: "",
		streamUrl: "",
	});

	// Edit event form
	let editEventData = $state({
		name: "",
		description: "",
		licenseType: "open" as "open" | "invited" | "location_based",
		visibility: "public" as "public" | "private",
		locationName: "",
		latitude: undefined as number | undefined,
		longitude: undefined as number | undefined,
		locationRadius: undefined as number | undefined,
		votingStartTime: undefined as string | undefined,
		votingEndTime: undefined as string | undefined,
	});

	let eventId = $derived($page.params.id);
	// Remove isParticipating check since all users on the page are participants
	let isCreator = $derived(user && event && event.creatorId === user.id);
	let isAdmin = $derived(
		user &&
			event &&
			(event.creatorId === user.id ||
				event.admins?.some((admin: User) => admin.id === user.id)),
	);

	// Event status and permissions
	let eventStatus = $derived(() => {
		if (!event?.eventDate || !event?.eventEndDate) return "upcoming";
		const now = new Date();
		const start = new Date(event.eventDate);
		const end = new Date(event.eventEndDate);

		if (now >= start && now < end) return "live";
		if (now < start) return "upcoming";
		return "ended";
	});

	let canVoteForTracks = $derived(() => {
		if (!user || !event) return false;

		// Can't vote on ended events
		if (eventStatus() === "ended") return false;

		// Can't vote on currently playing track
		if (
			currentPlayingTrack &&
			event.playlist?.find((t) => t.id === currentPlayingTrack)
		) {
			return false;
		}

		// Check license restrictions
		switch (event.licenseType) {
			case "open":
				return true;
			case "invited":
				return event.participants.some((p) => p.id === user.id);
			case "location_based":
				// TODO: Implement location-based voting validation
				return false;
			default:
				return false;
		}
	});

	// Sorted playlist with voting restrictions
	function sortedPlaylistTracks() {
		if (!event?.playlist || !Array.isArray(event.playlist)) return [];

		return [...event.playlist].sort((a: Track, b: Track) => {
			// Currently playing track stays at top
			if (currentPlayingTrack === a.id) return -1;
			if (currentPlayingTrack === b.id) return 1;

			// Then sort by vote count
			return (
				(b.voteCount || b.votes || 0) - (a.voteCount || a.votes || 0)
			);
		});
	}

	// Participants sorted by role
	let sortedParticipants = $derived(() => {
		if (!event?.participants) return [];

		return [...event.participants].sort((a: User, b: User) => {
			// Owner first
			if (a.id === event!.creatorId) return -1;
			if (b.id === event!.creatorId) return 1;

			// Then admins
			const aIsAdmin = event!.admins?.some(
				(admin: User) => admin.id === a.id,
			);
			const bIsAdmin = event!.admins?.some(
				(admin: User) => admin.id === b.id,
			);
			if (aIsAdmin && !bIsAdmin) return -1;
			if (bIsAdmin && !aIsAdmin) return 1;

			// Then alphabetically
			return (a.displayName || a.username || "").localeCompare(
				b.displayName || b.username || "",
			);
		});
	});

	// Real-time connection status
	let socketConnected = $state(false);

	// Initialize event data and socket connections
	onMount(async () => {
		// Load initial event data from props or fetch it
		if (data?.event) {
			event = {
				...data.event,
				// Ensure playlist is always an array
				playlist: Array.isArray(data.event.playlist) ? data.event.playlist : [],
				// Start with empty participants - they will be populated via socket events
				participants: [],
			};
			initializeEditForm();
		} else {
			await loadEvent();
		}

		// Load user playlists for adding tracks
		if (user) {
			try {
				userPlaylists = await playlistsService.getPlaylists(
					false,
					user.id,
				);
			} catch (err) {
				console.error("Failed to load user playlists:", err);
			}
		}

		// Set up socket connection for real-time collaborative features
		if (eventId && user) {
			await setupSocketConnection(eventId);
		} else if (eventId && !user) {
			// Wait a bit for user to be loaded from auth store
			setTimeout(async () => {
				const currentUser = $authStore;
				if (currentUser && eventId) {
					await setupSocketConnection(eventId);
				}
			}, 1000);
		}

		// Initialize music player for this event
		if (event && user) {
			await initializeMusicPlayer();
		}
	});

	onDestroy(() => {
		if (eventId && isSocketConnected) {
			cleanupSocketConnection(eventId);
		}

		// Clean up audio
		if (audioElement) {
			audioElement.pause();
			audioElement = null;
		}

		// Cleanup music player
		if (isMusicPlayerInitialized) {
			musicPlayerService.leaveRoom();
			isMusicPlayerInitialized = false;
		}
	});

	async function setupSocketConnection(playlistId: string) {
		try {
			if (!eventSocketService.isConnected()) {
				await eventSocketService.connect();
			}

			// Set up event-specific collaboration listeners
			setupEventSocketListeners();

			isSocketConnected = true;
		} catch (err) {
			console.error("Failed to set up socket connection:", err);
			error = "Failed to connect to real-time updates";
		}
	}

	function setupEventSocketListeners() {
		if (!eventId) return;
		eventSocketService.joinEvent(eventId);
		// Listen for real-time event updates (metadata changes)
		eventSocketService.on("event-updated", handleEventUpdated);
		eventSocketService.on("track-added", handleTrackAdded);
		eventSocketService.on("track-removed", handleTrackRemoved);
		eventSocketService.on("tracks-reordered", handleTracksReordered);
		eventSocketService.on(
			"current-track-changed",
			handleCurrentTrackChanged,
		);
		eventSocketService.on("vote-added", handleVoteUpdated);
		eventSocketService.on("vote-removed", handleVoteRemoved);
		eventSocketService.on("user-joined", handleParticipantAdded);
		eventSocketService.on("user-left", handleParticipantRemoved);
		eventSocketService.on("joined-event", handleJoinedEvent);
		eventSocketService.on("left-event", handleLeavedEvent);
		eventSocketService.on("admin-added", handleAdminAdded);
		eventSocketService.on("admin-removed", handleAdminRemoved);
		eventSocketService.on(
			"current-participants",
			handleCurrentParticipants,
		);
	}

	function cleanupSocketConnection(eventId: string) {
		try {
			// Leave the specific event room
			eventSocketService.leaveEvent(eventId);

			// Clean up event listeners
			eventSocketService.off("event-updated", handleEventUpdated);
			eventSocketService.off("track-added", handleTrackAdded);
			eventSocketService.off("track-removed", handleTrackRemoved);
			eventSocketService.off("tracks-reordered", handleTracksReordered);
			eventSocketService.off(
				"current-track-changed",
				handleCurrentTrackChanged,
			);
			eventSocketService.off("user-joined", handleParticipantAdded);
			eventSocketService.off("user-left", handleParticipantRemoved);
			eventSocketService.off("vote-added", handleVoteUpdated);
			eventSocketService.off("vote-removed", handleVoteRemoved);
			eventSocketService.off("joined-event", handleJoinedEvent);
			eventSocketService.off("left-event", handleLeavedEvent);
			eventSocketService.off("admin-added", handleAdminAdded);
			eventSocketService.off("admin-removed", handleAdminRemoved);
			eventSocketService.off(
				"current-participants",
				handleCurrentParticipants,
			);

			isSocketConnected = false;
		} catch (err) {
			console.error("Failed to clean up socket connection:", err);
		}
	}

	function handleAdminAdded(data: { eventId: string; userId: string }) {
		if (event && event.admins && data.eventId === event.id) {
			if (!event.admins.some((admin) => admin.id === data.userId)) {
				event.admins.push({
					id: data.userId,
					userId: data.userId,
					displayName: "New Admin",
					createdAt: new Date().toISOString(),
					updatedAt: new Date().toISOString(),
					email: "",
				});
				// Force reactivity update
				event = { ...event };
			}
		}
	}

	function handleAdminRemoved(data: { eventId: string; userId: string }) {
		if (event && event.admins && data.eventId === event.id) {
			const initialCount = event.admins.length;
			event.admins = event.admins.filter(
				(admin) => admin.id !== data.userId,
			);
			if (event.admins.length !== initialCount) {
				// Force reactivity update
				event = { ...event };
			}
		}
	}

	function handleEventUpdated(data: { event: Event }) {
		if (event && data.event.id === event.id) {
			const updatedEvent = {
				...event,
				...data.event,
				// Ensure playlist remains an array
				playlist: Array.isArray(data.event.playlist) 
					? data.event.playlist 
					: (Array.isArray(event.playlist) ? event.playlist : [])
			};
			event = updatedEvent;
		}
	}

	function handleTrackAdded(data: { track: Track }) {
		if (event) {
			if (!event.playlist || !Array.isArray(event.playlist)) {
				event.playlist = [];
			}
			event.playlist.push(data.track);
		}
	}
	function handleTrackRemoved(data: { trackId: string }) {
		if (event && event.playlist && Array.isArray(event.playlist)) {
			event.playlist = event.playlist.filter(
				(t) => t.id !== data.trackId,
			);
		}
	}
	function handleTracksReordered(data: { trackOrder: string[] }) {
		if (event && event.playlist && Array.isArray(event.playlist)) {
			const trackMap = new Map(event.playlist.map((t) => [t.id, t]));
			event.playlist = data.trackOrder
				.map((id) => trackMap.get(id))
				.filter((t): t is Track => t !== undefined);
		}
	}
	function handleCurrentTrackChanged(data: {
		track: Track | null;
		startedAt: string | null;
	}) {
		currentPlayingTrack = data.track ? data.track.id : null;
		if (data.track && data.startedAt) {
			// If a new track started, set up audio element
			if (audioElement) {
				audioElement.pause();
				audioElement = null;
			}
			audioElement = new Audio(data.track.streamUrl);
			audioElement.currentTime =
				(Date.now() - new Date(data.startedAt).getTime()) / 1000;
			if (isPlaying) {
				audioElement.play().catch((err) => {
					console.error("Failed to play audio:", err);
				});
			}
		} else {
			// No track is playing
			if (audioElement) {
				audioElement.pause();
				audioElement = null;
			}
		}
	}
	function handleVoteUpdated(data: {
		eventId: string;
		vote: { trackId: string; userId: string };
		results: VoteResult[];
	}) {
		if (event && data.eventId === event.id) {
			votingResults = data.results;
			// Update vote counts in playlist
			if (event.playlist && Array.isArray(event.playlist)) {
				event.playlist = event.playlist.map((track) => {
					const result = votingResults.find(
						(r) => r.track.id === track.id,
					);
					return {
						...track,
						voteCount: result ? result.voteCount : 0,
						votes: result ? result.voteCount : 0,
					};
				});
			}
		}
	}
	function handleVoteRemoved(data: {
		eventId: string;
		trackId: string;
		results: VoteResult[];
	}) {
		if (event && data.eventId === event.id) {
			votingResults = data.results;
			// Update vote counts in playlist
			if (event.playlist && Array.isArray(event.playlist)) {
				event.playlist = event.playlist.map((track) => {
					const result = votingResults.find(
						(r) => r.track.id === track.id,
					);
					return {
						...track,
						voteCount: result ? result.voteCount : 0,
						votes: result ? result.voteCount : 0,
					};
				});
			}
		}
	}
	function handleParticipantAdded(data: any) {
		if (event) {
			if (
				!event.participants.some(
					(p) => p.id === data.userId || p.userId === data.userId,
				)
			) {
				event.participants.push({
					id: data.userId, // Use id as primary property
					userId: data.userId, // Keep userId for compatibility
					displayName: data.displayName || "Unknown User",
					avatarUrl: data.avatarUrl || undefined,
					email: data.email || "",
					createdAt: data.createdAt || new Date().toISOString(),
					updatedAt: data.updatedAt || new Date().toISOString(),
				});
				// Force reactivity update
				event = { ...event };
			}
		}
	}
	function handleParticipantRemoved(data: any) {
		if (event) {
			const remainingParticipants = event.participants.filter(
				(p) => p.id !== data.userId && p.userId !== data.userId,
			);
			event.participants = remainingParticipants;
			// Force reactivity update
			event = { ...event };
		}
	}
	function handleJoinedEvent(data: any) {
		if (event) {
		}
	}
	function handleLeavedEvent(data: any) {
		if (event) {
			// This is when we ourselves leave an event
			event.participants = event.participants.filter(
				(p) => p.id !== data.userId,
			);
			// Force reactivity update
			event = { ...event };
		}
	}

	function handleCurrentParticipants(data: any) {
		if (event && data.eventId === event.id) {
			// Set the current participants list to only include currently connected users
			// Ensure consistent property naming (both id and userId)
			event.participants = (data.participants || []).map(
				(participant: any) => ({
					id: participant.userId || participant.id,
					userId: participant.userId || participant.id,
					displayName: participant.displayName || "Unknown User",
					avatarUrl: participant.avatarUrl || undefined,
					email: participant.email || "",
					createdAt:
						participant.createdAt || new Date().toISOString(),
					updatedAt:
						participant.updatedAt || new Date().toISOString(),
				}),
			);
			// Force reactivity update
			event = { ...event };
		}
	}

	function initializeEditForm() {
		if (event) {
			editEventData = {
				name: event.name,
				description: event.description || "",
				licenseType: event.licenseType,
				visibility: event.visibility,
				locationName: event.locationName || "",
				latitude: event.latitude || undefined,
				longitude: event.longitude || undefined,
				locationRadius: event.locationRadius || undefined,
				votingStartTime: event.votingStartTime || undefined,
				votingEndTime: event.votingEndTime || undefined,
			};
		}
	}

	// Load event data
	async function loadEvent() {
		if (!eventId) return;

		loading = true;
		error = "";

		try {
			const loadedEvent = await getEvent(eventId);

			// Transform event data to ensure compatibility
			event = {
				...loadedEvent,
				title: loadedEvent.title || loadedEvent.name,
				isPublic: loadedEvent.visibility === "public",
				hostId: loadedEvent.hostId || loadedEvent.creatorId,
				hostName: loadedEvent.creator?.displayName || "Unknown Host",
				startDate: loadedEvent.startDate || loadedEvent.eventDate,
				location: loadedEvent.location || loadedEvent.locationName,
				allowsVoting: loadedEvent.allowsVoting !== false, // Default to true
				playlist: (loadedEvent.playlist || []).map((track) => ({
					...track,
					voteCount: track.voteCount || track.votes || 0,
					votes: track.voteCount || track.votes || 0,
				})),
				// Start with empty participants - they will be populated via socket events
				participants: [],
			};

			initializeEditForm();

			// Load voting results if user can vote
			if (user && event.allowsVoting) {
				votingResults = await getVotingResults(eventId);
			}

			// Initialize music player for this event
			await initializeMusicPlayer();
		} catch (err) {
			error = err instanceof Error ? err.message : "Failed to load event";
		} finally {
			loading = false;
		}
	}

	async function leaveEvent() {
		if (!user || !eventId) return;

		try {
			await leaveEventAPI(eventId);
			await loadEvent();
		} catch (err) {
			error =
				err instanceof Error ? err.message : "Failed to leave event";
		}
	}

	async function addPlaylistToEvent(playlistId: string) {
		if (!user || !eventId) return;

		try {
			loading = true;
			const playlistTracks =
				await playlistsService.getPlaylistTracks(playlistId);

			// Add each track to the event
			for (const playlistTrack of playlistTracks) {
				const track = playlistTrack.track;
				await addTrackToEvent(eventId, {
					title: track.title,
					artist: track.artist,
					album: track.album,
					duration: track.duration,
					thumbnailUrl: track.albumCoverUrl,
					streamUrl: track.previewUrl,
				});
			}

			showPlaylistModal = false;
			await loadEvent();
		} catch (err) {
			error =
				err instanceof Error
					? err.message
					: "Failed to add playlist to event";
		} finally {
			loading = false;
		}
	}

	async function handleEditEvent(event: SubmitEvent) {
		event.preventDefault();
		if (!user || !eventId || !isCreator || !isAdmin) return;

		try {
			await updateEvent(eventId, editEventData);
			showEditModal = false;
			await loadEvent();
		} catch (err) {
			error =
				err instanceof Error ? err.message : "Failed to update event";
		}
	}

	async function handleDeleteEvent() {
		if (!user || !eventId || !isCreator) return;

		try {
			await deleteEvent(eventId);
			goto("/events");
		} catch (err) {
			error =
				err instanceof Error ? err.message : "Failed to delete event";
		}
	}

	async function handlePromoteUserToAdmin() {
		if (!user || !eventId || !isCreator || !isAdmin || !selectedUserId)
			return;

		try {
			await promoteUserToAdmin(eventId, selectedUserId);
			showPromoteModal = false;
			selectedUserId = "";
		} catch (err) {
			error =
				err instanceof Error
					? err.message
					: "Failed to promote user to admin";
		}
	}

	async function handleAddAdminByEmail() {
		if (
			!user ||
			!eventId ||
			!isCreator ||
			!isAdmin ||
			!addAdminEmail.trim()
		)
			return;

		try {
			// First, try to find user by email or username
			const response = await fetch(
				`${config.apiUrl}/api/users/search?q=${encodeURIComponent(addAdminEmail.trim())}`,
				{
					headers: {
						Authorization: `Bearer ${authService.getAuthToken()}`,
						"Content-Type": "application/json",
					},
				},
			);

			if (!response.ok) {
				throw new Error("Failed to find user");
			}

			const result = await response.json();
			const users = result.data || [];

			if (users.length === 0) {
				throw new Error("No user found with that email or username");
			}

			const targetUser = users[0]; // Take the first match
			await promoteUserToAdmin(eventId, targetUser.id);
			showAddAdminModal = false;
			addAdminEmail = "";
			await loadEvent();
		} catch (err) {
			error = err instanceof Error ? err.message : "Failed to add admin";
		}
	}

	// Music search functions
	async function searchTracks() {
		if (!searchQuery.trim()) {
			searchResults = [];
			return;
		}

		isSearching = true;
		searchError = "";

		try {
			const response = await deezerService.searchTracks({
				query: searchQuery,
				limit: 20,
			});
			searchResults = response?.data || [];
		} catch (err) {
			searchError = "Failed to search tracks. Please try again.";
			console.error("Search error:", err);
		} finally {
			isSearching = false;
		}
	}

	async function loadTopTracks() {
		isLoadingTop = true;
		try {
			const response = await deezerService.getTopTracks(20);
			topTracks = response?.data || [];
		} catch (error) {
			console.error("Failed to load top tracks:", error);
		} finally {
			isLoadingTop = false;
		}
	}

	// Load top tracks when modal opens
	$effect(() => {
		if (showAddTrackModal && topTracks.length === 0) {
			loadTopTracks();
		}
	});

	// Load playlists when modal opens
	$effect(() => {
		if (showPlaylistModal && userPlaylists.length === 0) {
			loadUserPlaylists();
		}
	});

	async function loadUserPlaylists() {
		if (!user) return;

		try {
			loading = true;
			// Get user's own playlists
			const myPlaylists = await playlistsService.getPlaylists(
				undefined,
				user.id,
			);
			// Get public playlists
			const publicPlaylists = await playlistsService.getPlaylists(true);

			// Combine and deduplicate
			const allPlaylists = [...myPlaylists];
			publicPlaylists.forEach((publicPlaylist) => {
				if (!allPlaylists.some((p) => p.id === publicPlaylist.id)) {
					allPlaylists.push(publicPlaylist);
				}
			});

			userPlaylists = allPlaylists;
		} catch (err) {
			error =
				err instanceof Error ? err.message : "Failed to load playlists";
		} finally {
			loading = false;
		}
	}

	// Debounced search
	let searchTimeout: NodeJS.Timeout;
	$effect(() => {
		if (searchQuery) {
			clearTimeout(searchTimeout);
			searchTimeout = setTimeout(searchTracks, 300);
		} else {
			searchResults = [];
		}
	});

	async function removeAdmin(userId: string) {
		if (!user || !eventId || !isCreator || !isAdmin) return;

		try {
			await removeUserFromAdmin(eventId, userId);
		} catch (err) {
			error =
				err instanceof Error ? err.message : "Failed to remove admin";
		}
	}


	async function pauseMusic() {
		if (!isAdmin || !eventId) return;

		try {
			isPlaying = false;
			eventSocketService.pauseTrack(eventId);

			if (audioElement) {
				audioElement.pause();
			}
		} catch (err) {
			error =
				err instanceof Error ? err.message : "Failed to pause music";
		}
	}

	async function resumeMusic() {
		if (!isAdmin || !eventId) return;

		try {
			isPlaying = true;
			eventSocketService.emit("music-resume", { eventId });

			if (audioElement) {
				await audioElement.play();
			}
		} catch (err) {
			error =
				err instanceof Error ? err.message : "Failed to resume music";
		}
	}

	async function playNextTrack() {
		if (!isAdmin || !eventId || !event?.playlist) return;

		try {
			// Find next track in sorted order
			const sortedTracks = sortedPlaylistTracks();
			const currentIndex = sortedTracks.findIndex(
				(t) => t.id === currentPlayingTrack,
			);
			const nextTrack = sortedTracks[currentIndex + 1];

			if (nextTrack) {
				await playTrack(currentIndex + 1);
			} else {
				// No more tracks, stop playing
				currentPlayingTrack = null;
				isPlaying = false;
				if (audioElement) {
					audioElement.pause();
					audioElement = null;
				}
			}
		} catch (err) {
			error =
				err instanceof Error
					? err.message
					: "Failed to play next track";
		}
	}

	// Helper functions for UI
	function formatDate(dateString: string) {
		return new Date(dateString).toLocaleDateString("en-US", {
			year: "numeric",
			month: "short",
			day: "numeric",
			hour: "2-digit",
			minute: "2-digit",
		});
	}

	function formatDuration(seconds: number) {
		const minutes = Math.floor(seconds / 60);
		const remainingSeconds = seconds % 60;
		return `${minutes}:${remainingSeconds.toString().padStart(2, "0")}`;
	}

	function getAvatarColor(name: string): string {
		const colors = [
			"#FF6B6B",
			"#4ECDC4",
			"#45B7D1",
			"#96CEB4",
			"#FFEAA7",
			"#DDA0DD",
			"#98D8C8",
			"#F7DC6F",
			"#BB8FCE",
			"#85C1E9",
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

	function getUserRole(userId: string): string {
		if (!event) return "Participant";
		if (event.creatorId === userId) return "Owner";
		if (event.admins?.some((admin) => admin.id === userId)) return "Admin";
		return "Participant";
	}

	const canEdit = $derived(isAdmin);

	// Filter tracks based on search query
	function filteredTracks() {
		if (!event?.playlist || !Array.isArray(event.playlist)) return [];
		if (!searchQuery.trim()) return sortedPlaylistTracks();

		const query = searchQuery.toLowerCase().trim();
		return sortedPlaylistTracks().filter(
			(track) =>
				track.title.toLowerCase().includes(query) ||
				track.artist.toLowerCase().includes(query) ||
				track.album?.toLowerCase().includes(query) ||
				(event &&
					event.participants
						.find((p) => p.id === track.addedBy)
						?.displayName?.toLowerCase()
						.includes(query)),
		);
	}

	// Drag and drop functions
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
		if (draggedIndex === null || draggedIndex === dropIndex || !eventId)
			return;
		draggedIndex = null;
	}

	// Music player initialization and control
	async function initializeMusicPlayer() {
		if (!event || !user || isMusicPlayerInitialized) return;

		try {
			if (!event.playlist || !Array.isArray(event.playlist) || event.playlist.length === 0) {
				console.warn(
					"Cannot initialize music player: event has no tracks or playlist is not an array",
					{ playlist: event.playlist }
				);
				return;
			}

			// Create room context for the music player
			const roomContext = {
				type: "event" as const,
				id: event.id,
				ownerId: event.creatorId || "",
				participants: event.participants.map((p) => p.id),
				licenseType: (event.licenseType === "location_based"
					? "location-time"
					: event.licenseType) as
					| "open"
					| "invited"
					| "location-time",
				visibility: event.visibility,
			};

			console.log("Initializing music player with context:", roomContext);
			console.log("Event tracks:", event.playlist.length);

			// Convert event tracks to playlist track format
			const playlistTracks = event.playlist.map((track, index) => ({
				id: track.id,
				position: index + 1,
				addedAt: track.createdAt || new Date().toISOString(),
				createdAt: track.createdAt || new Date().toISOString(),
				playlistId: event!.id,
				trackId: track.id,
				addedById: track.addedBy || event!.creatorId || "",
				track: {
					id: track.id,
					deezerId: track.deezerId || "",
					title: track.title,
					artist: track.artist,
					album: track.album || "",
					duration: track.duration || 0,
					previewUrl: track.streamUrl || track.previewUrl || "",
					albumCoverUrl: track.thumbnailUrl || "",
					albumCoverSmallUrl: track.thumbnailUrl || "",
					albumCoverMediumUrl: track.thumbnailUrl || "",
					albumCoverBigUrl: track.thumbnailUrl || "",
					deezerUrl: "",
					available: true,
					createdAt: track.createdAt || new Date().toISOString(),
					updatedAt: track.updatedAt || new Date().toISOString(),
				},
				addedBy: {
					id: track.addedBy || event!.creatorId || "",
					displayName:
						event!.participants.find((p) => p.id === track.addedBy)
							?.displayName || "Unknown",
				},
			}));

			// Initialize music player with event tracks
			await musicPlayerService.initializeForRoom(
				roomContext,
				playlistTracks || [],
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
				!event?.playlist ||
				!Array.isArray(event.playlist) ||
				trackIndex >= event.playlist.length ||
				trackIndex < 0
			) {
				console.error("Invalid track index:", {
					trackIndex,
					playlistLength: event?.playlist?.length,
					isArray: Array.isArray(event?.playlist),
				});
				error = `Cannot play track: invalid track position (${trackIndex + 1})`;
				setTimeout(() => (error = ""), 3000);
				return;
			}

			console.log("Playing track at index:", trackIndex);
			console.log("Track data:", event.playlist[trackIndex]);

			await musicPlayerService.playTrack(trackIndex);
		} catch (err) {
			console.error("Play track error:", err);
			error = err instanceof Error ? err.message : "Failed to play track";
			setTimeout(() => (error = ""), 3000);
		}
	}

	async function removeTrack(trackId: string) {
		if (!user || !eventId) return;

		try {
			const track = event?.playlist?.find((t) => t.id === trackId);
			if (!track) {
				error = "Track not found";
				return;
			}

			error = "Track removal from events is not yet implemented";
			setTimeout(() => (error = ""), 3000);
		} catch (err) {
			error =
				err instanceof Error ? err.message : "Failed to remove track";
		}
	}
</script>

<svelte:head>
	<title>{event?.name || event?.title || "Event"} - Music Room</title>
	<meta
		name="description"
		content="Join the live music event and vote for tracks"
	/>
</svelte:head>

{#if loading}
	<div class="flex justify-center items-center min-h-[400px]">
		<div
			class="animate-spin rounded-full h-12 w-12 border-b-2 border-secondary"
		></div>
	</div>
{:else if error && !event}
	<div class="container mx-auto px-4 py-8">
		<div
			class="bg-red-100 border border-red-400 text-red-700 px-4 py-3 rounded"
		>
			{error}
		</div>
	</div>
{:else if event}
	<div class="container mx-auto px-4 py-8">
		<div class="flex items-center justify-between w-full">
			<BackNavBtn />
			<button
				onclick={() => (showEditModal = true)}
				class="clickable"
				aria-label="Edit Event"
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
		<!-- Event Header -->
		<div class="bg-white rounded-lg shadow-md p-6 mb-8">
			<div class="flex items-start space-x-6">
				{#if event.coverImageUrl}
					<img
						src={event.coverImageUrl}
						alt={event.title}
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
								d="M19 11a7 7 0 01-7 7m0 0a7 7 0 01-7-7m7 7v4m0 0H8m4 0h4m-4-8a3 3 0 01-3-3V5a3 3 0 116 0v6a3 3 0 01-3 3z"
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
								{event.name || event.title}
							</h1>
							{#if event.description}
								<p class="text-gray-600 mb-4">
									{event.description}
								</p>
							{/if}
						</div>

						<div class="flex space-x-2">
							<span
								class="px-3 py-1 text-sm rounded-full {event.visibility ===
								'public'
									? 'bg-green-100 text-green-800'
									: 'bg-blue-100 text-blue-800'}"
							>
								{event.visibility === "public"
									? "Public"
									: "Private"}
							</span>
							{#if event.allowsVoting}
								<span
									class="px-3 py-1 text-sm rounded-full bg-purple-100 text-purple-800"
								>
									Voting Enabled
								</span>
							{/if}
						</div>
					</div>

					<div
						class="grid grid-cols-2 md:grid-cols-4 gap-4 text-sm text-gray-600 mb-4"
					>
						<div>
							<span class="font-medium">Host:</span>
							<span class="ml-1"
								>{event?.creator?.displayName ||
									event?.hostName ||
									"Unknown"}</span
							>
						</div>

						{#if event?.locationName || event?.location}
							<div>
								<span class="font-medium">Location:</span>
								<span class="ml-1"
									>{event.locationName ||
										event.location}</span
								>
							</div>
						{/if}

						{#if event?.eventDate || event?.startDate}
							<div>
								<span class="font-medium">Start:</span>
								<span class="ml-1"
									>{formatDate(
										event.eventDate ||
											event.startDate ||
											"",
									)}</span
								>
							</div>
						{/if}

						<div>
							<span class="font-medium">Participants:</span>
							<span class="ml-1"
								>{event?.participants?.length || 0}</span
							>
						</div>
					</div>
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

		<!-- Playlist -->
		<div class="bg-white rounded-lg shadow-md p-6 mb-8">
			<div class="flex justify-between items-center mb-6">
				<div>
					<h2 class="text-xl font-bold text-gray-800">
						Event Playlist
					</h2>
					<p class="text-sm text-gray-600">
						{sortedPlaylistTracks().length} track{sortedPlaylistTracks()
							.length !== 1
							? "s"
							: ""}
						{canVoteForTracks()
							? "• Vote to prioritize tracks"
							: "• Voting available for participants"}
					</p>
				</div>
				<div class="flex space-x-2">
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
					{#if isAdmin || isCreator}
						<button
							onclick={() => (showMusicSearchModal = true)}
							class="bg-secondary text-white px-4 py-2 rounded-lg hover:bg-secondary/80 transition-colors flex items-center space-x-2"
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
									d="M12 4v16m8-8H4"
								></path>
							</svg>
							<span>Search & Add Music</span>
						</button>
						<button
							onclick={() => (showPlaylistModal = true)}
							class="bg-purple-500 text-white px-4 py-2 rounded-lg hover:bg-purple-600 transition-colors flex items-center space-x-2"
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
									d="M9 19V6l12-3v13M9 19c0 1.105-1.343 2-3 2s-3-.895-3-2 1.343-2 3-2 3 .895 3 2z"
								></path>
							</svg>
							<span>Add Playlist</span>
						</button>
					{/if}
				</div>
			</div>

			<!-- Search for tracks within event -->
			{#if event?.playlist && event.playlist.length > 0}
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
							placeholder="Search tracks in this event..."
							class="block w-full pl-10 pr-3 py-2 border border-gray-300 rounded-lg focus:outline-none focus:ring-2 focus:ring-secondary focus:border-transparent"
						/>
					</div>
					{#if searchQuery.trim() && filteredTracks().length !== event.playlist.length}
						<p class="text-sm text-gray-600 mt-2">
							Showing {filteredTracks().length} of {event.playlist
								.length} tracks
						</p>
					{/if}
				</div>
			{/if}

			{#if sortedPlaylistTracks().length === 0}
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
										? (event?.playlist?.indexOf(track) ??
												index) + 1
										: index + 1}
								{/if}
							</div>

							{#if track.thumbnailUrl}
								<img
									src={track.thumbnailUrl}
									alt={track.title}
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
									{track.title}
								</h4>
								<p class="text-sm text-gray-600">
									{track.artist}
								</p>
								{#if track.album}
									<p class="text-xs text-gray-500">
										{track.album}
									</p>
								{/if}
								<p class="text-xs text-gray-400">
									Added by {event.participants.find(
										(p) => p.id === track.addedBy,
									)?.displayName || "Unknown"} • {formatDate(
										track.createdAt ||
											new Date().toISOString(),
									)}
								</p>
							</div>

							<div class="flex items-center space-x-3">
								{#if track.duration}
									<span class="text-sm text-gray-500"
										>{formatDuration(track.duration)}</span
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
														? (event?.playlist?.indexOf(
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
												? (event?.playlist?.indexOf(
														track,
													) ?? index)
												: index)
												? 'bg-secondary text-white'
												: 'bg-gray-100 text-gray-600'} hover:bg-secondary hover:text-white disabled:opacity-50 disabled:cursor-not-allowed transition-colors"
											title={playerState.currentTrackIndex ===
											(searchQuery.trim()
												? (event?.playlist?.indexOf(
														track,
													) ?? index)
												: index)
												? playerState.isPlaying
													? "Pause (30s preview)"
													: "Resume (30s preview)"
												: "Play 30s preview"}
											aria-label={`${playerState.currentTrackIndex === (searchQuery.trim() ? (event?.playlist?.indexOf(track) ?? index) : index) && playerState.isPlaying ? "Pause" : "Play"} ${track.title}`}
										>
											{#if playerState.currentTrackIndex === (searchQuery.trim() ? (event?.playlist?.indexOf(track) ?? index) : index) && playerState.isPlaying}
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
										onclick={() => removeTrack(track.id)}
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

		<!-- Participants Sidebar -->
		<div class="lg:col-span-1 space-y-6">
			<div class="bg-white rounded-lg shadow-md p-6">
				<div class="flex items-center justify-between mb-4">
					<h2 class="text-xl font-bold text-gray-800">
						Participants
					</h2>
					<span
						class="bg-secondary/10 text-secondary px-2 py-1 rounded-full text-sm font-medium"
					>
						{event.participants.length}
					</span>
				</div>

				<div>
					{#each sortedParticipants() as participant}
						{@const role = getUserRole(participant.id)}
						<button
							onclick={() => goto(`/users/${participant.id}`)}
							class="flex items-center space-x-3 p-2 rounded-lg hover:bg-gray-50 transition-colors w-full text-left {participant.id ===
							user?.id
								? 'bg-gray-100'
								: ''}"
						>
							{#if participant.avatarUrl && !participant.avatarUrl.startsWith("data:image/svg+xml")}
								<img
									src={participant.avatarUrl}
									alt={participant.displayName}
									class="w-10 h-10 rounded-full object-cover"
								/>
							{:else}
								<div
									class="w-10 h-10 rounded-full flex items-center justify-center text-white font-semibold text-sm"
									style="background-color: {getAvatarColor(
										participant.displayName || 'Unknown',
									)}"
								>
									{getAvatarLetter(
										participant.displayName || "Unknown",
									)}
								</div>
							{/if}

							<div class="flex-1 min-w-0">
								<p class="font-medium text-gray-800 truncate">
									{participant.displayName ||
										participant.username}
								</p>
								<div
									class="flex items-center space-x-2 text-xs text-gray-500"
								>
									{role}
								</div>
							</div>
						</button>
					{/each}
				</div>
			</div>
		</div>

		<!-- Enhanced Music Search Modal -->
		{#if showMusicSearchModal && eventId}
			<EnhancedMusicSearchModal
				{eventId}
				onTrackAdded={() => {
					showMusicSearchModal = false;
					// Reload event data to show the new track
					loadEvent();
				}}
				onClose={() => (showMusicSearchModal = false)}
			/>
		{/if}

		<!-- Invite Users Modal -->
		{#if showInviteModal}
			<div
				class="fixed inset-0 bg-black/50 z-51 flex items-center justify-center z-50 p-4"
			>
				<div
					class="bg-white rounded-lg max-w-md w-full max-h-[90vh] overflow-y-auto"
				>
					<div class="p-6">
						<div class="flex justify-between items-center mb-6">
							<h2 class="text-xl font-bold text-gray-800">
								Invite Users
							</h2>
							<button
								onclick={() => (showInviteModal = false)}
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

						<div class="space-y-6">
							<!-- Invite Link -->
							<div>
								<label
									for="invite-link"
									class="block text-sm font-medium text-gray-700 mb-2"
									>Share Event Link</label
								>
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
											navigator.clipboard.writeText(
												`${$page.url.origin}/events/${eventId}`,
											);
											// Show toast notification
										}}
										class="bg-secondary text-white px-4 py-3 rounded-lg hover:bg-secondary/80 transition-colors"
										title="Copy link"
										aria-label="Copy invite link"
									>
										<svg
											class="w-5 h-5"
											fill="none"
											stroke="currentColor"
											viewBox="0 0 24 24"
										>
											<path
												stroke-linecap="round"
												stroke-linejoin="round"
												stroke-width="2"
												d="M8 16H6a2 2 0 01-2-2V6a2 2 0 012-2h8a2 2 0 012 2v2m-6 12h8a2 2 0 002-2v-8a2 2 0 00-2-2h-8a2 2 0 00-2 2v8a2 2 0 002 2z"
											></path>
										</svg>
									</button>
								</div>
								<p class="text-xs text-gray-500 mt-2">
									Share this link to invite people to your
									event
								</p>
							</div>

							<!-- QR Code -->
							<div class="text-center">
								<div
									class="bg-gray-100 p-4 rounded-lg inline-block"
								>
									<div
										class="w-32 h-32 bg-white border-2 border-dashed border-gray-300 rounded flex items-center justify-center"
									>
										<span class="text-gray-500 text-sm"
											>QR Code</span
										>
									</div>
								</div>
								<p class="text-xs text-gray-500 mt-2">
									QR code for easy mobile sharing
								</p>
							</div>

							<!-- Social Share Buttons -->
							<div>
								<h3
									class="block text-sm font-medium text-gray-700 mb-3"
								>
									Share on Social Media
								</h3>
								<div class="grid grid-cols-2 gap-3">
									<button
										onclick={() => {
											const text = `Join me at "${event?.title || event?.name}" music event!`;
											const url = `${$page.url.origin}/events/${eventId}`;
											window.open(
												`https://twitter.com/intent/tweet?text=${encodeURIComponent(text)}&url=${encodeURIComponent(url)}`,
												"_blank",
											);
										}}
										class="flex items-center justify-center space-x-2 bg-blue-500 text-white px-4 py-3 rounded-lg hover:bg-blue-600 transition-colors"
										aria-label="Share on Twitter"
									>
										<svg
											class="w-5 h-5"
											fill="currentColor"
											viewBox="0 0 24 24"
										>
											<path
												d="M23.953 4.57a10 10 0 01-2.825.775 4.958 4.958 0 002.163-2.723c-.951.555-2.005.959-3.127 1.184a4.92 4.92 0 00-8.384 4.482C7.69 8.095 4.067 6.13 1.64 3.162a4.822 4.822 0 00-.666 2.475c0 1.71.87 3.213 2.188 4.096a4.904 4.904 0 01-2.228-.616v.06a4.923 4.923 0 003.946 4.827 4.996 4.996 0 01-2.212.085 4.936 4.936 0 004.604 3.417 9.867 9.867 0 01-6.102 2.105c-.39 0-.779-.023-1.17-.067a13.995 13.995 0 007.557 2.209c9.053 0 13.998-7.496 13.998-13.985 0-.21 0-.42-.015-.63A9.935 9.935 0 0024 4.59z"
											/>
										</svg>
										<span>Twitter</span>
									</button>

									<button
										onclick={() => {
											const text = `Join me at "${event?.title || event?.name}" music event!`;
											const url = `${$page.url.origin}/events/${eventId}`;
											window.open(
												`https://www.facebook.com/sharer/sharer.php?u=${encodeURIComponent(url)}&quote=${encodeURIComponent(text)}`,
												"_blank",
											);
										}}
										class="flex items-center justify-center space-x-2 bg-blue-600 text-white px-4 py-3 rounded-lg hover:bg-blue-700 transition-colors"
										aria-label="Share on Facebook"
									>
										<svg
											class="w-5 h-5"
											fill="currentColor"
											viewBox="0 0 24 24"
										>
											<path
												d="M24 12.073c0-6.627-5.373-12-12-12s-12 5.373-12 12c0 5.99 4.388 10.954 10.125 11.854v-8.385H7.078v-3.47h3.047V9.43c0-3.007 1.792-4.669 4.533-4.669 1.312 0 2.686.235 2.686.235v2.953H15.83c-1.491 0-1.956.925-1.956 1.874v2.25h3.328l-.532 3.47h-2.796v8.385C19.612 23.027 24 18.062 24 12.073z"
											/>
										</svg>
										<span>Facebook</span>
									</button>
								</div>
							</div>
						</div>

						<div
							class="flex justify-end pt-6 border-t border-gray-200 mt-6"
						>
							<button
								onclick={() => (showInviteModal = false)}
								class="px-6 py-3 bg-gray-100 text-gray-700 rounded-lg hover:bg-gray-200 transition-colors font-medium"
							>
								Close
							</button>
						</div>
					</div>
				</div>
			</div>
		{/if}

		<!-- Add Playlist Modal -->
		{#if showPlaylistModal}
			<div
				class="fixed inset-0 bg-black/50 z-51 flex items-center justify-center z-50 p-4"
			>
				<div
					class="bg-white rounded-lg max-w-lg w-full max-h-[90vh] overflow-y-auto"
				>
					<div class="p-6">
						<div class="flex justify-between items-center mb-6">
							<h2 class="text-xl font-bold text-gray-800">
								Add Playlist to Event
							</h2>
							<button
								onclick={() => (showPlaylistModal = false)}
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

						{#if userPlaylists.length === 0}
							<div class="text-center py-8">
								{#if loading}
									<div
										class="animate-spin w-8 h-8 border-4 border-secondary border-t-transparent rounded-full mx-auto mb-4"
									></div>
									<p class="text-gray-500">
										Loading playlists...
									</p>
								{:else}
									<p class="text-gray-500 mb-4">
										No playlists available.
									</p>
									<a
										href="/playlists"
										class="text-secondary hover:text-secondary/80"
										>Create your first playlist</a
									>
								{/if}
							</div>
						{:else}
							<div class="space-y-3 max-h-96 overflow-y-auto">
								{#each userPlaylists as playlist}
									<div
										class="border border-gray-200 rounded-lg p-4 hover:bg-gray-50 transition-colors"
									>
										<div
											class="flex items-center justify-between"
										>
											<div class="flex-1">
												<div
													class="flex items-center space-x-2 mb-1"
												>
													<h3
														class="font-medium text-gray-800"
													>
														{playlist.name}
													</h3>
													<span
														class="px-2 py-0.5 text-xs rounded-full {playlist.visibility ===
														'public'
															? 'bg-green-100 text-green-800'
															: 'bg-blue-100 text-blue-800'}"
													>
														{playlist.visibility ===
														"public"
															? "Public"
															: "Private"}
													</span>
													{#if playlist.creator?.displayName && playlist.creatorId !== user?.id}
														<span
															class="text-xs text-gray-500"
															>by {playlist
																.creator
																.displayName}</span
														>
													{/if}
												</div>
												<p
													class="text-sm text-gray-600"
												>
													{playlist.trackCount || 0} tracks
												</p>
												{#if playlist.description}
													<p
														class="text-xs text-gray-500 mt-1"
													>
														{playlist.description}
													</p>
												{/if}
											</div>
											<button
												onclick={() =>
													addPlaylistToEvent(
														playlist.id,
													)}
												disabled={loading}
												class="bg-secondary text-white px-4 py-2 rounded-lg hover:bg-secondary/80 disabled:opacity-50 transition-colors"
											>
												{loading ? "Adding..." : "Add"}
											</button>
										</div>
									</div>
								{/each}
							</div>
						{/if}

						<div
							class="flex justify-end pt-6 border-t border-gray-200 mt-6"
						>
							<button
								onclick={() => (showPlaylistModal = false)}
								class="px-6 py-3 bg-gray-100 text-gray-700 rounded-lg hover:bg-gray-200 transition-colors font-medium"
							>
								Cancel
							</button>
						</div>
					</div>
				</div>
			</div>
		{/if}

		<!-- Edit Event Modal -->
		{#if showEditModal}
			<div
				class="fixed inset-0 bg-black/50 z-51 flex items-center justify-center z-50 p-4"
			>
				<div
					class="bg-white rounded-lg max-w-2xl w-full max-h-[90vh] overflow-y-auto"
				>
					<div class="p-6">
						<div class="flex justify-between items-center mb-6">
							<h2 class="text-2xl font-bold text-gray-800">
								Edit Event
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

						<form onsubmit={handleEditEvent} class="space-y-6">
							<div class="space-y-4">
								<h3
									class="text-lg font-semibold text-gray-800 border-b border-gray-200 pb-2"
								>
									Basic Information
								</h3>

								<div>
									<label
										for="edit-event-name"
										class="block text-sm font-medium text-gray-700 mb-2"
										>Event Name *</label
									>
									<input
										id="edit-event-name"
										type="text"
										bind:value={editEventData.name}
										required
										class="w-full px-4 py-3 border border-gray-300 rounded-lg focus:outline-none focus:ring-2 focus:ring-secondary focus:border-transparent"
									/>
								</div>

								<div>
									<label
										for="edit-event-description"
										class="block text-sm font-medium text-gray-700 mb-2"
										>Description</label
									>
									<textarea
										id="edit-event-description"
										bind:value={editEventData.description}
										rows="4"
										class="w-full px-4 py-3 border border-gray-300 rounded-lg focus:outline-none focus:ring-2 focus:ring-secondary focus:border-transparent"
									></textarea>
								</div>
							</div>

							<div class="space-y-4">
								<h3
									class="text-lg font-semibold text-gray-800 border-b border-gray-200 pb-2"
								>
									Event Settings
								</h3>

								<div>
									<label
										for="edit-event-visibility"
										class="block text-sm font-medium text-gray-700 mb-2"
										>Visibility</label
									>
									<select
										id="edit-event-visibility"
										bind:value={editEventData.visibility}
										class="w-full px-4 py-3 border border-gray-300 rounded-lg focus:outline-none focus:ring-2 focus:ring-secondary focus:border-transparent"
									>
										<option value="public">Public</option>
										<option value="private">Private</option>
									</select>
								</div>

								<div>
									<label
										for="edit-event-license"
										class="block text-sm font-medium text-gray-700 mb-2"
										>Voting License</label
									>
									<select
										id="edit-event-license"
										bind:value={editEventData.licenseType}
										class="w-full px-4 py-3 border border-gray-300 rounded-lg focus:outline-none focus:ring-2 focus:ring-secondary focus:border-transparent"
									>
										<option value="open">Open</option>
										<option value="invited"
											>Invited Only</option
										>
										<option value="location_based"
											>Location Based</option
										>
									</select>
								</div>

								{#if editEventData.licenseType === "location_based"}
									<div>
										<label
											for="edit-location-name"
											class="block text-sm font-medium text-gray-700 mb-2"
											>Location Name</label
										>
										<input
											id="edit-location-name"
											type="text"
											bind:value={
												editEventData.locationName
											}
											class="w-full px-4 py-3 border border-gray-300 rounded-lg focus:outline-none focus:ring-2 focus:ring-secondary focus:border-transparent"
										/>
									</div>
									<div class="space-y-4">
										<h3
											class="text-lg font-semibold text-gray-800 border-b border-gray-200 pb-2"
										>
											Location-based Settings
										</h3>

										<div>
											<label
												for="event-location"
												class="block text-sm font-medium text-gray-700 mb-2"
												>Location Name</label
											>
											<input
												id="event-location"
												type="text"
												bind:value={
													editEventData.locationName
												}
												class="w-full px-4 py-3 border border-gray-300 rounded-lg focus:outline-none focus:ring-2 focus:ring-secondary focus:border-transparent"
												placeholder="Where is your event taking place?"
											/>
										</div>

										<div
											class="grid grid-cols-1 md:grid-cols-2 gap-4"
										>
											<div>
												<label
													for="latitude"
													class="block text-sm font-medium text-gray-700 mb-2"
													>Latitude</label
												>
												<input
													id="latitude"
													type="number"
													bind:value={
														editEventData.latitude
													}
													step="0.0001"
													min="-90"
													max="90"
													class="w-full px-4 py-3 border border-gray-300 rounded-lg focus:outline-none focus:ring-2 focus:ring-secondary focus:border-transparent"
													placeholder="e.g., 40.7128"
												/>
											</div>

											<div>
												<label
													for="longitude"
													class="block text-sm font-medium text-gray-700 mb-2"
													>Longitude</label
												>
												<input
													id="longitude"
													type="number"
													bind:value={
														editEventData.longitude
													}
													step="0.0001"
													min="-180"
													max="180"
													class="w-full px-4 py-3 border border-gray-300 rounded-lg focus:outline-none focus:ring-2 focus:ring-secondary focus:border-transparent"
													placeholder="e.g., -74.0060"
												/>
											</div>
										</div>

										<div>
											<label
												for="location-radius"
												class="block text-sm font-medium text-gray-700 mb-2"
												>Location Radius (meters)</label
											>
											<input
												id="location-radius"
												type="number"
												bind:value={
													editEventData.locationRadius
												}
												min="10"
												max="10000"
												class="w-full px-4 py-3 border border-gray-300 rounded-lg focus:outline-none focus:ring-2 focus:ring-secondary focus:border-transparent"
												placeholder="e.g., 100"
											/>
											<p
												class="text-xs text-gray-500 mt-1"
											>
												Users must be within this radius
												to vote
											</p>
										</div>

										<div
											class="grid grid-cols-1 md:grid-cols-2 gap-4"
										>
											<div>
												<label
													for="voting-start"
													class="block text-sm font-medium text-gray-700 mb-2"
													>Voting Start Time</label
												>
												<input
													id="voting-start"
													type="time"
													bind:value={
														editEventData.votingStartTime
													}
													class="w-full px-4 py-3 border border-gray-300 rounded-lg focus:outline-none focus:ring-2 focus:ring-secondary focus:border-transparent"
												/>
											</div>

											<div>
												<label
													for="voting-end"
													class="block text-sm font-medium text-gray-700 mb-2"
													>Voting End Time</label
												>
												<input
													id="voting-end"
													type="time"
													bind:value={
														editEventData.votingEndTime
													}
													class="w-full px-4 py-3 border border-gray-300 rounded-lg focus:outline-none focus:ring-2 focus:ring-secondary focus:border-transparent"
												/>
											</div>
										</div>
									</div>
								{/if}
								{#if isCreator}
									<button
										onclick={() => (
											(showEditModal = false),
											(showDeleteConfirm = true)
										)}
										class="bg-red-500 text-white px-4 py-2 rounded-lg hover:bg-red-600 transition-colors"
									>
										Delete Event
									</button>
								{/if}
							</div>
							<div
								class="flex space-x-4 pt-6 border-t border-gray-200"
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
									{loading ? "Updating..." : "Update Event"}
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
								Delete Event
							</h3>
						</div>

						<p class="text-gray-600 mb-6">
							Are you sure you want to delete "{event?.name}"?
							This action cannot be undone and all event data will
							be permanently lost.
						</p>

						<div class="flex space-x-4">
							<button
								onclick={() => (showDeleteConfirm = false)}
								class="flex-1 px-4 py-2 border border-gray-300 text-gray-700 rounded-lg hover:bg-gray-50 transition-colors"
							>
								Cancel
							</button>
							<button
								onclick={handleDeleteEvent}
								class="flex-1 bg-red-600 text-white px-4 py-2 rounded-lg hover:bg-red-700 transition-colors"
							>
								Delete Event
							</button>
						</div>
					</div>
				</div>
			</div>
		{/if}

		<!-- Promote User Modal -->
		{#if showPromoteModal}
			<div
				class="fixed inset-0 bg-black/50 z-51 flex items-center justify-center z-50 p-4"
			>
				<div class="bg-white rounded-lg max-w-md w-full">
					<div class="p-6">
						<div class="flex items-center space-x-3 mb-4">
							<div
								class="w-10 h-10 bg-purple-100 rounded-full flex items-center justify-center"
							>
								<svg
									class="w-5 h-5 text-purple-600"
									fill="none"
									stroke="currentColor"
									viewBox="0 0 24 24"
								>
									<path
										stroke-linecap="round"
										stroke-linejoin="round"
										stroke-width="2"
										d="M5 15l7-7 7 7"
									/>
								</svg>
							</div>
							<h3 class="text-lg font-semibold text-gray-800">
								Promote to Admin
							</h3>
						</div>

						{#if selectedUserId && event?.participants}
							{@const selectedUser = event.participants.find(
								(p) => p.id === selectedUserId,
							)}
							{#if selectedUser}
								<p class="text-gray-600 mb-6">
									Are you sure you want to promote <strong
										>{selectedUser.displayName ||
											selectedUser.username}</strong
									> to admin? They will be able to control music
									playback and manage the event.
								</p>
							{/if}
						{/if}

						<div class="flex space-x-4">
							<button
								onclick={() => {
									showPromoteModal = false;
									selectedUserId = "";
								}}
								class="flex-1 px-4 py-2 border border-gray-300 text-gray-700 rounded-lg hover:bg-gray-50 transition-colors"
							>
								Cancel
							</button>
							<button
								onclick={handlePromoteUserToAdmin}
								class="flex-1 bg-purple-600 text-white px-4 py-2 rounded-lg hover:bg-purple-700 transition-colors"
							>
								Promote
							</button>
						</div>
					</div>
				</div>
			</div>
		{/if}

		<!-- Add Admin Modal -->
		{#if showAddAdminModal}
			<div
				class="fixed inset-0 bg-black/50 z-51 flex items-center justify-center z-50 p-4"
			>
				<div class="bg-white rounded-lg max-w-md w-full">
					<div class="p-6">
						<div class="flex justify-between items-center mb-6">
							<h2 class="text-xl font-bold text-gray-800">
								Add Admin
							</h2>
							<button
								onclick={() => (showAddAdminModal = false)}
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

						<form
							onsubmit={handleAddAdminByEmail}
							class="space-y-4"
						>
							<div>
								<label
									for="admin-email"
									class="block text-sm font-medium text-gray-700 mb-2"
								>
									Email or Username
								</label>
								<input
									id="admin-email"
									type="text"
									bind:value={addAdminEmail}
									placeholder="Enter email address or username"
									required
									class="w-full px-4 py-3 border border-gray-300 rounded-lg focus:outline-none focus:ring-2 focus:ring-secondary focus:border-transparent"
								/>
							</div>

							{#if error}
								<div class="text-red-600 text-sm">{error}</div>
							{/if}

							<div class="flex space-x-4 pt-4">
								<button
									type="button"
									onclick={() => {
										showAddAdminModal = false;
										addAdminEmail = "";
										error = "";
									}}
									class="flex-1 px-6 py-3 border border-gray-300 text-gray-700 rounded-lg hover:bg-gray-50 transition-colors font-medium"
								>
									Cancel
								</button>
								<button
									type="submit"
									disabled={loading}
									class="flex-1 bg-secondary text-white px-6 py-3 rounded-lg hover:bg-secondary/80 disabled:opacity-50 transition-colors font-medium"
								>
									{loading ? "Adding..." : "Add Admin"}
								</button>
							</div>
						</form>
					</div>
				</div>
			</div>
		{/if}
	</div>
{/if}
