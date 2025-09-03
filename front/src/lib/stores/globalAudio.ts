import { writable } from 'svelte/store';

// Global audio manager to ensure only one audio instance plays at a time
class GlobalAudioManager {
  private currentAudioElement: HTMLAudioElement | null = null;
  private currentAudioId: string | null = null;

  /**
   * Register an audio element and pause any previously playing audio
   */
  registerAudio(audioElement: HTMLAudioElement, audioId: string): void {
    // If there's a different audio element currently playing, pause it
    if (this.currentAudioElement && this.currentAudioElement !== audioElement) {
      this.currentAudioElement.pause();
      console.log(`Paused previous audio (${this.currentAudioId}) to play new audio (${audioId})`);
    }
    
    this.currentAudioElement = audioElement;
    this.currentAudioId = audioId;
  }

  /**
   * Unregister an audio element when it's destroyed or paused
   */
  unregisterAudio(audioElement: HTMLAudioElement, audioId: string): void {
    if (this.currentAudioElement === audioElement) {
      this.currentAudioElement = null;
      this.currentAudioId = null;
      console.log(`Unregistered audio: ${audioId}`);
    }
  }

  /**
   * Pause all audio elements
   */
  pauseAll(): void {
    if (this.currentAudioElement) {
      this.currentAudioElement.pause();
      console.log(`Paused all audio (${this.currentAudioId})`);
    }
  }

  /**
   * Get the currently active audio element
   */
  getCurrentAudio(): { element: HTMLAudioElement | null; id: string | null } {
    return {
      element: this.currentAudioElement,
      id: this.currentAudioId
    };
  }

  /**
   * Check if a specific audio element is the current one
   */
  isCurrentAudio(audioElement: HTMLAudioElement): boolean {
    return this.currentAudioElement === audioElement;
  }
}

// Create a singleton instance
export const globalAudioManager = new GlobalAudioManager();

// Store to track the global audio state
export const globalAudioStore = writable({
  currentAudioId: null as string | null,
  isPlaying: false
});

// Update the store when audio changes - properly access private members
const updateGlobalAudioStore = () => {
  const current = globalAudioManager.getCurrentAudio();
  globalAudioStore.set({
    currentAudioId: current.id,
    isPlaying: current.element ? !current.element.paused : false
  });
};
