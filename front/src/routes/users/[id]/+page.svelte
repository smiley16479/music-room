<svelte:head>
	<title>{data.userProfile.displayName || 'User'} - Music Room</title>
	<meta name="description" content="View {data.userProfile.displayName || 'User'}'s public profile" />
</svelte:head>

<script lang="ts">
	import { goto } from '$app/navigation';
	import { authStore } from '$lib/stores/auth';
	import { friendsService } from '$lib/services/friends';
	import { generateGenericAvatar } from '$lib/utils/avatar';
	import type { PublicUserProfile } from '$lib/services/user';
	import BackNavBtn from '$lib/components/BackNavBtn.svelte';

	let { data } = $props();
	let userProfile: PublicUserProfile = $state(data.userProfile);
	let isAlreadyFriend = $state(data.isAlreadyFriend);
	let currentUser = $derived($authStore);
	let loading = $state(false);
	let error = $state('');
	let success = $state('');
	let hasPendingInvitation = $state(false);

	// Check if this is the current user's own profile
	let isOwnProfile = $derived(currentUser && currentUser.id === userProfile.id);

	// Check for pending invitations on mount
	$effect(() => {
		if (currentUser && !isOwnProfile && !isAlreadyFriend) {
			checkPendingInvitation();
		}
	});

	async function checkPendingInvitation() {
		try {
			const sentInvitations = await friendsService.getSentInvitations();
			hasPendingInvitation = sentInvitations.some(inv => inv.invitee.id === userProfile.id);
		} catch (e) {
			// Ignore errors when checking invitations
		}
	}

	async function sendFriendInvitation() {
		if (!currentUser) {
			goto('/auth/login');
			return;
		}

		loading = true;
		error = '';
		
		try {
			await friendsService.sendInvitation(userProfile.id);
			hasPendingInvitation = true;
			success = 'Friend request sent successfully!';
			setTimeout(() => success = '', 5000);
		} catch (e: any) {
			error = e.message || 'Failed to send friend request';
		} finally {
			loading = false;
		}
	}

	function formatDate(dateString: string | undefined): string {
		if (!dateString) return '';
		return new Date(dateString).toLocaleDateString();
	}

	function formatLastSeen(lastSeen: string | undefined): string {
		if (!lastSeen) return '';
		
		const now = new Date();
		const lastSeenDate = new Date(lastSeen);
		const diffInMinutes = Math.floor((now.getTime() - lastSeenDate.getTime()) / (1000 * 60));
		
		if (diffInMinutes < 5) {
			return 'Active now';
		} else if (diffInMinutes < 60) {
			return `Last seen ${diffInMinutes} minutes ago`;
		} else if (diffInMinutes < 1440) {
			const hours = Math.floor(diffInMinutes / 60);
			return `Last seen ${hours} hour${hours > 1 ? 's' : ''} ago`;
		} else {
			const days = Math.floor(diffInMinutes / 1440);
			return `Last seen ${days} day${days > 1 ? 's' : ''} ago`;
		}
	}
</script>

<div class="container mx-auto px-4 py-8">
	<BackNavBtn />

	<!-- Profile Header -->
	<div class="bg-white rounded-lg shadow-sm border border-gray-200 p-8 mb-8">
		<div class="flex flex-col md:flex-row md:items-center gap-6">
			<!-- Avatar -->
			<div class="flex-shrink-0">
				<img
					src={userProfile.avatarUrl || generateGenericAvatar(userProfile.displayName || 'User')}
					alt={userProfile.displayName || 'User'}
					class="w-24 h-24 rounded-full object-cover border-4 border-gray-100"
					onerror={(e) => {
						const target = e.target as HTMLImageElement;
						if (target) target.src = generateGenericAvatar(userProfile.displayName || 'User');
					}}
				/>
			</div>

			<!-- Profile Info -->
			<div class="flex-1">
				<div class="flex flex-col sm:flex-row sm:items-start sm:justify-between gap-4">
					<div>
						<h1 class="text-3xl font-bold text-gray-900">
							{userProfile.displayName || 'Unknown User'}
						</h1>
						
						{#if userProfile.bio}
							<p class="text-gray-600 mt-2 text-lg">
								{userProfile.bio}
							</p>
						{/if}

						<div class="flex flex-wrap gap-4 mt-4 text-sm text-gray-500">
							{#if userProfile.location}
								<div class="flex items-center">
									<svg class="w-4 h-4 mr-1" fill="none" stroke="currentColor" viewBox="0 0 24 24">
										<path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M17.657 16.657L13.414 20.9a1.998 1.998 0 01-2.827 0l-4.244-4.243a8 8 0 1111.314 0z" />
										<path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M15 11a3 3 0 11-6 0 3 3 0 016 0z" />
									</svg>
									{userProfile.location}
								</div>
							{/if}

							{#if userProfile.createdAt}
								<div class="flex items-center">
									<svg class="w-4 h-4 mr-1" fill="none" stroke="currentColor" viewBox="0 0 24 24">
										<path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M8 7V3m8 4V3m-9 8h10M5 21h14a2 2 0 002-2V7a2 2 0 00-2-2H5a2 2 0 00-2 2v12a2 2 0 002 2z" />
									</svg>
									Joined {formatDate(userProfile.createdAt)}
								</div>
							{/if}

							{#if userProfile.lastSeen}
								<div class="flex items-center">
									<div class="w-2 h-2 rounded-full bg-green-500 mr-2"></div>
									{formatLastSeen(userProfile.lastSeen)}
								</div>
							{/if}
						</div>
					</div>

					<!-- Action Buttons -->
					<div class="flex flex-col gap-3">
						{#if isOwnProfile}
							<a
								href="/profile"
								class="bg-secondary text-white px-6 py-2 rounded-lg text-center font-medium hover:bg-secondary/80 transition-colors"
							>
								Edit Profile
							</a>
						{:else if currentUser}
							{#if isAlreadyFriend}
								<div class="flex items-center px-6 py-2 bg-green-50 border border-green-200 rounded-lg text-green-700">
									<svg class="w-5 h-5 mr-2" fill="none" stroke="currentColor" viewBox="0 0 24 24">
										<path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M5 13l4 4L19 7" />
									</svg>
									Friends
								</div>
							{:else if hasPendingInvitation}
								<div class="px-6 py-2 bg-yellow-50 border border-yellow-200 rounded-lg text-yellow-700 text-center">
									Friend Request Sent
								</div>
							{:else}
								<button
									onclick={sendFriendInvitation}
									disabled={loading}
									class="bg-secondary text-white px-6 py-2 rounded-lg font-medium hover:bg-secondary/80 transition-colors disabled:opacity-50 disabled:cursor-not-allowed"
								>
									{loading ? 'Sending...' : 'Send Friend Request'}
								</button>
							{/if}
						{:else}
							<a
								href="/auth/login"
								class="bg-secondary text-white px-6 py-2 rounded-lg text-center font-medium hover:bg-secondary/80 transition-colors"
							>
								Log in to Connect
							</a>
						{/if}
					</div>
				</div>
			</div>
		</div>
	</div>

	<!-- Success/Error Messages -->
	{#if success}
		<div class="mb-6 p-4 bg-green-100 border border-green-300 text-green-700 rounded-lg">
			{success}
		</div>
	{/if}
	{#if error}
		<div class="mb-6 p-4 bg-red-100 border border-red-300 text-red-700 rounded-lg">
			{error}
		</div>
	{/if}

	<!-- Music Preferences -->
	{#if userProfile.musicPreferences && (userProfile.musicPreferences.favoriteGenres?.length || userProfile.musicPreferences.favoriteArtists?.length)}
		<div class="bg-white rounded-lg shadow-sm border border-gray-200 p-6">
			<h2 class="text-xl font-bold text-gray-900 mb-4">Music Preferences</h2>
			
			{#if userProfile.musicPreferences.favoriteGenres?.length}
				<div class="mb-6">
					<h3 class="text-sm font-medium text-gray-700 mb-3">Favorite Genres</h3>
					<div class="flex flex-wrap gap-2">
						{#each userProfile.musicPreferences.favoriteGenres as genre}
							<span class="px-3 py-1 bg-secondary/10 text-secondary rounded-full text-sm font-medium">
								{genre}
							</span>
						{/each}
					</div>
				</div>
			{/if}

			{#if userProfile.musicPreferences.favoriteArtists?.length}
				<div>
					<h3 class="text-sm font-medium text-gray-700 mb-3">Favorite Artists</h3>
					<div class="flex flex-wrap gap-2">
						{#each userProfile.musicPreferences.favoriteArtists as artist}
							<span class="px-3 py-1 bg-purple-100 text-purple-800 rounded-full text-sm font-medium">
								{artist}
							</span>
						{/each}
					</div>
				</div>
			{/if}
		</div>
	{/if}
</div>
