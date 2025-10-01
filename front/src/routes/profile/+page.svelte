<script lang="ts">
	import { onMount } from "svelte";
	import { config } from '$lib/config';
	import { goto } from "$app/navigation";
	import { friendsService, type Friend, type Invitation } from "$lib/services/friends";
	import { userService, type UserSearchResult } from "$lib/services/user";
	import { authStore } from "$lib/stores/auth";
	import { authService, type User } from "$lib/services/auth";
	import { generateGenericAvatar, getUserAvatarUrl } from "$lib/utils/avatar";

	// Visibility levels enum to match backend
	type VisibilityLevel = "public" | "friends" | "private";

	// Use the reactive auth store with proper store subscription
	let { data } = $props();
	let friends = $state<Friend[]>(data.friends || []);
	let pendingInvitations = $state<Invitation[]>(data.pendingInvitations || []);
	let sentInvitations = $state<Invitation[]>(data.sentInvitations || []);
	let searchResults = $state<UserSearchResult[]>([]);
	let searchQuery = $state("");
	let searchLoading = $state(false);
	let user = $state<User | null>(null);
	let loading = $state(false);
	let error = $state(data.error || "");
	let success = $state("");
	let activeTab = $state<"information" | "friends" | "music" | "accounts">("information");
	let friendsSubTab = $state<"list" | "pending" | "sent" | "search">("list");

	// Subscribe to auth store changes
	$effect(() => {
		const unsubscribe = authStore.subscribe((value) => {
			user = value;
		});
		return unsubscribe;
	});

	// Form data aligned with backend entity
	let profileData = $state({
		displayName: "",
		bio: "",
		avatarUrl: "",
		birthDate: "",
		location: "",
		displayNameVisibility: "public" as VisibilityLevel,
		bioVisibility: "public" as VisibilityLevel,
		birthDateVisibility: "friends" as VisibilityLevel,
		locationVisibility: "friends" as VisibilityLevel,
	});

	let musicPreferences = $state({
		favoriteGenres: [] as string[],
		favoriteArtists: [] as string[],
		dislikedGenres: [] as string[],
	});

	let passwordChangeData = $state({
		currentPassword: "",
		newPassword: "",
		confirmPassword: "",
	});

	let newGenre = $state("");
	let newArtist = $state("");
	let newDislikedGenre = $state("");
	let showPasswordChange = $state(false);

	// Common music genres
	const musicGenres = [
		"Rock",
		"Pop",
		"Hip Hop",
		"Jazz",
		"Classical",
		"Electronic",
		"Country",
		"R&B",
		"Reggae",
		"Blues",
		"Folk",
		"Indie",
		"Metal",
		"Funk",
		"Soul",
		"House",
		"Techno",
		"Trap",
		"Alternative",
		"Punk",
	];

	onMount(async () => {
		// Initialize auth store if not already done
		authStore.init();
		if (!user) {
			goto("/auth/login");
			return;
		}
		// Load current user data and populate form
		try {
			await authStore.refreshUser();
			if (user) {
				populateFormData(user);
			}
		} catch (err) {
			
		}
	});

	function populateFormData(userData: User) {
		// Map frontend User to backend entity structure - use direct properties
		profileData.displayName = userData.displayName || "";
		profileData.bio = userData.bio || "";
		profileData.avatarUrl = getProfilePictureUrl(userData);
		profileData.birthDate = userData.birthDate || "";
		profileData.location = userData.location || "";
		
		// Get visibility levels from user data or set defaults
		profileData.displayNameVisibility = userData.displayNameVisibility || "public";
		profileData.bioVisibility = userData.bioVisibility || "public";
		profileData.birthDateVisibility = userData.birthDateVisibility || "friends";
		profileData.locationVisibility = userData.locationVisibility || "friends";

		// Get music preferences correctly
		musicPreferences.favoriteGenres = userData.musicPreferences?.favoriteGenres || [];
		musicPreferences.favoriteArtists = userData.musicPreferences?.favoriteArtists || [];
		musicPreferences.dislikedGenres = userData.musicPreferences?.dislikedGenres || [];
	}

	function getProfilePictureUrl(userData: User): string {
		// Return the user's current avatar URL if it exists
		// This will be used to populate the form field, not for display
		if (userData.avatarUrl && !userData.avatarUrl.startsWith('data:image/svg+xml')) {
			return userData.avatarUrl;
		}
		
		// Return empty string - the backend now handles all avatar logic at creation
		// The preview will show the appropriate image based on the user's data
		return "";
	}

	async function updateProfile() {
		if (!user) return;

		loading = true;
		error = "";
		success = "";

		try {
			const updateData: any = {
				displayName: profileData.displayName,
				bio: profileData.bio,
				displayNameVisibility: profileData.displayNameVisibility,
				bioVisibility: profileData.bioVisibility,
				birthDateVisibility: profileData.birthDateVisibility,
				locationVisibility: profileData.locationVisibility,
				musicPreferences: {
					favoriteGenres: musicPreferences.favoriteGenres,
					favoriteArtists: musicPreferences.favoriteArtists,
					dislikedGenres: musicPreferences.dislikedGenres,
				},
			};

			// Only include optional fields if they're not empty
			if (profileData.birthDate && profileData.birthDate.trim() !== "") {
				updateData.birthDate = profileData.birthDate;
			}

			if (profileData.location && profileData.location.trim() !== "") {
				updateData.location = profileData.location;
			}

			// Only include avatarUrl if it's not empty and is a valid URL
			if (profileData.avatarUrl && profileData.avatarUrl.trim() !== "") {
				try {
					new URL(profileData.avatarUrl); // Validate URL format
					updateData.avatarUrl = profileData.avatarUrl;
				} catch (urlError) {
					error = "Please enter a valid URL for the profile picture";
					loading = false;
					return;
				}
			}

			const updatedUser = await authService.updateProfile(updateData);
			authStore.updateUser(updatedUser);
			success = "Profile updated successfully!";
			setTimeout(() => (success = ""), 3000);
		} catch (err) {
			error = err instanceof Error ? err.message : "Failed to update profile";
		} finally {
			loading = false;
		}
	}

	// Helper function to check if user is OAuth-only (no password)
	function isOAuthOnlyUser() {
		if (!user) return false;
		// Check if user has OAuth accounts - simplified logic
		return user.connectedAccounts?.google || user.connectedAccounts?.facebook;
	}

	async function changePassword() {
		if (!passwordChangeData.currentPassword || !passwordChangeData.newPassword) {
			error = "Please fill in all password fields";
			return;
		}

		if (passwordChangeData.newPassword !== passwordChangeData.confirmPassword) {
			error = "New passwords do not match";
			return;
		}

		if (passwordChangeData.newPassword.length < 6) {
			error = "New password must be at least 6 characters long";
			return;
		}

		loading = true;
		error = "";

		try {
			await authService.changePassword(
				passwordChangeData.currentPassword,
				passwordChangeData.newPassword
			);
			success = "Password changed successfully!";
			passwordChangeData = {
				currentPassword: "",
				newPassword: "",
				confirmPassword: "",
			};
			showPasswordChange = false;
			setTimeout(() => (success = ""), 3000);
		} catch (err) {
			error = err instanceof Error ? err.message : "Failed to change password";
		} finally {
			loading = false;
		}
	}

	async function linkSocialAccount(provider: "google" | "facebook") {
		if (!user) return;
		
		try {
			loading = true;
			error = "";
			success = "";
			
			// Get the current user's JWT token
			const token = localStorage.getItem('accessToken');
			if (!token) {
				throw new Error('You must be logged in to link accounts');
			}
			
			// Open OAuth popup window using the dedicated linking endpoints
			const popup = window.open(
				`${config.apiUrl}/api/auth/${provider}/link?token=${encodeURIComponent(token)}`,
				`${provider}_oauth`,
				'width=500,height=600,scrollbars=yes,resizable=yes'
			);
			
			if (!popup) {
				throw new Error('Popup blocked. Please allow popups for this site.');
			}
			
			// Listen for messages from the popup
			const handleMessage = (event: MessageEvent) => {
				// Check if message is from our backend
				if (!event.origin.includes(config.apiUrl.replace('/api', ''))) return;
				
				if (event.data.type === 'OAUTH_SUCCESS') {
					popup.close();
					success = `${provider} account linked successfully!`;
					authStore.refreshUser();
					window.removeEventListener('message', handleMessage);
					loading = false;
				} else if (event.data.type === 'OAUTH_ERROR') {
					popup.close();
					error = event.data.error || `Failed to link ${provider} account`;
					window.removeEventListener('message', handleMessage);
					loading = false;
				}
			};
			
			window.addEventListener('message', handleMessage);
			
			// Check if popup was closed manually
			const checkClosed = setInterval(() => {
				if (popup.closed) {
					clearInterval(checkClosed);
					window.removeEventListener('message', handleMessage);
					if (!success && !error) {
						error = 'OAuth process was cancelled';
					}
					loading = false;
				}
			}, 1000);
			
		} catch (err) {
			error = err instanceof Error ? err.message : `Failed to link ${provider} account`;
		} finally {
			loading = false;
		}
	}	async function unlinkSocialAccount(provider: "google" | "facebook") {
		if (!user) return;
		try {
			await authService.unlinkSocialAccount(provider);
			success = `${provider} account unlinked successfully!`;
			await authStore.refreshUser();
		} catch (err) {
			error = err instanceof Error ? err.message : `Failed to unlink ${provider} account`;
		}
	}

	async function resendVerification() {
		if (!user) return;
		try {
			await authService.resendVerification();
			success = "Verification email sent! Please check your inbox.";
		} catch (err) {
			error = err instanceof Error ? err.message : "Failed to send verification email";
		}
	}

	function addGenre() {
		if (!newGenre.trim()) return;
		if (!musicPreferences.favoriteGenres.includes(newGenre)) {
			musicPreferences.favoriteGenres = [...musicPreferences.favoriteGenres, newGenre];
		}
		newGenre = "";
	}

	function removeGenre(genre: string) {
		musicPreferences.favoriteGenres = musicPreferences.favoriteGenres.filter(g => g !== genre);
	}

	function addArtist() {
		if (!newArtist.trim()) return;
		if (!musicPreferences.favoriteArtists.includes(newArtist)) {
			musicPreferences.favoriteArtists = [...musicPreferences.favoriteArtists, newArtist];
		}
		newArtist = "";
	}

	function removeArtist(artist: string) {
		musicPreferences.favoriteArtists = musicPreferences.favoriteArtists.filter(a => a !== artist);
	}

	function addDislikedGenre() {
		if (!newDislikedGenre.trim()) return;
		if (!musicPreferences.dislikedGenres.includes(newDislikedGenre)) {
			musicPreferences.dislikedGenres = [...musicPreferences.dislikedGenres, newDislikedGenre];
		}
		newDislikedGenre = "";
	}

	function removeDislikedGenre(genre: string) {
		musicPreferences.dislikedGenres = musicPreferences.dislikedGenres.filter(g => g !== genre);
	}

	// Friends management functions
	async function loadFriendsData() {
		if (!user) return;
		loading = true;
		try {
			const [friendsData, pendingData, sentData] = await Promise.all([
				friendsService.getFriends(),
				friendsService.getPendingInvitations(),
				friendsService.getSentInvitations()
			]);
			friends = friendsData;
			pendingInvitations = pendingData;
			sentInvitations = sentData;
		} catch (err) {
			
			error = err instanceof Error ? err.message : 'Failed to load friends data';
		} finally {
			loading = false;
		}
	}

	async function searchUsers() {
		if (!searchQuery.trim()) {
			searchResults = [];
			return;
		}
		
		searchLoading = true;
		try {
			searchResults = await userService.searchUsers(searchQuery.trim());
		} catch (err) {
			
			error = err instanceof Error ? err.message : 'Failed to search users';
		} finally {
			searchLoading = false;
		}
	}

	async function sendFriendInvitation(userId: string) {
		loading = true;
		error = "";
		success = "";
		try {
			await friendsService.sendInvitation(userId);
			success = "Friend invitation sent successfully!";
			// Reload sent invitations
			sentInvitations = await friendsService.getSentInvitations();
		} catch (err) {
			
			error = err instanceof Error ? err.message : 'Failed to send friend invitation';
		} finally {
			loading = false;
		}
	}

	async function respondToFriendInvitation(invitationId: string, accept: boolean) {
		loading = true;
		error = "";
		success = "";
		try {
			await friendsService.respondToInvitation(invitationId, accept);
			success = accept ? "Friend invitation accepted!" : "Friend invitation declined!";
			// Reload data
			await loadFriendsData();
		} catch (err) {
			
			error = err instanceof Error ? err.message : 'Failed to respond to invitation';
		} finally {
			loading = false;
		}
	}

	async function cancelFriendInvitation(invitationId: string) {
		loading = true;
		error = "";
		success = "";
		try {
			await friendsService.cancelInvitation(invitationId);
			success = "Friend invitation cancelled!";
			// Reload sent invitations
			sentInvitations = await friendsService.getSentInvitations();
		} catch (err) {
			
			error = err instanceof Error ? err.message : 'Failed to cancel invitation';
		} finally {
			loading = false;
		}
	}

	async function removeFriend(friendId: string) {
		if (!confirm('Are you sure you want to remove this friend?')) return;
		
		loading = true;
		error = "";
		success = "";
		try {
			await friendsService.removeFriend(friendId);
			success = "Friend removed successfully!";
			// Reload friends list
			friends = await friendsService.getFriends();
		} catch (err) {
			
			error = err instanceof Error ? err.message : 'Failed to remove friend';
		} finally {
			loading = false;
		}
	}

	// Load friends data when friends tab is opened
	$effect(() => {
		if (activeTab === "friends" && user) {
			loadFriendsData();
		}
	});

	// Clear messages after 5 seconds
	$effect(() => {
		if (success || error) {
			const timeout = setTimeout(() => {
				success = "";
				error = "";
			}, 5000);
			return () => clearTimeout(timeout);
		}
	});

	// Debounced search
	let searchTimeout: NodeJS.Timeout;
	$effect(() => {
		clearTimeout(searchTimeout);
		if (searchQuery.trim()) {
			searchTimeout = setTimeout(searchUsers, 300);
		} else {
			searchResults = [];
		}
		return () => clearTimeout(searchTimeout);
	});

	onMount(() => {
		if (!user) {
			goto("/auth/login");
		}
	});
</script>

<svelte:head>
	<title>Profile - Music Room</title>
	<meta
		name="description"
		content="Manage your profile and music preferences"
	/>
</svelte:head>

{#if !user}
	<div class="container mx-auto px-4 py-8">
		<div class="text-center py-12">
			<h3 class="text-xl font-semibold text-gray-700 mb-2">
				Authentication Required
			</h3>
			<p class="text-gray-500 mb-4">
				Please log in to view your profile.
			</p>
			<a
				href="/auth/login"
				class="bg-secondary text-white px-6 py-2 rounded-lg hover:bg-secondary/80 transition-colors"
			>
				Log In
			</a>
		</div>
	</div>
{:else}
	<div class="container mx-auto px-4 py-8">
		<div class="flex items-center justify-between mb-8">
			<div>
				<h1
					class="font-family-main text-4xl font-bold text-gray-800 mb-2"
				>
					Profile Settings
				</h1>
				<p class="text-gray-600">
					Manage your personal information and preferences
				</p>
			</div>

			{#if !user.emailVerified}
				<div
					class="bg-yellow-100 border border-yellow-400 text-yellow-700 px-4 py-3 rounded-lg"
				>
					<div class="flex items-center space-x-2">
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
								d="M12 9v2m0 4h.01m-6.938 4h13.856c1.54 0 2.502-1.667 1.732-2.5L13.732 4c-.77-.833-1.964-.833-2.732 0L3.732 16.5c-.77.833.192 2.5 1.732 2.5z"
							></path>
						</svg>
						<span class="text-sm">Email not verified</span>
						<button
							onclick={resendVerification}
							class="text-sm underline hover:no-underline"
						>
							Resend verification
						</button>
					</div>
				</div>
			{/if}
		</div>

		<!-- Tab Navigation -->
		<div class="border-b border-gray-200 mb-8">
			<nav class="flex space-x-8">
				<button
					class="py-2 px-1 border-b-2 font-medium text-sm {activeTab ===
					'information'
						? 'border-secondary text-secondary'
						: 'border-transparent text-gray-500 hover:text-gray-700'}"
					onclick={() => (activeTab = "information")}
				>
					Information
				</button>
				<button
					class="py-2 px-1 border-b-2 font-medium text-sm {activeTab ===
					'friends'
						? 'border-secondary text-secondary'
						: 'border-transparent text-gray-500 hover:text-gray-700'}"
					onclick={() => (activeTab = "friends")}
				>
					Manage Friends
				</button>
				<button
					class="py-2 px-1 border-b-2 font-medium text-sm {activeTab ===
					'music'
						? 'border-secondary text-secondary'
						: 'border-transparent text-gray-500 hover:text-gray-700'}"
					onclick={() => (activeTab = "music")}
				>
					Music Preferences
				</button>
				<button
					class="py-2 px-1 border-b-2 font-medium text-sm {activeTab ===
					'accounts'
						? 'border-secondary text-secondary'
						: 'border-transparent text-gray-500 hover:text-gray-700'}"
					onclick={() => (activeTab = "accounts")}
				>
					Connected Accounts
				</button>
			</nav>
		</div>

		{#if error}
			<div
				class="bg-red-100 border border-red-400 text-red-700 px-4 py-3 rounded mb-6"
			>
				{error}
			</div>
		{/if}

		{#if success}
			<div
				class="bg-green-100 border border-green-400 text-green-700 px-4 py-3 rounded mb-6"
			>
				{success}
			</div>
		{/if}

		<form
			onsubmit={(e) => {
				e.preventDefault();
				if (activeTab !== "accounts") {
					updateProfile();
				}
			}}
		>
			<!-- Information Tab -->
			{#if activeTab === "information"}
				<div class="space-y-6 mb-6">
					<!-- Basic Information -->
					<div class="bg-white rounded-lg shadow-md p-6">
						<h2 class="text-xl font-bold text-gray-800 mb-4">
							Basic Information
						</h2>

						<div class="space-y-4">
							<!-- Email (read-only) -->
							<div>
								<label
									for="email"
									class="block text-sm font-medium text-gray-700 mb-1"
									>Email</label
								>
								<input
									id="email"
									type="email"
									value={user.email}
									disabled
									class="w-full px-3 py-2 border border-gray-300 rounded-lg bg-gray-50 text-gray-500"
								/>
								<p class="text-xs text-gray-500 mt-1">
									Email cannot be changed from this page
								</p>
							</div>

							<!-- Display Name -->
							<div>
								<label
									for="display-name"
									class="block text-sm font-medium text-gray-700 mb-1"
									>Display Name</label
								>
								<div class="flex space-x-2">
									<input
										id="display-name"
										type="text"
										bind:value={profileData.displayName}
										class="flex-1 px-3 py-2 border border-gray-300 rounded-lg focus:outline-none focus:ring-2 focus:ring-secondary"
										placeholder="Enter your display name"
									/>
									<select
										bind:value={profileData.displayNameVisibility}
										class="px-3 py-2 border border-gray-300 rounded-lg focus:outline-none focus:ring-2 focus:ring-secondary"
									>
										<option value="public">Public</option>
										<option value="friends">Friends Only</option>
										<option value="private">Private</option>
									</select>
								</div>
							</div>

							<!-- Bio -->
							<div>
								<label
									for="bio"
									class="block text-sm font-medium text-gray-700 mb-1"
									>Bio</label
								>
								<div class="space-y-2">
									<textarea
										id="bio"
										bind:value={profileData.bio}
										rows="4"
										class="w-full px-3 py-2 border border-gray-300 rounded-lg focus:outline-none focus:ring-2 focus:ring-secondary"
										placeholder="Tell others about yourself..."
									></textarea>
									<select
										bind:value={profileData.bioVisibility}
										class="px-3 py-2 border border-gray-300 rounded-lg focus:outline-none focus:ring-2 focus:ring-secondary"
									>
										<option value="public">Public</option>
										<option value="friends">Friends Only</option>
										<option value="private">Private</option>
									</select>
								</div>
							</div>

							<!-- Profile Picture -->
							<div>
								<label
									for="avatar-url"
									class="block text-sm font-medium text-gray-700 mb-1"
									>Profile Picture</label
								>
								
								<!-- Profile Picture Preview -->
								<div class="flex items-start space-x-4 mb-3">
									<div class="flex-shrink-0">
										{#if profileData.avatarUrl && profileData.avatarUrl.trim() !== ""}
											<img
												src={profileData.avatarUrl}
												alt="Profile"
												class="w-16 h-16 rounded-full object-cover border-2 border-gray-200"
												onerror={(e) => {
													const target = e.target as HTMLImageElement;
													if (target) {
														target.src = generateGenericAvatar(profileData.displayName || user?.email || 'U');
													}
												}}
											/>
										{:else if user?.avatarUrl && !user.avatarUrl.startsWith('data:image/svg+xml')}
											<!-- Show current avatar from user data if it's not a generic SVG -->
											<img
												src={user.avatarUrl}
												alt="Profile"
												class="w-16 h-16 rounded-full object-cover border-2 border-gray-200"
												onerror={(e) => {
													const target = e.target as HTMLImageElement;
													if (target) {
														target.src = generateGenericAvatar(profileData.displayName || user?.email || 'U');
													}
												}}
											/>
										{:else}
											<img
												src={generateGenericAvatar(profileData.displayName || user?.email || 'U')}
												alt="Profile"
												class="w-16 h-16 rounded-full object-cover border-2 border-gray-200"
											/>
										{/if}
									</div>
									<div class="flex-1">
										<input
											id="avatar-url"
											type="url"
											bind:value={profileData.avatarUrl}
											class="w-full px-3 py-2 border border-gray-300 rounded-lg focus:outline-none focus:ring-2 focus:ring-secondary"
											placeholder="https://example.com/profile.jpg (optional)"
										/>
										<p class="text-xs text-gray-500 mt-1">
											Leave empty to keep your current profile picture
										</p>
									</div>
								</div>
							</div>

							<!-- Birth Date -->
							<div>
								<label
									for="birth-date"
									class="block text-sm font-medium text-gray-700 mb-1"
									>Birth Date</label
								>
								<div class="flex space-x-2">
									<input
										id="birth-date"
										type="date"
										bind:value={profileData.birthDate}
										class="flex-1 px-3 py-2 border border-gray-300 rounded-lg focus:outline-none focus:ring-2 focus:ring-secondary"
									/>
									<select
										bind:value={profileData.birthDateVisibility}
										class="px-3 py-2 border border-gray-300 rounded-lg focus:outline-none focus:ring-2 focus:ring-secondary"
									>
										<option value="public">Public</option>
										<option value="friends">Friends Only</option>
										<option value="private">Private</option>
									</select>
								</div>
							</div>

							<!-- Location -->
							<div>
								<label
									for="location"
									class="block text-sm font-medium text-gray-700 mb-1"
									>Location</label
								>
								<div class="flex space-x-2">
									<input
										id="location"
										type="text"
										bind:value={profileData.location}
										class="flex-1 px-3 py-2 border border-gray-300 rounded-lg focus:outline-none focus:ring-2 focus:ring-secondary"
										placeholder="City, Country"
									/>
									<select
										bind:value={profileData.locationVisibility}
										class="px-3 py-2 border border-gray-300 rounded-lg focus:outline-none focus:ring-2 focus:ring-secondary"
									>
										<option value="public">Public</option>
										<option value="friends">Friends Only</option>
										<option value="private">Private</option>
									</select>
								</div>
							</div>
						</div>
					</div>

					<!-- Password Management -->
					<div class="bg-white rounded-lg shadow-md p-6">
						<h2 class="text-xl font-bold text-gray-800 mb-4">
							Password & Security
						</h2>

						{#if isOAuthOnlyUser()}
							<div class="bg-blue-50 border border-blue-200 rounded-lg p-4">
								<div class="flex items-start space-x-3">
									<svg class="w-5 h-5 text-blue-600 mt-0.5" fill="none" stroke="currentColor" viewBox="0 0 24 24">
										<path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M13 16h-1v-4h-1m1-4h.01M21 12a9 9 0 11-18 0 9 9 0 0118 0z"></path>
									</svg>
									<div>
										<h4 class="text-sm font-medium text-blue-800">OAuth Account</h4>
										<p class="text-sm text-blue-700 mt-1">
											You signed up using a social account. Password management is not available for OAuth accounts.
										</p>
									</div>
								</div>
							</div>
						{:else if !showPasswordChange}
							<div class="space-y-4">
								<p class="text-gray-600">
									Manage your password and account security
								</p>
								<div class="flex space-x-4">
									<button
										type="button"
										onclick={() => (showPasswordChange = true)}
										class="bg-secondary text-white px-4 py-2 rounded-lg hover:bg-secondary/80 transition-colors"
									>
										Change Password
									</button>
								</div>
							</div>
						{:else}
							<div class="space-y-4">
								<div>
									<label
										for="current-password"
										class="block text-sm font-medium text-gray-700 mb-1"
										>Current Password</label
									>
									<input
										id="current-password"
										type="password"
										bind:value={passwordChangeData.currentPassword}
										class="w-full px-3 py-2 border border-gray-300 rounded-lg focus:outline-none focus:ring-2 focus:ring-secondary"
										placeholder="Enter your current password"
									/>
								</div>

								<div>
									<label
										for="new-password"
										class="block text-sm font-medium text-gray-700 mb-1"
										>New Password</label
									>
									<input
										id="new-password"
										type="password"
										bind:value={passwordChangeData.newPassword}
										class="w-full px-3 py-2 border border-gray-300 rounded-lg focus:outline-none focus:ring-2 focus:ring-secondary"
										placeholder="Enter your new password"
									/>
								</div>

								<div>
									<label
										for="confirm-password"
										class="block text-sm font-medium text-gray-700 mb-1"
										>Confirm New Password</label
									>
									<input
										id="confirm-password"
										type="password"
										bind:value={passwordChangeData.confirmPassword}
										class="w-full px-3 py-2 border border-gray-300 rounded-lg focus:outline-none focus:ring-2 focus:ring-secondary"
										placeholder="Confirm your new password"
									/>
								</div>

								<div class="flex space-x-4">
									<button
										type="button"
										onclick={changePassword}
										disabled={loading}
										class="bg-secondary text-white px-4 py-2 rounded-lg hover:bg-secondary/80 disabled:opacity-50 transition-colors"
									>
										{loading ? "Changing..." : "Change Password"}
									</button>
									<button
										type="button"
										onclick={() => {
											showPasswordChange = false;
											passwordChangeData = {
												currentPassword: "",
												newPassword: "",
												confirmPassword: "",
											};
										}}
										class="border border-gray-300 text-gray-700 px-4 py-2 rounded-lg hover:bg-gray-50 transition-colors"
									>
										Cancel
									</button>
								</div>
							</div>
						{/if}
					</div>
				</div>
			{/if}

			<!-- Friends Tab -->
			{#if activeTab === "friends"}
				<div class="bg-white rounded-lg shadow-md p-6 mb-6">
					<h2 class="text-xl font-bold text-gray-800 mb-4">
						Manage Friends
					</h2>
					<p class="text-gray-600 mb-6">
						Manage your friend list and invitations
					</p>

					<!-- Sub-navigation -->
					<div class="flex space-x-1 mb-6 bg-gray-100 p-1 rounded-lg">
						<button
							class="px-4 py-2 rounded-md text-sm font-medium transition-colors {friendsSubTab === 'list' ? 'bg-white text-gray-900 shadow-sm' : 'text-gray-500 hover:text-gray-700'}"
							onclick={() => (friendsSubTab = "list")}
						>
							Friends ({friends.length})
						</button>
						<button
							class="px-4 py-2 rounded-md text-sm font-medium transition-colors {friendsSubTab === 'pending' ? 'bg-white text-gray-900 shadow-sm' : 'text-gray-500 hover:text-gray-700'}"
							onclick={() => (friendsSubTab = "pending")}
						>
							Pending ({pendingInvitations.length})
						</button>
						<button
							class="px-4 py-2 rounded-md text-sm font-medium transition-colors {friendsSubTab === 'sent' ? 'bg-white text-gray-900 shadow-sm' : 'text-gray-500 hover:text-gray-700'}"
							onclick={() => (friendsSubTab = "sent")}
						>
							Sent ({sentInvitations.length})
						</button>
						<button
							class="px-4 py-2 rounded-md text-sm font-medium transition-colors {friendsSubTab === 'search' ? 'bg-white text-gray-900 shadow-sm' : 'text-gray-500 hover:text-gray-700'}"
							onclick={() => (friendsSubTab = "search")}
						>
							Add Friends
						</button>
					</div>

					<!-- Friends List -->
					{#if friendsSubTab === "list"}
						<div>
							<h3 class="text-lg font-semibold text-gray-800 mb-4">
								Your Friends
							</h3>
							{#if friends.length === 0}
								<div class="text-center py-8">
									<div class="text-gray-400 text-4xl mb-4">👥</div>
									<p class="text-gray-500">You don't have any friends yet.</p>
									<button
										class="mt-4 text-secondary hover:text-secondary/80 font-medium"
										onclick={() => (friendsSubTab = "search")}
									>
										Find some friends to connect with!
									</button>
								</div>
							{:else}
								<div class="space-y-3">
									{#each friends as friend}
										<div class="flex items-center justify-between p-4 border border-gray-200 rounded-lg hover:bg-gray-50 transition-colors">
											<button 
												class="flex items-center space-x-3 flex-1 text-left"
												onclick={() => goto(`/users/${friend.id}`)}
												onkeydown={(e) => {
													if (e.key === 'Enter' || e.key === ' ') {
														e.preventDefault();
														goto(`/users/${friend.id}`);
													}
												}}
											>
												<img
													src={friend.avatarUrl || generateGenericAvatar(friend.displayName || 'User')}
													alt={friend.displayName || 'User'}
													class="w-12 h-12 rounded-full object-cover"
													onerror={(e) => { 
														const target = e.target as HTMLImageElement;
														if (target) target.src = generateGenericAvatar(friend.displayName || 'User');
													}}
												/>
												<div>
													<h4 class="font-medium text-gray-900">
														{friend.displayName || 'Unknown User'}
													</h4>
													{#if friend.bio}
														<p class="text-sm text-gray-500">{friend.bio}</p>
													{/if}
													{#if friend.since}
														<p class="text-xs text-gray-400">
															Friends since {new Date(friend.since).toLocaleDateString()}
														</p>
													{/if}
												</div>
											</button>
											<div class="flex items-center gap-2">
												<button
													type="button"
													onclick={(e) => {
														e.stopPropagation();
														removeFriend(friend.id);
													}}
													disabled={loading}
													class="text-red-600 hover:text-red-800 text-sm font-medium disabled:opacity-50"
												>
													Remove
												</button>
												<svg class="w-4 h-4 text-gray-400" fill="none" stroke="currentColor" viewBox="0 0 24 24">
													<path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M9 5l7 7-7 7" />
												</svg>
											</div>
										</div>
									{/each}
								</div>
							{/if}
						</div>
					{/if}

					<!-- Pending Invitations -->
					{#if friendsSubTab === "pending"}
						<div>
							<h3 class="text-lg font-semibold text-gray-800 mb-4">
								Pending Invitations
							</h3>
							<p class="text-gray-600 mb-4">
								Friend requests you've received
							</p>
							{#if pendingInvitations.length === 0}
								<div class="text-center py-8">
									<div class="text-gray-400 text-4xl mb-4">📬</div>
									<p class="text-gray-500">No pending invitations.</p>
								</div>
							{:else}
								<div class="space-y-3">
									{#each pendingInvitations as invitation}
										<div class="flex items-center justify-between p-4 border border-gray-200 rounded-lg hover:bg-gray-50 transition-colors">
											<button 
												class="flex items-center space-x-3 flex-1 text-left"
												onclick={() => goto(`/users/${invitation.inviter.id}`)}
												onkeydown={(e) => {
													if (e.key === 'Enter' || e.key === ' ') {
														e.preventDefault();
														goto(`/users/${invitation.inviter.id}`);
													}
												}}
											>
												<img
													src={invitation.inviter.avatarUrl || generateGenericAvatar(invitation.inviter.displayName || 'User')}
													alt={invitation.inviter.displayName || 'User'}
													class="w-12 h-12 rounded-full object-cover"
													onerror={(e) => { 
														const target = e.target as HTMLImageElement;
														if (target) target.src = generateGenericAvatar(invitation.inviter.displayName || 'User');
													}}
												/>
												<div>
													<h4 class="font-medium text-gray-900">
														{invitation.inviter.displayName || 'Unknown User'}
													</h4>
													{#if invitation.message}
														<p class="text-sm text-gray-600">"{invitation.message}"</p>
													{/if}
													<p class="text-xs text-gray-400">
														Sent {new Date(invitation.createdAt).toLocaleDateString()}
													</p>
												</div>
											</button>
											<div class="flex items-center gap-2">
												<div class="flex space-x-2">
													<button
														type="button"
														onclick={(e) => {
															e.stopPropagation();
															respondToFriendInvitation(invitation.id, true);
														}}
														disabled={loading}
														class="bg-green-600 text-white px-3 py-1 rounded text-sm hover:bg-green-700 disabled:opacity-50"
													>
														Accept
													</button>
													<button
														type="button"
														onclick={(e) => {
															e.stopPropagation();
															respondToFriendInvitation(invitation.id, false);
														}}
														disabled={loading}
														class="bg-red-600 text-white px-3 py-1 rounded text-sm hover:bg-red-700 disabled:opacity-50"
													>
														Decline
													</button>
												</div>
												<svg class="w-4 h-4 text-gray-400" fill="none" stroke="currentColor" viewBox="0 0 24 24">
													<path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M9 5l7 7-7 7" />
												</svg>
											</div>
										</div>
									{/each}
								</div>
							{/if}
						</div>
					{/if}

					<!-- Sent Invitations -->
					{#if friendsSubTab === "sent"}
						<div>
							<h3 class="text-lg font-semibold text-gray-800 mb-4">
								Sent Invitations
							</h3>
							<p class="text-gray-600 mb-4">
								Friend requests you've sent
							</p>
							{#if sentInvitations.length === 0}
								<div class="text-center py-8">
									<div class="text-gray-400 text-4xl mb-4">📤</div>
									<p class="text-gray-500">No sent invitations.</p>
								</div>
							{:else}
								<div class="space-y-3">
									{#each sentInvitations as invitation}
										<div class="flex items-center justify-between p-4 border border-gray-200 rounded-lg hover:bg-gray-50 transition-colors">
											<button 
												class="flex items-center space-x-3 flex-1 text-left"
												onclick={() => goto(`/users/${invitation.invitee.id}`)}
												onkeydown={(e) => {
													if (e.key === 'Enter' || e.key === ' ') {
														e.preventDefault();
														goto(`/users/${invitation.invitee.id}`);
													}
												}}
											>
												<img
													src={invitation.invitee.avatarUrl || generateGenericAvatar(invitation.invitee.displayName || 'User')}
													alt={invitation.invitee.displayName || 'User'}
													class="w-12 h-12 rounded-full object-cover"
													onerror={(e) => { 
														const target = e.target as HTMLImageElement;
														if (target) target.src = generateGenericAvatar(invitation.invitee.displayName || 'User');
													}}
												/>
												<div>
													<h4 class="font-medium text-gray-900">
														{invitation.invitee.displayName || 'Unknown User'}
													</h4>
													{#if invitation.message}
														<p class="text-sm text-gray-600">"{invitation.message}"</p>
													{/if}
													<p class="text-xs text-gray-400">
														Sent {new Date(invitation.createdAt).toLocaleDateString()}
													</p>
												</div>
											</button>
											<div class="flex items-center gap-2">
												<button
													type="button"
													onclick={(e) => {
														e.stopPropagation();
														cancelFriendInvitation(invitation.id);
													}}
													disabled={loading}
													class="text-red-600 hover:text-red-800 text-sm font-medium disabled:opacity-50"
												>
													Cancel
												</button>
												<svg class="w-4 h-4 text-gray-400" fill="none" stroke="currentColor" viewBox="0 0 24 24">
													<path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M9 5l7 7-7 7" />
												</svg>
											</div>
										</div>
									{/each}
								</div>
							{/if}
						</div>
					{/if}

					<!-- Search Users -->
					{#if friendsSubTab === "search"}
						<div>
							<h3 class="text-lg font-semibold text-gray-800 mb-4">
								Find Friends
							</h3>
							<p class="text-gray-600 mb-4">
								Search for users to send friend requests
							</p>
							
							<!-- Search Input -->
							<div class="mb-6">
								<div class="relative">
									<input
										type="text"
										bind:value={searchQuery}
										placeholder="Search by username or display name..."
										class="w-full px-4 py-2 pl-10 border border-gray-300 rounded-lg focus:outline-none focus:ring-2 focus:ring-secondary"
									/>
									<div class="absolute inset-y-0 left-0 pl-3 flex items-center pointer-events-none">
										<svg class="w-5 h-5 text-gray-400" fill="none" stroke="currentColor" viewBox="0 0 24 24">
											<path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M21 21l-6-6m2-5a7 7 0 11-14 0 7 7 0 0114 0z"></path>
										</svg>
									</div>
									{#if searchLoading}
										<div class="absolute inset-y-0 right-0 pr-3 flex items-center">
											<div class="animate-spin rounded-full h-4 w-4 border-b-2 border-secondary"></div>
										</div>
									{/if}
								</div>
							</div>

							<!-- Search Results -->
							{#if searchQuery.trim() && searchResults.length === 0 && !searchLoading}
								<div class="text-center py-8">
									<div class="text-gray-400 text-4xl mb-4">🔍</div>
									<p class="text-gray-500">No users found matching "{searchQuery}"</p>
								</div>
							{:else if searchResults.length > 0}
								<div class="space-y-3">
									{#each searchResults as searchUser}
										{@const isAlreadyFriend = friends.some(f => f.id === searchUser.id)}
										{@const hasPendingInvitation = sentInvitations.some(i => i.invitee.id === searchUser.id)}
										{@const isCurrentUser = user && user.id === searchUser.id}
										
										<div class="flex items-center justify-between p-4 border border-gray-200 rounded-lg hover:bg-gray-50 transition-colors">
											{#if !isCurrentUser}
												<button 
													class="flex items-center space-x-3 flex-1 text-left"
													onclick={() => goto(`/users/${searchUser.id}`)}
													onkeydown={(e) => {
														if (e.key === 'Enter' || e.key === ' ') {
															e.preventDefault();
															goto(`/users/${searchUser.id}`);
														}
													}}
												>
													<img
														src={searchUser.avatarUrl || generateGenericAvatar(searchUser.displayName || 'User')}
														alt={searchUser.displayName || 'User'}
														class="w-12 h-12 rounded-full object-cover"
														onerror={(e) => { 
															const target = e.target as HTMLImageElement;
															if (target) target.src = generateGenericAvatar(searchUser.displayName || 'User');
														}}
													/>
													<div>
														<h4 class="font-medium text-gray-900">
															{searchUser.displayName || 'Unknown User'}
														</h4>
														{#if searchUser.bio}
															<p class="text-sm text-gray-600">{searchUser.bio}</p>
														{/if}
														{#if searchUser.musicPreferences?.favoriteGenres?.length}
															<div class="flex flex-wrap gap-1 mt-1">
																{#each searchUser.musicPreferences.favoriteGenres.slice(0, 3) as genre}
																	<span class="px-2 py-1 bg-gray-100 text-gray-600 text-xs rounded">{genre}</span>
																{/each}
															</div>
														{/if}
													</div>
												</button>
											{:else}
												<div class="flex items-center space-x-3 flex-1">
													<img
														src={searchUser.avatarUrl || generateGenericAvatar(searchUser.displayName || 'User')}
														alt={searchUser.displayName || 'User'}
														class="w-12 h-12 rounded-full object-cover"
														onerror={(e) => { 
															const target = e.target as HTMLImageElement;
															if (target) target.src = generateGenericAvatar(searchUser.displayName || 'User');
														}}
													/>
													<div>
														<h4 class="font-medium text-gray-900">
															{searchUser.displayName || 'Unknown User'}
														</h4>
														{#if searchUser.bio}
															<p class="text-sm text-gray-600">{searchUser.bio}</p>
														{/if}
														{#if searchUser.musicPreferences?.favoriteGenres?.length}
															<div class="flex flex-wrap gap-1 mt-1">
																{#each searchUser.musicPreferences.favoriteGenres.slice(0, 3) as genre}
																	<span class="px-2 py-1 bg-gray-100 text-gray-600 text-xs rounded">{genre}</span>
																{/each}
															</div>
														{/if}
													</div>
												</div>
											{/if}
											<div class="flex items-center gap-2">
												{#if isCurrentUser}
													<span class="text-gray-500 text-sm">That's you!</span>
												{:else if isAlreadyFriend}
													<span class="text-green-600 text-sm font-medium">✓ Friends</span>
												{:else if hasPendingInvitation}
													<span class="text-yellow-600 text-sm font-medium">Invitation Sent</span>
												{:else}
													<button
														type="button"
														onclick={(e) => {
															e.stopPropagation();
															sendFriendInvitation(searchUser.id);
														}}
														disabled={loading}
														class="bg-secondary text-white px-3 py-1 rounded text-sm hover:bg-secondary/80 disabled:opacity-50"
													>
														Send Request
													</button>
												{/if}
												{#if !isCurrentUser}
													<svg class="w-4 h-4 text-gray-400" fill="none" stroke="currentColor" viewBox="0 0 24 24">
														<path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M9 5l7 7-7 7" />
													</svg>
												{/if}
											</div>
										</div>
									{/each}
								</div>
							{/if}
						</div>
					{/if}
				</div>
			{/if}

			<!-- Music Preferences Tab -->
			{#if activeTab === "music"}
				<div class="bg-white rounded-lg shadow-md p-6 mb-6">
					<h2 class="text-xl font-bold text-gray-800 mb-4">
						Music Preferences
					</h2>
					<p class="text-gray-600 mb-6">
						Help us recommend better music for you
					</p>

					<div class="space-y-6">
						<!-- Favorite Genres -->
						<div>
							<label
								for="favorite-genres"
								class="block text-sm font-medium text-gray-700 mb-1"
								>Favorite Genres</label
							>
							<div class="flex flex-wrap gap-2 mb-2">
								{#each musicPreferences.favoriteGenres as genre}
									<span
										class="inline-flex items-center px-3 py-1 rounded-full text-sm bg-green-100 text-green-700"
									>
										{genre}
										<button
											type="button"
											onclick={() => removeGenre(genre)}
											class="ml-2 text-green-500 hover:text-green-700"
										>
											×
										</button>
									</span>
								{/each}
							</div>
							<div class="flex space-x-2">
								<input
									id="favorite-genres"
									type="text"
									bind:value={newGenre}
									class="flex-1 px-3 py-2 border border-gray-300 rounded-lg focus:outline-none focus:ring-2 focus:ring-secondary"
									placeholder="Add a genre"
									onkeydown={(e) =>
										e.key === "Enter" &&
										(e.preventDefault(), addGenre())}
								/>
								<button
									type="button"
									onclick={addGenre}
									class="px-4 py-2 bg-secondary text-white rounded-lg hover:bg-secondary/80"
								>
									Add
								</button>
							</div>
							<div class="mt-2 flex flex-wrap gap-1">
								{#each musicGenres as genre}
									{#if !musicPreferences.favoriteGenres.includes(genre)}
										<button
											type="button"
											onclick={() => {
												newGenre = genre;
												addGenre();
											}}
											class="text-xs px-2 py-1 bg-gray-100 text-gray-600 rounded hover:bg-gray-200"
										>
											{genre}
										</button>
									{/if}
								{/each}
							</div>
						</div>

						<!-- Favorite Artists -->
						<div>
							<label
								for="favorite-artists"
								class="block text-sm font-medium text-gray-700 mb-1"
								>Favorite Artists</label
							>
							<div class="flex flex-wrap gap-2 mb-2">
								{#each musicPreferences.favoriteArtists as artist}
									<span
										class="inline-flex items-center px-3 py-1 rounded-full text-sm bg-blue-100 text-blue-700"
									>
										{artist}
										<button
											type="button"
											onclick={() => removeArtist(artist)}
											class="ml-2 text-blue-500 hover:text-blue-700"
										>
											×
										</button>
									</span>
								{/each}
							</div>
							<div class="flex space-x-2">
								<input
									id="favorite-artists"
									type="text"
									bind:value={newArtist}
									class="flex-1 px-3 py-2 border border-gray-300 rounded-lg focus:outline-none focus:ring-2 focus:ring-secondary"
									placeholder="Add an artist"
									onkeydown={(e) =>
										e.key === "Enter" &&
										(e.preventDefault(), addArtist())}
								/>
								<button
									type="button"
									onclick={addArtist}
									class="px-4 py-2 bg-secondary text-white rounded-lg hover:bg-secondary/80"
								>
									Add
								</button>
							</div>
						</div>

						<!-- Disliked Genres -->
						<div>
							<label
								for="disliked-genres"
								class="block text-sm font-medium text-gray-700 mb-1"
								>Disliked Genres</label
							>
							<p class="text-xs text-gray-500 mb-2">
								Help us avoid recommending music you don't enjoy
							</p>
							<div class="flex flex-wrap gap-2 mb-2">
								{#each musicPreferences.dislikedGenres as genre}
									<span
										class="inline-flex items-center px-3 py-1 rounded-full text-sm bg-red-100 text-red-700"
									>
										{genre}
										<button
											type="button"
											onclick={() => removeDislikedGenre(genre)}
											class="ml-2 text-red-500 hover:text-red-700"
										>
											×
										</button>
									</span>
								{/each}
							</div>
							<div class="flex space-x-2">
								<input
									id="disliked-genres"
									type="text"
									bind:value={newDislikedGenre}
									class="flex-1 px-3 py-2 border border-gray-300 rounded-lg focus:outline-none focus:ring-2 focus:ring-secondary"
									placeholder="Add a disliked genre"
									onkeydown={(e) =>
										e.key === "Enter" &&
										(e.preventDefault(), addDislikedGenre())}
								/>
								<button
									type="button"
									onclick={addDislikedGenre}
									class="px-4 py-2 bg-red-600 text-white rounded-lg hover:bg-red-700"
								>
									Add
								</button>
							</div>
							<div class="mt-2 flex flex-wrap gap-1">
								{#each musicGenres as genre}
									{#if !musicPreferences.dislikedGenres.includes(genre)}
										<button
											type="button"
											onclick={() => {
												newDislikedGenre = genre;
												addDislikedGenre();
											}}
											class="text-xs px-2 py-1 bg-gray-100 text-gray-600 rounded hover:bg-gray-200"
										>
											{genre}
										</button>
									{/if}
								{/each}
							</div>
						</div>
					</div>
				</div>
			{/if}

			<!-- Connected Accounts Tab -->
			{#if activeTab === "accounts"}
				<div class="bg-white rounded-lg shadow-md p-6">
					<h2 class="text-xl font-bold text-gray-800 mb-4">
						Connected Accounts
					</h2>
					<p class="text-gray-600 mb-6">
						Link your social media accounts for easier access
					</p>

					<div class="space-y-4">
						<!-- Google Account -->
						<div
							class="flex items-center justify-between p-4 border border-gray-200 rounded-lg"
						>
							<div class="flex items-center space-x-3">
								<div
									class="w-10 h-10 bg-red-100 rounded-lg flex items-center justify-center"
								>
									<svg
										class="w-6 h-6 text-red-600"
										viewBox="0 0 24 24"
										fill="currentColor"
									>
										<path
											d="M22.56 12.25c0-.78-.07-1.53-.2-2.25H12v4.26h5.92c-.26 1.37-1.04 2.53-2.21 3.31v2.77h3.57c2.08-1.92 3.28-4.74 3.28-8.09z"
										/>
										<path
											d="M12 23c2.97 0 5.46-.98 7.28-2.66l-3.57-2.77c-.98.66-2.23 1.06-3.71 1.06-2.86 0-5.29-1.93-6.16-4.53H2.18v2.84C3.99 20.53 7.7 23 12 23z"
										/>
										<path
											d="M5.84 14.09c-.22-.66-.35-1.36-.35-2.09s.13-1.43.35-2.09V7.07H2.18C1.43 8.55 1 10.22 1 12s.43 3.45 1.18 4.93l2.85-2.22.81-.62z"
										/>
										<path
											d="M12 5.38c1.62 0 3.06.56 4.21 1.64l3.15-3.15C17.45 2.09 14.97 1 12 1 7.7 1 3.99 3.47 2.18 7.07l3.66 2.84c.87-2.6 3.3-4.53 6.16-4.53z"
										/>
									</svg>
								</div>
								<div>
									<h3 class="font-medium text-gray-800">
										Google
									</h3>
									<p class="text-sm text-gray-500">
										{user.connectedAccounts?.google
											? "Connected"
											: "Not connected"}
									</p>
								</div>
							</div>
							{#if user.connectedAccounts?.google}
								<button
									type="button"
									onclick={() => unlinkSocialAccount("google")}
									class="border border-red-500 text-red-500 px-4 py-2 rounded-lg hover:bg-red-50 transition-colors"
								>
									Disconnect
								</button>
							{:else}
								<button
									type="button"
									onclick={() => linkSocialAccount("google")}
									class="bg-red-600 text-white px-4 py-2 rounded-lg hover:bg-red-700 transition-colors"
								>
									Connect
								</button>
							{/if}
						</div>

						<!-- Facebook Account -->
						<div
							class="flex items-center justify-between p-4 border border-gray-200 rounded-lg"
						>
							<div class="flex items-center space-x-3">
								<div
									class="w-10 h-10 bg-blue-100 rounded-lg flex items-center justify-center"
								>
									<svg
										class="w-6 h-6 text-blue-600"
										viewBox="0 0 24 24"
										fill="currentColor"
									>
										<path
											d="M24 12.073c0-6.627-5.373-12-12-12s-12 5.373-12 12c0 5.99 4.388 10.954 10.125 11.854v-8.385H7.078v-3.47h3.047V9.43c0-3.007 1.792-4.669 4.533-4.669 1.312 0 2.686.235 2.686.235v2.953H15.83c-1.491 0-1.956.925-1.956 1.874v2.25h3.328l-.532 3.47h-2.796v8.385C19.612 23.027 24 18.062 24 12.073z"
										/>
									</svg>
								</div>
								<div>
									<h3 class="font-medium text-gray-800">
										Facebook
									</h3>
									<p class="text-sm text-gray-500">
										{user.connectedAccounts?.facebook
											? "Connected"
											: "Not connected"}
									</p>
								</div>
							</div>
							{#if user.connectedAccounts?.facebook}
								<button
									type="button"
									onclick={() => unlinkSocialAccount("facebook")}
									class="border border-red-500 text-red-500 px-4 py-2 rounded-lg hover:bg-red-50 transition-colors"
								>
									Disconnect
								</button>
							{:else}
								<button
									type="button"
									onclick={() => linkSocialAccount("facebook")}
									class="bg-blue-600 text-white px-4 py-2 rounded-lg hover:bg-blue-700 transition-colors"
								>
									Connect
								</button>
							{/if}
						</div>
					</div>
				</div>
			{/if}

			<!-- Save Button (only show for editable tabs) -->
			{#if activeTab !== "accounts" && activeTab !== "friends"}
				<div class="flex justify-end">
					<button
						type="submit"
						disabled={loading}
						class="bg-secondary text-white px-8 py-3 rounded-lg font-semibold hover:bg-secondary/80 disabled:opacity-50 transition-colors"
					>
						{loading ? "Saving..." : "Save Changes"}
					</button>
				</div>
			{/if}
		</form>
	</div>
{/if}
