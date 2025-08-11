<script lang="ts">
	import { onMount } from "svelte";
	import { goto } from "$app/navigation";
	import { authStore } from "$lib/stores/auth";
	import { authService, type User } from "$lib/services/auth";

	// Use the reactive auth store with proper store subscription
	let user = $state<User | null>(null);
	let loading = $state(false);
	let error = $state("");
	let success = $state("");
	let activeTab = $state<
		"public" | "friends" | "private" | "music" | "accounts"
	>("public");

	// Subscribe to auth store changes
	$effect(() => {
		const unsubscribe = authStore.subscribe((value) => {
			user = value;
		});
		return unsubscribe;
	});

	// Form data for each section
	let publicInfo = $state({
		displayName: "",
		bio: "",
		profilePicture: "",
	});

	let friendsInfo = $state({
		realName: "",
		location: "",
		favoriteGenres: [] as string[],
	});

	let privateInfo = $state({
		phoneNumber: "",
		birthDate: "",
	});

	let musicPreferences = $state({
		favoriteGenres: [] as string[],
		favoriteArtists: [] as string[],
		listeningHabits: "",
	});

	let newGenre = $state("");
	let newArtist = $state("");

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
			console.error("Failed to load user data:", err);
		}
	});

	function populateFormData(userData: User) {
		// Populate public info
		publicInfo.displayName =
			userData.publicInfo?.displayName || userData.displayName || "";
		publicInfo.bio = userData.publicInfo?.bio || "";
		publicInfo.profilePicture =
			userData.publicInfo?.profilePicture ||
			userData.profilePicture ||
			"";

		friendsInfo.realName = userData.friendsInfo?.realName || "";
		friendsInfo.location = userData.friendsInfo?.location || "";
		friendsInfo.favoriteGenres = userData.friendsInfo?.favoriteGenres || [];

		privateInfo.phoneNumber = userData.privateInfo?.phoneNumber || "";
		privateInfo.birthDate = userData.privateInfo?.birthDate || "";

		musicPreferences.favoriteGenres =
			userData.musicPreferences?.favoriteGenres || [];
		musicPreferences.favoriteArtists =
			userData.musicPreferences?.favoriteArtists || [];
		musicPreferences.listeningHabits =
			userData.musicPreferences?.listeningHabits || "";
	}

	async function updateProfile() {
		if (!user) return;

		loading = true;
		error = "";
		success = "";

		try {
			const updateData: Partial<User> = {
				publicInfo: { ...publicInfo },
				friendsInfo: { ...friendsInfo },
				privateInfo: { ...privateInfo },
				musicPreferences: { ...musicPreferences },
			};

			const updatedUser = await authService.updateProfile(updateData);
			authStore.updateUser(updatedUser);
			success = "Profile updated successfully!";
			setTimeout(() => (success = ""), 3000);
		} catch (err) {
			error =
				err instanceof Error ? err.message : "Failed to update profile";
		} finally {
			loading = false;
		}
	}

	async function linkSocialAccount(provider: "google" | "facebook") {
		if (!user) return;
		try {
			// In a real implementation, this would open OAuth flow
			// For now, we'll just show a placeholder
			const token = prompt(
				`Enter your ${provider} authentication token:`,
			);
			if (token) {
				await authService.linkSocialAccount(provider, token);
				success = `${provider} account linked successfully!`;
				// Reload user data
				await authStore.refreshUser();
			}
		} catch (err) {
			error =
				err instanceof Error
					? err.message
					: `Failed to link ${provider} account`;
		}
	}

	async function unlinkSocialAccount(provider: "google" | "facebook") {
		if (!user) return;
		try {
			await authService.unlinkSocialAccount(provider);
			success = `${provider} account unlinked successfully!`;
			// Reload user data
			await authStore.refreshUser();
		} catch (err) {
			error =
				err instanceof Error
					? err.message
					: `Failed to unlink ${provider} account`;
		}
	}

	async function resendVerification() {
		if (!user) return;
		try {
			await authService.resendVerification();
			success = "Verification email sent! Please check your inbox.";
		} catch (err) {
			error =
				err instanceof Error
					? err.message
					: "Failed to send verification email";
		}
	}

	function addGenre(target: "friends" | "music") {
		if (!newGenre.trim()) return;
		if (target === "friends") {
			if (!friendsInfo.favoriteGenres.includes(newGenre)) {
				friendsInfo.favoriteGenres = [
					...friendsInfo.favoriteGenres,
					newGenre,
				];
			}
		} else {
			if (!musicPreferences.favoriteGenres.includes(newGenre)) {
				musicPreferences.favoriteGenres = [
					...musicPreferences.favoriteGenres,
					newGenre,
				];
			}
		}
		newGenre = "";
	}

	function removeGenre(genre: string, target: "friends" | "music") {
		if (target === "friends") {
			friendsInfo.favoriteGenres = friendsInfo.favoriteGenres.filter(
				(g: string) => g !== genre,
			);
		} else {
			musicPreferences.favoriteGenres =
				musicPreferences.favoriteGenres.filter(
					(g: string) => g !== genre,
				);
		}
	}

	function addArtist() {
		if (!newArtist.trim()) return;
		if (!musicPreferences.favoriteArtists.includes(newArtist)) {
			musicPreferences.favoriteArtists = [
				...musicPreferences.favoriteArtists,
				newArtist,
			];
		}
		newArtist = "";
	}

	function removeArtist(artist: string) {
		musicPreferences.favoriteArtists =
			musicPreferences.favoriteArtists.filter(
				(a: string) => a !== artist,
			);
	}

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

			{#if !user.isEmailVerified}
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
					'public'
						? 'border-secondary text-secondary'
						: 'border-transparent text-gray-500 hover:text-gray-700'}"
					onclick={() => (activeTab = "public")}
				>
					Public Information
				</button>
				<button
					class="py-2 px-1 border-b-2 font-medium text-sm {activeTab ===
					'friends'
						? 'border-secondary text-secondary'
						: 'border-transparent text-gray-500 hover:text-gray-700'}"
					onclick={() => (activeTab = "friends")}
				>
					Friends Information
				</button>
				<button
					class="py-2 px-1 border-b-2 font-medium text-sm {activeTab ===
					'private'
						? 'border-secondary text-secondary'
						: 'border-transparent text-gray-500 hover:text-gray-700'}"
					onclick={() => (activeTab = "private")}
				>
					Private Information
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
				updateProfile();
			}}
		>
			<!-- Public Information Tab -->
			{#if activeTab === "public"}
				<div class="bg-white rounded-lg shadow-md p-6 mb-6">
					<h2 class="text-xl font-bold text-gray-800 mb-4">
						Public Information
					</h2>
					<p class="text-gray-600 mb-6">
						This information is visible to all users
					</p>

					<div class="space-y-4">
						<div>
							<label
								for="display-name"
								class="block text-sm font-medium text-gray-700 mb-1"
								>Display Name</label
							>
							<input
								id="display-name"
								type="text"
								bind:value={publicInfo.displayName}
								class="w-full px-3 py-2 border border-gray-300 rounded-lg focus:outline-none focus:ring-2 focus:ring-secondary"
								placeholder="Enter your display name"
							/>
						</div>

						<div>
							<label
								for="bio"
								class="block text-sm font-medium text-gray-700 mb-1"
								>Bio</label
							>
							<textarea
								id="bio"
								bind:value={publicInfo.bio}
								rows="4"
								class="w-full px-3 py-2 border border-gray-300 rounded-lg focus:outline-none focus:ring-2 focus:ring-secondary"
								placeholder="Tell others about yourself..."
							></textarea>
						</div>

						<div>
							<label
								for="profile-picture"
								class="block text-sm font-medium text-gray-700 mb-1"
								>Profile Picture URL</label
							>
							<input
								id="profile-picture"
								type="url"
								bind:value={publicInfo.profilePicture}
								class="w-full px-3 py-2 border border-gray-300 rounded-lg focus:outline-none focus:ring-2 focus:ring-secondary"
								placeholder="https://example.com/profile.jpg"
							/>
						</div>
					</div>
				</div>
			{/if}

			<!-- Friends Information Tab -->
			{#if activeTab === "friends"}
				<div class="bg-white rounded-lg shadow-md p-6 mb-6">
					<h2 class="text-xl font-bold text-gray-800 mb-4">
						Friends Information
					</h2>
					<p class="text-gray-600 mb-6">
						This information is only visible to your friends
					</p>

					<div class="space-y-4">
						<div>
							<label
								for="real-name"
								class="block text-sm font-medium text-gray-700 mb-1"
								>Real Name</label
							>
							<input
								id="real-name"
								type="text"
								bind:value={friendsInfo.realName}
								class="w-full px-3 py-2 border border-gray-300 rounded-lg focus:outline-none focus:ring-2 focus:ring-secondary"
								placeholder="Enter your real name"
							/>
						</div>

						<div>
							<label
								for="location"
								class="block text-sm font-medium text-gray-700 mb-1"
								>Location</label
							>
							<input
								id="location"
								type="text"
								bind:value={friendsInfo.location}
								class="w-full px-3 py-2 border border-gray-300 rounded-lg focus:outline-none focus:ring-2 focus:ring-secondary"
								placeholder="City, Country"
							/>
						</div>

						<div>
							<label
								for="friends-genres"
								class="block text-sm font-medium text-gray-700 mb-1"
								>Favorite Genres</label
							>
							<div class="flex flex-wrap gap-2 mb-2">
								{#each friendsInfo.favoriteGenres as genre}
									<span
										class="inline-flex items-center px-3 py-1 rounded-full text-sm bg-secondary/20 text-secondary"
									>
										{genre}
										<button
											type="button"
											onclick={() =>
												removeGenre(genre, "friends")}
											class="ml-2 text-secondary/70 hover:text-secondary"
										>
											×
										</button>
									</span>
								{/each}
							</div>
							<div class="flex space-x-2">
								<input
									id="friends-genres"
									type="text"
									bind:value={newGenre}
									class="flex-1 px-3 py-2 border border-gray-300 rounded-lg focus:outline-none focus:ring-2 focus:ring-secondary"
									placeholder="Add a genre"
									onkeydown={(e) =>
										e.key === "Enter" &&
										(e.preventDefault(),
										addGenre("friends"))}
								/>
								<button
									type="button"
									onclick={() => addGenre("friends")}
									class="px-4 py-2 bg-secondary text-white rounded-lg hover:bg-secondary/80"
								>
									Add
								</button>
							</div>
							<div class="mt-2 flex flex-wrap gap-1">
								{#each musicGenres as genre}
									{#if !friendsInfo.favoriteGenres.includes(genre)}
										<button
											type="button"
											onclick={() => {
												newGenre = genre;
												addGenre("friends");
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

			<!-- Private Information Tab -->
			{#if activeTab === "private"}
				<div class="bg-white rounded-lg shadow-md p-6 mb-6">
					<h2 class="text-xl font-bold text-gray-800 mb-4">
						Private Information
					</h2>
					<p class="text-gray-600 mb-6">
						This information is only visible to you
					</p>

					<div class="space-y-4">
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

						<div>
							<label
								for="phone-number"
								class="block text-sm font-medium text-gray-700 mb-1"
								>Phone Number</label
							>
							<input
								id="phone-number"
								type="tel"
								bind:value={privateInfo.phoneNumber}
								class="w-full px-3 py-2 border border-gray-300 rounded-lg focus:outline-none focus:ring-2 focus:ring-secondary"
								placeholder="+1 (555) 123-4567"
							/>
						</div>

						<div>
							<label
								for="birth-date"
								class="block text-sm font-medium text-gray-700 mb-1"
								>Birth Date</label
							>
							<input
								id="birth-date"
								type="date"
								bind:value={privateInfo.birthDate}
								class="w-full px-3 py-2 border border-gray-300 rounded-lg focus:outline-none focus:ring-2 focus:ring-secondary"
							/>
						</div>
					</div>
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
						<div>
							<label
								for="music-genres"
								class="block text-sm font-medium text-gray-700 mb-1"
								>Favorite Genres</label
							>
							<div class="flex flex-wrap gap-2 mb-2">
								{#each musicPreferences.favoriteGenres as genre}
									<span
										class="inline-flex items-center px-3 py-1 rounded-full text-sm bg-purple-100 text-purple-700"
									>
										{genre}
										<button
											type="button"
											onclick={() =>
												removeGenre(genre, "music")}
											class="ml-2 text-purple-500 hover:text-purple-700"
										>
											×
										</button>
									</span>
								{/each}
							</div>
							<div class="flex space-x-2">
								<input
									id="music-genres"
									type="text"
									bind:value={newGenre}
									class="flex-1 px-3 py-2 border border-gray-300 rounded-lg focus:outline-none focus:ring-2 focus:ring-secondary"
									placeholder="Add a genre"
									onkeydown={(e) =>
										e.key === "Enter" &&
										(e.preventDefault(), addGenre("music"))}
								/>
								<button
									type="button"
									onclick={() => addGenre("music")}
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
												addGenre("music");
											}}
											class="text-xs px-2 py-1 bg-gray-100 text-gray-600 rounded hover:bg-gray-200"
										>
											{genre}
										</button>
									{/if}
								{/each}
							</div>
						</div>

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

						<div>
							<label
								for="listening-habits"
								class="block text-sm font-medium text-gray-700 mb-1"
								>Listening Habits</label
							>
							<textarea
								id="listening-habits"
								bind:value={musicPreferences.listeningHabits}
								rows="4"
								class="w-full px-3 py-2 border border-gray-300 rounded-lg focus:outline-none focus:ring-2 focus:ring-secondary"
								placeholder="Describe your listening habits, favorite times to listen to music, etc."
							></textarea>
						</div>
					</div>
				</div>
			{/if}

			<!-- Connected Accounts Tab -->
			{#if activeTab === "accounts"}
				<div class="bg-white rounded-lg shadow-md p-6 mb-6">
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
									onclick={() =>
										unlinkSocialAccount("google")}
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
									onclick={() =>
										unlinkSocialAccount("facebook")}
									class="border border-red-500 text-red-500 px-4 py-2 rounded-lg hover:bg-red-50 transition-colors"
								>
									Disconnect
								</button>
							{:else}
								<button
									type="button"
									onclick={() =>
										linkSocialAccount("facebook")}
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
			{#if activeTab !== "accounts"}
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
