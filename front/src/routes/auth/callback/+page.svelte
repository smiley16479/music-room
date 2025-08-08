<script lang="ts">
  import { onMount } from 'svelte';
  import { goto } from '$app/navigation';
  import { page } from '$app/stores';

  let error = '';
  let processing = true;

  onMount(() => {
    const params = new URLSearchParams(window.location.search);
    const token = params.get('token');
    const refreshToken = params.get('refresh');
    const errorMsg = params.get('error');
    
    if (errorMsg) {
      error = decodeURIComponent(errorMsg);
      processing = false;
      return;
    }

    if (token && refreshToken) {
      // Store tokens
      localStorage.setItem('accessToken', token);
      localStorage.setItem('refreshToken', refreshToken);
      
      // Redirect to home page
      setTimeout(() => {
        goto('/');
      }, 1000);
    } else {
      error = 'Authentication failed: No tokens received';
      processing = false;
    }
  });
</script>

<div class="flex min-h-[calc(100vh-12rem)] items-center justify-center">
  <div class="w-full max-w-md space-y-8 p-8 bg-white dark:bg-gray-800 rounded-lg shadow-md">
    <div class="text-center">
      <h1 class="text-3xl font-bold text-gray-900 dark:text-white">Authentication</h1>
      
      {#if processing}
        <div class="mt-4">
          <svg class="animate-spin mx-auto h-10 w-10 text-primary" xmlns="http://www.w3.org/2000/svg" fill="none" viewBox="0 0 24 24">
            <circle class="opacity-25" cx="12" cy="12" r="10" stroke="currentColor" stroke-width="4"></circle>
            <path class="opacity-75" fill="currentColor" d="M4 12a8 8 0 018-8V0C5.373 0 0 5.373 0 12h4zm2 5.291A7.962 7.962 0 014 12H0c0 3.042 1.135 5.824 3 7.938l3-2.647z"></path>
          </svg>
          <p class="mt-2 text-sm text-gray-600 dark:text-gray-400">
            Processing authentication, please wait...
          </p>
        </div>
      {:else if error}
        <div class="p-3 bg-red-100 border border-red-400 text-red-700 rounded">
          {error}
        </div>
        <div class="mt-4">
          <a href="/auth/login" class="font-medium text-primary hover:text-primary-dark">
            Return to login
          </a>
        </div>
      {:else}
        <div class="p-3 bg-green-100 border border-green-400 text-green-700 rounded">
          Authentication successful! Redirecting...
        </div>
      {/if}
    </div>
  </div>
</div>
