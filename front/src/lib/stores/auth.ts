import { writable } from 'svelte/store';
import { authService, type User } from '../services/auth';

function createAuthStore() {
  const { subscribe, set, update } = writable<User | null>(null);

  return {
    subscribe,
    set, // Expose the set method
    
    // Initialize the store with current auth state
    init: () => {
      const user = authService.isAuthenticated();
      set(user);
      
      // If we have tokens, try to get fresh data in the background
      if (authService.getAuthToken()) {
        authService.getCurrentUser()
          .then((freshUser: User | null) => {
            if (freshUser) {
              set(freshUser);
            } else {
              // Check if we still have tokens after the getCurrentUser call
              const stillHasTokens = authService.getAuthToken();
              if (!stillHasTokens) {
                // Tokens were cleared by getCurrentUser due to auth failure
                set(null);
              } else if (user) {
                // Server failed but we have cached user and tokens, keep the cached version
                set(user);
              }
            }
          })
          .catch((error) => {
            
            // Check if we still have tokens after the error
            const stillHasTokens = authService.getAuthToken();
            if (!stillHasTokens) {
              // Tokens were cleared due to auth failure
              set(null);
            } else if (user) {
              // We have cached user data and tokens, keep it even if server is unreachable
              set(user);
            } else {
              // No cached user and server failed, user is definitely logged out
              set(null);
            }
          });
      }
    },
    
    // Login and update the store
    login: async (email: string, password: string) => {
      const response = await authService.login({ email, password });
      if (response.success && response.data?.user) {
        set(response.data.user);
      }
      return response;
    },
    
    // Logout and clear the store
    logout: () => {
      authService.logout();
      set(null);
    },
    
    // Update user data in the store
    updateUser: (userData: Partial<User>) => {
      update((currentUser: User | null) => {
        if (currentUser) {
          return { ...currentUser, ...userData };
        }
        return currentUser;
      });
    },
    
    // Refresh user data from server
    refreshUser: async () => {
      const currentUser = authService.isAuthenticated();
      const user = await authService.getCurrentUser();
      
      if (user) {
        set(user);
      } else {
        // Check if tokens were cleared (indicating auth failure)
        const stillHasTokens = authService.getAuthToken();
        if (!stillHasTokens) {
          // User was logged out due to invalid tokens
          set(null);
        } else if (currentUser) {
          // If server refresh failed but we have cached user and tokens, keep the cached version
          set(currentUser);
        } else {
          // No user data available, set to null
          set(null);
        }
      }
      
      return user || currentUser;
    }
  };
}

export const authStore = createAuthStore();
