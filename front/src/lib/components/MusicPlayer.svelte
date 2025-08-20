<script lang="ts">
  import { onMount, onDestroy } from 'svelte';
  import { musicPlayerStore } from '$lib/stores/musicPlayer';
  import { authStore } from '$lib/stores/auth';
  import { socketService } from '$lib/services/socket';
  import { devicesService } from '$lib/services/devices';
  
  let audioElement: HTMLAudioElement;
  let progressSlider: HTMLInputElement;
  let volumeSlider: HTMLInputElement;
  let isDragging = false;
  let showVolumeControl = false;
  
  // Subscribe to stores
  $: playerState = $musicPlayerStore;
  $: user = $authStore;
  
  let currentAudioSrc = '';
  let loadTimeout: NodeJS.Timeout | null = null;
  
  // Update audio source when track changes
  $: if (audioElement && playerState.currentTrack?.previewUrl && currentAudioSrc !== playerState.currentTrack.previewUrl) {
    console.log('MusicPlayer: Updating audio source:', {
      newSrc: playerState.currentTrack.previewUrl,
      currentSrc: currentAudioSrc,
      track: playerState.currentTrack.title
    });
    
    // Clear any existing timeout
    if (loadTimeout) {
      clearTimeout(loadTimeout);
      loadTimeout = null;
    }
    
    currentAudioSrc = playerState.currentTrack.previewUrl;
    audioElement.src = currentAudioSrc;
    
    // Set a timeout to clear loading state if audio doesn't load
    loadTimeout = setTimeout(() => {
      if (playerState.isLoading) {
        console.warn('Audio load timeout, clearing loading state');
        musicPlayerStore.setLoading(false);
      }
      loadTimeout = null;
    }, 5000); // 5 second timeout
    
    // Clear timeout when audio loads successfully
    const handleLoadSuccess = () => {
      console.log('Audio loaded successfully');
      if (loadTimeout) {
        clearTimeout(loadTimeout);
        loadTimeout = null;
      }
    };
    
    audioElement.addEventListener('canplay', handleLoadSuccess, { once: true });
    audioElement.addEventListener('loadeddata', handleLoadSuccess, { once: true });
  }

  // Handle the case where currentTrack is set but has no previewUrl
  $: if (playerState.currentTrack && !playerState.currentTrack.previewUrl) {
    console.warn('Current track has no preview URL:', playerState.currentTrack);
    musicPlayerStore.setLoading(false);
  }
  
  function formatTime(seconds: number): string {
    const mins = Math.floor(seconds / 60);
    const secs = Math.floor(seconds % 60);
    return `${mins}:${secs.toString().padStart(2, '0')}`;
  }
  
  function handleLoadedMetadata() {
    console.log('Audio: loadedmetadata event');
    if (audioElement && playerState.currentTrack) {
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
    console.log('Audio: ended event');
    musicPlayerStore.nextTrack();
  }
  
  function handleCanPlay() {
    console.log('Audio: canplay event');
    musicPlayerStore.setLoading(false);
  }
  
  function handleLoadStart() {
    console.log('Audio: loadstart event');
    musicPlayerStore.setLoading(true);
  }
  
  function handleError(event: Event) {
    console.error('Audio error:', event);
    const audioError = audioElement?.error;
    if (audioError) {
      console.error('Audio error details:', {
        code: audioError.code,
        message: audioError.message,
        MEDIA_ERR_ABORTED: audioError.MEDIA_ERR_ABORTED,
        MEDIA_ERR_NETWORK: audioError.MEDIA_ERR_NETWORK,
        MEDIA_ERR_DECODE: audioError.MEDIA_ERR_DECODE,
        MEDIA_ERR_SRC_NOT_SUPPORTED: audioError.MEDIA_ERR_SRC_NOT_SUPPORTED
      });
    }
    musicPlayerStore.setLoading(false);
    musicPlayerStore.pause();
  }

  async function handlePlayPause() {
    if (!playerState.canControl) return;
    
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
            await audioElement.play();
            musicPlayerStore.play();
          }
        }
      }
    } catch (error) {
      console.error('Playback error:', error);
      musicPlayerStore.setLoading(false);
      musicPlayerStore.pause();
    }
  }

  async function handleNext() {
    if (!playerState.canControl) return;
    
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
    if (!playerState.canControl) return;
    
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
    if (!playerState.canControl) return;
    
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
    if (!playerState.canControl || !audioElement) return;
    
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
    if (!playerState.canControl) return;
    
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
  
  // Reactive updates
  $: if (audioElement) {
    audioElement.volume = (playerState.isMuted ? 0 : playerState.volume) / 100;
  }
  
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
{#if playerState.currentTrack}
<div class="fixed bottom-0 left-0 right-0 bg-white border-t border-gray-200 shadow-lg z-50">
  <div class="container mx-auto px-4 py-3">
    <!-- Progress Bar -->
    <div class="w-full mb-3">
      <input
        bind:this={progressSlider}
        type="range"
        min="0"
        max={playerState.duration || 100}
        value={playerState.currentTime}
        oninput={handleSeek}
        onmousedown={handleProgressMouseDown}
        onmouseup={handleProgressMouseUp}
        disabled={!playerState.canControl}
        class="w-full h-1 bg-gray-200 rounded-lg appearance-none cursor-pointer slider"
        class:disabled={!playerState.canControl}
      />
      <div class="flex justify-between text-xs text-gray-500 mt-1">
        <span>{formatTime(playerState.currentTime)}</span>
        <span>{formatTime(playerState.duration)}</span>
      </div>
    </div>

    <!-- Main Player Controls -->
    <div class="flex items-center justify-between">
      <!-- Track Info -->
      <div class="flex items-center space-x-3 flex-1 min-w-0">
        {#if playerState.currentTrack.albumCoverUrl}
          <img 
            src={playerState.currentTrack.albumCoverUrl} 
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
            {playerState.currentTrack.title}
          </h4>
          <p class="text-xs text-gray-500 truncate">
            {playerState.currentTrack.artist}
          </p>
        </div>
      </div>

      <!-- Playback Controls -->
      <div class="flex items-center space-x-3 mx-6">
        <button
          onclick={handlePrevious}
          disabled={!playerState.canControl || playerState.currentTrackIndex <= 0}
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
          disabled={!playerState.canControl || playerState.isLoading}
          class="p-3 bg-secondary text-white rounded-full hover:bg-secondary/90 disabled:opacity-50 disabled:cursor-not-allowed transition-colors"
          title={playerState.isPlaying ? 'Pause' : 'Play'}
        >
          {#if playerState.isLoading}
            <svg class="w-5 h-5 animate-spin" fill="none" viewBox="0 0 24 24">
              <circle class="opacity-25" cx="12" cy="12" r="10" stroke="currentColor" stroke-width="4"></circle>
              <path class="opacity-75" fill="currentColor" d="m4 12a8 8 0 018-8V0C5.373 0 0 5.373 0 12h4zm2 5.291A7.962 7.962 0 014 12H0c0 3.042 1.135 5.824 3 7.938l3-2.647z"></path>
            </svg>
          {:else if playerState.isPlaying}
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
          disabled={!playerState.canControl || playerState.currentTrackIndex >= playerState.playlist.length - 1}
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
          {#if playerState.isMuted || playerState.volume === 0}
            <svg class="w-5 h-5" fill="none" stroke="currentColor" viewBox="0 0 24 24">
              <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M5.586 15H4a1 1 0 01-1-1v-4a1 1 0 011-1h1.586l4.707-4.707C10.923 3.663 12 4.109 12 5v14c0 .891-1.077 1.337-1.707.707L5.586 15z M17 14l2-2m0 0l2-2m-2 2l-2-2m2 2l2 2"></path>
            </svg>
          {:else if playerState.volume < 30}
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
              value={playerState.volume}
              oninput={handleVolumeChange}
              disabled={!playerState.canControl}
              class="w-20 h-1 bg-gray-200 rounded-lg appearance-none cursor-pointer slider"
              class:disabled={!playerState.canControl}
            />
            <span class="text-xs text-gray-500 w-8">{playerState.volume}%</span>
          </div>
        {/if}
        
        <!-- Permission indicator -->
        {#if !playerState.canControl}
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