<script lang="ts">
	import Header from './Header.svelte';
	import '../app.css';
	
	let { children } = $props();
</script>

<div class="bg-primary flex flex-col min-h-screen">
	<Header />

	<main class="flex-1">
		{@render children()}
	</main>

	<footer class="bg-white bg-opacity-80 border-t border-secondary/20 py-8 mt-16">
		<div class="container mx-auto px-4 text-center">
			<div class="grid grid-cols-1 md:grid-cols-3 gap-8 mb-6">
				<div>
					<h4 class="font-bold text-gray-800 mb-2">Music Room</h4>
					<p class="text-gray-600 text-sm">Collaborative music experience for everyone</p>
				</div>
				<div>
					<h4 class="font-bold text-gray-800 mb-2">Features</h4>
					<ul class="text-gray-600 text-sm space-y-1">
						<li><a href="/events" class="hover:text-secondary">Events</a></li>
						<li><a href="/playlists" class="hover:text-secondary">Playlists</a></li>
						<li><a href="/devices" class="hover:text-secondary">Devices</a></li>
					</ul>
				</div>
				<div>
					<h4 class="font-bold text-gray-800 mb-2">Connect</h4>
					<ul class="text-gray-600 text-sm space-y-1">
						<li><a href="/profile" class="hover:text-secondary">Profile</a></li>
						<li><a href="/auth/login" class="hover:text-secondary">Sign In</a></li>
						<li><a href="/auth/register" class="hover:text-secondary">Register</a></li>
					</ul>
				</div>
			</div>
			<div class="border-t border-gray-200 pt-6">
				<p class="text-gray-500 text-sm">
					© 2024 Music Room. Built with ❤️ for music lovers everywhere.
				</p>
			</div>
		</div>
	</footer>
</div>

<style>
  :global(body) {
    margin: 0;
    padding: 0;
    font-family: 'Inter', sans-serif;
    background: #ffe2c1;
  }
  
  :global(.font-family-main) {
    font-family: 'Inter', sans-serif;
    font-weight: 700;
  }
</style>
