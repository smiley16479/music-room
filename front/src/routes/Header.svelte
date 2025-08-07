<script lang="ts">
	import { page } from '$app/state';
</script>


<header class="sticky top-0 z-50 flex justify-between items-center w-full">
  <div></div>
  <nav class="flex justify-center items-center px-2 rounded-lg">
	<svg viewBox="0 0 2 3" aria-hidden="true" class="w-8 h-12 block">
	  <path d="M0,0 L1,2 C1.5,3 1.5,3 2,3 L2,0 Z" fill="rgba(219, 217, 248, 0.7)" />
	</svg>
	<ul class="flex items-center h-12 list-none m-0 p-0 relative bg-accent/70">
	  <li class="relative h-full {page.url.pathname === '/' ? 'before:content-[\"\"] before:absolute before:top-0 before:left-[calc(50%-6px)] before:w-0 before:h-0 before:border-[6px] before:border-transparent before:border-t-secondary' : ''}">
		<a href="/" class="flex h-full items-center px-2 font-bold text-sm uppercase tracking-widest text-gray-800 hover:text-secondary transition-colors font-semibold">Home</a>
	  </li>
	  <li class="relative h-full {String(page.url.pathname) === '/events' ? 'before:content-[\"\"] before:absolute before:top-0 before:left-[calc(50%-6px)] before:w-0 before:h-0 before:border-[6px] before:border-transparent before:border-t-secondary' : ''}">
		<a href="/events" class="flex h-full items-center px-2 font-bold text-sm uppercase tracking-widest text-gray-800 hover:text-secondary transition-colors font-semibold">Events</a>
	  </li>
	  <li class="relative h-full {String(page.url.pathname) === '/playlist' ? 'before:content-[\"\"] before:absolute before:top-0 before:left-[calc(50%-6px)] before:w-0 before:h-0 before:border-[6px] before:border-transparent before:border-t-secondary' : ''}">
		<a href="/playlist" class="flex h-full items-center px-2 font-bold text-sm uppercase tracking-widest text-gray-800 hover:text-secondary transition-colors font-semibold">Playlist</a>
	  </li>
	</ul>
	<svg viewBox="0 0 2 3" aria-hidden="true" class="w-8 h-12 block">
	  <path d="M0,0 L0,3 C0.5,3 0.5,3 1,2 L2,0 Z" fill="rgba(219, 217, 248, 0.7)" />
	</svg>
  </nav>
  <div></div>
</header>