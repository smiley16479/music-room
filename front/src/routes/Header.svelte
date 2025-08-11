<script lang="ts">
	import { page } from '$app/state';
	import { authStore } from '$lib/stores/auth';

	// Use the reactive auth store
	let user = $derived($authStore);

	function logout() {
		authStore.logout();
		window.location.href = '/';
	}
</script>

<header class="sticky top-0 z-50 flex justify-between items-center w-full bg-accent/90 backdrop-blur-sm border-b border-secondary/20">
  <div class="flex items-center px-4">
	<h1 class="font-family-main text-2xl font-bold text-gray-800">MUSIC ROOM</h1>
  </div>
  
  <nav class="flex justify-center items-center px-2 rounded-lg">
	<svg viewBox="0 0 2 3" aria-hidden="true" class="w-8 h-12 block">
	  <path d="M0,0 L1,2 C1.5,3 1.5,3 2,3 L2,0 Z" fill="rgba(219, 217, 248, 0.7)" />
	</svg>
	<ul class="flex items-center h-12 list-none m-0 p-0 relative bg-accent/70">
	  <li class="relative h-full {page.url.pathname === '/' ? 'before:content-[\"\"] before:absolute before:top-0 before:left-[calc(50%-6px)] before:w-0 before:h-0 before:border-[6px] before:border-transparent before:border-t-secondary' : ''}">
		<a href="/" class="flex h-full items-center px-3 font-bold text-sm uppercase tracking-widest text-gray-800 hover:text-secondary transition-colors">Home</a>
	  </li>
	  <li class="relative h-full {String(page.url.pathname).startsWith('/events') ? 'before:content-[\"\"] before:absolute before:top-0 before:left-[calc(50%-6px)] before:w-0 before:h-0 before:border-[6px] before:border-transparent before:border-t-secondary' : ''}">
		<a href="/events" class="flex h-full items-center px-3 font-bold text-sm uppercase tracking-widest text-gray-800 hover:text-secondary transition-colors">Events</a>
	  </li>
	  <li class="relative h-full {String(page.url.pathname).startsWith('/playlists') ? 'before:content-[\"\"] before:absolute before:top-0 before:left-[calc(50%-6px)] before:w-0 before:h-0 before:border-[6px] before:border-transparent before:border-t-secondary' : ''}">
		<a href="/playlists" class="flex h-full items-center px-3 font-bold text-sm uppercase tracking-widest text-gray-800 hover:text-secondary transition-colors">Playlists</a>
	  </li>
	  {#if user}
	  <li class="relative h-full {String(page.url.pathname).startsWith('/devices') ? 'before:content-[\"\"] before:absolute before:top-0 before:left-[calc(50%-6px)] before:w-0 before:h-0 before:border-[6px] before:border-transparent before:border-t-secondary' : ''}">
		<a href="/devices" class="flex h-full items-center px-3 font-bold text-sm uppercase tracking-widest text-gray-800 hover:text-secondary transition-colors">Devices</a>
	  </li>
	  {/if}
	</ul>
	<svg viewBox="0 0 2 3" aria-hidden="true" class="w-8 h-12 block">
	  <path d="M0,0 L0,3 C0.5,3 0.5,3 1,2 L2,0 Z" fill="rgba(219, 217, 248, 0.7)" />
	</svg>
  </nav>
  
  <div class="flex items-center px-4 space-x-3">
	{#if user}
	  <div class="flex items-center space-x-3">
		<a href="/profile" class="flex items-center space-x-2 text-gray-800 hover:text-secondary transition-colors">
		  {#if user.profilePicture}
			<img src={user.profilePicture} alt="Profile" class="w-8 h-8 rounded-full object-cover" />
		  {:else}
			<div class="w-8 h-8 rounded-full bg-secondary/20 flex items-center justify-center">
			  <span class="text-sm font-semibold">{user.displayName?.charAt(0) || user.email.charAt(0)}</span>
			</div>
		  {/if}
		  <span class="text-sm font-medium hidden md:block">{user.displayName || user.email}</span>
		</a>
		<button 
		  onclick={logout}
		  class="bg-secondary text-white px-3 py-1 rounded text-sm font-medium hover:bg-secondary/80 transition-colors"
		>
		  Logout
		</button>
	  </div>
	{:else}
	  <div class="flex items-center space-x-2">
		<a href="/auth/login" class="text-gray-800 hover:text-secondary transition-colors text-sm font-medium">Login</a>
		<a href="/auth/register" class="bg-secondary text-white px-3 py-1 rounded text-sm font-medium hover:bg-secondary/80 transition-colors">Sign Up</a>
	  </div>
	{/if}
  </div>
</header>