import { writable } from 'svelte/store';
import { authService, type User } from '../services/auth';

function createAuthStore() {
  const { subscribe, set, update } = writable<User | null>(null);

  return {
    subscribe,
    
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
            }
          })
          .catch(() => {
            // If server request fails, keep the localStorage user
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
      const user = await authService.getCurrentUser();
      set(user);
      return user;
    }
  };
}

export const authStore = createAuthStore();
