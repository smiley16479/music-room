<script lang="ts">
  import { onMount, onDestroy } from 'svelte';
  import { musicPlayerStore } from '$lib/stores/musicPlayer';
  import { authStore } from '$lib/stores/auth';
  import { socketService } from '$lib/services/socket';
  import { devicesService } from '$lib/services/devices';
  
  let audioElement = $state<HTMLAudioElement>();
  let progressSlider = $state<HTMLInputElement>();
  let volumeSlider = $state<HTMLInputElement>();
  let isDragging = $state(false);
  let showVolumeControl = $state(false);
  
  // Subscribe to stores using Svelte 5 runes - break down into specific reactive values to avoid cycles
  let playerState = $derived($musicPlayerStore);
  let user = $derived($authStore);
  
  // Create specific derived values to avoid reactivity cycles
  let currentTrack = $derived(playerState.currentTrack);
  let isPlaying = $derived(playerState.isPlaying);
  let volume = $derived(playerState.volume);
  let isMuted = $derived(playerState.isMuted);
  let isLoading = $derived(playerState.isLoading);
  let canControl = $derived(playerState.canControl);
  let currentTime = $derived(playerState.currentTime);
  let duration = $derived(playerState.duration);
  let playlist = $derived(playerState.playlist);
  let currentTrackIndex = $derived(playerState.currentTrackIndex);
  
  let currentAudioSrc = '';
  let loadTimeout: NodeJS.Timeout | null = null;
  
  // Update audio source when track changes using Svelte 5 effect
  $effect(() => {
    if (audioElement && currentTrack?.previewUrl && currentAudioSrc !== currentTrack.previewUrl) {
      
      // Clear any existing timeout
      if (loadTimeout) {
        clearTimeout(loadTimeout);
        loadTimeout = null;
      }
      
      currentAudioSrc = currentTrack.previewUrl;
      
      // Validate URL before setting it
      try {
        new URL(currentAudioSrc); // This will throw if URL is invalid
        
        audioElement.src = currentAudioSrc;
        audioElement.load(); // Force reload of the audio
        
        // Auto-play if the player is in playing state
        if (isPlaying) {
          // Small delay to ensure audio is loaded
          setTimeout(() => {
            audioElement?.play().catch(error => {
              console.warn('Auto-play failed after track change:', error);
              musicPlayerStore.pause();
            });
          }, 100);
        }
        
        // Set a timeout to clear loading state if audio doesn't load
        loadTimeout = setTimeout(() => {
          // Use a more specific check to avoid reading playerState during effect
          musicPlayerStore.setLoading(false);
          loadTimeout = null;
          console.warn('Audio load timeout for track:', currentTrack.title);
        }, 5000); // 5 second timeout
        
        // Clear timeout when audio loads successfully
        const handleLoadSuccess = () => {
          if (loadTimeout) {
            clearTimeout(loadTimeout);
            loadTimeout = null;
          }
        };
        
        audioElement.addEventListener('canplay', handleLoadSuccess, { once: true });
        audioElement.addEventListener('loadeddata', handleLoadSuccess, { once: true });
        
      } catch (urlError) {
        console.warn('Invalid preview URL for track:', currentTrack.title, urlError);
        musicPlayerStore.setLoading(false);
        // Don't set the invalid URL, keep the previous state
      }
    }
  });

  // Handle the case where currentTrack is set but has no previewUrl using Svelte 5 effect
  $effect(() => {
    if (currentTrack && !currentTrack.previewUrl) {
      musicPlayerStore.setLoading(false);
    }
  });

  // Sync audio element play/pause state with store
  $effect(() => {
    if (audioElement && audioElement.src) {
      if (isPlaying && audioElement.paused) {
        audioElement.play().catch(error => {
          musicPlayerStore.pause();
        });
      } else if (!isPlaying && !audioElement.paused) {
        audioElement.pause();
      }
    }
  });
  
  function formatTime(seconds: number): string {
    const mins = Math.floor(seconds / 60);
    const secs = Math.floor(seconds % 60);
    return `${mins}:${secs.toString().padStart(2, '0')}`;
  }
  
  function handleLoadedMetadata() {
    if (audioElement && currentTrack) {
      musicPlayerStore.setCurrentTime(0);
      musicPlayerStore.setLoading(false);
    }
  }
  
  function handleTimeUpdate() {
    if (audioElement && !isDragging) {
      musicPlayerStore.setCurrentTime(audioElement.currentTime);
    }
  }
  
  function handleEnded() {
    console.log('Track ended, current index:', currentTrackIndex, 'playlist length:', playlist.length);
    
    // Always advance to the next track when a track ends naturally
    musicPlayerStore.nextTrack();
    
    // Auto-play the next track after a brief delay, with better error handling
    setTimeout(async () => {
      const newPlayerState = $musicPlayerStore;
      
      // Only auto-play if we were playing and we have a valid next track
      if (isPlaying && audioElement && newPlayerState.currentTrack) {
        try {
          // Check if the audio source is properly loaded before playing
          if (audioElement.error) {
            console.warn('Next track failed to load, attempting to skip:', audioElement.error);
            
            // Try to skip unplayable tracks, but with a limit to avoid infinite loops
            let skipAttempts = 0;
            const maxSkipAttempts = playlist.length; // Don't skip more than the total playlist length
            
            while (audioElement.error && skipAttempts < maxSkipAttempts) {
              console.log(`Skip attempt ${skipAttempts + 1}/${maxSkipAttempts}`);
              musicPlayerStore.nextTrack();
              skipAttempts++;
              
              // Wait a bit for the new track to load
              await new Promise(resolve => setTimeout(resolve, 200));
              
              // If we've come full circle and still have errors, stop
              if (skipAttempts >= maxSkipAttempts) {
                console.warn('Reached maximum skip attempts, stopping playback to avoid infinite loop');
                musicPlayerStore.pause();
                return;
              }
            }
          }
          
          // Try to play the current track
          await audioElement.play();
          console.log('Successfully auto-played next track');
          
        } catch (error) {
          console.warn('Failed to auto-play next track:', error);
          
          // Try to skip to the next available track, but limit attempts
          let skipAttempts = 0;
          const maxSkipAttempts = Math.min(5, playlist.length); // Limit to 5 attempts or playlist length
          
          while (skipAttempts < maxSkipAttempts) {
            console.log(`Auto-skip attempt ${skipAttempts + 1}/${maxSkipAttempts} due to playback error`);
            musicPlayerStore.nextTrack();
            skipAttempts++;
            
            // Wait a bit and try to play
            await new Promise(resolve => setTimeout(resolve, 300));
            
            try {
              if (audioElement && !audioElement.error) {
                await audioElement.play();
                console.log('Successfully played after skip attempts');
                return; // Success, stop trying
              }
            } catch (retryError) {
              console.log('Retry failed:', retryError);
            }
          }
          
          // If we've exhausted our skip attempts, stop playing
          console.warn('Exhausted skip attempts, stopping playback to prevent infinite loop');
          musicPlayerStore.pause();
        }
      }
    }, 100);
  }
  
  function handleCanPlay() {
    musicPlayerStore.setLoading(false);
  }
  
  function handleLoadStart() {
    musicPlayerStore.setLoading(true);
  }
  
  function handleError(event: Event) {
    const audioError = audioElement?.error;
    if (audioError) {
      // Only log detailed error in development mode, show user-friendly messages
      if (audioError.code === MediaError.MEDIA_ERR_NETWORK) {
        console.info('Preview not available: Network/CORS restriction for track:', currentTrack?.title);
      } else if (audioError.code === MediaError.MEDIA_ERR_SRC_NOT_SUPPORTED) {
        console.info('Preview not available: Format not supported for track:', currentTrack?.title);
      } else {
        console.info('Preview not available: Media load failed for track:', currentTrack?.title);
      }
      
      // If we're currently playing and this error occurred, try to skip to the next track
      if (isPlaying) {
        console.log('Auto-skipping failed track during playback...');
        
        // Use a timeout to avoid immediate recursive calls
        setTimeout(async () => {
          const initialIndex = currentTrackIndex;
          let skipAttempts = 0;
          const maxSkipAttempts = Math.min(playlist.length, 10); // Reasonable limit
          
          // Try to find a playable track
          while (skipAttempts < maxSkipAttempts) {
            musicPlayerStore.nextTrack();
            skipAttempts++;
            
            const newState = $musicPlayerStore;
            
            // If we've circled back to where we started, stop to avoid infinite loop
            if (newState.currentTrackIndex === initialIndex && skipAttempts > 1) {
              console.warn('Circled back to original track, stopping to avoid infinite loop');
              musicPlayerStore.pause();
              break;
            }
            
            // Wait a moment for the new track to load
            await new Promise(resolve => setTimeout(resolve, 200));
            
            // Check if the new track is playable
            if (audioElement && !audioElement.error) {
              try {
                await audioElement.play();
                console.log(`Successfully found playable track after ${skipAttempts} attempts`);
                return; // Success!
              } catch (playError) {
                console.log(`Track ${newState.currentTrackIndex} also failed to play:`, playError);
                // Continue to next iteration
              }
            }
          }
          
          // If we get here, we couldn't find any playable tracks
          console.warn('Could not find any playable tracks, stopping playback');
          musicPlayerStore.pause();
        }, 500);
      }
    }
    musicPlayerStore.setLoading(false);
    // Don't automatically pause on error for manual play attempts
  }

  async function handlePlayPause() {
    if (!canControl) return;
    
    try {
      if (playerState.deviceId) {
        // Send command to device
        if (playerState.isPlaying) {
          await devicesService.pauseDevice(playerState.deviceId);
        } else {
          await devicesService.playDevice(playerState.deviceId, {
            trackId: playerState.currentTrack?.id
          });
        }
      } else {
        if (audioElement && playerState.currentTrack?.previewUrl) {
          if (playerState.isPlaying) {
            audioElement.pause();
            musicPlayerStore.pause();
          } else {
            // Check if audio has failed to load before trying to play
            if (audioElement.error) {
              console.warn('Cannot play: Audio failed to load due to CORS/403 error');
              console.info('This track preview is not available due to licensing restrictions');
              return;
            }
            
            // Ensure audio is loaded before playing
            if (audioElement.src !== playerState.currentTrack.previewUrl) {
              audioElement.src = playerState.currentTrack.previewUrl;
              audioElement.load();
              
              // Wait for audio to load or fail before trying to play
              const loadPromise = new Promise<void>((resolve, reject) => {
                const onCanPlay = () => {
                  cleanup();
                  resolve();
                };
                const onError = () => {
                  cleanup();
                  reject(new Error('Audio failed to load'));
                };
                const cleanup = () => {
                  audioElement?.removeEventListener('canplay', onCanPlay);
                  audioElement?.removeEventListener('error', onError);
                };
                
                if (audioElement) {
                  audioElement.addEventListener('canplay', onCanPlay, { once: true });
                  audioElement.addEventListener('error', onError, { once: true });
                }
                
                // Timeout after 3 seconds
                setTimeout(() => {
                  cleanup();
                  reject(new Error('Audio load timeout'));
                }, 3000);
              });
              
              try {
                await loadPromise;
              } catch (loadError) {
                const errorMessage = loadError instanceof Error ? loadError.message : 'Unknown error';
                console.warn('Audio preview not available:', errorMessage);
                console.info('This track preview cannot be played due to licensing or CORS restrictions');
                return;
              }
            }
            
            await audioElement.play();
            musicPlayerStore.play();
          }
        } else if (!playerState.currentTrack?.previewUrl) {
          console.warn('No preview URL available for current track');
        }
      }
    } catch (error) {
      const errorMessage = error instanceof Error ? error.message : String(error);
      console.warn('Playback failed:', errorMessage);
      console.info('This track preview cannot be played due to browser security policies or licensing restrictions');
      musicPlayerStore.setLoading(false);
      musicPlayerStore.pause();
    }
  }

  async function handleNext() {
    if (!canControl) return;
    
    try {
      if (playerState.deviceId) {
        await devicesService.skipDevice(playerState.deviceId);
      }
      musicPlayerStore.nextTrack();
    } catch (error) {
      console.error('Next track error:', error);
    }
  }
  
  async function handlePrevious() {
    if (!canControl) return;
    
    try {
      if (playerState.deviceId) {
        await devicesService.previousDevice(playerState.deviceId);
      }
      musicPlayerStore.previousTrack();
    } catch (error) {
      console.error('Previous track error:', error);
    }
  }
  
  async function handleVolumeChange(event: Event) {
    if (!canControl) return;
    
    const target = event.target as HTMLInputElement;
    const volume = parseInt(target.value);
    
    try {
      if (playerState.deviceId) {
        await devicesService.setDeviceVolume(playerState.deviceId, volume);
      } else if (audioElement) {
        audioElement.volume = volume / 100;
      }
      musicPlayerStore.setVolume(volume);
    } catch (error) {
      console.error('Volume change error:', error);
    }
  }
  
  function handleSeek(event: Event) {
    if (!canControl || !audioElement) return;
    
    const target = event.target as HTMLInputElement;
    const time = parseFloat(target.value);
    
    try {
      if (playerState.deviceId) {
        devicesService.seekDevice(playerState.deviceId, time);
      } else {
        audioElement.currentTime = time;
      }
      musicPlayerStore.seekTo(time);
    } catch (error) {
      console.error('Seek error:', error);
    }
  }
  
  function handleProgressMouseDown() {
    isDragging = true;
  }
  
  function handleProgressMouseUp() {
    isDragging = false;
  }
  
  function toggleMute() {
    if (!canControl) return;
    
    musicPlayerStore.toggleMute();
    if (audioElement) {
      audioElement.muted = !audioElement.muted;
    }
  }
  
  // Socket event handlers for real-time sync
  function setupSocketListeners() {
    if (!socketService.isConnected()) return;
    
    socketService.on('music-play', () => {
      musicPlayerStore.play();
      if (audioElement && !audioElement.paused) {
        audioElement.play().catch(console.error);
      }
    });
    
    socketService.on('music-pause', () => {
      musicPlayerStore.pause();
      if (audioElement && !audioElement.paused) {
        audioElement.pause();
      }
    });
    
    socketService.on('music-seek', (data: { time: number }) => {
      musicPlayerStore.seekTo(data.time);
      if (audioElement) {
        audioElement.currentTime = data.time;
      }
    });
    
    socketService.on('music-volume', (data: { volume: number }) => {
      musicPlayerStore.setVolume(data.volume);
      if (audioElement) {
        audioElement.volume = data.volume / 100;
      }
    });
    
    socketService.on('track-changed', (data: any) => {
      musicPlayerStore.setCurrentTrack(data.track, data.playlist, data.index);
    });
  }
  
  // Reactive updates using Svelte 5 effect
  $effect(() => {
    if (audioElement) {
      audioElement.volume = (isMuted ? 0 : volume) / 100;
    }
  });
  
  onMount(() => {
    setupSocketListeners();
    
    // Set initial audio properties
    if (audioElement) {
      audioElement.volume = playerState.volume / 100;
    }
  });
  
  onDestroy(() => {
    // Clear any pending timeout
    if (loadTimeout) {
      clearTimeout(loadTimeout);
      loadTimeout = null;
    }
    
    if (socketService.isConnected()) {
      socketService.off('music-play');
      socketService.off('music-pause');
      socketService.off('music-seek');
      socketService.off('music-volume');
      socketService.off('track-changed');
    }
  });
</script>

<!-- Audio element for local playback -->
<audio 
  bind:this={audioElement}
  onloadedmetadata={handleLoadedMetadata}
  ontimeupdate={handleTimeUpdate}
  onended={handleEnded}
  oncanplay={handleCanPlay}
  onloadstart={handleLoadStart}
  onerror={handleError}
  preload="metadata"
  class="hidden"
></audio>

<!-- Music Player UI -->
{#if currentTrack || playlist.length > 0}
<div class="fixed bottom-0 left-0 right-0 bg-white border-t-2 border-secondary shadow-2xl z-50" style="min-height: 80px;">
  <div class="container mx-auto px-4 py-3">
    <!-- Progress Bar -->
    <div class="w-full mb-3">
      <input
        bind:this={progressSlider}
        type="range"
        min="0"
        max={duration || 100}
        value={currentTime}
        oninput={handleSeek}
        onmousedown={handleProgressMouseDown}
        onmouseup={handleProgressMouseUp}
        disabled={!canControl}
        class="w-full h-1 bg-gray-200 rounded-lg appearance-none cursor-pointer slider"
        class:disabled={!canControl}
      />
      <div class="flex justify-between text-xs text-gray-500 mt-1">
        <span>{formatTime(currentTime)}</span>
        <span>{formatTime(duration)}</span>
      </div>
    </div>

    <!-- Main Player Controls -->
    <div class="flex items-center justify-between">
      <!-- Track Info -->
      <div class="flex items-center space-x-3 flex-1 min-w-0">
        {#if currentTrack?.albumCoverUrl}
          <img 
            src={currentTrack.albumCoverUrl} 
            alt="Album cover"
            class="w-12 h-12 rounded-lg object-cover flex-shrink-0"
          />
        {:else}
          <div class="w-12 h-12 bg-gray-200 rounded-lg flex items-center justify-center flex-shrink-0">
            <svg class="w-6 h-6 text-gray-400" fill="none" stroke="currentColor" viewBox="0 0 24 24">
              <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M9 19V6l12-3v13M9 19c0 1.105-1.343 2-3 2s-3-.895-3-2 1.343-2 3-2 3 .895 3 2zm12-3c0 1.105-1.343 2-3 2s-3-.895-3-2 1.343-2 3-2 3 .895 3 2zM9 10l12-3"></path>
            </svg>
          </div>
        {/if}
        
        <div class="min-w-0 flex-1">
          <h4 class="text-sm font-medium text-gray-900 truncate">
            {currentTrack?.title || 'Ready to play'}
          </h4>
          <p class="text-xs text-gray-500 truncate">
            {currentTrack?.artist || `${playlist.length} tracks available`}
          </p>
        </div>
      </div>

      <!-- Playback Controls -->
      <div class="flex items-center space-x-3 mx-6">
        <button
          onclick={handlePrevious}
          disabled={!canControl || playlist.length === 0}
          class="p-2 rounded-full hover:bg-gray-100 disabled:opacity-50 disabled:cursor-not-allowed transition-colors"
          title="Previous track"
          aria-label="Previous track"
        >
          <svg class="w-5 h-5" fill="none" stroke="currentColor" viewBox="0 0 24 24">
            <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M11 19l-7-7 7-7m8 14l-7-7 7-7"></path>
          </svg>
        </button>

        <button
          onclick={handlePlayPause}
          disabled={!canControl || isLoading || (!currentTrack && playlist.length === 0) || (!!audioElement?.error && !!currentTrack?.previewUrl)}
          class="p-3 bg-secondary text-white rounded-full hover:bg-secondary/90 disabled:opacity-50 disabled:cursor-not-allowed transition-colors"
          title={
            !currentTrack ? 'Select a track to play' :
            audioElement?.error && currentTrack?.previewUrl ? 'Preview unavailable due to licensing restrictions' :
            !currentTrack?.previewUrl ? 'No preview available for this track' :
            isPlaying ? 'Pause preview' : 'Play preview'
          }
        >
          {#if isLoading}
            <svg class="w-5 h-5 animate-spin" fill="none" viewBox="0 0 24 24">
              <circle class="opacity-25" cx="12" cy="12" r="10" stroke="currentColor" stroke-width="4"></circle>
              <path class="opacity-75" fill="currentColor" d="m4 12a8 8 0 018-8V0C5.373 0 0 5.373 0 12h4zm2 5.291A7.962 7.962 0 014 12H0c0 3.042 1.135 5.824 3 7.938l3-2.647z"></path>
            </svg>
          {:else if isPlaying}
            <svg class="w-5 h-5" fill="none" stroke="currentColor" viewBox="0 0 24 24">
              <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M10 9v6m4-6v6m7-3a9 9 0 11-18 0 9 9 0 0118 0z"></path>
            </svg>
          {:else}
            <svg class="w-5 h-5" fill="currentColor" viewBox="0 0 24 24">
              <path d="M8 5v14l11-7z"></path>
            </svg>
          {/if}
        </button>

        <button
          onclick={handleNext}
          disabled={!canControl || playlist.length === 0}
          class="p-2 rounded-full hover:bg-gray-100 disabled:opacity-50 disabled:cursor-not-allowed transition-colors"
          title="Next track"
          aria-label="Next track"
        >
          <svg class="w-5 h-5" fill="none" stroke="currentColor" viewBox="0 0 24 24">
            <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M13 5l7 7-7 7M5 5l7 7-7 7"></path>
          </svg>
        </button>
      </div>

      <!-- Volume Control -->
      <div class="flex items-center space-x-2 flex-1 justify-end">
        <button
          onclick={() => showVolumeControl = !showVolumeControl}
          class="p-2 rounded-full hover:bg-gray-100 transition-colors"
          title="Volume"
        >
          {#if isMuted || volume === 0}
            <svg class="w-5 h-5" fill="none" stroke="currentColor" viewBox="0 0 24 24">
              <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M5.586 15H4a1 1 0 01-1-1v-4a1 1 0 011-1h1.586l4.707-4.707C10.923 3.663 12 4.109 12 5v14c0 .891-1.077 1.337-1.707.707L5.586 15z M17 14l2-2m0 0l2-2m-2 2l-2-2m2 2l2 2"></path>
            </svg>
          {:else if volume < 30}
            <svg class="w-5 h-5" fill="none" stroke="currentColor" viewBox="0 0 24 24">
              <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M15.536 8.464a5 5 0 010 7.072m2.828-9.9a9 9 0 010 12.728M5.586 15H4a1 1 0 01-1-1v-4a1 1 0 011-1h1.586l4.707-4.707C10.923 3.663 12 4.109 12 5v14c0 .891-1.077 1.337-1.707.707L5.586 15z"></path>
            </svg>
          {:else}
            <svg class="w-5 h-5" fill="none" stroke="currentColor" viewBox="0 0 24 24">
              <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M15.536 8.464a5 5 0 010 7.072m2.828-9.9a9 9 0 010 12.728M5.586 15H4a1 1 0 01-1-1v-4a1 1 0 011-1h1.586l4.707-4.707C10.923 3.663 12 4.109 12 5v14c0 .891-1.077 1.337-1.707.707L5.586 15z"></path>
            </svg>
          {/if}
        </button>

        {#if showVolumeControl}
          <div class="flex items-center space-x-2">
            <input
              bind:this={volumeSlider}
              type="range"
              min="0"
              max="100"
              value={volume}
              oninput={handleVolumeChange}
              disabled={!canControl}
              class="w-20 h-1 bg-gray-200 rounded-lg appearance-none cursor-pointer slider"
              class:disabled={!canControl}
            />
            <span class="text-xs text-gray-500 w-8">{volume}%</span>
          </div>
        {/if}
        
        <!-- Permission indicator -->
        {#if !canControl}
          <div class="flex items-center space-x-1 text-xs text-gray-500">
            <svg class="w-4 h-4" fill="none" stroke="currentColor" viewBox="0 0 24 24">
              <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M12 15v2m0 0v2m0-2h2m-2 0H10m2-5V9m0 0V7m0 2H10m2 0h2"></path>
            </svg>
            <span>Listen only</span>
          </div>
        {/if}
      </div>
    </div>
  </div>
</div>
{/if}

<style>
  .slider {
    -webkit-appearance: none;
    appearance: none;
  }
  
  .slider::-webkit-slider-thumb {
    -webkit-appearance: none;
    appearance: none;
    height: 16px;
    width: 16px;
    border-radius: 50%;
    background: #ffa500;
    cursor: pointer;
    border: 2px solid white;
    box-shadow: 0 2px 4px rgba(0,0,0,0.2);
  }
  
  .slider::-moz-range-thumb {
    height: 16px;
    width: 16px;
    border-radius: 50%;
    background: #ffa500;
    cursor: pointer;
    border: 2px solid white;
    box-shadow: 0 2px 4px rgba(0,0,0,0.2);
  }
  
  .slider:disabled {
    opacity: 0.5;
    cursor: not-allowed;
  }
  
  .slider:disabled::-webkit-slider-thumb {
    cursor: not-allowed;
  }
  
  .slider:disabled::-moz-range-thumb {
    cursor: not-allowed;
  }
</style>