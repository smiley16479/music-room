<script lang="ts">
	import { authStore } from '$lib/stores/auth';
	import { friendsService, type Friend } from '$lib/services/friends';
	import { userService, type User } from '$lib/services/users';
	import { playlistsService } from '$lib/services/playlists';
	import * as eventsService from '$lib/services/events';
	import { getAvatarColor, getAvatarLetter } from '$lib/utils/avatar';
	import { onMount } from 'svelte';

	// Props - support both playlist collaborators and event participants
	let { 
		playlistId = undefined,
		eventId = undefined,
		onCollaboratorAdded = () => {},
		onParticipantAdded = () => {},
		onClose = () => {}
	}: {
		playlistId?: string;
		eventId?: string;
		onCollaboratorAdded?: () => void;
		onParticipantAdded?: () => void;
		onClose?: () => void;
	} = $props();

	const currentUser = $derived($authStore);
	
	// Determine if this is for playlist or event
	const isPlaylistMode = $derived(!!playlistId);
	const isEventMode = $derived(!!eventId);

	// Tab state
	let activeTab = $state<'friends' | 'search'>('friends');
	
	// Friends data
	let friends = $state<Friend[]>([]);
	let loadingFriends = $state(false);

	// Search data
	let searchQuery = $state('');
	let searchResults = $state<User[]>([]);
	let loadingSearch = $state(false);
	let searchDebounceTimer: ReturnType<typeof setTimeout> | null = null;

	// Direct input data
	let directInput = $state('');

	// General state
	let adding = $state(false);
	let error = $state('');

	onMount(async () => {
		await loadFriends();
	});

	async function loadFriends() {
		if (loadingFriends) return;
		
		loadingFriends = true;
		try {
			friends = await friendsService.getFriends();
		} catch (err) {
			console.error('Failed to load friends:', err);
			friends = [];
		} finally {
			loadingFriends = false;
		}
	}

	async function searchUsers(query: string) {
		if (!query.trim()) {
			searchResults = [];
			return;
		}

		loadingSearch = true;
		try {
			searchResults = await userService.searchUsers(query.trim(), 10);
		} catch (err) {
			console.error('Failed to search users:', err);
			searchResults = [];
		} finally {
			loadingSearch = false;
		}
	}

	function handleSearchInput() {
		if (searchDebounceTimer) {
			clearTimeout(searchDebounceTimer);
		}
		
		searchDebounceTimer = setTimeout(() => {
			searchUsers(searchQuery);
		}, 300);
	}

	async function addCollaborator(userId: string, displayName: string) {
		if (adding) return;

		adding = true;
		error = '';

		try {
			if (isPlaylistMode) {
				await playlistsService.addCollaborator(playlistId!, userId);
				onCollaboratorAdded();
			} else if (isEventMode) {
				// For events, add the user as a collaborator to the event's playlist
				// This grants them access to the private event through playlist collaboration
				const event = await eventsService.getEvent(eventId!);
				if (!event.playlistId) {
					throw new Error('Event playlist not found');
				}
				await playlistsService.addCollaborator(event.playlistId, userId);
				onParticipantAdded();
			}
			onClose();
		} catch (err) {
			error = err instanceof Error ? err.message : `Failed to ${isPlaylistMode ? 'add collaborator' : 'invite to event'}`;
		} finally {
			adding = false;
		}
	}

	async function handleDirectAdd() {
		if (!directInput.trim()) return;

		const input = directInput.trim();
		error = '';

		try {
			let userId: string;
			let displayName: string;

			// Check if it's an email
			if (input.includes('@')) {
				const user = await userService.getUserByEmail(input);
				if (!user) {
					error = 'User not found with this email';
					return;
				}
				userId = user.id;
				displayName = user.displayName;
			} 
			// Check if it's a valid UUID (user ID)
			else if (input.match(/^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$/i)) {
				const user = await userService.getUserById(input);
				userId = user.id;
				displayName = user.displayName;
			}
			// Try searching as display name
			else {
				const users = await userService.searchUsers(input, 1);
				if (users.length === 0) {
					error = 'User not found';
					return;
				}
				userId = users[0].id;
				displayName = users[0].displayName;
			}

			await addCollaborator(userId, displayName);
		} catch (err) {
			error = err instanceof Error ? err.message : `Failed to ${isPlaylistMode ? 'add collaborator' : 'invite to event'}`;
		}
	}

	function setTab(tab: 'friends' | 'search') {
		activeTab = tab;
		error = '';
		// Clear search when switching tabs
		if (tab !== 'search') {
			searchQuery = '';
			searchResults = [];
		}
	}

	// Dynamic text based on mode
	const modalTitle = $derived(isPlaylistMode ? 'Add Collaborator' : 'Invite to Event');
	const actionButtonText = $derived(isPlaylistMode ? 'Add Collaborator' : 'Invite');
	const addingText = $derived(isPlaylistMode ? 'Adding...' : 'Inviting...');
	const shortAddText = $derived(isPlaylistMode ? 'Add' : 'Invite');
	const emailPlaceholder = $derived(isPlaylistMode ? 'friend@example.com or user-id-123...' : 'participant@example.com or user-id-123...');
	const directInputDescription = $derived(isPlaylistMode ? 
		'You can enter an email address, user ID, or display name' : 
		'Invite users to access this private event by adding them as playlist collaborators'
	);
</script>

<div class="fixed inset-0 bg-black/50 z-51 flex items-center justify-center z-50 p-4">
	<div class="bg-white rounded-lg max-w-2xl w-full max-h-[80vh] overflow-hidden">
		<div class="p-6 border-b border-gray-200">
			<div class="flex justify-between items-center">
				<h2 class="text-xl font-bold text-gray-800">{modalTitle}</h2>
				<button 
					onclick={() => onClose()}
					aria-label="Close modal"
					class="text-gray-400 hover:text-gray-600"
				>
					<svg class="w-6 h-6" fill="none" stroke="currentColor" viewBox="0 0 24 24">
						<path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M6 18L18 6M6 6l12 12"></path>
					</svg>
				</button>
			</div>

			{#if isEventMode}
				<p class="text-sm text-gray-600 mt-2">
					Inviting users will grant them access to this private event by adding them as playlist collaborators.
				</p>
			{/if}

			<!-- Tab Navigation -->
			<div class="flex space-x-1 mt-4 bg-gray-100 rounded-lg p-1">
				<button 
					onclick={() => setTab('friends')}
					class="tab-button {activeTab === 'friends' ? 'active' : ''}"
				>
					Friends
				</button>
				<button 
					onclick={() => setTab('search')}
					class="tab-button {activeTab === 'search' ? 'active' : ''}"
				>
					Search Users
				</button>
			</div>
		</div>

		{#if error}
			<div class="mx-6 mt-4 p-3 bg-red-100 border border-red-400 text-red-700 rounded">
				{error}
			</div>
		{/if}

		<div class="p-6 overflow-y-auto max-h-96">
			{#if activeTab === 'friends'}
				<!-- Friends Tab -->
				<div class="space-y-3">
					{#if loadingFriends}
						<div class="text-center py-8">
							<div class="animate-spin rounded-full h-8 w-8 border-b-2 border-secondary mx-auto"></div>
							<p class="text-gray-500 mt-2">Loading friends...</p>
						</div>
					{:else if friends.length === 0}
						<div class="text-center py-8">
							<p class="text-gray-500">No friends found</p>
						</div>
					{:else}
						{#each friends as friend (friend.id)}
							<div class="flex items-center justify-between p-3 border border-gray-200 rounded-lg hover:bg-gray-50">
								<div class="flex items-center space-x-3">
									{#if friend.avatarUrl}
										<img src={friend.avatarUrl} alt={friend.displayName} class="w-10 h-10 rounded-full object-cover" />
									{:else}
										<div 
											class="w-10 h-10 rounded-full flex items-center justify-center"
											style="background-color: {getAvatarColor(friend.displayName)}"
										>
											<span class="text-sm font-semibold text-white">{getAvatarLetter(friend.displayName)}</span>
										</div>
									{/if}
									<div>
										<p class="font-medium text-gray-800">{friend.displayName}</p>
										{#if friend.bio}
											<p class="text-sm text-gray-500">{friend.bio}</p>
										{/if}
									</div>
								</div>
								<button 
									onclick={() => addCollaborator(friend.id, friend.displayName)}
									disabled={adding}
									class="bg-secondary text-white px-4 py-2 rounded-lg hover:bg-secondary/80 disabled:opacity-50"
								>
									{adding ? addingText : shortAddText}
								</button>
							</div>
						{/each}
					{/if}
				</div>

			{:else if activeTab === 'search'}
				<!-- Search Tab -->
				<div class="space-y-4">
					<div>
						<input 
							type="text" 
							bind:value={searchQuery}
							oninput={handleSearchInput}
							placeholder="Search by name or email..."
							class="w-full px-3 py-2 border border-gray-300 rounded-lg focus:outline-none focus:ring-2 focus:ring-secondary"
						/>
					</div>

					<div class="space-y-3">
						{#if loadingSearch}
							<div class="text-center py-4">
								<div class="animate-spin rounded-full h-6 w-6 border-b-2 border-secondary mx-auto"></div>
								<p class="text-gray-500 mt-2 text-sm">Searching...</p>
							</div>
						{:else if searchQuery && searchResults.length === 0}
							<div class="text-center py-4">
								<p class="text-gray-500">No users found</p>
							</div>
						{:else if searchResults.length > 0}
							{#each searchResults as user (user.id)}
								<div class="flex items-center justify-between p-3 border border-gray-200 rounded-lg hover:bg-gray-50">
									<div class="flex items-center space-x-3">
										{#if user.avatarUrl}
											<img src={user.avatarUrl} alt={user.displayName} class="w-10 h-10 rounded-full object-cover" />
										{:else}
											<div 
												class="w-10 h-10 rounded-full flex items-center justify-center"
												style="background-color: {getAvatarColor(user.displayName)}"
											>
												<span class="text-sm font-semibold text-white">{getAvatarLetter(user.displayName)}</span>
											</div>
										{/if}
										<div>
											<p class="font-medium text-gray-800">{user.displayName}</p>
											<p class="text-sm text-gray-500">{user.email}</p>
											{#if user.bio}
												<p class="text-xs text-gray-400">{user.bio}</p>
											{/if}
										</div>
									</div>
									<button 
										onclick={() => addCollaborator(user.id, user.displayName)}
										disabled={adding}
										class="bg-secondary text-white px-4 py-2 rounded-lg hover:bg-secondary/80 disabled:opacity-50"
									>
										{adding ? addingText : shortAddText}
									</button>
								</div>
							{/each}
						{/if}
					</div>
				</div>
			{/if}
		</div>
		<div class="p-6 border-t border-gray-200">
			<button 
				onclick={() => onClose()}
				class="w-full px-4 py-2 border border-gray-300 text-gray-700 rounded-lg hover:bg-gray-50"
			>
				Cancel
			</button>
		</div>
	</div>
</div>

<style>
	.tab-button {
		flex: 1;
		padding: 8px 16px;
		text-align: center;
		border-radius: 6px;
		font-weight: 500;
		transition: all 0.2s ease;
		color: #6b7280;
	}

	.tab-button:hover {
		background: white;
		color: #374151;
	}

	.tab-button.active {
		background: white;
		color: #1f2937;
		box-shadow: 0 1px 3px rgba(0, 0, 0, 0.1);
	}
</style>
