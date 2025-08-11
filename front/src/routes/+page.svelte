<svelte:head>
	<title>Music Room - Collaborative Music Experience</title>
	<meta name="description" content="Create, share, and enjoy music together with friends in real-time" />
</svelte:head>

<script lang="ts">
  import { authService } from '$lib/services/auth';
  import { onMount } from 'svelte';
  
  let user: any = null;
  
  onMount(async () => {
    user = authService.isAuthenticated();
  });
</script>

<section class="min-h-screen bg-primary text-[#5e53f1]">
	<div class="container mx-auto px-4 py-16 flex flex-col items-center justify-center text-center">
	{#if user}
	  <div class="mb-6 text-lg text-gray-800">
		Welcome back, <span class="font-semibold">{user.displayName || user.email}</span>!
	  </div>
	{/if}
		<h1 class="font-family-main text-5xl md:text-6xl font-bold mb-8 text-gray-800">
			Music Room
		</h1>
		
		<p class="text-xl md:text-2xl mb-12 max-w-2xl text-gray-700">
			Create, share, and enjoy music together with friends in real-time
		</p>
		
		<div class="grid grid-cols-1 md:grid-cols-3 gap-8 w-full max-w-4xl mb-12">
			<div class="bg-white bg-opacity-80 p-6 rounded-lg shadow-lg border border-secondary/20">
				<div class="w-12 h-12 bg-secondary/20 rounded-lg flex items-center justify-center mb-4 mx-auto">
					<svg class="w-6 h-6 text-secondary" fill="none" stroke="currentColor" viewBox="0 0 24 24">
						<path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M5 15l7-7 7 7"></path>
					</svg>
				</div>
				<h3 class="text-xl font-bold mb-3 text-gray-800">Track Voting</h3>
				<p class="text-gray-600 mb-4">Vote on the next tracks to play at events and parties. Create democratic playlists where everyone has a voice.</p>
				<a href="/events" class="inline-block bg-secondary text-white px-4 py-2 rounded-lg hover:bg-secondary/80 transition-colors">
					Join Events
				</a>
			</div>
			
			<div class="bg-white bg-opacity-80 p-6 rounded-lg shadow-lg border border-secondary/20">
				<div class="w-12 h-12 bg-secondary/20 rounded-lg flex items-center justify-center mb-4 mx-auto">
					<svg class="w-6 h-6 text-secondary" fill="none" stroke="currentColor" viewBox="0 0 24 24">
						<path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M9 19V6l12-3v13M9 19c0 1.105-1.343 2-3 2s-3-.895-3-2 1.343-2 3-2 3 .895 3 2z"></path>
					</svg>
				</div>
				<h3 class="text-xl font-bold mb-3 text-gray-800">Playlist Editor</h3>
				<p class="text-gray-600 mb-4">Collaborate on playlists in real-time with your friends. Build the perfect soundtrack together.</p>
				<a href="/playlists" class="inline-block bg-secondary text-white px-4 py-2 rounded-lg hover:bg-secondary/80 transition-colors">
					Create Playlists
				</a>
			</div>
			
			<div class="bg-white bg-opacity-80 p-6 rounded-lg shadow-lg border border-secondary/20">
				<div class="w-12 h-12 bg-secondary/20 rounded-lg flex items-center justify-center mb-4 mx-auto">
					<svg class="w-6 h-6 text-secondary" fill="none" stroke="currentColor" viewBox="0 0 24 24">
						<path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M8 9l3 3-3 3m13 0h-6"></path>
					</svg>
				</div>
				<h3 class="text-xl font-bold mb-3 text-gray-800">Control Delegation</h3>
				<p class="text-gray-600 mb-4">Share music control with friends across devices. Let others DJ for you remotely.</p>
				{#if user}
				<a href="/devices" class="inline-block bg-secondary text-white px-4 py-2 rounded-lg hover:bg-secondary/80 transition-colors">
					Manage Devices
				</a>
				{:else}
				<a href="/auth/login" class="inline-block bg-secondary text-white px-4 py-2 rounded-lg hover:bg-secondary/80 transition-colors">
					Get Started
				</a>
				{/if}
			</div>
		</div>

		{#if !user}
		<div class="flex space-x-4">
			<a href="/auth/register" class="bg-secondary text-white px-8 py-3 rounded-lg font-semibold hover:bg-secondary/80 transition-colors">
				Get Started
			</a>
			<a href="/auth/login" class="border border-secondary text-secondary px-8 py-3 rounded-lg font-semibold hover:bg-secondary/10 transition-colors">
				Sign In
			</a>
		</div>
		{:else}
		<div class="grid grid-cols-1 md:grid-cols-2 gap-6 w-full max-w-2xl">
			<a href="/events" class="bg-secondary text-white px-6 py-3 rounded-lg font-semibold text-center hover:bg-secondary/80 transition-colors">
				Browse Events
			</a>
			<a href="/playlists" class="border border-secondary text-secondary px-6 py-3 rounded-lg font-semibold text-center hover:bg-secondary/10 transition-colors">
				My Playlists
			</a>
		</div>
		{/if}
	</div>

	<!-- Features Overview -->
	<div class="container mx-auto px-4 py-16">
		<div class="text-center mb-12">
			<h2 class="font-family-main text-3xl md:text-4xl font-bold mb-4 text-gray-800">
				How It Works
			</h2>
			<p class="text-lg text-gray-600 max-w-2xl mx-auto">
				Music Room brings people together through the universal language of music
			</p>
		</div>

		<div class="grid grid-cols-1 md:grid-cols-3 gap-8 mb-16">
			<div class="text-center">
				<div class="w-16 h-16 bg-secondary/20 rounded-full flex items-center justify-center mb-4 mx-auto">
					<span class="text-2xl font-bold text-secondary">1</span>
				</div>
				<h3 class="text-xl font-semibold mb-2 text-gray-800">Create or Join</h3>
				<p class="text-gray-600">Start a new event or playlist, or join existing ones created by your friends.</p>
			</div>

			<div class="text-center">
				<div class="w-16 h-16 bg-secondary/20 rounded-full flex items-center justify-center mb-4 mx-auto">
					<span class="text-2xl font-bold text-secondary">2</span>
				</div>
				<h3 class="text-xl font-semibold mb-2 text-gray-800">Collaborate</h3>
				<p class="text-gray-600">Add tracks, vote for favorites, and work together to create the perfect musical experience.</p>
			</div>

			<div class="text-center">
				<div class="w-16 h-16 bg-secondary/20 rounded-full flex items-center justify-center mb-4 mx-auto">
					<span class="text-2xl font-bold text-secondary">3</span>
				</div>
				<h3 class="text-xl font-semibold mb-2 text-gray-800">Enjoy Together</h3>
				<p class="text-gray-600">Listen and enjoy music together, whether you're in the same room or across the world.</p>
			</div>
		</div>

		<div class="bg-white bg-opacity-80 rounded-xl p-8 shadow-lg border border-secondary/20">
			<div class="grid grid-cols-1 md:grid-cols-2 gap-8 items-center">
				<div>
					<h3 class="font-family-main text-2xl font-bold mb-4 text-gray-800">
						Perfect for Any Occasion
					</h3>
					<ul class="space-y-3 text-gray-600">
						<li class="flex items-center">
							<svg class="w-5 h-5 text-secondary mr-3" fill="none" stroke="currentColor" viewBox="0 0 24 24">
								<path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M5 13l4 4L19 7"></path>
							</svg>
							House parties and gatherings
						</li>
						<li class="flex items-center">
							<svg class="w-5 h-5 text-secondary mr-3" fill="none" stroke="currentColor" viewBox="0 0 24 24">
								<path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M5 13l4 4L19 7"></path>
							</svg>
							Road trips and travel
						</li>
						<li class="flex items-center">
							<svg class="w-5 h-5 text-secondary mr-3" fill="none" stroke="currentColor" viewBox="0 0 24 24">
								<path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M5 13l4 4L19 7"></path>
							</svg>
							Workout sessions
						</li>
						<li class="flex items-center">
							<svg class="w-5 h-5 text-secondary mr-3" fill="none" stroke="currentColor" viewBox="0 0 24 24">
								<path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M5 13l4 4L19 7"></path>
							</svg>
							Study groups and work
						</li>
						<li class="flex items-center">
							<svg class="w-5 h-5 text-secondary mr-3" fill="none" stroke="currentColor" viewBox="0 0 24 24">
								<path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M5 13l4 4L19 7"></path>
							</svg>
							Virtual hangouts
						</li>
					</ul>
				</div>
				<div class="text-center">
					<div class="w-32 h-32 bg-gradient-to-br from-secondary/20 to-purple-300 rounded-full flex items-center justify-center mx-auto mb-6">
						<svg class="w-16 h-16 text-secondary" fill="none" stroke="currentColor" viewBox="0 0 24 24">
							<path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M17 20h5v-2a3 3 0 00-5.356-1.857M17 20H7m10 0v-2c0-.656-.126-1.283-.356-1.857M7 20H2v-2a3 3 0 015.356-1.857M7 20v-2c0-.656.126-1.283.356-1.857m0 0a5.002 5.002 0 019.288 0M15 7a3 3 0 11-6 0 3 3 0 016 0zm6 3a2 2 0 11-4 0 2 2 0 014 0zM7 10a2 2 0 11-4 0 2 2 0 014 0z"></path>
						</svg>
					</div>
					{#if !user}
					<a href="/auth/register" class="bg-secondary text-white px-6 py-3 rounded-lg font-semibold hover:bg-secondary/80 transition-colors">
						Join the Community
					</a>
					{/if}
				</div>
			</div>
		</div>
	</div>
</section>