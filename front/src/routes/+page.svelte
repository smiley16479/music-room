<svelte:head>
	<title>Music Room - Collaborative Music Experience</title>
	<meta name="description" content="Create, share, and enjoy music together with friends in real-time" />
</svelte:head>

<script lang="ts">
    import { authService } from '$lib/services/auth';
  import { onMount } from 'svelte';
  let isAuthenticated: boolean | null = null;
  onMount(async () => {
	const user = await authService.isAuthenticated();

	if (user) isAuthenticated = user;
  });
</script>

<section class="min-h-screen bg-primary text-[#5e53f1]">
	<div class="container mx-auto px-4 py-16 flex flex-col items-center justify-center text-center">
	{#if isAuthenticated}
	  <div class="mb-6 text-lg text-white">Hello you are Authenticated</div>
	{/if}
		<h1 class="font-family-main text-5xl md:text-6xl font-bold mb-8">
			Welcome to Music Room
		</h1>
		
		<p class="text-xl md:text-2xl mb-12 max-w-2xl">
			Create, share, and enjoy music together with friends in real-time
		</p>
		
		<div class="grid grid-cols-1 md:grid-cols-3 gap-8 w-full max-w-4xl mb-12">
			<div class="bg-indigo-800 bg-opacity-50 p-6 rounded-lg shadow-lg">
				<h3 class="text-xl font-bold mb-3">Track Voting</h3>
				<p>Vote on the next tracks to play at events and parties</p>
				<a href="/events" class="mt-4 inline-block text-sm text-purple-300 hover:text-white">
					Browse Events →
				</a>
			</div>
			
			<div class="bg-indigo-800 bg-opacity-50 p-6 rounded-lg shadow-lg">
				<h3 class="text-xl font-bold mb-3">Playlist Editor</h3>
				<p>Collaborate on playlists in real-time with your friends</p>
				<a href="/playlists" class="mt-4 inline-block text-sm text-purple-300 hover:text-white">
					Explore Playlists →
				</a>
			</div>
			
			<div class="bg-indigo-800 bg-opacity-50 p-6 rounded-lg shadow-lg">
				<h3 class="text-xl font-bold mb-3">Control Delegation</h3>
				<p>Share music control with friends across devices</p>
				<a href="/devices" class="mt-4 inline-block text-sm text-purple-300 hover:text-white">
					Manage Devices →
				</a>
			</div>
		</div>
		
		<div class="flex flex-col sm:flex-row gap-4">
			<a href="/auth/login" class="bg-purple-600 hover:bg-purple-700 text-white font-bold py-3 px-8 rounded-full transition duration-300">
				Login
			</a>
			<a href="/auth/register" class="bg-transparent border-2 border-purple-600 hover:bg-purple-600 text-white font-bold py-3 px-8 rounded-full transition duration-300">
				Register
			</a>
		</div>
	</div>

	<!-- Features Section -->
	<div class="py-20 bg-primary">
		<div class="container mx-auto px-4">
			<h2 class="text-3xl md:text-4xl font-bold mb-16 text-center">How Music Room Works</h2>
			
			<div class="grid grid-cols-1 md:grid-cols-2 gap-16">
				<div class="flex flex-col md:flex-row items-start md:items-center gap-6">
					<div class="bg-purple-700 rounded-full p-4 text-white">
						<svg xmlns="http://www.w3.org/2000/svg" class="h-8 w-8" fill="none" viewBox="0 0 24 24" stroke="currentColor">
							<path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M9 19V6l12-3v13M9 19c0 1.105-1.343 2-3 2s-3-.895-3-2 1.343-2 3-2 3 .895 3 2zm12-3c0 1.105-1.343 2-3 2s-3-.895-3-2 1.343-2 3-2 3 .895 3 2zM9 10l12-3" />
						</svg>
					</div>
					<div>
						<h3 class="text-xl font-bold mb-3">Create or Join Music Events</h3>
						<p class="text-indigo-200">Host virtual or in-person music events where everyone can suggest and vote for the next track in the playlist.</p>
					</div>
				</div>
				
				<div class="flex flex-col md:flex-row items-start md:items-center gap-6">
					<div class="bg-purple-700 rounded-full p-4 text-white">
						<svg xmlns="http://www.w3.org/2000/svg" class="h-8 w-8" fill="none" viewBox="0 0 24 24" stroke="currentColor">
							<path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M11 4a2 2 0 114 0v1a1 1 0 001 1h3a1 1 0 011 1v3a1 1 0 01-1 1h-1a2 2 0 100 4h1a1 1 0 011 1v3a1 1 0 01-1 1h-3a1 1 0 01-1-1v-1a2 2 0 10-4 0v1a1 1 0 01-1 1H7a1 1 0 01-1-1v-3a1 1 0 00-1-1H4a2 2 0 110-4h1a1 1 0 001-1V7a1 1 0 011-1h3a1 1 0 001-1V4z" />
						</svg>
					</div>
					<div>
						<h3 class="text-xl font-bold mb-3">Real-time Collaboration</h3>
						<p class="text-indigo-200">Edit playlists together with friends or like-minded music enthusiasts in real-time, creating unique musical experiences.</p>
					</div>
				</div>
				
				<div class="flex flex-col md:flex-row items-start md:items-center gap-6">
					<div class="bg-purple-700 rounded-full p-4 text-white">
						<svg xmlns="http://www.w3.org/2000/svg" class="h-8 w-8" fill="none" viewBox="0 0 24 24" stroke="currentColor">
							<path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M12 4.354a4 4 0 110 5.292M15 21H3v-1a6 6 0 0112 0v1zm0 0h6v-1a6 6 0 00-9-5.197M13 7a4 4 0 11-8 0 4 4 0 018 0z" />
						</svg>
					</div>
					<div>
						<h3 class="text-xl font-bold mb-3">Privacy Controls</h3>
						<p class="text-indigo-200">Choose between public and private events or playlists, with granular control over who can access and contribute.</p>
					</div>
				</div>
				
				<div class="flex flex-col md:flex-row items-start md:items-center gap-6">
					<div class="bg-purple-700 rounded-full p-4 text-white">
						<svg xmlns="http://www.w3.org/2000/svg" class="h-8 w-8" fill="none" viewBox="0 0 24 24" stroke="currentColor">
							<path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M9 12l2 2 4-4m5.618-4.016A11.955 11.955 0 0112 2.944a11.955 11.955 0 01-8.618 3.04A12.02 12.02 0 003 9c0 5.591 3.824 10.29 9 11.622 5.176-1.332 9-6.03 9-11.622 0-1.042-.133-2.052-.382-3.016z" />
						</svg>
					</div>
					<div>
						<h3 class="text-xl font-bold mb-3">License Management</h3>
						<p class="text-indigo-200">Control who can vote and edit with flexible licensing options, including location-based permissions.</p>
					</div>
				</div>
			</div>
		</div>
	</div>

	<!-- Getting Started Section -->
	<div class="py-20">
		<div class="container mx-auto px-4 text-center">
			<h2 class="text-3xl md:text-4xl font-bold mb-6">Ready to Get Started?</h2>
			<p class="text-xl mb-12 max-w-2xl mx-auto">Join Music Room today and transform how you experience music with friends</p>
			
			<div class="flex flex-col sm:flex-row gap-4 justify-center">
				<a href="/auth/register" class="bg-purple-600 hover:bg-purple-700 text-white font-bold py-3 px-8 rounded-full transition duration-300">
					Create Free Account
				</a>
				<a href="#features" class="bg-transparent border-2 border-purple-600 hover:bg-purple-600 text-white font-bold py-3 px-8 rounded-full transition duration-300">
					Learn More
				</a>
			</div>
		</div>
	</div>
</section>