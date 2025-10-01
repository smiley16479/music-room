import { writable } from 'svelte/store';

// Define types for different audio player types
type AudioPlayer = HTMLAudioElement | any; // 'any' for YouTube player which has different methods

// Global audio manager to ensure only one audio instance plays at a time
class GlobalAudioManager {
  private currentAudioElement: AudioPlayer | null = null;
  private currentAudioId: string | null = null;

  /**
   * Check if an element is an HTML5 audio element
   */
  private isHTMLAudioElement(element: AudioPlayer): element is HTMLAudioElement {
    return element && typeof element.pause === 'function' && element.tagName === 'AUDIO';
  }

  /**
   * Check if an element is a YouTube player
   */
  private isYouTubePlayer(element: AudioPlayer): boolean {
    return element && typeof element.pauseVideo === 'function';
  }

  /**
   * Pause any audio player (HTML5 or YouTube)
   */
  private pausePlayer(player: any) {
    if (player && player.pause && typeof player.pause === 'function') {
      player.pause();
    }
    else if (player && player.pauseVideo && typeof player.pauseVideo === 'function') {
      try {
        player.pauseVideo();
      } catch (error) {
        // Error handling without logging
      }
    }
  }

  /**
   * Register an audio element and pause any previously playing audio
   */
  registerAudio(player: any, audioId: string) {
    if (this.currentAudioId && this.currentAudioId !== audioId && this.currentAudioElement) {
      this.pausePlayer(this.currentAudioElement);
    }
    
    this.currentAudioElement = player;
    this.currentAudioId = audioId;
  }

  /**
   * Unregister an audio element when it's destroyed or paused
   */
  unregisterAudio(audioElement: AudioPlayer, audioId: string): void {
    if (this.currentAudioElement === audioElement) {
      this.currentAudioElement = null;
      this.currentAudioId = null;
    }
  }

  /**
   * Pause all audio elements
   */
  pauseAll(): void {
    if (this.currentAudioElement) {
      this.pausePlayer(this.currentAudioElement);
    }
  }

  /**
   * Get the currently active audio element
   */
  getCurrentAudio(): { element: AudioPlayer | null; id: string | null } {
    return {
      element: this.currentAudioElement,
      id: this.currentAudioId
    };
  }

  /**
   * Check if a specific audio element is the current one
   */
  isCurrentAudio(audioElement: AudioPlayer): boolean {
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
  let isPlaying = false;
  
  if (current.element) {
    // Check if it's HTML5 audio or YouTube player
    if (current.element.tagName === 'AUDIO') {
      isPlaying = !current.element.paused;
    } else if (current.element.getPlayerState) {
      // YouTube player - state 1 is playing
      isPlaying = current.element.getPlayerState() === 1;
    }
  }
  
  globalAudioStore.set({
    currentAudioId: current.id,
    isPlaying
  });
};
