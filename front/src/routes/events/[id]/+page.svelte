<script lang="ts">
	import { onMount, onDestroy } from "svelte";
	import { page } from "$app/stores";
	import { goto } from "$app/navigation";
	import { authStore } from "$lib/stores/auth";
	import { authService } from "$lib/services/auth";
	import { config } from "$lib/config";
	import {
		getEvent,
		joinEvent,
		leaveEvent as leaveEventAPI,
		voteForTrackInEvent,
		removeVote,
		getVotingResults,
		addTrackToEvent,
		addTracksToEvent,
		addPlaylistTracksToEvent,
		removeTrackFromEvent,
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
		type Vote,
	} from "$lib/services/events";
	import { eventSocketService } from "$lib/services/event-socket";
	import { playlistsService, type Playlist } from "$lib/services/playlists";
	import { deezerService, type DeezerTrack } from "$lib/services/deezer";
	import { musicPlayerService } from "$lib/services/musicPlayer";
	import { musicPlayerStore } from "$lib/stores/musicPlayer";
	import { geocodingService } from "$lib/services/geocoding";
	import EnhancedMusicSearchModal from "$lib/components/EnhancedMusicSearchModal.svelte";
	import AddCollaboratorModal from "$lib/components/AddCollaboratorModal.svelte";
	import BackNavBtn from "$lib/components/BackNavBtn.svelte";
	import { getAvatarColor, getAvatarLetter } from "$lib/utils/avatar";
	import { flip } from 'svelte/animate';

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
	let userPlaylists: Playlist[] = $state([]);
	let selectedUserId = $state("");
	let isSocketConnected = $state(false);
	let isPlaylistCollaborator = $state(false);
	let hasEventAccess = $state(true); // Assume access initially, check when data loads
	let isMusicPlayerInitialized = $state(false); // Track music player initialization

	// Location-based voting state
	let hasLocationPermission = $state(false);
	let locationStatus = $state<'checking' | 'allowed' | 'denied' | 'unavailable' | 'outside_time'>('checking');
	let locationError = $state("");
	let currentUserLocation = $state<{latitude: number, longitude: number} | null>(null);
	let locationWatchId: number | null = null;

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
	let showMusicSearchModal = $state(false);
	let hasAttemptedPlaylistLoad = $state(false);

	// Music player store state
	const playerState = $derived($musicPlayerStore);

	// Edit event form
	let editEventData = $state({
		name: "",
		description: "",
		licenseType: "open" as "open" | "invited" | "location_based",
		visibility: "public" as "public" | "private",
		locationName: "",
		locationRadius: undefined as number | undefined,
		votingStartTime: undefined as string | undefined,
		votingEndTime: undefined as string | undefined,
		maxVotesPerUser: 1
	});

	// Edit form city input state
	let editCityInput = $state("");
	let editCitySuggestions = $state<string[]>([]);
	let showEditCitySuggestions = $state(false);
	let isGeocodingEditCity = $state(false);
	let editCityError = $state("");
	// Vote button animation state tracking - local to this user only
	let voteAnimations = $state(new Map<string, { upvote: string, downvote: string, remove: string }>());
	// Local user vote state tracking - independent of WebSocket updates
	let localUserVotes = $state(new Map<string, 'upvote' | 'downvote' | null>());
	// Track original insertion order for consistent sorting when vote counts are equal
	let originalTrackOrder = $state(new Map<string, number>());
	let eventId = $derived($page.params.id);

	// Remove isParticipating check since all users on the page are participants
	let isCreator = $derived(user && event && event.creatorId === user.id);
	let isAdmin = $derived(
		user &&
		event &&
		(event.creatorId === user.id ||
		event.admins?.some((admin: User) => admin.id === user.id)),
	);
	const canEdit = $derived(isAdmin);
	let eventStatus = $derived(() => {
		if (!event?.eventDate || !event?.eventEndDate) return "upcoming";
		const now = new Date();
		const start = new Date(event.eventDate);
		const end = new Date(event.eventEndDate);

		if (now >= start && now < end) return "live";
		if (now < start) return "upcoming";
		return "ended";
	});
	let numberOfVotesAvailable = $derived(() => {
		if (!event) return 0;
		// If maxVotesPerUser is 0, it means unlimited votes
		if (event.maxVotesPerUser === 0) return Infinity;
		// Count only votes that are not null (actual votes)
		const activeVotes = Array.from(localUserVotes.values()).filter(vote => vote !== null).length;
		return event.maxVotesPerUser - activeVotes;
	});
	let canVoteForTracks = $derived(() => {
		if (!user || !event) return false;

		// Can't vote on ended events
		if (eventStatus() === "ended") return false;

		// Check license restrictions
		switch (event.licenseType) {
			case "open":
				return true;
			case "invited":
				// Allow voting if user is a participant OR a playlist collaborator
				return event.participants.some((p) => p.id === user.id) || isPlaylistCollaborator;
			case "location_based":
				// Allow voting if user has valid location and time permission
				return hasLocationPermission;
			default:
				return false;
		}
	});
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
	let socketConnected = $state(false);
	let hasLoadedVotingData = $state(false);
	// Debounced search
	let searchTimeout: NodeJS.Timeout;

	// Reactive effect to load voting data when user becomes available
	$effect(() => {
		if (user && eventId && event && !hasLoadedVotingData && !votingResults.length) {
			// Only load if we haven't loaded voting results yet
			loadVotingDataForUser();
		}
	});

	// Automatically set licenseType to 'invited' when visibility is 'private'
	$effect(() => {
		if (editEventData.visibility === 'private') {
			editEventData.licenseType = 'invited';
		}
	});

	// Check playlist collaborator status when user or event changes
	$effect(() => {
		if (user && event?.playlistId) {
			checkPlaylistCollaboratorStatus();
		}
	});

	// Check event access when user or event changes
	$effect(() => {
		if (event) {
			checkEventAccess();
		}
	});

	// Check location permission when event becomes location-based
	$effect(() => {
		if (event && event.licenseType === 'location_based' && user) {
			checkLocationPermission(false); // Fresh location check initially
			startLocationWatching();
		} else if (event && event.licenseType !== 'location_based') {
			stopLocationWatching();
			hasLocationPermission = true;
			locationStatus = 'allowed';
		}
	});

	// Load top tracks when modal opens
	$effect(() => {
		if (showAddTrackModal && topTracks.length === 0) {
			loadTopTracks();
		}
	});

	// Initialize page data when component loads or event ID changes
	$effect(() => {
		if (eventId && user) {
			if (!event || event.id !== eventId) {
				loadEvent();
			}
		}
	});

	$effect(() => {
		if (searchQuery) {
			clearTimeout(searchTimeout);
			searchTimeout = setTimeout(searchTracks, 300);
		} else {
			searchResults = [];
		}
	});

	// Handle page unload - leave event when user navigates away or closes tab
	function handlePageUnload() {
		if (user && eventId && event) {
			const isParticipant = event.participants?.some(p => p.id === user.id);
			if (isParticipant) {
				// Use navigator.sendBeacon for reliable cleanup on page unload
				const data = JSON.stringify({});
				const url = `${config.apiUrl}/api/events/${eventId}/leave`;
				const token = authService.getAuthToken();
				
				// Check if sendBeacon is available and working
				if (typeof navigator !== 'undefined' && 'sendBeacon' in navigator) {
					// Create a blob with the request data
					const blob = new Blob([data], { type: 'application/json' });
					
					// Unfortunately, sendBeacon doesn't support custom headers, so we'll try fetch with keepalive
					fetch(url, {
						method: 'POST',
						headers: {
							'Authorization': `Bearer ${token}`,
							'Content-Type': 'application/json',
						},
						body: data,
						keepalive: true, // This ensures the request continues even if page is closing
					}).catch(error => {
						// Failed to leave event during page unload
					});
				}
			}
		}
	}

	// Initialize music player for the event
	async function initializeMusicPlayer() {
		if (!event || !user || isMusicPlayerInitialized) return;

		try {
			// Create local reference to satisfy TypeScript null checks
			const currentEvent = event;
			
			// Set up music player store for event mode - always initialize, even with empty playlist
			musicPlayerStore.setInEvent(true, currentEvent.id);
			
			// Set user permissions based on event role
			const canControl = isCreator || isAdmin;
			musicPlayerStore.setCanControl(!!canControl);

			let playlistTracks = [] as any[];

			// Convert event playlist to music player format if available
			if (currentEvent.playlist && Array.isArray(currentEvent.playlist)) {
				playlistTracks = currentEvent.playlist.map((track, index) => ({
					id: track.id,
					position: index,
					addedAt: new Date().toISOString(),
					createdAt: new Date().toISOString(),
					playlistId: currentEvent.id,
					trackId: track.id,
					addedById: track.addedBy || currentEvent.creatorId || "",
					track: {
						id: track.id,
						deezerId: track.deezerId || "",
						title: track.title,
						artist: track.artist,
						album: track.album || "",
						duration: track.duration || 30,
						previewUrl: track.previewUrl || "",
						albumCoverUrl: track.thumbnailUrl || "",
						albumCoverSmallUrl: track.thumbnailUrl || "",
						albumCoverMediumUrl: track.thumbnailUrl || "",
						albumCoverBigUrl: track.thumbnailUrl || "",
						deezerUrl: "",
						genres: "",
						releaseDate: "",
						available: true,
						createdAt: track.createdAt || new Date().toISOString(),
						updatedAt: track.updatedAt || new Date().toISOString()
					},
					addedBy: {
						id: track.addedBy || currentEvent.creatorId || "",
						displayName: "User",
						email: "",
						createdAt: new Date().toISOString(),
						updatedAt: new Date().toISOString()
					}
				}));
			}

			// Always set the playlist in the music player (even if empty)
			musicPlayerStore.setPlaylist(playlistTracks, playlistTracks.length > 0 ? 0 : -1);

			// If there's a current track, set it
			if (currentEvent.currentTrack && playlistTracks.length > 0) {
				const currentIndex = playlistTracks.findIndex(pt => pt.track.id === currentEvent.currentTrack?.id);
				if (currentIndex >= 0) {
					const currentTrack = currentEvent.currentTrack;
					musicPlayerStore.setCurrentTrack(
						{
							id: currentTrack.id,
							title: currentTrack.title,
							artist: currentTrack.artist,
							album: currentTrack.album || "",
							duration: currentTrack.duration || 30,
							albumCoverUrl: currentTrack.thumbnailUrl || "",
							previewUrl: currentTrack.previewUrl || ""
						},
						playlistTracks,
						currentIndex
					);
				}
			} else if (playlistTracks.length > 0) {
				// No current track but we have tracks - set the first track as current
				// This ensures the music player shows track info instead of "waiting for tracks"
				const firstTrack = playlistTracks[0];
				musicPlayerStore.setCurrentTrack(
					{
						id: firstTrack.track.id,
						title: firstTrack.track.title,
						artist: firstTrack.track.artist,
						album: firstTrack.track.album || "",
						duration: firstTrack.track.duration || 30,
						albumCoverUrl: firstTrack.track.albumCoverUrl || "",
						previewUrl: firstTrack.track.previewUrl || ""
					},
					playlistTracks,
					0
				);
			}

			// Connect to event socket if not already connected
			if (eventId) {
				try {
					await eventSocketService.connect();
					eventSocketService.joinEvent(eventId);
				} catch (error) {
					// Failed to connect to event socket
				}
			}

			isMusicPlayerInitialized = true;
			// Music player initialized for event
		} catch (error) {
			// Failed to initialize music player
		}
	}


	// Initialize event data and socket connections
	onMount(async () => {
		// Load initial event data from props or fetch it
		if (data?.event) {
			// Deduplicate participants from initial load to prevent issues
			const uniqueParticipants = new Map();
			(data.event.participants || []).forEach((participant: any) => {
				const userId = participant.id || participant.userId;
				if (userId) {
					uniqueParticipants.set(userId, participant);
				}
			});
			
			event = {
				...data.event,
				// Ensure playlist is always an array
				playlist: Array.isArray(data.event.playlist) ? data.event.playlist : [],
				// Use deduplicated participants
				participants: Array.from(uniqueParticipants.values()),
				// Ensure allowsVoting defaults to true
				allowsVoting: data.event.allowsVoting !== false,
			};
			
			// Initialize original track order mapping when playlist is first loaded
			if (event.playlist && Array.isArray(event.playlist)) {
				event.playlist.forEach((track, index) => {
					originalTrackOrder.set(track.id, index);
				});
			}
			
			initializeEditForm();
			
			// Always try to load voting results if we have an eventId and user
			if (eventId && user) {
				try {
					const rawVotingResults = await getVotingResults(eventId);
					hasLoadedVotingData = true; // Mark as loaded to prevent reactive effect from triggering
					
					// Process raw voting results to calculate vote counts per track
					const { processedResults, userVotesMap } = processRawVotingResults(rawVotingResults);
					votingResults = processedResults;
					
					// Initialize local user votes from processed results
					localUserVotes = userVotesMap;
					
					// Update playlist tracks with vote counts from voting results
					if (event.playlist && Array.isArray(event.playlist)) {
						event.playlist = event.playlist.map((track) => {
							const result = votingResults.find((r) => r.track?.id === track.id);
							const newVoteCount = result ? result.voteCount : 0;
							return {
								...track,
								voteCount: newVoteCount,
								votes: newVoteCount,
							};
						});
						
						// Don't sort here - let sortedPlaylistTracks() handle display order
						// Force reactivity update
						event = { ...event };
					}
				} catch (err) {
					
				}
			}
		} else {
			await loadEvent();
		}

		// NOTE: User playlists will be loaded on-demand when the playlist modal is opened

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

		// Initialize location-based voting if needed
		if (event && event.licenseType === 'location_based' && user) {
			await checkLocationPermission();
			startLocationWatching();
		}

		// Add page unload event listeners to automatically leave event
		window.addEventListener('beforeunload', handlePageUnload);
		document.addEventListener('visibilitychange', () => {
			if (document.visibilityState === 'hidden') {
				handlePageUnload();
			}
		});
	});

	onDestroy(() => {
		// Remove page unload event listeners
		window.removeEventListener('beforeunload', handlePageUnload);
		document.removeEventListener('visibilitychange', handlePageUnload);

		// Cleanup refreshVotingResults timeout
		if (refreshVotingResultsTimeout) {
			clearTimeout(refreshVotingResultsTimeout);
			refreshVotingResultsTimeout = null;
		}

		// Attempt to leave event (will be handled by page unload if user is navigating away)
		if (user && eventId && event) {
			const isParticipant = event.participants?.some(p => p.id === user.id);
			if (isParticipant) {
				// Try to leave gracefully, but don't wait for it
				leaveEventAPI(eventId).catch(error => {
					
				});
			}
		}

		// Cleanup WebSocket connection
		if (eventId && isSocketConnected) {
			cleanupSocketConnection(eventId);
		}

		// Cleanup music player
		if (isMusicPlayerInitialized) {
			musicPlayerStore.setInEvent(false);
			musicPlayerStore.setCanControl(false);
			musicPlayerService.leaveRoom();
			isMusicPlayerInitialized = false;
		}

		// Cleanup location watching
		stopLocationWatching();
	});

	// Display playlist tracks sorted by vote count with currently playing track protection
	function sortedPlaylistTracks() {
		if (!event?.playlist || !Array.isArray(event.playlist)) return [];

		// Separate tracks into different categories
		const { currentTrack, votableTracks } = categorizeEventTracks();

		// Sort votable tracks by vote count (highest first), then by creation time for consistent tiebreaker
		const sortedVotableTracks = votableTracks.sort((a, b) => {
			const aVotes = a.voteCount || a.votes || 0;
			const bVotes = b.voteCount || b.votes || 0;
			
			// Primary sort: by vote count (descending)
			if (bVotes !== aVotes) {
				return bVotes - aVotes;
			}
			
			// Secondary sort: by creation time (ascending) - earlier tracks appear first when vote counts are equal
			// Fall back to original insertion order if no creation time available
			const aCreatedAt = new Date(a.createdAt || 0).getTime();
			const bCreatedAt = new Date(b.createdAt || 0).getTime();
			
			if (aCreatedAt && bCreatedAt && aCreatedAt !== bCreatedAt) {
				return aCreatedAt - bCreatedAt;
			}
			
			// Final fallback: use original insertion order
			const aOriginalIndex = originalTrackOrder.get(a.id) ?? 999999;
			const bOriginalIndex = originalTrackOrder.get(b.id) ?? 999999;
			return aOriginalIndex - bOriginalIndex;
		});

		const orderedTracks = [];
		
		if (currentTrack) {
			orderedTracks.push(currentTrack);
		}
		
		orderedTracks.push(...sortedVotableTracks);

		return orderedTracks;
	}

	// Helper function to categorize tracks based on their status
	function categorizeEventTracks() {
		if (!event?.playlist || !Array.isArray(event.playlist)) {
			return { currentTrack: null as Track | null, votableTracks: [] as Track[] };
		}

		let currentTrack: Track | null = null;
		const votableTracks: Track[] = [];

		// Find current playing track from music player store
		const playerState = $musicPlayerStore;
		const currentTrackId = playerState.currentTrack?.id;

		event.playlist.forEach((track) => {
			if (track.id === currentTrackId) {
				currentTrack = track;
			} else {
				votableTracks.push(track);
			}
		});

		return { currentTrack, votableTracks };
	}

	// Helper function to check if a track can be voted on
	function canVoteOnTrack(trackId: string): boolean {
		const { currentTrack } = categorizeEventTracks();
		
		// Can't vote on currently playing track
		if (currentTrack && currentTrack.id === trackId) {
			return false;
		}

		return canVoteForTracks();
	}

	// Helper function to get track status for UI styling
	function getTrackStatus(track: any, index: number): 'current' | 'votable' {
		const { currentTrack } = categorizeEventTracks();
		if (currentTrack && currentTrack.id === track.id) {
			return 'current';
		}
		
		return 'votable';
	}

	// Helper function to get track container classes based on status
	function getTrackContainerClass(track: any, index: number): string {
		const status = getTrackStatus(track, index);
		
		switch (status) {
			case 'current':
				return 'border-secondary bg-secondary/5 ring-2 ring-secondary/20';
			case 'votable':
			default:
				return 'border-gray-200 hover:bg-gray-50';
		}
	}

	// Helper function to get vote count badge classes
	function getVoteCountBadgeClass(track: any, index: number): string {
		const status = getTrackStatus(track, index);
		
		switch (status) {
			case 'current':
				return 'bg-secondary text-white';
			case 'votable':
			default:
				return 'bg-gray-200 text-gray-600';
		}
	}


	// Helper function to process raw voting results from backend
	function processRawVotingResults(rawVotes: any[]) {
		
		if (!rawVotes || !Array.isArray(rawVotes)) {
			return { processedResults: [], userVotesMap: new Map() };
		}

		// Group votes by track ID
		const trackVotesMap = new Map<string, { track: any, votes: any[], upvotes: number, downvotes: number }>();
		const userVotesMap = new Map<string, 'upvote' | 'downvote' | null>();
		
		rawVotes.forEach(vote => {
			if (!vote.trackId || !vote.track) return;
			
			// Track user's votes for this track
			if (vote.userId === user?.id) {
				userVotesMap.set(vote.trackId, vote.type);
			}
			
			// Group votes by track
			if (!trackVotesMap.has(vote.trackId)) {
				trackVotesMap.set(vote.trackId, {
					track: vote.track,
					votes: [],
					upvotes: 0,
					downvotes: 0
				});
			}
			
			const trackData = trackVotesMap.get(vote.trackId)!;
			trackData.votes.push(vote);
			
			if (vote.type === 'upvote') {
				trackData.upvotes++;
			} else if (vote.type === 'downvote') {
				trackData.downvotes++;
			}
		});
		
		// Convert to VoteResult format
		const processedResults: VoteResult[] = [];
		trackVotesMap.forEach((trackData, trackId) => {
			const userVote = rawVotes.find(vote => vote.trackId === trackId && vote.userId === user?.id);
			
			processedResults.push({
				track: trackData.track,
				voteCount: trackData.upvotes - trackData.downvotes, // Net vote count
				userVote: userVote as Vote | undefined, // Cast to proper type
				position: 0 // Will be set later when sorting
			});
		});
		
		// Sort by vote count and assign positions with consistent secondary sorting
		processedResults.sort((a, b) => {
			// Primary sort: by vote count (descending)
			if (b.voteCount !== a.voteCount) {
				return b.voteCount - a.voteCount;
			}
			// Secondary sort: by creation time (ascending) - earlier tracks appear first when vote counts are equal
			const aCreatedAt = new Date(a.track?.createdAt || 0).getTime();
			const bCreatedAt = new Date(b.track?.createdAt || 0).getTime();
			
			if (aCreatedAt && bCreatedAt && aCreatedAt !== bCreatedAt) {
				return aCreatedAt - bCreatedAt;
			}
			
			// Final fallback: by original insertion order (ascending) - first added tracks appear first when vote counts are equal
			const aOriginalIndex = originalTrackOrder.get(a.track?.id || '') ?? 999999;
			const bOriginalIndex = originalTrackOrder.get(b.track?.id || '') ?? 999999;
			return aOriginalIndex - bOriginalIndex;
		});
		processedResults.forEach((result, index) => {
			result.position = index + 1;
		});
		
		return { processedResults, userVotesMap };
	}

	// Helper function to update local vote counts and reorder tracks
	function updateLocalVoteCount(trackId: string, voteType: 'upvote' | 'downvote' | null, previousVoteType: 'upvote' | 'downvote' | null = null) {
		if (!event?.playlist || !Array.isArray(event.playlist)) return;

		// Update the specific track's vote count
		event.playlist = event.playlist.map((track) => {
			if (track.id === trackId) {
				let currentVoteCount = track.voteCount || 0;

				// Remove previous vote if exists
				if (previousVoteType === 'upvote') {
					currentVoteCount--;
				} else if (previousVoteType === 'downvote') {
					currentVoteCount++;
				}

				// Add new vote
				if (voteType === 'upvote') {
					currentVoteCount++;
				} else if (voteType === 'downvote') {
					currentVoteCount--;
				}

				return {
					...track,
					voteCount: currentVoteCount,
					votes: currentVoteCount,
				};
			}
			return track;
		});

		// Force reactivity update
		event = { ...event };

		// Update music player playlist with vote-based ordering for live events
		if (eventStatus() === "live" && isMusicPlayerInitialized) {
			updateMusicPlayerPlaylistOrder();
		}

		// Update votingResults as well for consistency
		if (votingResults && Array.isArray(votingResults)) {
			votingResults = votingResults.map((result) => {
				if (result.track?.id === trackId) {
					let currentVoteCount = result.voteCount;

					// Remove previous vote if exists
					if (previousVoteType === 'upvote') {
						currentVoteCount--;
					} else if (previousVoteType === 'downvote') {
						currentVoteCount++;
					}

					// Add new vote
					if (voteType === 'upvote') {
						currentVoteCount++;
					} else if (voteType === 'downvote') {
						currentVoteCount--;
					}

					return {
						...result,
						voteCount: currentVoteCount,
						userVote: voteType ? { 
							id: `temp-${trackId}-${user?.id}`,
							eventId: eventId || '',
							userId: user?.id || '',
							trackId: trackId,
							type: voteType,
							weight: 1,
							createdAt: new Date().toISOString()
						} as Vote : undefined,
					};
				}
				return result;
			});

			// Re-sort votingResults by vote count with consistent secondary sorting
			votingResults.sort((a, b) => {
				// Primary sort: by vote count (descending)
				if (b.voteCount !== a.voteCount) {
					return b.voteCount - a.voteCount;
				}
				// Secondary sort: by creation time (ascending) - first added tracks appear first when vote counts are equal
				const aCreatedAt = new Date(a.track?.createdAt || 0).getTime();
				const bCreatedAt = new Date(b.track?.createdAt || 0).getTime();
				return aCreatedAt - bCreatedAt;
			});
			
			// Update positions
			votingResults.forEach((result, index) => {
				result.position = index + 1;
			});
		}
	}

	// Helper function to update track vote count from socket events (votes from other users)
	function updateTrackVoteCountFromSocket(trackId: string, voteType: 'upvote' | 'downvote' | null, weight: number) {
		if (!event?.playlist || !Array.isArray(event.playlist)) return;

		// Update the specific track's vote count
		event.playlist = event.playlist.map((track) => {
			if (track.id === trackId) {
				let currentVoteCount = track.voteCount || 0;

				// Apply vote change based on type and weight
				if (voteType === 'upvote') {
					currentVoteCount += weight;
				} else if (voteType === 'downvote') {
					currentVoteCount -= weight;
				} else {
					// For vote removal (voteType is null), weight is negative
					currentVoteCount += weight;
				}

				return {
					...track,
					voteCount: currentVoteCount,
					votes: currentVoteCount,
				};
			}
			return track;
		});

		// Force reactivity update
		event = { ...event };

		// Update votingResults as well for consistency
		if (votingResults && Array.isArray(votingResults)) {
			votingResults = votingResults.map((result) => {
				if (result.track?.id === trackId) {
					let currentVoteCount = result.voteCount;

					// Apply vote change based on type and weight
					if (voteType === 'upvote') {
						currentVoteCount += weight;
					} else if (voteType === 'downvote') {
						currentVoteCount -= weight;
					} else {
						// For vote removal (voteType is null), weight is negative
						currentVoteCount += weight;
					}

					return {
						...result,
						voteCount: currentVoteCount,
					};
				}
				return result;
			});

			// Re-sort votingResults by vote count with consistent secondary sorting
			votingResults.sort((a, b) => {
				// Primary sort: by vote count (descending)
				if (b.voteCount !== a.voteCount) {
					return b.voteCount - a.voteCount;
				}
				// Secondary sort: by creation time (ascending) - earlier tracks appear first when vote counts are equal
				const aCreatedAt = new Date(a.track?.createdAt || 0).getTime();
				const bCreatedAt = new Date(b.track?.createdAt || 0).getTime();
				
				if (aCreatedAt && bCreatedAt && aCreatedAt !== bCreatedAt) {
					return aCreatedAt - bCreatedAt;
				}
				
				// Final fallback: by original insertion order (ascending) - first added tracks appear first when vote counts are equal
				const aOriginalIndex = originalTrackOrder.get(a.track?.id || '') ?? 999999;
				const bOriginalIndex = originalTrackOrder.get(b.track?.id || '') ?? 999999;
				return aOriginalIndex - bOriginalIndex;
			});
			
			// Update positions
			votingResults.forEach((result, index) => {
				result.position = index + 1;
			});
		}
	}

	// Helper function to reorder tracks based on current vote counts
	function reorderTracksBasedOnVotes() {
		if (!event?.playlist || !Array.isArray(event.playlist)) return;

		// Sort playlist tracks by vote count (highest first), then by creation time for consistent ordering
		event.playlist.sort((a, b) => {
			const aVotes = a.voteCount || 0;
			const bVotes = b.voteCount || 0;
			
			// Primary sort: by vote count (descending)
			if (bVotes !== aVotes) {
				return bVotes - aVotes;
			}
			
			// Secondary sort: by creation time (ascending) - earlier tracks appear first when vote counts are equal
			const aCreatedAt = new Date(a.createdAt || 0).getTime();
			const bCreatedAt = new Date(b.createdAt || 0).getTime();
			
			if (aCreatedAt && bCreatedAt && aCreatedAt !== bCreatedAt) {
				return aCreatedAt - bCreatedAt;
			}
			
			// Final fallback: by original insertion order (ascending) - first added tracks appear first when vote counts are equal
			const aOriginalIndex = originalTrackOrder.get(a.id) ?? 999999;
			const bOriginalIndex = originalTrackOrder.get(b.id) ?? 999999;
			return aOriginalIndex - bOriginalIndex;
		});
		// Force reactivity update
		event = { ...event };
	}


	// Check if user is a playlist collaborator
	async function checkPlaylistCollaboratorStatus() {
		if (!user || !event?.playlistId) {
			isPlaylistCollaborator = false;
			return;
		}

		try {
			const playlist = await playlistsService.getPlaylist(event.playlistId);
			isPlaylistCollaborator = playlist.collaborators?.some(collaborator => collaborator.id === user.id) || false;
		} catch (error) {
			
			isPlaylistCollaborator = false;
		}
	}

	// Check if user has access to this event
	async function checkEventAccess() {
		if (!user || !event) {
			hasEventAccess = event?.visibility === 'public';
			return;
		}

		// Public events are always accessible
		if (event.visibility === 'public') {
			hasEventAccess = true;
			return;
		}

		// Event creator and admins always have access
		if (event.creatorId === user.id || event.admins?.some(admin => admin.id === user.id)) {
			hasEventAccess = true;
			return;
		}

		// For private/invited events, check if user is a playlist collaborator
		if ((event.visibility === 'private' || event.licenseType === 'invited') && event.playlistId) {
			try {
				const playlist = await playlistsService.getPlaylist(event.playlistId);
				hasEventAccess = playlist.collaborators?.some(collaborator => collaborator.id === user.id) || false;
			} catch (error) {
				
				hasEventAccess = false;
			}
		} else {
			hasEventAccess = false;
		}
	}

	// Debounce variable to prevent multiple rapid calls to refreshVotingResults
	let refreshVotingResultsTimeout: NodeJS.Timeout | null = null;

	// Function to refresh voting results and update UI (used when participant leaves and votes are removed)
	async function refreshVotingResults() {
		if (!user || !eventId) return;
		
		// Debounce the function to prevent multiple rapid calls from duplicate socket events
		if (refreshVotingResultsTimeout) {
			clearTimeout(refreshVotingResultsTimeout);
		}
		
		refreshVotingResultsTimeout = setTimeout(async () => {
			try {
				
				const rawVotingResults = await getVotingResults(eventId);
				
				// Process raw voting results to calculate vote counts per track
				const { processedResults, userVotesMap } = processRawVotingResults(rawVotingResults);
				votingResults = processedResults;
				
				// Update local user votes from processed results
				localUserVotes = userVotesMap;
				
				// Update playlist tracks with vote counts from voting results
				if (event?.playlist && Array.isArray(event.playlist)) {
					event.playlist = event.playlist.map((track) => {
						const result = votingResults.find((r) => r.track?.id === track.id);
						const newVoteCount = result ? result.voteCount : 0;
						return {
							...track,
							voteCount: newVoteCount,
							votes: newVoteCount,
						};
					});
					
					// Reorder tracks based on updated vote counts after participant left
					reorderTracksBasedOnVotes();
					
					// Force reactivity update
					event = { ...event };
					
					// Update music player playlist with vote-based ordering for live events
					if (eventStatus() === "live" && isMusicPlayerInitialized) {
						updateMusicPlayerPlaylistOrder();
					}
				}
				
				
			} catch (err) {
				
			} finally {
				refreshVotingResultsTimeout = null;
			}
		}, 100); // 100ms debounce delay
	}

	async function loadVotingDataForUser() {
		if (!user || !eventId || hasLoadedVotingData) return;
		
		try {
			const rawVotingResults = await getVotingResults(eventId);
			hasLoadedVotingData = true; // Mark as loaded to prevent re-triggering
			
			// Process raw voting results to calculate vote counts per track
			const { processedResults, userVotesMap } = processRawVotingResults(rawVotingResults);
			votingResults = processedResults;
			
			// Initialize local user votes from processed results
			localUserVotes = userVotesMap;
			
			// Update playlist tracks with vote counts from voting results
			if (event?.playlist && Array.isArray(event.playlist)) {
				event.playlist = event.playlist.map((track) => {
					const result = votingResults.find((r) => r.track?.id === track.id);
					const newVoteCount = result ? result.voteCount : 0;
					return {
						...track,
						voteCount: newVoteCount,
						votes: newVoteCount,
					};
				});
				
				// Force reactivity update
				event = { ...event };
			}
		} catch (err) {
			
		}
	}


	async function setupSocketConnection(eventId: string) {
		try {
			// First, join the event via HTTP API to ensure user is a participant in the database
			if (user && event) {
				try {
					// Only join if user is not already a participant
					const isParticipant = event.participants?.some(p => p.id === user.id);
					if (!isParticipant) {
						await joinEvent(eventId);
					}
				} catch (error) {
					// If joining fails, still try to connect to socket for read-only access
					
				}
			}

			if (!eventSocketService.isConnected()) {
				await eventSocketService.connect();
			}

			// Set up event-specific collaboration listeners
			setupEventSocketListeners();

			isSocketConnected = true;
		} catch (err) {
			
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
		// Fix: Backend sends 'vote-updated' not 'vote-added'
		eventSocketService.on("vote-updated", handleVoteUpdated);
		eventSocketService.on("vote-removed", handleVoteRemoved);
		eventSocketService.on("vote-optimistic-update", handleVoteOptimisticUpdate);
		eventSocketService.on("user-joined", handleParticipantAdded);
		eventSocketService.on("user-left", handleParticipantRemoved);
		eventSocketService.on("joined-event", handleJoinedEvent);
		eventSocketService.on("left-event", handleLeavedEvent);
		eventSocketService.on("admin-added", handleAdminAdded);
		eventSocketService.on("admin-removed", handleAdminRemoved);
		eventSocketService.on("music-track-changed", handleMusicTrackChanged);
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
			// Fix: Clean up vote-updated listener
			eventSocketService.off("vote-updated", handleVoteUpdated);
			eventSocketService.off("vote-removed", handleVoteRemoved);
			eventSocketService.off("vote-optimistic-update", handleVoteOptimisticUpdate);
			eventSocketService.off("user-joined", handleParticipantAdded);
			eventSocketService.off("user-left", handleParticipantRemoved);
			eventSocketService.off("joined-event", handleJoinedEvent);
			eventSocketService.off("left-event", handleLeavedEvent);
			eventSocketService.off("admin-added", handleAdminAdded);
			eventSocketService.off("admin-removed", handleAdminRemoved);
			eventSocketService.off("music-track-changed", handleMusicTrackChanged);
			eventSocketService.off(
				"current-participants",
				handleCurrentParticipants,
			);

			isSocketConnected = false;
		} catch (err) {
			
		}
	}

	function handleAdminAdded(data: { eventId: string; userId: string }) {
		if (event && data.eventId === event.id) {
			// Initialize admins array if it doesn't exist
			if (!event.admins) {
				event.admins = [];
			}
			
			// Check if user is already an admin
			if (!event.admins.some((admin) => admin.id === data.userId)) {
				// Find the user in participants to get their complete data
				const participant = event.participants?.find((p) => p.id === data.userId);
				
				if (participant) {
					event.admins.push({
						id: data.userId,
						userId: data.userId,
						displayName: participant.displayName || participant.username || "Unknown User",
						email: participant.email || "",
						avatarUrl: participant.avatarUrl,
						createdAt: participant.createdAt || new Date().toISOString(),
						updatedAt: participant.updatedAt || new Date().toISOString(),
					});
				} else {
					// Fallback if participant not found (shouldn't happen normally)
					event.admins.push({
						id: data.userId,
						userId: data.userId,
						displayName: "New Admin",
						createdAt: new Date().toISOString(),
						updatedAt: new Date().toISOString(),
						email: "",
					});
				}
				
				// Force reactivity update
				event = { ...event };
			}
		}
	}

	function handleAdminRemoved(data: { eventId: string; userId: string }) {
		if (event && data.eventId === event.id) {
			// Initialize admins array if it doesn't exist
			if (!event.admins) {
				event.admins = [];
				return;
			}
			
			const initialCount = event.admins.length;
			event.admins = event.admins.filter(
				(admin) => admin.id !== data.userId,
			);
			
			// Force reactivity update if there was actually a change
			if (event.admins.length !== initialCount) {
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
			
			// Check if this is the first track being added to an empty playlist
			const wasPlaylistEmpty = event.playlist.length === 0;
			
			// Ensure the track has proper vote count properties initialized
			const trackWithVotes = {
				...data.track,
				voteCount: data.track.voteCount || data.track.votes || 0,
				votes: data.track.voteCount || data.track.votes || 0,
			};
			
		event.playlist.push(trackWithVotes);
		
		// Add new track to original order tracking only if it doesn't already exist
		// This prevents re-added tracks from getting a new position and messing up the sort order
		if (!originalTrackOrder.has(data.track.id)) {
			const nextIndex = originalTrackOrder.size;
			originalTrackOrder.set(data.track.id, nextIndex);
		}			// Clear any persisting visual states for this track when it's re-added
			if (data.track.id) {
				voteAnimations.delete(data.track.id);
				voteAnimations = new Map(voteAnimations);
				
				// Reset local vote state for this track
				localUserVotes.delete(data.track.id);
				localUserVotes = new Map(localUserVotes);
			}
			
			// Always update the music player playlist when tracks are added, regardless of event status
			if (isMusicPlayerInitialized) {
				// Convert all event tracks to the format expected by music player
				const playlistTracks = event.playlist.map((track: any, index: number) => ({
					id: track.id || '',
					trackId: track.id || '',
					position: index + 1,
					addedAt: track.createdAt || new Date().toISOString(),
					createdAt: track.createdAt || new Date().toISOString(),
					playlistId: event?.playlistId || '',
					addedById: track.addedBy || event?.creatorId || "",
					track: {
						id: track.id || '',
						deezerId: track.deezerId || '',
						title: track.title || '',
						artist: track.artist || '',
						album: track.album || '',
						albumCoverUrl: track.thumbnailUrl || "",
						albumCoverSmallUrl: track.thumbnailUrl || "",
						albumCoverMediumUrl: track.thumbnailUrl || "",
						albumCoverBigUrl: track.thumbnailUrl || "",
						previewUrl: track.previewUrl || "",
						deezerUrl: "",
						available: true,
						duration: track.duration || 30,
						createdAt: track.createdAt || new Date().toISOString(),
						updatedAt: track.updatedAt || new Date().toISOString(),
					},
					addedBy: {
						id: track.addedBy || event?.creatorId || "",
						displayName: "Event Admin"
					},
				}));
				
				// Update the music player store with the current playlist
				// For live events, use vote-based ordering; otherwise use regular order
				if (eventStatus() === "live") {
					updateMusicPlayerPlaylistOrder();
				} else {
					// For non-live events, just update with current track order
					musicPlayerStore.setPlaylist(playlistTracks, playerState.currentTrackIndex);
				}
				
				// Auto-start playback in several scenarios:
				// 1. Playlist was empty before this track was added
				// 2. Player has no current track but has tracks available (recovery scenario)
				// 3. Player is not currently playing
				if ((wasPlaylistEmpty || !playerState.currentTrack) && 
					!playerState.isPlaying &&
					playlistTracks.length > 0) {
					
					// Start playing the first available track
					setTimeout(async () => {
						try {
							// Use the first track with a valid preview URL
							let trackToPlay = playlistTracks[0];
							let trackIndex = 0;
							
							// Try to find a track with a preview URL
							for (let i = 0; i < playlistTracks.length; i++) {
								if (playlistTracks[i].track.previewUrl) {
									trackToPlay = playlistTracks[i];
									trackIndex = i;
									break;
								}
							}
							
							// Set and start playing the track
							musicPlayerStore.setCurrentTrack({
								id: trackToPlay.track.id,
								title: trackToPlay.track.title,
								artist: trackToPlay.track.artist,
								album: trackToPlay.track.album,
								duration: trackToPlay.track.duration,
								albumCoverUrl: trackToPlay.track.albumCoverUrl,
								previewUrl: trackToPlay.track.previewUrl
							}, playlistTracks, trackIndex);
							
							// Start playback if the track has a preview URL
							if (trackToPlay.track.previewUrl) {
								musicPlayerStore.play();
							}
							
						} catch (error) {
							
						}
					}, 100); // Small delay to ensure DOM updates
				}
			}
		}
	}

	function handleTrackRemoved(data: { trackId: string }) {
		if (event && event.playlist && Array.isArray(event.playlist)) {
			// Check if the removed track was the currently playing track
			const wasCurrentTrack = playerState.currentTrack?.id === data.trackId;
			
			event.playlist = event.playlist.filter(
				(t) => t.id !== data.trackId,
			);
			
			// Remove from original track order mapping
			originalTrackOrder.delete(data.trackId);
			
			// Remove the user's vote for this track if they had voted for it
			// This ensures the vote counter updates correctly when tracks are removed
			if (localUserVotes.has(data.trackId)) {
				localUserVotes.delete(data.trackId);
				localUserVotes = new Map(localUserVotes);
			}
			
			// Always update the music player playlist when in a live event
			if (eventStatus() === "live" && isMusicPlayerInitialized) {
				if (event.playlist.length === 0) {
					// No more tracks, stop playback and clear playlist
					musicPlayerStore.pause();
					musicPlayerStore.setPlaylist([], -1);
				} else {
					// Update the music player playlist with remaining tracks
					const playlistTracks = event.playlist.map((track: any, index: number) => ({
						id: track.id || '',
						trackId: track.id || '',
						position: index + 1,
						addedAt: track.createdAt || new Date().toISOString(),
						createdAt: track.createdAt || new Date().toISOString(),
						playlistId: event?.playlistId || '',
						addedById: track.addedBy || event?.creatorId || "",
						track: {
							id: track.id || '',
							deezerId: track.deezerId || '',
							title: track.title || '',
							artist: track.artist || '',
							album: track.album || '',
							albumCoverUrl: track.thumbnailUrl || track.albumCoverUrl || "",
							albumCoverSmallUrl: track.thumbnailUrl || track.albumCoverUrl || "",
							albumCoverMediumUrl: track.thumbnailUrl || track.albumCoverUrl || "",
							albumCoverBigUrl: track.thumbnailUrl || track.albumCoverUrl || "",
							previewUrl: track.previewUrl || "",
							deezerUrl: "",
							available: true,
							duration: track.duration || 30,
							createdAt: track.createdAt || new Date().toISOString(),
							updatedAt: track.updatedAt || new Date().toISOString(),
						},
						addedBy: {
							id: track.addedBy || event?.creatorId || "",
							displayName: "Event Admin"
						},
					}));
					
					// Update the playlist with vote-based ordering
					updateMusicPlayerPlaylistOrder();
					
					// If the current track was removed and we were playing, start the next track
					if (wasCurrentTrack && playerState.isPlaying && playlistTracks.length > 0) {
						setTimeout(() => {
							try {
								// Start playing the first available track
								musicPlayerStore.setCurrentTrack({
									id: playlistTracks[0].track.id,
									title: playlistTracks[0].track.title,
									artist: playlistTracks[0].track.artist,
									album: playlistTracks[0].track.album,
									duration: playlistTracks[0].track.duration,
									albumCoverUrl: playlistTracks[0].track.albumCoverUrl,
									previewUrl: playlistTracks[0].track.previewUrl
								}, playlistTracks, 0);
								
								// Continue playback
								musicPlayerStore.play();
							} catch (error) {
								
							}
						}, 100);
					}
				}
			}
		}
	}

	function handleCurrentTrackChanged(data: {
		track: Track | null;
		startedAt: string | null;
	}) {

	}

	function handleMusicTrackChanged(data: {
		eventId: string;
		trackId: string;
		trackIndex?: number;
		controlledBy: string;
		timestamp: string;
		playlistOrder?: string[]; // Add playlist order from server for synchronization
	}) {
		if (event && data.eventId === event.id && isMusicPlayerInitialized) {
			
			
			// If server provides playlist order, use it to ensure all clients have same order
			if (data.playlistOrder && event.playlist && Array.isArray(event.playlist)) {
				const trackMap = new Map(event.playlist.map((t) => [t.id, t]));
				const reorderedPlaylist = data.playlistOrder
					.map((id) => trackMap.get(id))
					.filter((t): t is Track => t !== undefined);
				
				// Add any tracks that weren't in the server order (shouldn't happen but safety)
				const reorderedIds = new Set(data.playlistOrder);
				const remainingTracks = event.playlist.filter(t => !reorderedIds.has(t.id));
				
				// Update event playlist with server-synchronized order
				event.playlist = [...reorderedPlaylist, ...remainingTracks];
				event = { ...event };
			}
			
			// Find the track in our (now synchronized) playlist and update the music player
			const playlist = event.playlist || [];
			const trackIndex = data.trackIndex !== undefined ? data.trackIndex : 
				playlist.findIndex(t => t.id === data.trackId);
			
			if (trackIndex >= 0 && trackIndex < playlist.length) {
				const track = playlist[trackIndex];
				
				// Update the music player to the new track using current playlist order
				const musicPlayerPlaylist = playlist.map((t: any, i: number) => ({
					id: t.id,
					position: i,
					addedAt: new Date().toISOString(),
					createdAt: new Date().toISOString(),
					playlistId: event?.id || "",
					trackId: t.id,
					addedById: t.addedBy || event?.creatorId || "",
					track: {
						id: t.id,
						deezerId: t.deezerId || "",
						title: t.title,
						artist: t.artist,
						album: t.album || "",
						duration: t.duration || 30,
						previewUrl: t.previewUrl || "",
						albumCoverUrl: t.thumbnailUrl || "",
						albumCoverSmallUrl: t.thumbnailUrl || "",
						albumCoverMediumUrl: t.thumbnailUrl || "",
						albumCoverBigUrl: t.thumbnailUrl || "",
						deezerUrl: "",
						genres: "",
						releaseDate: "",
						available: true,
						createdAt: t.createdAt || new Date().toISOString(),
						updatedAt: t.updatedAt || new Date().toISOString()
					},
					addedBy: {
						id: t.addedBy || event?.creatorId || "",
						displayName: "User",
						email: "",
						createdAt: new Date().toISOString(),
						updatedAt: new Date().toISOString()
					}
				}));
				
				musicPlayerStore.setCurrentTrack({
					id: track.id,
					title: track.title,
					artist: track.artist,
					album: track.album || "",
					duration: track.duration || 30,
					albumCoverUrl: track.thumbnailUrl || "",
					previewUrl: track.previewUrl || ""
				}, musicPlayerPlaylist, trackIndex);
				
				// Auto-play the new track if it has a valid preview URL
				if (track.previewUrl) {
					musicPlayerStore.play();
				}
			}
		}
	}

	function handleVoteUpdated(data: {
		eventId: string;
		vote: {
			trackId: string;
			userId: string;
			type: 'upvote' | 'downvote';
			weight: number;
		};
	}) {
		if (event && data.eventId === event.id) {
			// Don't process our own votes - they're already handled locally for instant feedback
			if (data.vote.userId === user?.id) {
				return;
			}

			// Update vote count for the specific track
			updateTrackVoteCountFromSocket(data.vote.trackId, data.vote.type, data.vote.weight);
			
			// Reorder tracks based on updated vote counts
			reorderTracksBasedOnVotes();

			// Update music player playlist with vote-based ordering for live events
			if (eventStatus() === "live" && isMusicPlayerInitialized) {
				updateMusicPlayerPlaylistOrder();
			}
		}
	}
	
	function handleVoteRemoved(data: {
		eventId: string;
		vote: {
			trackId: string;
			userId: string;
			type: 'upvote' | 'downvote';
			weight: number;
		};
	}) {
		if (event && data.eventId === event.id) {
			// Don't process our own vote removals - they're already handled locally for instant feedback
			if (data.vote.userId === user?.id) {
				return;
			}

			// Update vote count for the specific track (remove the vote)
			// When removing a vote, we need to reverse its effect
			const weightToRemove = data.vote.type === 'upvote' ? -data.vote.weight : data.vote.weight;
			updateTrackVoteCountFromSocket(data.vote.trackId, null, weightToRemove);
			
			// Reorder tracks based on updated vote counts
			reorderTracksBasedOnVotes();
			
			// Update music player playlist with vote-based ordering for live events
			if (eventStatus() === "live" && isMusicPlayerInitialized) {
				updateMusicPlayerPlaylistOrder();
			}
		}
	}

	function handleVoteOptimisticUpdate(data: {
		eventId: string;
		vote: {
			trackId: string;
			userId: string;
			type: 'upvote' | 'downvote';
		};
		timestamp: string;
	}) {
		if (event && data.eventId === event.id) {
			// Don't process our own votes - they're already handled locally for instant feedback
			if (data.vote.userId === user?.id) {
				return;
			}

			// Update vote count for the specific track with weight of 1 (standard vote)
			updateTrackVoteCountFromSocket(data.vote.trackId, data.vote.type, 1);
			
			// Reorder tracks based on updated vote counts
			reorderTracksBasedOnVotes();
			
			// Update music player playlist with vote-based ordering for live events
			if (eventStatus() === "live" && isMusicPlayerInitialized) {
				updateMusicPlayerPlaylistOrder();
			}
		}
	}
	
	function handleTracksReordered(data: { eventId: string; trackOrder: string[]; playlistOrder?: string[] }) {
		if (event && data.eventId === event.id && event.playlist && Array.isArray(event.playlist)) {
			
			
			// Use server-provided playlist order if available, otherwise use trackOrder
			const serverOrder = data.playlistOrder || data.trackOrder;
			
			// Store the currently playing track info
			const currentlyPlayingTrack = event.playlist.length > 0 ? event.playlist[0] : null;
			
			// Reorder the playlist based on the server's authoritative order
			const trackMap = new Map(event.playlist.map((t) => [t.id, t]));
			const reorderedPlaylist = serverOrder
				.map((id) => trackMap.get(id))
				.filter((t): t is Track => t !== undefined);
			
			// Add any tracks that weren't in the reorder list (shouldn't happen but safety)
			const reorderedIds = new Set(serverOrder);
			const remainingTracks = event.playlist.filter(t => !reorderedIds.has(t.id));
			
			// If there was a currently playing track, ensure it stays at the top
			if (currentlyPlayingTrack) {
				const filteredReordered = reorderedPlaylist.filter(t => t.id !== currentlyPlayingTrack.id);
				const filteredRemaining = remainingTracks.filter(t => t.id !== currentlyPlayingTrack.id);
				event.playlist = [currentlyPlayingTrack, ...filteredReordered, ...filteredRemaining];
			} else {
				event.playlist = [...reorderedPlaylist, ...remainingTracks];
			}
			
			// Update original track order mapping with server order only for tracks that don't have an original order yet
			// This preserves the true insertion order for tracks that were added earlier
			serverOrder.forEach((trackId, index) => {
				if (!originalTrackOrder.has(trackId)) {
					originalTrackOrder.set(trackId, index);
				}
			});
			
			// Note: Vote counts are preserved during reordering, no need to refresh
			// WebSocket events handle any necessary vote count updates
			
			// Force reactivity update
			event = { ...event };
			
			// Update music player playlist order for live events
			if (eventStatus() === "live" && isMusicPlayerInitialized) {
				updateMusicPlayerPlaylistOrder();
			}
		}
	}
	
	function handleParticipantAdded(data: any) {
		if (event) {
			// Handle both 'user-joined' and 'participant-joined' event structures
			const userId = data.userId || data.user?.id;
			const displayName = data.displayName || data.user?.displayName || "Unknown User";
			const avatarUrl = data.avatarUrl || data.user?.avatarUrl;
			const email = data.email || "";

			// Only add participant if they don't already exist (prevent duplicates)
			if (userId && !event.participants.some((p) => p.id === userId || p.userId === userId)) {
				event.participants.push({
					id: userId, // Use id as primary property
					userId: userId, // Keep userId for compatibility
					displayName: displayName,
					avatarUrl: avatarUrl || undefined,
					email: email,
					createdAt: data.createdAt || new Date().toISOString(),
					updatedAt: data.updatedAt || new Date().toISOString(),
				});
				// Force reactivity update
				event = { ...event };
			} else if (userId) {
				// If participant already exists, update their information instead of adding duplicate
				const existingIndex = event.participants.findIndex((p) => p.id === userId || p.userId === userId);
				if (existingIndex !== -1) {
					event.participants[existingIndex] = {
						...event.participants[existingIndex],
						displayName: displayName,
						avatarUrl: avatarUrl || event.participants[existingIndex].avatarUrl,
						email: email || event.participants[existingIndex].email,
						updatedAt: data.updatedAt || new Date().toISOString(),
					};
					// Force reactivity update
					event = { ...event };
				}
			}
		}
	}

	function handleParticipantRemoved(data: any) {
		if (event) {
			// Handle both 'user-left' and 'participant-left' event structures
			const userId = data.userId || data.user?.id;
			
			if (userId) {
				const remainingParticipants = event.participants.filter(
					(p) => p.id !== userId && p.userId !== userId,
				);
				event.participants = remainingParticipants;
				
				if (user && eventId) {
					// Refresh voting results to get updated vote counts after user left
					refreshVotingResults();
				}
				
				// Force reactivity update
				event = { ...event };
			}
		}
	}

	function handleJoinedEvent(data: any) {
		if (event) {
		}
	}

	function handleLeavedEvent(data: any) {
		if (event) {
			// This is when we ourselves leave an event
			const userId = data.userId;
			
			event.participants = event.participants.filter(
				(p) => p.id !== userId,
			);
			
			// If the current user is leaving, clear all local vote state
			if (userId === user?.id) {
				localUserVotes.clear();
				localUserVotes = new Map(localUserVotes);
				voteAnimations.clear();
				voteAnimations = new Map(voteAnimations);
			}
			
			// Force reactivity update
			event = { ...event };
		}
	}

	async function handleEditEvent(event: SubmitEvent) {
		event.preventDefault();
		if (!user || !eventId || (!isCreator && !isAdmin)) return;

		try {
			await updateEvent(eventId, editEventData);
			showEditModal = false;
			// Socket events will handle updating the event data
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
		if (!user || !eventId || !isAdmin || !selectedUserId)
			return;

		try {
			await promoteUserToAdmin(eventId, selectedUserId);
			showPromoteModal = false;
			selectedUserId = "";
			// Note: Admin list will be updated via socket events (handleAdminAdded)
		} catch (err) {
			error =
				err instanceof Error
					? err.message
					: "Failed to promote user to admin";
		}
	}

	async function handleLeaveEvent() {
		if (!user || !eventId) return;

		try {
			await leaveEventAPI(eventId);
			goto("/events");
		} catch (err) {
			error = err instanceof Error ? err.message : "Failed to leave event";
			
		}
	}

	function handleCurrentParticipants(data: any) {
		if (event && data.eventId === event.id) {
			// Replace the entire participants list with the authoritative list from the server
			// This prevents duplicates by completely resetting the participants
			const uniqueParticipants = new Map();
			
			(data.participants || []).forEach((participant: any) => {
				const userId = participant.userId || participant.id;
				if (userId) {
					uniqueParticipants.set(userId, {
						id: userId,
						userId: userId,
						displayName: participant.displayName || "Unknown User",
						avatarUrl: participant.avatarUrl || undefined,
						email: participant.email || "",
						createdAt: participant.createdAt || new Date().toISOString(),
						updatedAt: participant.updatedAt || new Date().toISOString(),
					});
				}
			});
			
			event.participants = Array.from(uniqueParticipants.values());
			// Force reactivity update
			event = { ...event };
		}
	}

	async function addPlaylistToEvent(playlistId: string) {
		if (!user || !eventId) return;

		try {
			loading = true;
			
			// Use the optimized batch function to add all tracks at once
			await addPlaylistTracksToEvent(eventId, playlistId);

			closePlaylistModal();
			// Socket events will handle updating the track list
		} catch (err) {
			error =
				err instanceof Error
					? err.message
					: "Failed to add playlist to event";
		} finally {
			loading = false;
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
				locationRadius: event.locationRadius || undefined,
				votingStartTime: event.votingStartTime || undefined,
				votingEndTime: event.votingEndTime || undefined,
				maxVotesPerUser: event.maxVotesPerUser || 1
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

			// Deduplicate participants from the loaded event
			const uniqueParticipants = new Map();
			(loadedEvent.participants || []).forEach((participant: any) => {
				const userId = participant.id || participant.userId;
				if (userId) {
					uniqueParticipants.set(userId, participant);
				}
			});

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
				// Preserve admins from backend
				admins: loadedEvent.admins || [],
				// Use deduplicated participants from the fresh load
				participants: Array.from(uniqueParticipants.values()),
			};

			hasEventAccess = true;
			initializeEditForm();

			// Initialize original track order mapping for tracks loaded from server
			if (event.playlist && Array.isArray(event.playlist)) {
				event.playlist.forEach((track, index) => {
					originalTrackOrder.set(track.id, index);
				});
			}

			// Load voting results if user can vote
			if (user && event.allowsVoting) {
				try {
					const rawVotingResults = await getVotingResults(eventId);
					hasLoadedVotingData = true; // Mark as loaded to prevent reactive effect from triggering
					
					// Process raw voting results to calculate vote counts per track
					const { processedResults, userVotesMap } = processRawVotingResults(rawVotingResults);
					votingResults = processedResults;
					
					// Initialize local user votes from processed results
					localUserVotes = userVotesMap;
					
					// Update playlist tracks with vote counts from voting results
					if (event.playlist && Array.isArray(event.playlist)) {
						event.playlist = event.playlist.map((track) => {
							const result = votingResults.find((r) => r.track?.id === track.id);
							const newVoteCount = result ? result.voteCount : 0;
							return {
								...track,
								voteCount: newVoteCount,
								votes: newVoteCount,
							};
						});
						
						// Don't sort here - let sortedPlaylistTracks() handle display order
						// Force reactivity update
						event = { ...event };
					}
				} catch (err) {
					
				}
			}

			// Initialize music player for this event
			await initializeMusicPlayer();
		} catch (err) {
			// With the backend now supporting playlist collaborator access,
			// most access denied errors should be legitimate
			error = err instanceof Error ? err.message : "Failed to load event";
		} finally {
			loading = false;
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
			
		} finally {
			isLoadingTop = false;
		}
	}

	// Load playlists manually when needed (no reactive effects to prevent loops)
	async function openPlaylistModal() {
		showPlaylistModal = true;
		if (userPlaylists.length === 0 && !hasAttemptedPlaylistLoad) {
			await loadUserPlaylists();
		}
	}

	function closePlaylistModal() {
		showPlaylistModal = false;
		hasAttemptedPlaylistLoad = false; // Reset for next time
	}

	async function loadUserPlaylists() {
		if (!user) return;

		try {
			hasAttemptedPlaylistLoad = true;
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

	async function removeAdmin(userId: string) {
		if (!user || !eventId || !isCreator || !isAdmin) return;

		try {
			await removeUserFromAdmin(eventId, userId);
		} catch (err) {
			error =
				err instanceof Error ? err.message : "Failed to remove admin";
		}
	}

	function formatDuration(seconds: number) {
		const minutes = Math.floor(seconds / 60);
		const remainingSeconds = seconds % 60;
		return `${minutes}:${remainingSeconds.toString().padStart(2, "0")}`;
	}

	function getUserRole(userId: string): string {
		if (!event) return "Participant";
		if (event.creatorId === userId) return "Owner";
		if (event.admins?.some((admin) => admin.id === userId)) return "Admin";
		return "Participant";
	}

	// Function to request playlist synchronization from server when there might be conflicts
	async function requestPlaylistSynchronization() {
		if (!eventId || !isSocketConnected) return;
		
		try {
			
			eventSocketService.requestPlaylistSync(eventId);
		} catch (error) {
			
		}
	}

	// Helper function to update music player playlist order based on votes
	function updateMusicPlayerPlaylistOrder() {
		if (!event?.playlist || !Array.isArray(event.playlist) || !isMusicPlayerInitialized) {
			return;
		}

		const playerState = $musicPlayerStore;
		const currentTrackId = playerState.currentTrack?.id;

		// Get the sorted tracks using the same logic as the UI
		const sortedTracks = sortedPlaylistTracks();
		
		// Convert to the format expected by music player
		const playlistTracks = sortedTracks.map((track: any, index: number) => ({
			id: track.id || '',
			trackId: track.id || '',
			position: index + 1,
			addedAt: track.createdAt || new Date().toISOString(),
			createdAt: track.createdAt || new Date().toISOString(),
			playlistId: event?.playlistId || '',
			addedBy: track.addedBy || null,
			addedById: track.addedBy?.id || track.addedById || '',
			track: {
				id: track.id || '',
				title: track.title || '',
				artist: track.artist || '',
				album: track.album || '',
				duration: track.duration || 30,
				albumCoverUrl: track.albumCoverUrl || '',
				albumCoverSmallUrl: track.albumCoverSmallUrl || '',
				albumCoverMediumUrl: track.albumCoverMediumUrl || '',
				albumCoverBigUrl: track.albumCoverBigUrl || '',
				previewUrl: track.previewUrl || '',
				deezerId: track.deezerId || '',
				deezerUrl: track.deezerUrl || '',
				spotifyId: track.spotifyId || null,
				youtubeId: track.youtubeId || null,
				available: track.available !== undefined ? track.available : true,
				createdAt: track.createdAt || new Date().toISOString(),
				updatedAt: track.updatedAt || new Date().toISOString()
			}
		}));

		// Find the new index of the currently playing track
		let newCurrentIndex = 0;
		if (currentTrackId) {
			const foundIndex = playlistTracks.findIndex(t => t.track.id === currentTrackId);
			if (foundIndex !== -1) {
				newCurrentIndex = foundIndex;
			}
		}
		
		// Only update if track order has actually changed to avoid unnecessary updates
		const currentPlaylist = playerState.playlist;
		const hasOrderChanged = playlistTracks.length !== currentPlaylist.length ||
			playlistTracks.some((track, index) => 
				currentPlaylist[index]?.track.id !== track.track.id
			);
		
		if (hasOrderChanged) {
			// Update the music player playlist
			musicPlayerStore.setPlaylist(playlistTracks, newCurrentIndex);
		}
	}

	// Filter tracks based on search query - uses vote-sorted tracks
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

	// Music player initialization and control
	async function playTrack(trackIndex: number) {
		try {
			if (!isMusicPlayerInitialized) {
				
				await initializeMusicPlayer();

				if (!isMusicPlayerInitialized) {
					
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
				
				error = `Cannot play track: invalid track position (${trackIndex + 1})`;
				setTimeout(() => (error = ""), 3000);
				return;
			}

			await musicPlayerService.playTrack(trackIndex);
		} catch (err) {
			
			error = err instanceof Error ? err.message : "Failed to play track";
			setTimeout(() => (error = ""), 3000);
		}
	}

	async function removeTrack(trackId: string) {
		if (!user || !eventId) return;

		let originalPlaylist = null; // Declare outside try block for error handling

		try {
			const track = event?.playlist?.find((t) => t.id === trackId);
			if (!track) {
				error = "Track not found";
				return;
			}

			// Find track index for UI optimization
			const trackIndex = event?.playlist?.findIndex((t) => t.id === trackId) ?? -1;
			
			// Optimistically remove the track from the UI
			if (trackIndex !== -1 && event?.playlist) {
				originalPlaylist = [...event.playlist];
				event.playlist = event.playlist.filter((t) => t.id !== trackId);
				// Force reactivity update
				event = { ...event };
			}
			
			// Get playlist ID from the event object to avoid unnecessary API call
			const playlistId = event?.playlistId || (event?.playlist && typeof event.playlist === 'object' && 'id' in event.playlist ? (event.playlist as any).id : undefined);
			
			// Call the service to remove the track with the playlist ID
			await removeTrackFromEvent(eventId, trackId, playlistId);
			
			// Show success message temporarily
		} catch (err) {
			// Revert the optimistic update on error
			if (originalPlaylist && event) {
				event.playlist = originalPlaylist;
				event = { ...event };
			}
			
			
			error = err instanceof Error ? err.message : 'Failed to remove track from event';
			setTimeout(() => (error = ""), 3000);
		}
	}

	// Helper function to get current user vote for a track (uses local state first, then WebSocket data)
	function getUserVoteForTrack(trackId: string): 'upvote' | 'downvote' | null {
		// Check local state first (for immediate UI updates)
		if (localUserVotes.has(trackId)) {
			return localUserVotes.get(trackId) || null;
		}
		
		// Fall back to WebSocket data - ensure votingResults is properly initialized
		if (!votingResults || !Array.isArray(votingResults)) {
			return null;
		}
		
		const result = votingResults.find(r => r.track?.id === trackId);
		return result?.userVote?.type || null;
	}

	// Helper function to get button width class based on vote state
	function getButtonWidthClass(trackId: string, buttonType: 'upvote' | 'downvote' | 'remove'): string {
		const userVote = getUserVoteForTrack(trackId);
		const animation = voteAnimations.get(trackId);

		// if no votes left, hide vote and downvote buttons (but not for unlimited votes)
		const votesRemaining = numberOfVotesAvailable();
		if (votesRemaining <= 0 && votesRemaining !== Infinity && (buttonType === 'upvote' || buttonType === 'downvote') && !userVote) {
			return 'w-0 overflow-hidden';
		}

		// Use animation state if transitioning
		if (animation) {
			if (buttonType === 'remove') {
				return animation.remove;
			}
			return animation[buttonType as 'upvote' | 'downvote'];
		}
		
		// Default state based on user vote
		if (!userVote) {
			if (buttonType === 'remove') {
				return 'w-0 overflow-hidden'; // Remove button hidden when no vote
			}
			return 'w-full'; // Vote buttons full width when no vote
		}
		
		if (buttonType === 'remove') {
			return userVote === 'upvote' ? 'w-100 bg-gradient-to-l' : 'w-100 bg-gradient-to-r'; // Remove button is visible when user has voted
		}
		
		if (userVote === buttonType) {
			return 'w-full'; // Voted button stays full width
		} else {
			return 'w-0 overflow-hidden'; // Other vote button shrinks to 0
		}
	}

	// Voting functionality
	async function voteForTrackSimple(trackId: string, voteType: 'upvote' | 'downvote' = 'upvote') {
		if (!user || !eventId) {
			error = "You must be logged in to vote";
			setTimeout(() => (error = ""), 3000);
			return;
		}

		if (!canVoteOnTrack(trackId)) {
			error = "You can't vote on this track (it may be currently playing or already played)";
			setTimeout(() => (error = ""), 3000);
			return;
		}

		// Get previous vote type for this track (moved outside try block for error handling)
		const previousVoteType = localUserVotes.get(trackId) || null;

		try {
			// Update local user vote state immediately for instant UI feedback
			localUserVotes.set(trackId, voteType);
			localUserVotes = new Map(localUserVotes);
			
			// Update local vote counts and reorder tracks
			updateLocalVoteCount(trackId, voteType, previousVoteType);
			
			// Start animation - shrink the opposite buttons
			if (voteType === 'upvote') {
				voteAnimations.set(trackId, {
					upvote: 'w-full',
					downvote: 'w-0 overflow-hidden',
					remove: 'w-full'
				});
			} else {
				voteAnimations.set(trackId, {
					upvote: 'w-0 overflow-hidden', 
					downvote: 'w-full',
					remove: 'w-full'
				});
			}
			
			// Force reactive update
			voteAnimations = new Map(voteAnimations);
			
			// Send vote via WebSocket for real-time feedback to other users
			if (eventSocketService.isConnected()) {
				eventSocketService.vote(eventId, trackId, voteType, 1);
			}

			// Call HTTP API for persistence
			const httpResults = await voteForTrackInEvent(eventId, trackId, voteType);

			// Clear animation state and reset to default
			voteAnimations.delete(trackId);
			voteAnimations = new Map(voteAnimations);

		} catch (err) {
			// Reset animation state and revert local changes on error
			voteAnimations.delete(trackId);
			voteAnimations = new Map(voteAnimations);
			
			// Revert local vote state
			localUserVotes.set(trackId, previousVoteType);
			localUserVotes = new Map(localUserVotes);
			
			// Revert local vote count
			updateLocalVoteCount(trackId, previousVoteType, voteType);
			
			
			error = err instanceof Error ? err.message : 'Failed to vote for track';
			setTimeout(() => (error = ""), 3000);
		}
	}

	async function removeVoteForTrack(trackId: string) {
		if (!user || !eventId) return;

		if (!canVoteOnTrack(trackId)) {
			error = "You can't modify votes on this track (it may be currently playing or already played)";
			setTimeout(() => (error = ""), 3000);
			return;
		}

		// Get previous vote type for this track outside try block
		const previousVoteType = localUserVotes.get(trackId) || null;

		try {
			// Update local user vote state immediately for instant UI feedback
			localUserVotes.set(trackId, null);
			localUserVotes = new Map(localUserVotes);

			// Update local vote counts and reorder tracks
			updateLocalVoteCount(trackId, null, previousVoteType);

			// Start animation - expand all buttons back to full width
			voteAnimations.set(trackId, {
				upvote: 'w-full',
				downvote: 'w-full',
				remove: 'w-0 overflow-hidden'
			});
			voteAnimations = new Map(voteAnimations);

			// Call HTTP API for persistence (which will handle socket notification)
			const httpResults = await removeVote(eventId, trackId);

			// Clear animation state after successful vote removal
			voteAnimations.delete(trackId);
			voteAnimations = new Map(voteAnimations);

		} catch (err) {
			// Reset animation state and revert local changes on error
			voteAnimations.delete(trackId);
			voteAnimations = new Map(voteAnimations);
			
			// Revert local vote state
			localUserVotes.set(trackId, previousVoteType);
			localUserVotes = new Map(localUserVotes);
			
			// Revert local vote count
			updateLocalVoteCount(trackId, previousVoteType, null);
			
			// Only show user-friendly error message for actual vote not found errors
			if (err instanceof Error && err.message.includes('Vote not found')) {
				error = "You haven't voted for this track yet";
			} else {
				error = err instanceof Error ? err.message : 'Failed to remove vote';
			}
			
			setTimeout(() => (error = ""), 3000);
		}
	}

	// Location-based voting functions
	async function getCurrentLocation(useCache = true): Promise<{latitude: number, longitude: number}> {
		// If we have a recent cached location and user wants to use cache, return it
		if (useCache && currentUserLocation) {
			return currentUserLocation;
		}

		return new Promise((resolve, reject) => {
			if (!navigator.geolocation) {
				reject(new Error('Geolocation is not supported by this browser'));
				return;
			}

			navigator.geolocation.getCurrentPosition(
				(position) => {
					const coordinates = {
						latitude: position.coords.latitude,
						longitude: position.coords.longitude,
					};
					currentUserLocation = coordinates;
					resolve(coordinates);
				},
				(error) => {
					let errorMessage = 'Failed to get location';
					switch (error.code) {
						case error.PERMISSION_DENIED:
							errorMessage = 'Location access denied. Please enable location access to vote.';
							break;
						case error.POSITION_UNAVAILABLE:
							errorMessage = 'Location information unavailable';
							break;
						case error.TIMEOUT:
							errorMessage = 'Location request timed out';
							break;
					}
					reject(new Error(errorMessage));
				},
				{
					enableHighAccuracy: true,
					timeout: 10000,
					maximumAge: 300000, // 5 minutes - use cached position if recent
				}
			);
		});
	}

	async function checkLocationPermission(useCache = true): Promise<void> {
		if (!event || event.licenseType !== 'location_based' || !eventId) {
			hasLocationPermission = true;
			return;
		}

		try {
			locationStatus = 'checking';
			locationError = "";
			
			// Get current location (use cache for voting, fresh for initial check)
			const location = await getCurrentLocation(useCache);
			
			// Check with backend if location is valid
			const response = await fetch(`${config.apiUrl}/api/events/${eventId}/check-location`, {
				method: 'POST',
				headers: {
					'Authorization': `Bearer ${authService.getAuthToken()}`,
					'Content-Type': 'application/json',
				},
				body: JSON.stringify({
					latitude: location.latitude,
					longitude: location.longitude,
				}),
			});

			if (!response.ok) {
				const errorData = await response.json();
				throw new Error(errorData.message || 'Failed to check location permission');
			}

			const result = await response.json();
			hasLocationPermission = result.data.hasPermission;
			
			if (hasLocationPermission) {
				locationStatus = 'allowed';
				locationError = "";
			} else {
				locationStatus = 'denied';
				locationError = "You're not in the correct location or time to vote for this event.";
			}
		} catch (err) {
			
			hasLocationPermission = false;
			locationStatus = 'unavailable';
			locationError = err instanceof Error ? err.message : 'Location check failed';
		}
	}

	function startLocationWatching(): void {
		if (!navigator.geolocation || locationWatchId !== null || event?.licenseType !== 'location_based') {
			return;
		}

		locationWatchId = navigator.geolocation.watchPosition(
			async (position) => {
				const coordinates = {
					latitude: position.coords.latitude,
					longitude: position.coords.longitude,
				};
				currentUserLocation = coordinates;
				
				// Recheck permission when location changes significantly (use cached coordinates)
				if (event && eventId) {
					await checkLocationPermission(true);
				}
			},
			(error) => {
				
				locationStatus = 'unavailable';
				locationError = 'Unable to track location changes';
			},
			{
				enableHighAccuracy: true,
				timeout: 10000,
				maximumAge: 300000, // 5 minutes
			}
		);
	}

	function stopLocationWatching(): void {
		if (locationWatchId !== null) {
			navigator.geolocation.clearWatch(locationWatchId);
			locationWatchId = null;
		}
	}

	// Edit city input handling functions
	async function handleEditCityInput(event: globalThis.Event & { currentTarget: EventTarget & HTMLInputElement }) {
		const target = event.currentTarget;
		const value = target.value;
		editCityInput = value;
		editCityError = "";

		if (value.length >= 2) {
			try {
				editCitySuggestions = await geocodingService.getSuggestedCities(value);
				showEditCitySuggestions = editCitySuggestions.length > 0;
			} catch (error) {
				console.error('Error getting city suggestions:', error);
				editCitySuggestions = [];
				showEditCitySuggestions = false;
			}
		} else {
			editCitySuggestions = [];
			showEditCitySuggestions = false;
		}
	}

	function selectEditCity(city: string) {
		editCityInput = city;
		editCitySuggestions = [];
		showEditCitySuggestions = false;
		editCityError = "";
	}

	function hideEditCitySuggestions() {
		// Delay hiding to allow for city selection
		setTimeout(() => {
			showEditCitySuggestions = false;
		}, 150);
	}

	async function validateEditCityInput() {
		if (!editCityInput.trim()) {
			editCityError = "";
			return;
		}

		try {
			const isValid = await geocodingService.validateCity(editCityInput.trim());
			if (!isValid) {
				editCityError = `City "${editCityInput}" not found. Please check the spelling or try a different city.`;
			} else {
				editCityError = "";
			}
		} catch (error) {
			editCityError = "Unable to validate city. Please try again.";
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
{:else if event && !hasEventAccess}
	<div class="container mx-auto px-4 py-8">
		<div class="bg-yellow-100 border border-yellow-400 text-yellow-700 px-4 py-3 rounded">
			<h3 class="font-semibold mb-2">Access Restricted</h3>
			<p>This is a private event. You need to be invited by the event creator to access it.</p>
			<div class="mt-4">
				<button
					onclick={() => goto('/events')}
					class="bg-secondary text-white px-4 py-2 rounded-lg hover:bg-secondary/80 transition-colors"
				>
					← Back to Events
				</button>
			</div>
		</div>
	</div>
{:else if event && hasEventAccess}
	<div class="container mx-auto px-4 py-8">
		<div class="flex items-center justify-between w-full">
			<BackNavBtn />
			{#if canEdit}
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
			{/if}
		</div>
		<!-- Event Header -->
		<div class="bg-white rounded-lg shadow-md p-6 mb-8">
			<div class="flex flex-col md:flex-row items-center md:items-start md:space-x-6 text-center md:text-left">
				{#if event.coverImageUrl}
					<img
						src={event.coverImageUrl}
						alt={event.title}
						class="w-32 h-32 rounded-lg object-cover"
					/>
				{:else}
					<div
						class="w-32 h-32 min-w-32 min-h-32 bg-gradient-to-br from-secondary/20 to-purple-300 rounded-lg flex items-center justify-center"
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

				<div class="flex-1 min-w-0 w-full overflow-hidden">
					<div class="flex flex-col sm:flex-row sm:justify-between sm:items-start my-4">
						<div id="here" class="w-full min-w-0 max-w-full overflow-hidden">
							<h1
								class="font-family-main text-2xl sm:text-3xl font-bold text-gray-800 mb-2 truncate w-full"
							>
								{event.name || event.title}
							</h1>
							{#if event.description}
								<p class="text-gray-600 mb-4 text-sm sm:text-base break-words truncate w-full">
									{event.description}
								</p>
							{/if}
						</div>
					</div>

					<div
						class="grid grid-cols-1 md:grid-cols-2 lg:grid-cols-4 gap-4 text-sm text-gray-600"
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
									>{event.eventDate ||
										event.startDate}</span
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
					
					{#if event.licenseType === "invited" && (isCreator || isAdmin)}
						<div class="flex space-x-3 mt-4 justify-center md:justify-start">
							<button
								onclick={() => (showInviteModal = true)}
								class="border border-secondary text-secondary px-4 py-2 rounded-lg hover:bg-secondary/10 transition-colors"
							>
								Invite to Event
							</button>
						</div>
					{/if}
				</div>
				<div class="flex space-x-2 mt-4 md:mt-0">
					{#if eventStatus() === "live"}
						<span
							class="flex px-2 py-1 text-xs rounded-full bg-red-100 text-red-800"
						>
							<div class='absolute animate-ping mr-2'>🔴</div>
							<div class='mr-2'>🔴</div>
							<div>Live</div>
						</span>
					{/if}
					{#if event.visibility === "private"}
						<span
							class="px-2 py-1 text-xs rounded-full bg-red-100 text-red-800"
						>
							Private
						</span>
					{/if}
					{#if event.visibility !== "private" && event.licenseType === "invited"}
						<span
							class="px-2 py-1 text-xs rounded-full bg-blue-100 text-blue-800"
						>
							Closed
						</span>
					{/if}
					{#if event.licenseType === "location_based" && event.locationName}
						<span
							class="px-2 py-1 text-xs rounded-full bg-green-100 text-green-800"
						>
							{event.locationName}
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

		{#if event?.licenseType === "location_based" && locationError}
			<div
				class="bg-yellow-100 border border-yellow-400 text-yellow-700 px-4 py-3 rounded mb-6"
			>
				<div class="flex items-center">
					<svg class="w-5 h-5 mr-2" fill="currentColor" viewBox="0 0 20 20">
						<path fill-rule="evenodd" d="M8.257 3.099c.765-1.36 2.722-1.36 3.486 0l5.58 9.92c.75 1.334-.213 2.98-1.742 2.98H4.42c-1.53 0-2.493-1.646-1.743-2.98l5.58-9.92zM11 13a1 1 0 11-2 0 1 1 0 012 0zm-1-8a1 1 0 00-1 1v3a1 1 0 002 0V6a1 1 0 00-1-1z" clip-rule="evenodd" />
					</svg>
					<div>
						<h4 class="font-semibold">Location Required</h4>
						<p class="text-sm">{locationError}</p>
						{#if currentUserLocation && locationStatus === 'denied'}
							<div class="mt-2 p-2 bg-yellow-50 rounded border text-xs">
								<p class="font-medium">Your current location:</p>
								<p>Latitude: {currentUserLocation.latitude.toFixed(4)}</p>
								<p>Longitude: {currentUserLocation.longitude.toFixed(4)}</p>
							</div>
						{/if}
						{#if locationStatus === 'unavailable'}
							<button
								onclick={() => checkLocationPermission(false)}
								class="mt-2 bg-yellow-600 text-white px-3 py-1 rounded text-sm hover:bg-yellow-700 transition-colors"
							>
								Try Again
							</button>
						{/if}
					</div>
				</div>
			</div>
		{/if}

		<!-- Music Player handled by global layout -->

		<!-- Playlist -->
		<div class="flex flex-col lg:flex-row gap-8">
			<div class="w-full bg-white rounded-lg shadow-md p-6">
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
							• 
							{canVoteForTracks()
								? numberOfVotesAvailable() > 0
									? `You have ${numberOfVotesAvailable()} vote${
											numberOfVotesAvailable() !== 1
												? "s"
												: ""
									  } left`
									: "No votes left"
								: "• Voting available for participants"}
						</p>
					</div>
					{#if isAdmin || isCreator}
						<div class="flex space-x-3">
							<button
								onclick={() => (showMusicSearchModal = true)}
								class="bg-secondary text-white px-4 py-2 rounded-lg hover:bg-secondary/80 transition-colors flex items-center space-x-2"
							>
								<span>Search & Add Music</span>
							</button>
							<button
								onclick={() => openPlaylistModal()}
								class="bg-purple-500 text-white px-4 py-2 rounded-lg hover:bg-purple-600 transition-colors flex items-center space-x-2"
							>
								<span>Add Playlist</span>
							</button>
						</div>
					{/if}
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
						{#each filteredTracks() as track, index (track.id)}
							{@const trackStatus = getTrackStatus(track, index)}
							<div class="relative" animate:flip={{ duration: 700 }}>
								<div
									class="flex relative group items-center overflow-hidden space-x-4 p-3 border rounded-lg transition-colors {getTrackContainerClass(track, index)}"
									role={canEdit ? "listitem" : "none"}
								>
									<div
										class="w-8 h-8 rounded-full flex items-center justify-center text-sm font-semibold {getVoteCountBadgeClass(track, index)}"
									>
										{#if trackStatus === 'current'}
											<!-- Now playing indicator -->
											<svg version="1.0" class="w-4 h-4" id="Layer_1" xmlns="http://www.w3.org/2000/svg" xmlns:xlink="http://www.w3.org/1999/xlink" viewBox="0 0 64 64" enable-background="new 0 0 64 64" xml:space="preserve" fill="currentColor"><g id="SVGRepo_bgCarrier" stroke-width="0"></g><g id="SVGRepo_tracerCarrier" stroke-linecap="round" stroke-linejoin="round"></g><g id="SVGRepo_iconCarrier"> <path fill="currentColor" d="M62.799,23.737c-0.47-1.399-1.681-2.419-3.139-2.642l-16.969-2.593L35.069,2.265 C34.419,0.881,33.03,0,31.504,0c-1.527,0-2.915,0.881-3.565,2.265l-7.623,16.238L3.347,21.096c-1.458,0.223-2.669,1.242-3.138,2.642 c-0.469,1.4-0.115,2.942,0.916,4l12.392,12.707l-2.935,17.977c-0.242,1.488,0.389,2.984,1.62,3.854 c1.23,0.87,2.854,0.958,4.177,0.228l15.126-8.365l15.126,8.365c0.597,0.33,1.254,0.492,1.908,0.492c0.796,0,1.592-0.242,2.269-0.72 c1.231-0.869,1.861-2.365,1.619-3.854l-2.935-17.977l12.393-12.707C62.914,26.68,63.268,25.138,62.799,23.737z"></path> </g></svg>
										{:else}
											{track.voteCount ?? track.votes ?? 0}
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
											)?.displayName || "Unknown"}
										</p>
									</div>

									<div class="flex items-center space-x-3 mr-4">
										<!-- Music Player Controls -->
										{#if isMusicPlayerInitialized && index === 0}
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
															playTrack(actualIndex);
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
															? "Pause"
															: "Resume"
														: "Play"}
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
											</div>
										{/if}
										{#if track.duration}
											<span class="text-sm text-gray-500"
												>{formatDuration(track.duration)}</span
											>
										{/if}

									</div>
									<!-- Hover overlays based on track status -->
									{#if getTrackStatus(track, index) === 'votable' && canVoteForTracks()}
										<!-- Vote Hover - Only show for votable tracks -->
										<div class="absolute top-0 left-[-4%] w-[108%] h-full rounded-lg flex justify-center {getUserVoteForTrack(track.id) ? '' : 'opacity-0'} group-hover:opacity-100 transition-opacity">
											<!-- UpVote Button -->
											<button disabled={getUserVoteForTrack(track.id) === 'upvote'} class="clickable bg-gradient-to-r from-orange-400/20 to-orange-400/80 {getButtonWidthClass(track.id, 'upvote')} flex items-center justify-center opacity-20 -skew-x-19 {getUserVoteForTrack(track.id) === 'upvote' ? '' : 'hover:opacity-80'} cursor-pointer rounded-l-lg transition-all duration-300 ease-in-out" onclick={() => voteForTrackSimple(track.id, 'upvote')} aria-label="upvote track" title="Upvote Track">
												<svg viewBox="-2.4 -2.4 28.80 28.80" class="w-9 h-9 skew-x-19" version="1.1" xmlns="http://www.w3.org/2000/svg" xmlns:xlink="http://www.w3.org/1999/xlink" fill="#000000"><g id="SVGRepo_bgCarrier" ><path transform="translate(-2.4, -2.4), scale(1.7999999999999998)" fill="#f9fafb" d="M9.166.33a2.25 2.25 0 00-2.332 0l-5.25 3.182A2.25 2.25 0 00.5 5.436v5.128a2.25 2.25 0 001.084 1.924l5.25 3.182a2.25 2.25 0 002.332 0l5.25-3.182a2.25 2.25 0 001.084-1.924V5.436a2.25 2.25 0 00-1.084-1.924L9.166.33z"></path></g><g id="SVGRepo_tracerCarrier" stroke-linecap="round" stroke-linejoin="round"></g><g id="SVGRepo_iconCarrier"> <title>Promote</title> <g id="页面-1" stroke="none" stroke-width="1" fill="none" fill-rule="evenodd"> <g id="Arrow" transform="translate(-432.000000, 0.000000)"> <g id="Promote" transform="translate(432.000000, 0.000000)"> <path d="M24,0 L24,24 L0,24 L0,0 L24,0 Z M12.5934901,23.257841 L12.5819402,23.2595131 L12.5108777,23.2950439 L12.4918791,23.2987469 L12.4918791,23.2987469 L12.4767152,23.2950439 L12.4056548,23.2595131 C12.3958229,23.2563662 12.3870493,23.2590235 12.3821421,23.2649074 L12.3780323,23.275831 L12.360941,23.7031097 L12.3658947,23.7234994 L12.3769048,23.7357139 L12.4804777,23.8096931 L12.4953491,23.8136134 L12.4953491,23.8136134 L12.5071152,23.8096931 L12.6106902,23.7357139 L12.6232938,23.7196733 L12.6232938,23.7196733 L12.6266527,23.7031097 L12.609561,23.275831 C12.6075724,23.2657013 12.6010112,23.2592993 12.5934901,23.257841 L12.5934901,23.257841 Z M12.8583906,23.1452862 L12.8445485,23.1473072 L12.6598443,23.2396597 L12.6498822,23.2499052 L12.6498822,23.2499052 L12.6471943,23.2611114 L12.6650943,23.6906389 L12.6699349,23.7034178 L12.6699349,23.7034178 L12.678386,23.7104931 L12.8793402,23.8032389 C12.8914285,23.8068999 12.9022333,23.8029875 12.9078286,23.7952264 L12.9118235,23.7811639 L12.8776777,23.1665331 C12.8752882,23.1545897 12.8674102,23.1470016 12.8583906,23.1452862 L12.8583906,23.1452862 Z M12.1430473,23.1473072 C12.1332178,23.1423925 12.1221763,23.1452606 12.1156365,23.1525954 L12.1099173,23.1665331 L12.0757714,23.7811639 C12.0751323,23.7926639 12.0828099,23.8018602 12.0926481,23.8045676 L12.108256,23.8032389 L12.3092106,23.7104931 L12.3186497,23.7024347 L12.3186497,23.7024347 L12.3225043,23.6906389 L12.340401,23.2611114 L12.337245,23.2485176 L12.337245,23.2485176 L12.3277531,23.2396597 L12.1430473,23.1473072 Z" id="MingCute" fill-rule="nonzero"> </path> <path d="M11.2929,8.2928 C11.6834,7.90228 12.3166,7.90228 12.7071,8.2928 L18.364,13.9497 C18.7545,14.3402 18.7545,14.9733 18.364,15.3639 C17.9734,15.7544 17.3403,15.7544 16.9497,15.3639 L12,10.4141 L7.05025,15.3639 C6.65973,15.7544 6.02656,15.7544 5.63604,15.3639 C5.24551,14.9733 5.24551,14.3402 5.63604,13.9497 L11.2929,8.2928 Z" fill="#f6a437"> </path> </g> </g> </g> </g></svg>
											</button>
											<!-- Remove Vote Button -->
											<button class="clickable from-gray-400/20 to-gray-600/80 {getButtonWidthClass(track.id, 'remove')} flex items-center justify-center opacity-20 -skew-x-19 hover:opacity-80 cursor-pointer transition-all duration-300 ease-in-out" onclick={() => removeVoteForTrack(track.id)} aria-label="remove vote" title="Remove Vote">
												<svg viewBox="-2.4 -2.4 28.80 28.80" class="w-9 h-9 skew-x-19" fill="none" xmlns="http://www.w3.org/2000/svg"><g id="SVGRepo_bgCarrier" stroke-width="0"><path transform="translate(-2.4, -2.4), scale(1.7999999999999998)" fill="#ffffff" d="M9.166.33a2.25 2.25 0 00-2.332 0l-5.25 3.182A2.25 2.25 0 00.5 5.436v5.128a2.25 2.25 0 001.084 1.924l5.25 3.182a2.25 2.25 0 002.332 0l5.25-3.182a2.25 2.25 0 001.084-1.924V5.436a2.25 2.25 0 00-1.084-1.924L9.166.33z" stroke-width="0"></path></g><g id="SVGRepo_tracerCarrier" stroke-linecap="round" stroke-linejoin="round"></g><g id="SVGRepo_iconCarrier"> <path d="M6.99486 7.00636C6.60433 7.39689 6.60433 8.03005 6.99486 8.42058L10.58 12.0057L6.99486 15.5909C6.60433 15.9814 6.60433 16.6146 6.99486 17.0051C7.38538 17.3956 8.01855 17.3956 8.40907 17.0051L11.9942 13.4199L15.5794 17.0051C15.9699 17.3956 16.6031 17.3956 16.9936 17.0051C17.3841 16.6146 17.3841 15.9814 16.9936 15.5909L13.4084 12.0057L16.9936 8.42059C17.3841 8.03007 17.3841 7.3969 16.9936 7.00638C16.603 6.61585 15.9699 6.61585 15.5794 7.00638L11.9942 10.5915L8.40907 7.00636C8.01855 6.61584 7.38538 6.61584 6.99486 7.00636Z" fill="#6b7280"></path> </g></svg>
											</button>
											<!-- DownVote Button -->
											<button disabled={getUserVoteForTrack(track.id) === 'downvote'} class="clickable bg-gradient-to-l from-purple-400/20 to-purple-400/80 {getButtonWidthClass(track.id, 'downvote')} flex items-center justify-center opacity-20 -skew-x-19 {getUserVoteForTrack(track.id) === 'downvote' ? '' : 'hover:opacity-80'} cursor-pointer rounded-r-lg transition-all duration-300 ease-in-out" onclick={() => voteForTrackSimple(track.id, 'downvote')} aria-label="downvote track" title="Downvote Track">
												<svg viewBox="-2.4 -2.4 28.80 28.80" class="w-9 h-9 skew-x-19 rotate-180" version="1.1" xmlns="http://www.w3.org/2000/svg" xmlns:xlink="http://www.w3.org/1999/xlink" fill="#000000"><g id="SVGRepo_bgCarrier" ><path transform="translate(-2.4, -2.4), scale(1.7999999999999998)" fill="#f9fafb" d="M9.166.33a2.25 2.25 0 00-2.332 0l-5.25 3.182A2.25 2.25 0 00.5 5.436v5.128a2.25 2.25 0 001.084 1.924l5.25 3.182a2.25 2.25 0 002.332 0l5.25-3.182a2.25 2.25 0 001.084-1.924V5.436a2.25 2.25 0 00-1.084-1.924L9.166.33z"></path></g><g id="SVGRepo_tracerCarrier" stroke-linecap="round" stroke-linejoin="round"></g><g id="SVGRepo_iconCarrier"> <title>Promote</title> <g id="页面-1" stroke="none" stroke-width="1" fill="none" fill-rule="evenodd"> <g id="Arrow" transform="translate(-432.000000, 0.000000)"> <g id="Promote" transform="translate(432.000000, 0.000000)"> <path d="M24,0 L24,24 L0,24 L0,0 L24,0 Z M12.5934901,23.257841 L12.5819402,23.2595131 L12.5108777,23.2950439 L12.4918791,23.2987469 L12.4918791,23.2987469 L12.4767152,23.2950439 L12.4056548,23.2595131 C12.3958229,23.2563662 12.3870493,23.2590235 12.3821421,23.2649074 L12.3780323,23.275831 L12.360941,23.7031097 L12.3658947,23.7234994 L12.3769048,23.7357139 L12.4804777,23.8096931 L12.4953491,23.8136134 L12.4953491,23.8136134 L12.5071152,23.8096931 L12.6106902,23.7357139 L12.6232938,23.7196733 L12.6232938,23.7196733 L12.6266527,23.7031097 L12.609561,23.275831 C12.6075724,23.2657013 12.6010112,23.2592993 12.5934901,23.257841 L12.5934901,23.257841 Z M12.8583906,23.1452862 L12.8445485,23.1473072 L12.6598443,23.2396597 L12.6498822,23.2499052 L12.6498822,23.2499052 L12.6471943,23.2611114 L12.6650943,23.6906389 L12.6699349,23.7034178 L12.6699349,23.7034178 L12.678386,23.7104931 L12.8793402,23.8032389 C12.8914285,23.8068999 12.9022333,23.8029875 12.9078286,23.7952264 L12.9118235,23.7811639 L12.8776777,23.1665331 C12.8752882,23.1545897 12.8674102,23.1470016 12.8583906,23.1452862 L12.8583906,23.1452862 Z M12.1430473,23.1473072 C12.1332178,23.1423925 12.1221763,23.1452606 12.1156365,23.1525954 L12.1099173,23.1665331 L12.0757714,23.7811639 C12.0751323,23.7926639 12.0828099,23.8018602 12.0926481,23.8045676 L12.108256,23.8032389 L12.3092106,23.7104931 L12.3186497,23.7024347 L12.3186497,23.7024347 L12.3225043,23.6906389 L12.340401,23.2611114 L12.337245,23.2485176 L12.337245,23.2485176 L12.3277531,23.2396597 L12.1430473,23.1473072 Z" id="MingCute" fill-rule="nonzero"> </path> <path d="M11.2929,8.2928 C11.6834,7.90228 12.3166,7.90228 12.7071,8.2928 L18.364,13.9497 C18.7545,14.3402 18.7545,14.9733 18.364,15.3639 C17.9734,15.7544 17.3403,15.7544 16.9497,15.3639 L12,10.4141 L7.05025,15.3639 C6.65973,15.7544 6.02656,15.7544 5.63604,15.3639 C5.24551,14.9733 5.24551,14.3402 5.63604,13.9497 L11.2929,8.2928 Z" fill="#c084fc"> </path> </g> </g> </g> </g></svg>
											</button>
										</div>
									{/if}
								</div>
								<!-- Remove Track Button -->
								{#if canEdit}
									<button class="absolute clickable right-0 top-[50%] translate-x-[50%] translate-y-[-50%] w-10 h-10 group" onclick={() => (removeTrack(track.id))} aria-label="remove track" title="Remove Track">
										<svg viewBox="-8.4 -8.4 40.80 40.80" fill="none" xmlns="http://www.w3.org/2000/svg"><g id="SVGRepo_bgCarrier" stroke-width="0"><path transform="translate(-8.4, -8.4), scale(2.55)" fill="#ffffff" class:group-hover:fill-secondary={index === 0} class="group-hover:fill-gray-200 transition-colors duration-200" d="M9.166.33a2.25 2.25 0 00-2.332 0l-5.25 3.182A2.25 2.25 0 00.5 5.436v5.128a2.25 2.25 0 001.084 1.924l5.25 3.182a2.25 2.25 0 002.332 0l5.25-3.182a2.25 2.25 0 001.084-1.924V5.436a2.25 2.25 0 00-1.084-1.924L9.166.33z"></path></g><g id="SVGRepo_tracerCarrier" stroke-linecap="round" stroke-linejoin="round"></g><g id="SVGRepo_iconCarrier"> <path d="M4 6H20M16 6L15.7294 5.18807C15.4671 4.40125 15.3359 4.00784 15.0927 3.71698C14.8779 3.46013 14.6021 3.26132 14.2905 3.13878C13.9376 3 13.523 3 12.6936 3H11.3064C10.477 3 10.0624 3 9.70951 3.13878C9.39792 3.26132 9.12208 3.46013 8.90729 3.71698C8.66405 4.00784 8.53292 4.40125 8.27064 5.18807L8 6M18 6V16.2C18 17.8802 18 18.7202 17.673 19.362C17.3854 19.9265 16.9265 20.3854 16.362 20.673C15.7202 21 14.8802 21 13.2 21H10.8C9.11984 21 8.27976 21 7.63803 20.673C7.07354 20.3854 6.6146 19.9265 6.32698 19.362C6 18.7202 6 17.8802 6 16.2V6M14 10V17M10 10V17" stroke="#e01b24" stroke-width="2" stroke-linecap="round" stroke-linejoin="round"></path> </g></svg>
									</button>
								{/if}
							</div>
						{/each}
					</div>
				{/if}
			</div>
			<!-- Participants Sidebar -->
			<div class="bg-white rounded-lg shadow-md p-6 w-full lg:max-w-xs">
				<div class="flex items-center justify-between mb-4">
					<h2 class="text-xl font-bold text-gray-800">
						Participants
					</h2>
					<span
						class="bg-secondary/10 text-secondary px-2 py-1 rounded-full text-sm font-medium ml-2"
					>
						{event.participants.length}
					</span>
				</div>
				<div>
					{#each sortedParticipants() as participant}
						{@const role = getUserRole(participant.id)}
						<div class="group relative">
							<button
								onclick={() => goto(`/users/${participant.id}`)}
								class="flex pr-4 items-center space-x-3 p-2 rounded-lg hover:bg-gray-50 transition-colors w-full relative text-left {participant.id ===
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
							{#if (isCreator || isAdmin) && participant.id !== user?.id && role !== "Owner" && role !== "Admin"}
								<button class="absolute clickable right-0 top-[50%] translate-x-[50%] translate-y-[-50%] opacity-0 group-hover:opacity-100 transition-opacity duration-200" onclick={() => (showPromoteModal = true, selectedUserId = participant.id)} aria-label="Promote to admin">
									<svg viewBox="-2.4 -2.4 28.80 28.80" class="w-9 h-9 animate-bounce" version="1.1" xmlns="http://www.w3.org/2000/svg" xmlns:xlink="http://www.w3.org/1999/xlink" fill="#000000"><g id="SVGRepo_bgCarrier" ><path transform="translate(-2.4, -2.4), scale(1.7999999999999998)" fill="#f9fafb" d="M9.166.33a2.25 2.25 0 00-2.332 0l-5.25 3.182A2.25 2.25 0 00.5 5.436v5.128a2.25 2.25 0 001.084 1.924l5.25 3.182a2.25 2.25 0 002.332 0l5.25-3.182a2.25 2.25 0 001.084-1.924V5.436a2.25 2.25 0 00-1.084-1.924L9.166.33z"></path></g><g id="SVGRepo_tracerCarrier" stroke-linecap="round" stroke-linejoin="round"></g><g id="SVGRepo_iconCarrier"> <title>Promote</title> <g id="页面-1" stroke="none" stroke-width="1" fill="none" fill-rule="evenodd"> <g id="Arrow" transform="translate(-432.000000, 0.000000)"> <g id="Promote" transform="translate(432.000000, 0.000000)"> <path d="M24,0 L24,24 L0,24 L0,0 L24,0 Z M12.5934901,23.257841 L12.5819402,23.2595131 L12.5108777,23.2950439 L12.4918791,23.2987469 L12.4918791,23.2987469 L12.4767152,23.2950439 L12.4056548,23.2595131 C12.3958229,23.2563662 12.3870493,23.2590235 12.3821421,23.2649074 L12.3780323,23.275831 L12.360941,23.7031097 L12.3658947,23.7234994 L12.3769048,23.7357139 L12.4804777,23.8096931 L12.4953491,23.8136134 L12.4953491,23.8136134 L12.5071152,23.8096931 L12.6106902,23.7357139 L12.6232938,23.7196733 L12.6232938,23.7196733 L12.6266527,23.7031097 L12.609561,23.275831 C12.6075724,23.2657013 12.6010112,23.2592993 12.5934901,23.257841 L12.5934901,23.257841 Z M12.8583906,23.1452862 L12.8445485,23.1473072 L12.6598443,23.2396597 L12.6498822,23.2499052 L12.6498822,23.2499052 L12.6471943,23.2611114 L12.6650943,23.6906389 L12.6699349,23.7034178 L12.6699349,23.7034178 L12.678386,23.7104931 L12.8793402,23.8032389 C12.8914285,23.8068999 12.9022333,23.8029875 12.9078286,23.7952264 L12.9118235,23.7811639 L12.8776777,23.1665331 C12.8752882,23.1545897 12.8674102,23.1470016 12.8583906,23.1452862 L12.8583906,23.1452862 Z M12.1430473,23.1473072 C12.1332178,23.1423925 12.1221763,23.1452606 12.1156365,23.1525954 L12.1099173,23.1665331 L12.0757714,23.7811639 C12.0751323,23.7926639 12.0828099,23.8018602 12.0926481,23.8045676 L12.108256,23.8032389 L12.3092106,23.7104931 L12.3186497,23.7024347 L12.3186497,23.7024347 L12.3225043,23.6906389 L12.340401,23.2611114 L12.337245,23.2485176 L12.337245,23.2485176 L12.3277531,23.2396597 L12.1430473,23.1473072 Z" id="MingCute" fill-rule="nonzero"> </path> <path d="M11.2929,8.2928 C11.6834,7.90228 12.3166,7.90228 12.7071,8.2928 L18.364,13.9497 C18.7545,14.3402 18.7545,14.9733 18.364,15.3639 C17.9734,15.7544 17.3403,15.7544 16.9497,15.3639 L12,10.4141 L7.05025,15.3639 C6.65973,15.7544 6.02656,15.7544 5.63604,15.3639 C5.24551,14.9733 5.24551,14.3402 5.63604,13.9497 L11.2929,8.2928 Z" fill="#f6a437"> </path> </g> </g> </g> </g></svg>
								</button>
							{/if}
							{#if role === "Admin" || role === "Owner"}
								<svg viewBox="-2.4 -2.4 28.80 28.80" class="w-9 h-9 absolute right-0 top-[50%] translate-x-[50%] translate-y-[-50%]" class:group-hover:hidden={isCreator && role === 'Admin'} fill="none" xmlns="http://www.w3.org/2000/svg"><g id="SVGRepo_bgCarrier"><path transform="translate(-2.4, -2.4), scale(1.7999999999999998)" fill="#ffffff" d="M9.166.33a2.25 2.25 0 00-2.332 0l-5.25 3.182A2.25 2.25 0 00.5 5.436v5.128a2.25 2.25 0 001.084 1.924l5.25 3.182a2.25 2.25 0 002.332 0l5.25-3.182a2.25 2.25 0 001.084-1.924V5.436a2.25 2.25 0 00-1.084-1.924L9.166.33z"></path></g><g id="SVGRepo_tracerCarrier" stroke-linecap="round" stroke-linejoin="round"></g><g id="SVGRepo_iconCarrier"> <path d="M11.2691 4.41115C11.5006 3.89177 11.6164 3.63208 11.7776 3.55211C11.9176 3.48263 12.082 3.48263 12.222 3.55211C12.3832 3.63208 12.499 3.89177 12.7305 4.41115L14.5745 8.54808C14.643 8.70162 14.6772 8.77839 14.7302 8.83718C14.777 8.8892 14.8343 8.93081 14.8982 8.95929C14.9705 8.99149 15.0541 9.00031 15.2213 9.01795L19.7256 9.49336C20.2911 9.55304 20.5738 9.58288 20.6997 9.71147C20.809 9.82316 20.8598 9.97956 20.837 10.1342C20.8108 10.3122 20.5996 10.5025 20.1772 10.8832L16.8125 13.9154C16.6877 14.0279 16.6252 14.0842 16.5857 14.1527C16.5507 14.2134 16.5288 14.2807 16.5215 14.3503C16.5132 14.429 16.5306 14.5112 16.5655 14.6757L17.5053 19.1064C17.6233 19.6627 17.6823 19.9408 17.5989 20.1002C17.5264 20.2388 17.3934 20.3354 17.2393 20.3615C17.0619 20.3915 16.8156 20.2495 16.323 19.9654L12.3995 17.7024C12.2539 17.6184 12.1811 17.5765 12.1037 17.56C12.0352 17.5455 11.9644 17.5455 11.8959 17.56C11.8185 17.5765 11.7457 17.6184 11.6001 17.7024L7.67662 19.9654C7.18404 20.2495 6.93775 20.3915 6.76034 20.3615C6.60623 20.3354 6.47319 20.2388 6.40075 20.1002C6.31736 19.9408 6.37635 19.6627 6.49434 19.1064L7.4341 14.6757C7.46898 14.5112 7.48642 14.429 7.47814 14.3503C7.47081 14.2807 7.44894 14.2134 7.41394 14.1527C7.37439 14.0842 7.31195 14.0279 7.18708 13.9154L3.82246 10.8832C3.40005 10.5025 3.18884 10.3122 3.16258 10.1342C3.13978 9.97956 3.19059 9.82316 3.29993 9.71147C3.42581 9.58288 3.70856 9.55304 4.27406 9.49336L8.77835 9.01795C8.94553 9.00031 9.02911 8.99149 9.10139 8.95929C9.16534 8.93081 9.2226 8.8892 9.26946 8.83718C9.32241 8.77839 9.35663 8.70162 9.42508 8.54808L11.2691 4.41115Z" stroke="#f6a437" stroke-width="2" stroke-linecap="round" stroke-linejoin="round"></path> </g></svg>
								{#if isCreator && role === "Admin"}
									<button class="absolute right-0 top-[50%] translate-x-[50%] translate-y-[-50%] hidden group-hover:block" onclick={() => (removeAdmin(participant.id))} aria-label="Promote to admin">
										<svg viewBox="-2.4 -2.4 28.80 28.80" class="w-9 h-9 rotate-180 animate-bounce" version="1.1" xmlns="http://www.w3.org/2000/svg" xmlns:xlink="http://www.w3.org/1999/xlink" fill="#000000"><g id="SVGRepo_bgCarrier" ><path transform="translate(-2.4, -2.4), scale(1.7999999999999998)" fill="#f9fafb" d="M9.166.33a2.25 2.25 0 00-2.332 0l-5.25 3.182A2.25 2.25 0 00.5 5.436v5.128a2.25 2.25 0 001.084 1.924l5.25 3.182a2.25 2.25 0 002.332 0l5.25-3.182a2.25 2.25 0 001.084-1.924V5.436a2.25 2.25 0 00-1.084-1.924L9.166.33z"></path></g><g id="SVGRepo_tracerCarrier" stroke-linecap="round" stroke-linejoin="round"></g><g id="SVGRepo_iconCarrier"> <title>Promote</title> <g id="页面-1" stroke="none" stroke-width="1" fill="none" fill-rule="evenodd"> <g id="Arrow" transform="translate(-432.000000, 0.000000)"> <g id="Promote" transform="translate(432.000000, 0.000000)"> <path d="M24,0 L24,24 L0,24 L0,0 L24,0 Z M12.5934901,23.257841 L12.5819402,23.2595131 L12.5108777,23.2950439 L12.4918791,23.2987469 L12.4918791,23.2987469 L12.4767152,23.2950439 L12.4056548,23.2595131 C12.3958229,23.2563662 12.3870493,23.2590235 12.3821421,23.2649074 L12.3780323,23.275831 L12.360941,23.7031097 L12.3658947,23.7234994 L12.3769048,23.7357139 L12.4804777,23.8096931 L12.4953491,23.8136134 L12.4953491,23.8136134 L12.5071152,23.8096931 L12.6106902,23.7357139 L12.6232938,23.7196733 L12.6232938,23.7196733 L12.6266527,23.7031097 L12.609561,23.275831 C12.6075724,23.2657013 12.6010112,23.2592993 12.5934901,23.257841 L12.5934901,23.257841 Z M12.8583906,23.1452862 L12.8445485,23.1473072 L12.6598443,23.2396597 L12.6498822,23.2499052 L12.6498822,23.2499052 L12.6471943,23.2611114 L12.6650943,23.6906389 L12.6699349,23.7034178 L12.6699349,23.7034178 L12.678386,23.7104931 L12.8793402,23.8032389 C12.8914285,23.8068999 12.9022333,23.8029875 12.9078286,23.7952264 L12.9118235,23.7811639 L12.8776777,23.1665331 C12.8752882,23.1545897 12.8674102,23.1470016 12.8583906,23.1452862 L12.8583906,23.1452862 Z M12.1430473,23.1473072 C12.1332178,23.1423925 12.1221763,23.1452606 12.1156365,23.1525954 L12.1099173,23.1665331 L12.0757714,23.7811639 C12.0751323,23.7926639 12.0828099,23.8018602 12.0926481,23.8045676 L12.108256,23.8032389 L12.3092106,23.7104931 L12.3186497,23.7024347 L12.3186497,23.7024347 L12.3225043,23.6906389 L12.340401,23.2611114 L12.337245,23.2485176 L12.337245,23.2485176 L12.3277531,23.2396597 L12.1430473,23.1473072 Z" id="MingCute" fill-rule="nonzero"> </path> <path d="M11.2929,8.2928 C11.6834,7.90228 12.3166,7.90228 12.7071,8.2928 L18.364,13.9497 C18.7545,14.3402 18.7545,14.9733 18.364,15.3639 C17.9734,15.7544 17.3403,15.7544 16.9497,15.3639 L12,10.4141 L7.05025,15.3639 C6.65973,15.7544 6.02656,15.7544 5.63604,15.3639 C5.24551,14.9733 5.24551,14.3402 5.63604,13.9497 L11.2929,8.2928 Z" fill="#c084fc"> </path> </g> </g> </g> </g></svg>
									</button>
								{/if}
							{/if}
						</div>
					{/each}
				</div>
			</div>
		</div>


		<!-- Enhanced Music Search Modal -->
		{#if showMusicSearchModal && eventId}
			<EnhancedMusicSearchModal
				{eventId}
				eventTracks={event?.playlist || []}
				onTrackAdded={() => {}}
				onClose={() => (showMusicSearchModal = false)}
			/>
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
								onclick={() => closePlaylistModal()}
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
											class="flex items-center justify-between truncate break-all overflow-hidden"
										>
											<button
												onclick={() =>
													addPlaylistToEvent(
														playlist.id,
													)}
												disabled={loading}
												class="bg-secondary text-white px-4 py-2 mr-4 rounded-lg hover:bg-secondary/80 disabled:opacity-50 transition-colors"
											>
												{loading ? "Adding..." : "Add"}
											</button>
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

										</div>
									</div>
								{/each}
							</div>
						{/if}

						<div
							class="flex justify-end pt-6 border-t border-gray-200 mt-6"
						>
							<button
								onclick={() => closePlaylistModal()}
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
										<option value="open" disabled={editEventData.visibility === "private"}>Open</option>
										<option value="invited"
											>Invited Only</option
										>
										<option value="location_based"
											>Location Based</option
										>
									</select>
								</div>
								<div>
									<label
										for="edit-event-max-votes"
										class="block text-sm font-medium text-gray-700 mb-2"
										>Max Votes Per User</label
									>
									<input
										id="edit-event-max-votes"
										type="number"
										bind:value={editEventData.maxVotesPerUser}
										class="w-full px-4 py-3 border border-gray-300 rounded-lg focus:outline-none focus:ring-2 focus:ring-secondary focus:border-transparent"
										placeholder="1 by default"
									/>
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

		<!-- Add Participant Modal -->
		{#if showInviteModal && eventId}
			<AddCollaboratorModal
				eventId={eventId}
				onParticipantAdded={() => {
					showInviteModal = false;
				}}
				onClose={() => (showInviteModal = false)}
			/>
		{/if}
	</div>
{/if}
