<script lang="ts">
	import { onMount, onDestroy } from "svelte";
	import { page } from "$app/stores";
	import { authStore } from "$lib/stores/auth";
	import {
		getEvents,
		getMyEvents,
		getEvent,
		createEvent as createEventAPI,
		type Event,
		type CreateEventData,
	} from "$lib/services/events";
	import { playlistsService, type Playlist } from "$lib/services/playlists";
	import { eventSocketService } from "$lib/services/event-socket";
	import { goto, replaceState } from "$app/navigation";

	let { data } = $props();
	let events: Event[] = $state(data?.events || []);
	let filteredEvents: Event[] = $state([]);
	let loading = $state(false);
	let error = $state("");
	let user = $derived($authStore);
	let showCreateModal = $state(false);
	let activeTab: "all" | "mine" = $state("all");
	let searchQuery = $state("");
	let sortBy = $state<"date" | "participants" | "license" | "tracks">("date");
	let sortOrder = $state<"asc" | "desc">("asc");
	let isSocketConnected = $state(false);
	const maxSocketRetries = 5;
	let socketRetryAttempts = 0;

	// Create event form
	let newEvent = $state<CreateEventData>({
		name: "",
		description: "",
		visibility: "public",
		licenseType: "open",
		eventDate: "",
		eventEndDate: "",
		locationName: "",
	});

	let formErrors = $state({
		eventDate: "",
		eventEndDate: "",
	});

	// Update tab based on URL parameter on initial load only
	let initialTabFromURL = $derived(
		$page.url.searchParams.get("tab") || "all",
	);
	let hasInitialized = $state(false);

	$effect(() => {
		if (!hasInitialized) {
			activeTab = initialTabFromURL as typeof activeTab;
			hasInitialized = true;
		}
	});

	$effect(() => {
		if (newEvent.visibility === "private") {
			newEvent.licenseType = "invited";
		}
	});

	// Update events when data changes
	$effect(() => {
		if (data?.events) {
			events = data.events;
		}
	});

	// NOTE: Collaborative events are now automatically included in the backend response
	// through the updated access control logic, so no need for separate loading

	// Helper functions for event management

	// NOTE: Since collaborative events are included in backend response,
	// manual refresh is no longer needed

	// Reload events when tab changes
	$effect(() => {
		loadEvents();
	});

	// Filter and sort events
	$effect(() => {
		let filtered = [...events];
		// Update event status based on date
		const now = new Date();
		filtered.forEach((event: Event) => {
			if (event.eventDate && event.eventEndDate) {
				const start = new Date(event.eventDate);
				const end = new Date(event.eventEndDate);
				if (now >= start && now < end) {
					event.status = "live";
				}
			}
		});

		// Filter by search query
		if (searchQuery.trim()) {
			const query = searchQuery.trim().toLowerCase();
			filtered = filtered.filter(
				(event) =>
					event.name.toLowerCase().includes(query) ||
					event.description?.toLowerCase().includes(query) ||
					event.creator?.displayName?.toLowerCase().includes(query) ||
					event.locationName?.toLowerCase().includes(query),
			);
		}

		// Filter by tab
		// NOTE: No filtering needed for "mine" tab since the backend endpoint returns the correct data
		// The getMyEvents() endpoint already includes events where user is creator, participant, or collaborator

		// Sort events - Live events first, then by nearest date
		filtered.sort((a, b) => {
			// If we're sorting by date (default), prioritize live events first
			if (sortBy === "date") {
				// Live events always come first
				if (a.status === "live" && b.status !== "live") return -1;
				if (b.status === "live" && a.status !== "live") return 1;

				// If both are live or both are not live, sort by date
				const dateA = new Date(a.eventDate || a.createdAt).getTime();
				const dateB = new Date(b.eventDate || b.createdAt).getTime();
				return sortOrder === "asc" ? dateA - dateB : dateB - dateA;
			}

			// For other sort types, use the existing logic
			let comparison = 0;

			switch (sortBy) {
				case "tracks":
					comparison =
						(a.playlist?.length || 0) - (b.playlist?.length || 0);
					break;
				case "participants":
					comparison =
						(a.stats?.participantCount || 0) -
						(b.stats?.participantCount || 0);
					break;
				case "license":
					const licenseOrder = {
						open: 0,
						invited: 1,
						location_based: 2,
					};
					comparison =
						licenseOrder[a.licenseType] -
						licenseOrder[b.licenseType];
					break;
			}

			return sortOrder === "asc" ? comparison : -comparison;
		});

		filteredEvents = filtered;
	});

	onMount(async () => {
		await setupSocketConnection();
		await loadEvents();
	});

	onDestroy(() => {
		cleanupSocketConnection();
	});

	async function setupSocketConnection() {
		try {
			if (!eventSocketService.isConnected()) {
				await eventSocketService.connect();
			}

			setupEventSocketListeners();

			eventSocketService.emit("join-events-room", {});

			isSocketConnected = true;
			socketRetryAttempts = 0;
		} catch (err) {
			console.error("Failed to set up socket connection:", err);
			isSocketConnected = false;

			if (socketRetryAttempts < maxSocketRetries) {
				socketRetryAttempts++;
				setTimeout(() => {
					setupSocketConnection();
				}, 3000);
			} else {
				console.error(
					"Max socket retry attempts reached. Operating in offline mode.",
				);
				error =
					"Real-time updates unavailable. Please refresh the page to retry.";
			}
		}
	}

	function setupEventSocketListeners() {
		// Listen for event creation, updates, deletions
		eventSocketService.on("event-created", handleEventCreated);
		eventSocketService.on("event-updated", handleEventUpdated);
		eventSocketService.on("event-deleted", handleEventDeleted);
	}

	function cleanupSocketConnection() {
		if (isSocketConnected) {
			// Remove listeners
			eventSocketService.off("event-created", handleEventCreated);
			eventSocketService.off("event-updated", handleEventUpdated);
			eventSocketService.off("event-deleted", handleEventDeleted);
			isSocketConnected = false;
		}
	}

	// Socket event handlers for real-time updates
	function handleEventCreated(data: { event: Event }) {
		events = [...events, data.event];
	}

	function handleEventUpdated(data: { event: Event }) {
		events = events.map((e) => (e.id === data.event.id ? data.event : e));
	}

	function handleEventDeleted(data: { eventId: string }) {
		events = events.filter((e) => e.id !== data.eventId);
	}

	async function loadEvents() {
		loading = true;
		error = "";
		try {
			if (activeTab === "mine" && user) {
				// Use dedicated "my events" endpoint for authenticated users
				events = await getMyEvents();
			} else {
				// Use general events endpoint (includes public + accessible private events)
				events = await getEvents();
			}
		} catch (err) {
			error = "Failed to load events";
			console.error(err);
		} finally {
			loading = false;
		}
	}

	async function createEvent(event: SubmitEvent) {
		event.preventDefault();
		if (!user) {
			goto("/auth/login");
			return;
		}

		// Validate dates
		formErrors = { eventDate: "", eventEndDate: "" };
		let hasErrors = false;

		if (newEvent.eventDate) {
			const startDate = new Date(newEvent.eventDate);
			const now = new Date();

			if (startDate <= now) {
				formErrors.eventDate = "Event start date must be in the future";
				hasErrors = true;
			}

			if (newEvent.eventEndDate) {
				const endDate = new Date(newEvent.eventEndDate);
				if (endDate <= startDate) {
					formErrors.eventEndDate =
						"Event end date must be after start date";
					hasErrors = true;
				}
			}
		}

		if (hasErrors) return;

		loading = true;
		error = "";

		try {
			// Convert local datetime to ISO string with timezone offset
			const eventDataToSend = { ...newEvent };

			if (eventDataToSend.eventDate) {
				eventDataToSend.eventDate = convertLocalDateTimeToISO(
					eventDataToSend.eventDate,
				);
			}

			if (eventDataToSend.eventEndDate) {
				eventDataToSend.eventEndDate = convertLocalDateTimeToISO(
					eventDataToSend.eventEndDate,
				);
			}

			const newEventResponse = await createEventAPI(eventDataToSend);
			showCreateModal = false;
			// Reset form
			newEvent = {
				name: "",
				description: "",
				visibility: "public",
				licenseType: "open",
				eventDate: "",
				eventEndDate: "",
				locationName: "",
			};
			formErrors = { eventDate: "", eventEndDate: "" };
		} catch (err: any) {
			error =
				err instanceof Error ? err.message : "Failed to create event";
		} finally {
			loading = false;
		}
	}

	function formatEventDate(dateString: string) {
		const date = new Date(dateString);
		const now = new Date();
		const currentYear = now.getFullYear();
		const eventYear = date.getFullYear();

		const options: Intl.DateTimeFormatOptions = {
			month: "short",
			day: "numeric",
			hour: "2-digit",
			minute: "2-digit",
		};

		// Add year only if it's different from current year
		if (eventYear !== currentYear) {
			options.year = "numeric";
		}

		return date.toLocaleDateString("en-US", options);
	}

	function getEventDuration(startDate: string, endDate?: string) {
		if (!endDate) return "";

		const start = new Date(startDate);
		const end = new Date(endDate);
		const diffMs = end.getTime() - start.getTime();
		const diffHours = Math.round(diffMs / (1000 * 60 * 60));

		if (diffHours < 24) {
			return `${diffHours}h`;
		} else {
			const days = Math.floor(diffHours / 24);
			const hours = diffHours % 24;
			return hours > 0 ? `${days}d ${hours}h` : `${days}d`;
		}
	}

	function handleTabChange(newTab: "all" | "mine") {
		if (activeTab !== newTab) {
			activeTab = newTab;

			const url = new URL(window.location.href);
			if (activeTab === "all") {
				url.searchParams.delete("tab");
			} else {
				url.searchParams.set("tab", activeTab);
			}
			replaceState(url.href, {});
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

	function getSortIcon(column: typeof sortBy) {
		if (sortBy !== column) return "↕";
		return sortOrder === "asc" ? "↑" : "↓";
	}

	function clearDateError(field: "eventDate" | "eventEndDate") {
		formErrors[field] = "";
	}

	// Helper function to convert datetime-local value to ISO string with timezone
	function convertLocalDateTimeToISO(dateTimeLocal: string): string {
		if (!dateTimeLocal) return "";
		const localDate = new Date(dateTimeLocal);
		return localDate.toISOString();
	}
</script>

<svelte:head>
	<title>Events - Music Room</title>
	<meta
		name="description"
		content="Join live music events and vote for tracks"
	/>
</svelte:head>

<div class="container mx-auto px-4 py-8">
	<div
		class="flex flex-col md:flex-row text-center md:text-start justify-between items-center mb-8"
	>
		<div>
			<h1 class="font-family-main text-4xl font-bold text-gray-800 mb-2">
				Music Events
			</h1>
			<p class="text-gray-600">
				Join live music events and vote for the next tracks
			</p>
		</div>

		{#if user}
			<div class="flex space-x-3 mt-4 md:mt-0">
				<button
					onclick={() => loadEvents()}
					class="bg-gray-100 text-gray-700 px-4 py-3 rounded-lg font-medium hover:bg-gray-200 transition-colors"
					title="Refresh events"
					aria-label="Refresh events"
				>
					<svg class="w-5 h-5" fill="none" stroke="currentColor" viewBox="0 0 24 24">
						<path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M4 4v5h.582m15.356 2A8.001 8.001 0 004.582 9m0 0H9m11 11v-5h-.581m0 0a8.003 8.003 0 01-15.357-2m15.357 2H15"></path>
					</svg>
				</button>
				<button
					onclick={() => (showCreateModal = true)}
					class="bg-secondary text-white px-6 py-3 rounded-lg font-semibold hover:bg-secondary/80 transition-colors"
				>
					Create Event
				</button>
			</div>
		{/if}
	</div>

	<!-- Tab Navigation -->
	<div class="flex space-x-4 mb-6">
		<button
			class="px-4 py-2 rounded-lg font-medium transition-colors {activeTab ===
			'all'
				? 'bg-secondary text-white'
				: 'bg-gray-200 text-gray-700 hover:bg-gray-300'}"
			onclick={() => handleTabChange("all")}
		>
			All Events
		</button>
		{#if user}
			<button
				class="px-4 py-2 rounded-lg font-medium transition-colors {activeTab ===
				'mine'
					? 'bg-secondary text-white'
					: 'bg-gray-200 text-gray-700 hover:bg-gray-300'}"
				onclick={() => handleTabChange("mine")}
			>
				My Events
			</button>
		{/if}
	</div>

	<!-- Search and Sort Controls -->
	<div class="bg-white rounded-lg shadow-sm border border-gray-200 p-4 mb-6">
		<div
			class="flex flex-col md:flex-row gap-4 items-start sm:items-center justify-between"
		>
			<!-- Search -->
			<div class="flex-1 w-full sm:max-w-md">
				<label for="search" class="sr-only">Search events</label>
				<div class="relative">
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
						id="search"
						type="text"
						bind:value={searchQuery}
						placeholder="Search events by name, creator, or location..."
						class="block w-full pl-10 pr-3 py-2 border border-gray-300 rounded-lg focus:outline-none focus:ring-2 focus:ring-secondary focus:border-transparent"
					/>
				</div>
			</div>

			<!-- Sort Controls -->
			<div class="flex items-center space-x-4">
				<span class="text-sm text-gray-600 font-medium hidden lg:block"
					>Sort by:</span
				>
				<button
					onclick={() => handleSort("date")}
					class="px-3 py-1 text-sm rounded-md transition-colors {sortBy ===
					'date'
						? 'bg-secondary text-white'
						: 'bg-gray-100 text-gray-700 hover:bg-gray-200'}"
				>
					Date {getSortIcon("date")}
				</button>
				<button
					onclick={() => handleSort("tracks")}
					class="px-3 py-1 text-sm rounded-md transition-colors {sortBy ===
					'tracks'
						? 'bg-secondary text-white'
						: 'bg-gray-100 text-gray-700 hover:bg-gray-200'}"
				>
					Tracks {getSortIcon("tracks")}
				</button>
				<button
					onclick={() => handleSort("participants")}
					class="px-3 py-1 text-sm rounded-md transition-colors {sortBy ===
					'participants'
						? 'bg-secondary text-white'
						: 'bg-gray-100 text-gray-700 hover:bg-gray-200'}"
				>
					Participants {getSortIcon("participants")}
				</button>
				<button
					onclick={() => handleSort("license")}
					class="px-3 py-1 text-sm rounded-md transition-colors {sortBy ===
					'license'
						? 'bg-secondary text-white'
						: 'bg-gray-100 text-gray-700 hover:bg-gray-200'}"
				>
					License {getSortIcon("license")}
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
	{:else if filteredEvents.length === 0}
		<div class="text-center py-12">
			<h3 class="text-xl font-semibold text-gray-700 mb-2">
				{#if searchQuery.trim()}
					No events found matching "{searchQuery.trim()}"
				{:else}
					No events found
				{/if}
			</h3>
			<p class="text-gray-500 mb-4">
				{#if activeTab === "mine"}
					You haven't created any events yet, and you haven't joined
					any.
				{:else}
					Be the first to create an event!
				{/if}
			</p>
			{#if user}
				<button
					onclick={() => (showCreateModal = true)}
					class="bg-secondary text-white px-6 py-2 rounded-lg font-medium hover:bg-secondary/80 transition-colors"
				>
					Create Event
				</button>
			{/if}
		</div>
	{:else}
		<!-- Events List -->
		<div
			class="bg-white rounded-lg shadow-sm border border-gray-200 overflow-hidden"
		>
			{#each filteredEvents as event, index}
				<div
					class="border-b border-gray-200 last:border-b-0 transition-colors relative {event.status ===
					'live'
						? 'bg-red-50 border-red-200 shadow-md'
						: 'hover:bg-gray-50'}"
				>
					{#if event.status === "live"}
						<div
							class="absolute left-0 top-0 bottom-0 w-1 bg-red-500 animate-pulse"
						></div>
					{/if}
					<a
						href="/events/{event.id}"
						class="block p-6 hover:no-underline {event.status ===
						'live'
							? 'hover:bg-red-100'
							: ''}"
					>
						<div class="flex items-start sm:space-x-4 space-x-2">
							<!-- Event Icon -->
							<div class="flex-shrink-0">
								<div
									class="w-16 h-16 bg-gradient-to-br from-secondary/20 to-purple-300 rounded-lg flex items-center justify-center relative"
								>
									{#if event.status === "live"}
										<div
											class="absolute -top-1 -right-1 w-4 h-4 bg-red-500 rounded-full animate-pulse"
										></div>
										<div
											class="absolute inset-0 bg-red-500/20 rounded-lg animate-pulse"
										></div>
									{/if}
									<svg
										class="w-8 h-8 text-white relative z-10"
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
							</div>

							<!-- Event Info -->
							<div class="flex-1 min-w-0">
								<div
									class="flex items-start justify-between mb-2"
								>
									<div class="flex-1 min-w-0">
										<h3
											class="text-lg font-semibold text-gray-900 truncate"
										>
											{event.name}
										</h3>
										<p class="text-sm text-gray-600">
											by {event.creator?.displayName ||
												"Unknown"}
										</p>
									</div>
									<div
										class="flex flex-col space-y-2 md:flex-row md:space-x-2 md:space-y-0 items-center ml-4"
									>
										{#if event.status === "live"}
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

								{#if event.description}
									<p
										class="text-sm text-gray-600 mb-2 line-clamp-2 hidden sm:block hyphens-auto break-all truncate"
									>
										{event.description}
									</p>
								{/if}

								<div
									class="flex items-center space-x-6 text-sm text-gray-500 hidden sm:flex"
								>
									{#if event.locationName}
										<div class="flex items-center">
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
													d="M17.657 16.657L13.414 20.9a1.998 1.998 0 01-2.827 0l-4.244-4.243a8 8 0 1111.314 0z"
												></path>
												<path
													stroke-linecap="round"
													stroke-linejoin="round"
													stroke-width="2"
													d="M15 11a3 3 0 11-6 0 3 3 0 016 0z"
												></path>
											</svg>
											<span>{event.locationName}</span>
										</div>
									{/if}
									<div class="flex items-center">
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
												d="M17 20h5v-2a3 3 0 00-5.356-1.857M17 20H7m10 0v-2c0-.656-.126-1.283-.356-1.857M7 20H2v-2a3 3 0 015.356-1.857M7 20v-2c0-.656.126-1.283.356-1.857m0 0a5.002 5.002 0 019.288 0M15 7a3 3 0 11-6 0 3 3 0 016 0zm6 3a2 2 0 11-4 0 2 2 0 014 0zM7 10a2 2 0 11-4 0 2 2 0 014 0z"
											></path>
										</svg>
										<span
											>{event.stats?.participantCount ||
												event.participants.length} participants</span
										>
									</div>
									<div class="flex items-center">
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
												d="M9 19V6l12-3v13M9 19c0 1.105-1.343 2-3 2s-3-.895-3-2 1.343-2 3-2 3 .895 3 2z"
											></path>
										</svg>
										<span
											>{event.stats?.trackCount ||
												event.playlist?.length ||
												0} tracks</span
										>
									</div>
									{#if event.eventDate}
										<div class="flex items-center">
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
													d="M8 7V3m8 4V3m-9 8h10M5 21h14a2 2 0 002-2V7a2 2 0 00-2-2H5a2 2 0 00-2 2v12a2 2 0 002 2z"
												></path>
											</svg>
											<span
												>{formatEventDate(
													event.eventDate,
												)}</span
											>
											{#if event.eventEndDate}
												<span
													class="ml-1 text-xs text-gray-400"
													>({getEventDuration(
														event.eventDate,
														event.eventEndDate,
													)})</span
												>
											{/if}
										</div>
									{/if}
								</div>
							</div>

							<!-- Arrow indicator -->
							<div
								class="flex-shrink-0 hidden sm:flex items-center"
							>
								<svg
									class="w-5 h-5 text-gray-400"
									fill="none"
									stroke="currentColor"
									viewBox="0 0 24 24"
								>
									<path
										stroke-linecap="round"
										stroke-linejoin="round"
										stroke-width="2"
										d="M9 5l7 7-7 7"
									></path>
								</svg>
							</div>
						</div>
					</a>
				</div>
			{/each}
		</div>

		<!-- Results count -->
		<div class="mt-4 text-sm text-gray-600 text-center">
			Showing {filteredEvents.length} event{filteredEvents.length !== 1
				? "s"
				: ""}
			{#if searchQuery.trim()}
				matching "{searchQuery.trim()}"
			{/if}
		</div>
	{/if}
</div>

<!-- Create Event Modal -->
{#if showCreateModal}
	<div
		class="fixed inset-0 bg-black/50 z-51 flex items-center justify-center z-50 p-4"
	>
		<div
			class="bg-white rounded-lg max-w-2xl w-full max-h-[90vh] overflow-y-auto"
		>
			<div class="p-6">
				<div class="flex justify-between items-center mb-6">
					<h2 class="text-2xl font-bold text-gray-800">
						Create New Event
					</h2>
					<button
						onclick={() => (showCreateModal = false)}
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

				<form onsubmit={createEvent} class="space-y-6">
					<!-- Basic Information -->
					<div class="space-y-4">
						<h3
							class="text-lg font-semibold text-gray-800 border-b border-gray-200 pb-2"
						>
							Basic Information
						</h3>

						<div>
							<label
								for="event-name"
								class="block text-sm font-medium text-gray-700 mb-2"
								>Event Name *</label
							>
							<input
								id="event-name"
								type="text"
								bind:value={newEvent.name}
								required
								class="w-full px-4 py-3 border border-gray-300 rounded-lg focus:outline-none focus:ring-2 focus:ring-secondary focus:border-transparent"
								placeholder="Enter a catchy event name"
							/>
						</div>

						<div>
							<label
								for="event-description"
								class="block text-sm font-medium text-gray-700 mb-2"
								>Description</label
							>
							<textarea
								id="event-description"
								bind:value={newEvent.description}
								rows="4"
								class="w-full px-4 py-3 border border-gray-300 rounded-lg focus:outline-none focus:ring-2 focus:ring-secondary focus:border-transparent"
								placeholder="Describe your event, the music style, and what participants can expect"
							></textarea>
						</div>
					</div>

					<!-- Date & Time -->
					<div class="space-y-4">
						<h3
							class="text-lg font-semibold text-gray-800 border-b border-gray-200 pb-2"
						>
							Date & Time
						</h3>

						<div class="grid grid-cols-1 md:grid-cols-2 gap-4">
							<div>
								<label
									for="event-start"
									class="block text-sm font-medium text-gray-700 mb-2"
									>Start Date & Time</label
								>
								<input
									id="event-start"
									type="datetime-local"
									bind:value={newEvent.eventDate}
									oninput={() => clearDateError("eventDate")}
									class="w-full px-4 py-3 border border-gray-300 rounded-lg focus:outline-none focus:ring-2 focus:ring-secondary focus:border-transparent {formErrors.eventDate
										? 'border-red-500'
										: ''}"
								/>
								{#if formErrors.eventDate}
									<p class="text-red-500 text-xs mt-1">
										{formErrors.eventDate}
									</p>
								{/if}
							</div>

							<div>
								<label
									for="event-end"
									class="block text-sm font-medium text-gray-700 mb-2"
									>End Date & Time</label
								>
								<input
									id="event-end"
									type="datetime-local"
									bind:value={newEvent.eventEndDate}
									oninput={() =>
										clearDateError("eventEndDate")}
									class="w-full px-4 py-3 border border-gray-300 rounded-lg focus:outline-none focus:ring-2 focus:ring-secondary focus:border-transparent {formErrors.eventEndDate
										? 'border-red-500'
										: ''}"
								/>
								{#if formErrors.eventEndDate}
									<p class="text-red-500 text-xs mt-1">
										{formErrors.eventEndDate}
									</p>
								{/if}
							</div>
						</div>
					</div>

					<!-- Event Settings -->
					<div class="space-y-4">
						<h3
							class="text-lg font-semibold text-gray-800 border-b border-gray-200 pb-2"
						>
							Event Settings
						</h3>

						<div>
							<label
								for="event-visibility"
								class="block text-sm font-medium text-gray-700 mb-2"
								>Visibility</label
							>
							<select
								id="event-visibility"
								bind:value={newEvent.visibility}
								class="w-full px-4 py-3 border border-gray-300 rounded-lg focus:outline-none focus:ring-2 focus:ring-secondary focus:border-transparent"
							>
								<option value="public"
									>Public - Anyone can discover and join</option
								>
								<option value="private"
									>Private - Invitation only</option
								>
							</select>
						</div>

						<div>
							<label
								for="event-license"
								class="block text-sm font-medium text-gray-700 mb-2"
								>Voting License</label
							>
							<select
								id="event-license"
								bind:value={newEvent.licenseType}
								class="w-full px-4 py-3 border border-gray-300 rounded-lg focus:outline-none focus:ring-2 focus:ring-secondary focus:border-transparent"
							>
								<option
									value="open"
									disabled={newEvent.visibility === "private"}
									>Open - Anyone can vote (public only)</option
								>
								<option value="invited"
									>Invited Only - Restrict voting to invited
									participants</option
								>
								<option value="location_based"
									>Location Based - Voting restricted by
									location and time</option
								>
							</select>
							<p class="text-xs text-gray-500 mt-1">
								Choose who can participate in voting for tracks
							</p>
						</div>
						<div>
							<label
								for="event-max-votes"
								class="block text-sm font-medium text-gray-700 mb-2"
								>Max Votes Per Participant</label
							>
							<input
								type="number"
								min="0"
								bind:value={newEvent.maxVotesPerUser}
								class="w-full px-4 py-3 border border-gray-300 rounded-lg focus:outline-none focus:ring-2 focus:ring-secondary focus:border-transparent"
								placeholder="1 by default"
							/>
							<p class="text-xs text-gray-500 mt-1">
								Set to 0 for unlimited votes per user
							</p>
						</div>
					</div>

					<!-- Location-based Settings (conditional) -->
					{#if newEvent.licenseType === "location_based"}
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
									bind:value={newEvent.locationName}
									class="w-full px-4 py-3 border border-gray-300 rounded-lg focus:outline-none focus:ring-2 focus:ring-secondary focus:border-transparent"
									placeholder="Where is your event taking place?"
								/>
							</div>

							<div class="grid grid-cols-1 md:grid-cols-2 gap-4">
								<div>
									<label
										for="latitude"
										class="block text-sm font-medium text-gray-700 mb-2"
										>Latitude</label
									>
									<input
										id="latitude"
										type="number"
										bind:value={newEvent.latitude}
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
										bind:value={newEvent.longitude}
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
									bind:value={newEvent.locationRadius}
									min="10"
									max="10000"
									class="w-full px-4 py-3 border border-gray-300 rounded-lg focus:outline-none focus:ring-2 focus:ring-secondary focus:border-transparent"
									placeholder="e.g., 100"
								/>
								<p class="text-xs text-gray-500 mt-1">
									Users must be within this radius to vote
								</p>
							</div>

							<div class="grid grid-cols-1 md:grid-cols-2 gap-4">
								<div>
									<label
										for="voting-start"
										class="block text-sm font-medium text-gray-700 mb-2"
										>Voting Start Time</label
									>
									<input
										id="voting-start"
										type="time"
										bind:value={newEvent.votingStartTime}
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
										bind:value={newEvent.votingEndTime}
										class="w-full px-4 py-3 border border-gray-300 rounded-lg focus:outline-none focus:ring-2 focus:ring-secondary focus:border-transparent"
									/>
								</div>
							</div>
						</div>
					{/if}

					<div class="flex space-x-4 pt-6 border-t border-gray-200">
						<button
							type="button"
							onclick={() => (showCreateModal = false)}
							class="flex-1 px-6 py-3 border border-gray-300 text-gray-700 rounded-lg hover:bg-gray-50 transition-colors font-medium"
						>
							Cancel
						</button>
						<button
							type="submit"
							disabled={loading}
							class="flex-1 bg-secondary text-white px-6 py-3 rounded-lg hover:bg-secondary/80 disabled:opacity-50 transition-colors font-medium"
						>
							{loading ? "Creating..." : "Create Event"}
						</button>
					</div>
				</form>
			</div>
		</div>
	</div>
{/if}
