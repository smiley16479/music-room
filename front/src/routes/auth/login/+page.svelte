
<script lang="ts">
  import { config } from '$lib/config';
  import { authStore } from '$lib/stores/auth';
  import { goto } from '$app/navigation';

  let email = '';
  let password = '';
  let errors: Record<string, string> = {};
  let isSubmitting = false;
  let generalError = '';
  let successMessage = '';
  let rememberMe = false;

  const validateForm = (): boolean => {
    errors = {};
    if (!email) {
      errors.email = 'Email is required';
    } else if (!/\S+@\S+\.\S+/.test(email)) {
      errors.email = 'Email is invalid';
    }
    if (!password) {
      errors.password = 'Password is required';
    }
    return Object.keys(errors).length === 0;
  };

  const handleSubmit = async (e: Event) => {
    e.preventDefault();
    if (!validateForm()) {
      return;
    }
    isSubmitting = true;
    generalError = '';
    successMessage = '';
    try {
      const response = await authStore.login(email, password);
      successMessage = response.message || 'Login successful! Redirecting...';
      setTimeout(() => {
        goto('/');
      }, 1500);
    } catch (error: any) {
      generalError = error.message || 'Login failed. Please try again.';
    } finally {
      isSubmitting = false;
    }
  };
</script>


<div class="flex min-h-[calc(100vh-12rem)] items-center justify-center">
  <div class="w-full max-w-md space-y-8 p-8 bg-white dark:bg-gray-800 rounded-lg shadow-md">
    <div class="text-center">
      <h1 class="text-3xl font-bold text-gray-900 dark:text-white">Sign in</h1>
      <p class="mt-2 text-sm text-gray-600 dark:text-gray-400">
        Welcome to {config.appName}, your collaborative music platform
      </p>
    </div>

    {#if generalError}
      <div class="p-3 bg-red-100 border border-red-400 text-red-700 rounded">
        {generalError}
      </div>
    {/if}

    {#if successMessage}
      <div class="p-3 bg-green-100 border border-green-400 text-green-700 rounded">
        {successMessage}
      </div>
    {/if}

    <form class="mt-8 space-y-6" on:submit={handleSubmit}>
      <div class="space-y-4 rounded-md">
        <div>
          <label for="email-address" class="sr-only">Email address</label>
          <input
            id="email-address"
            name="email"
            type="email"
            bind:value={email}
            autocomplete="email"
            required
            class="relative block w-full px-3 py-2 border border-gray-300 dark:border-gray-700 rounded-md placeholder-gray-500 text-gray-900 dark:text-white dark:bg-gray-700 focus:outline-none focus:ring-primary focus:border-primary"
            placeholder="Email address"
          />
          {#if errors.email}
            <p class="mt-1 text-sm text-red-600">{errors.email}</p>
          {/if}
        </div>
        <div>
          <label for="password" class="sr-only">Password</label>
          <input
            id="password"
            name="password"
            type="password"
            bind:value={password}
            autocomplete="current-password"
            required
            class="relative block w-full px-3 py-2 border border-gray-300 dark:border-gray-700 rounded-md placeholder-gray-500 text-gray-900 dark:text-white dark:bg-gray-700 focus:outline-none focus:ring-primary focus:border-primary"
            placeholder="Password"
          />
          {#if errors.password}
            <p class="mt-1 text-sm text-red-600">{errors.password}</p>
          {/if}
        </div>
      </div>

      <div class="flex items-center justify-between">
        <div class="flex items-center">
          <input
            id="remember-me"
            name="rememberMe"
            type="checkbox"
            bind:checked={rememberMe}
            class="h-4 w-4 text-primary focus:ring-primary border-gray-300 rounded"
          />
          <label for="remember-me" class="ml-2 block text-sm text-gray-900 dark:text-gray-300">
            Remember me
          </label>
        </div>
        <div class="text-sm">
          <a href="/auth/reset-password" class="font-medium text-primary hover:text-primary-dark">
            Forgot your password?
          </a>
        </div>
      </div>

      <div>
        <button
          type="submit"
          disabled={isSubmitting}
          class="group relative w-full flex justify-center py-2 px-4 border border-transparent text-sm font-medium rounded-md text-black bg-accent hover:bg-primary-dark focus:outline-none focus:ring-2 focus:ring-offset-2 focus:ring-primary disabled:opacity-50 disabled:cursor-not-allowed"
        >
          {#if isSubmitting}
            <svg class="animate-spin -ml-1 mr-3 h-5 w-5 text-white" xmlns="http://www.w3.org/2000/svg" fill="none" viewBox="0 0 24 24">
              <circle class="opacity-25" cx="12" cy="12" r="10" stroke="currentColor" stroke-width="4"></circle>
              <path class="opacity-75" fill="currentColor" d="M4 12a8 8 0 018-8V0C5.373 0 0 5.373 0 12h4zm2 5.291A7.962 7.962 0 014 12H0c0 3.042 1.135 5.824 3 7.938l3-2.647z"></path>
            </svg>
            Signing in...
          {:else}
            Sign in
          {/if}
        </button>
      </div>
    </form>

    <div class="mt-6">
      <div class="relative">
        <div class="absolute inset-0 flex items-center">
          <div class="w-full border-t border-gray-300 dark:border-gray-700"></div>
        </div>
        <div class="relative flex justify-center text-sm">
          <span class="px-2 bg-white dark:bg-gray-800 text-gray-500 dark:text-gray-400">
            Or sign in with
          </span>
        </div>
      </div>

      <div class="mt-6 grid grid-cols-2 gap-3">
        <div>
          <a
            href="{config.apiUrl}/api/auth/google"
            class="w-full inline-flex justify-center py-2 px-4 border border-gray-300 dark:border-gray-700 rounded-md shadow-sm bg-white dark:bg-gray-700 text-sm font-medium text-gray-700 dark:text-gray-200 hover:bg-gray-50 dark:hover:bg-gray-600"
          >
            <span class="sr-only">Sign in with Google</span>
            <svg class="w-7" viewBox="-0.5 0 48 48">
              <path d="M9.82727273,24 C9.82727273,22.4757333 10.0804318,21.0144 10.5322727,19.6437333 L2.62345455,13.6042667 C1.08206818,16.7338667 0.213636364,20.2602667 0.213636364,24 C0.213636364,27.7365333 1.081,31.2608 2.62025,34.3882667 L10.5247955,28.3370667 C10.0772273,26.9728 9.82727273,25.5168 9.82727273,24" id="Fill-1" fill="#FBBC05"> </path>
              <path d="M23.7136364,10.1333333 C27.025,10.1333333 30.0159091,11.3066667 32.3659091,13.2266667 L39.2022727,6.4 C35.0363636,2.77333333 29.6954545,0.533333333 23.7136364,0.533333333 C14.4268636,0.533333333 6.44540909,5.84426667 2.62345455,13.6042667 L10.5322727,19.6437333 C12.3545909,14.112 17.5491591,10.1333333 23.7136364,10.1333333" id="Fill-2" fill="#EB4335"> </path>
              <path d="M23.7136364,37.8666667 C17.5491591,37.8666667 12.3545909,33.888 10.5322727,28.3562667 L2.62345455,34.3946667 C6.44540909,42.1557333 14.4268636,47.4666667 23.7136364,47.4666667 C29.4455,47.4666667 34.9177955,45.4314667 39.0249545,41.6181333 L31.5177727,35.8144 C29.3995682,37.1488 26.7323182,37.8666667 23.7136364,37.8666667" id="Fill-3" fill="#34A853"> </path>
              <path d="M46.1454545,24 C46.1454545,22.6133333 45.9318182,21.12 45.6113636,19.7333333 L23.7136364,19.7333333 L23.7136364,28.8 L36.3181818,28.8 C35.6879545,31.8912 33.9724545,34.2677333 31.5177727,35.8144 L39.0249545,41.6181333 C43.3393409,37.6138667 46.1454545,31.6490667 46.1454545,24" id="Fill-4" fill="#4285F4"> </path>
            </svg>
          </a>
        </div>

        <div>
          <a
            href="{config.apiUrl}/api/auth/facebook"
            class="w-full inline-flex justify-center py-2 px-4 border border-gray-300 dark:border-gray-700 rounded-md shadow-sm bg-white dark:bg-gray-700 text-sm font-medium text-gray-700 dark:text-gray-200 hover:bg-gray-50 dark:hover:bg-gray-600"
          >
            <span class="sr-only">Sign in with Facebook</span>
            <svg class="w-7" viewBox="1 1 14 14" fill="none">
              <path fill="#ffffff" d="M10.725 10.023L11.035 8H9.094V6.687c0-.553.27-1.093 1.14-1.093h.883V3.87s-.801-.137-1.567-.137c-1.6 0-2.644.97-2.644 2.724V8H5.13v2.023h1.777v4.892a7.037 7.037 0 002.188 0v-4.892h1.63z"></path>
              <path fill="#0866ff" d="M15 8a7 7 0 00-7-7 7 7 0 00-1.094 13.915v-4.892H5.13V8h1.777V6.458c0-1.754 1.045-2.724 2.644-2.724.766 0 1.567.137 1.567.137v1.723h-.883c-.87 0-1.14.54-1.14 1.093V8h1.941l-.31 2.023H9.094v4.892A7.001 7.001 0 0015 8z"></path>
            </svg>
          </a>
        </div>
      </div>
    </div>

    <div class="text-center mt-4">
      <p class="text-sm text-gray-600 dark:text-gray-400">
        Don't have an account?
        <a href="/auth/register" class="font-medium text-primary hover:text-primary-dark">
          Sign up
        </a>
      </p>
    </div>
  </div>
</div>
