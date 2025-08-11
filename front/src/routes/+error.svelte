<script lang="ts">
  import { page } from '$app/stores';
</script>

<svelte:head>
  <title>Error - Music Room</title>
</svelte:head>

<div class="min-h-screen bg-primary flex items-center justify-center">
  <div class="container mx-auto px-4 text-center">
    <div class="bg-white bg-opacity-80 rounded-xl p-8 shadow-lg border border-secondary/20 max-w-md mx-auto">
      <div class="w-16 h-16 bg-red-100 rounded-full flex items-center justify-center mb-6 mx-auto">
        <svg class="w-8 h-8 text-red-500" fill="none" stroke="currentColor" viewBox="0 0 24 24">
          <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M12 9v2m0 4h.01m-6.938 4h13.856c1.54 0 2.502-1.667 1.732-2.5L13.732 4c-.77-.833-1.964-.833-2.732 0L3.732 16.5c-.77.833.192 2.5 1.732 2.5z"></path>
        </svg>
      </div>
      
      <h1 class="text-3xl font-bold text-gray-800 mb-4">
        Oops! Something went wrong
      </h1>
      
      <p class="text-gray-600 mb-6">
        {#if $page.status === 404}
          The page you're looking for doesn't exist.
        {:else if $page.status >= 500}
          We're experiencing technical difficulties. Please try again later.
        {:else}
          An unexpected error occurred.
        {/if}
      </p>
      
      <div class="space-y-3">
        <button 
          onclick={() => history.back()} 
          class="w-full bg-secondary text-white px-6 py-3 rounded-lg font-semibold hover:bg-secondary/80 transition-colors"
        >
          Go Back
        </button>
        
        <a 
          href="/" 
          class="block w-full border border-secondary text-secondary px-6 py-3 rounded-lg font-semibold hover:bg-secondary/10 transition-colors"
        >
          Return Home
        </a>
      </div>
      
      {#if $page.status}
        <p class="text-sm text-gray-500 mt-6">
          Error {$page.status}
        </p>
      {/if}
    </div>
  </div>
</div>
