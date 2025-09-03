<script lang="ts">
  import { onMount, onDestroy } from 'svelte';
  import { musicPlayerStore } from '$lib/stores/musicPlayer';
  import { socketService } from '$lib/services/socket';
  import { eventSocketService } from '$lib/services/event-socket';
  import { devicesService } from '$lib/services/devices';
  import { musicPlayerService } from '$lib/services/musicPlayer';
  import { removeTrackFromEvent } from '$lib/services/events';
  import { page } from '$app/stores';
  import { globalAudioManager } from '$lib/stores/globalAudio';
  
  let audioElement = $state<HTMLAudioElement>();
  let isDragging = $state(false);
  let showVolumeControl = $state(false);
  let skipMessage = $state<string | null>(null);
  let skipMessageTimeout: NodeJS.Timeout | null = null;
  
  // Generate unique audio ID for this instance
  const audioId = `music-player-${Math.random().toString(36).substr(2, 9)}`;
  
  // Subscribe to stores using Svelte 5 runes - break down into specific reactive values to avoid cycles
  let playerState = $derived($musicPlayerStore);
  
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
  let isInEvent = $derived(playerState.isInEvent);
  
  // Check if we're on an event or playlist page where music player should always be visible
  let currentPage = $derived($page);
  let isOnEventPage = $derived(currentPage?.route?.id?.includes('/events/[id]') || false);
  let isOnPlaylistPage = $derived(currentPage?.route?.id?.includes('/playlists/[id]') || false);
  let shouldAlwaysShow = $derived(isOnEventPage || isOnPlaylistPage);
  
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
            if (audioElement && globalAudioManager.isCurrentAudio(audioElement)) {
              audioElement?.play().catch(error => {
                console.warn('Auto-play failed after track change:', error);
                musicPlayerStore.pause();
              });
            } else if (audioElement) {
              // Register this audio and play it
              globalAudioManager.registerAudio(audioElement, audioId);
              audioElement?.play().catch(error => {
                console.warn('Auto-play failed after track change:', error);
                musicPlayerStore.pause();
              });
            }
          }, 100);
        }
        
        // Set a timeout to clear loading state if audio doesn't load
        loadTimeout = setTimeout(() => {
          // Use a more specific check to avoid reading playerState during effect
          musicPlayerStore.setLoading(false);
          loadTimeout = null;
          
          // Mark the track as failed due to timeout
          if (currentTrack) {
            musicPlayerStore.markTrackAsFailed(currentTrack.id);
          }
          
          // If we're playing and this track timed out, auto-skip to next track
          if (isPlaying && currentTrack) {
            showSkipMessage('Skipping unplayable track...');
            setTimeout(() => {
              musicPlayerStore.nextTrack();
            }, 500);
          }
        }, 3000); // Reduced timeout to 3 seconds for faster skipping
        
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

  // Sync audio element play/pause state with store and global audio manager
  $effect(() => {
    if (audioElement && audioElement.src) {
      if (isPlaying && audioElement.paused) {
        // Register this audio element as the active one before playing
        globalAudioManager.registerAudio(audioElement, audioId);
        audioElement.play().catch(error => {
          console.warn('Failed to play audio:', error);
          musicPlayerStore.pause();
        });
      } else if (!isPlaying && !audioElement.paused) {
        audioElement.pause();
        // Unregister when paused
        globalAudioManager.unregisterAudio(audioElement, audioId);
      }
    }
  });
  
  function formatTime(seconds: number): string {
    const mins = Math.floor(seconds / 60);
    const secs = Math.floor(seconds % 60);
    return `${mins}:${secs.toString().padStart(2, '0')}`;
  }

  function showSkipMessage(message: string) {
    skipMessage = message;
    
    // Clear any existing timeout
    if (skipMessageTimeout) {
      clearTimeout(skipMessageTimeout);
    }
    
    // Hide message after 3 seconds
    skipMessageTimeout = setTimeout(() => {
      skipMessage = null;
      skipMessageTimeout = null;
    }, 3000);
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
    // If we're in an event, handle track ending differently
    if (isInEvent && currentTrack && playerState.eventId) {
      const finishedTrackId = currentTrack.id;
      
      // Notify all participants that the track has ended
      // The backend will handle track progression for admin users
      eventSocketService.notifyTrackEnded(playerState.eventId, finishedTrackId);
      
      // Show message and let backend handle the progression
      if (canControl) {
        showSkipMessage('Track finished, selecting next track...');
        
        // For admins, request playlist sync to ensure we have the current order
        // before the backend selects the next track
        setTimeout(() => {
          eventSocketService.requestPlaylistSync(playerState.eventId!);
        }, 100);
      } else {
        showSkipMessage('Track finished, waiting for next track...');
      }
      
      // For events, return early - backend handles track progression
      return;
    } else {
      // For regular playlists, advance to the next track locally
      musicPlayerStore.nextTrack();
      
      // Auto-play the next track after a brief delay, with better error handling
      setTimeout(async () => {
        const newPlayerState = $musicPlayerStore;
        
        // Only auto-play if we were playing and we have a valid next track
        if (isPlaying && audioElement && newPlayerState.currentTrack) {
          try {
            // Check if the audio source is properly loaded before playing
            if (audioElement.error) {
              // Try to skip unplayable tracks, but with a limit to avoid infinite loops
              let skipAttempts = 0;
              const maxSkipAttempts = playlist.length; // Don't skip more than the total playlist length
              
              while (audioElement.error && skipAttempts < maxSkipAttempts) {
                musicPlayerStore.nextTrack();
                skipAttempts++;
                
                // Wait a bit for the new track to load
                await new Promise(resolve => setTimeout(resolve, 200));
                
                // If we've come full circle and still have errors, stop
                if (skipAttempts >= maxSkipAttempts) {
                  musicPlayerStore.pause();
                  return;
                }
              }
            }
            
            // Try to play the current track
            if (audioElement && !audioElement.error) {
              globalAudioManager.registerAudio(audioElement, audioId);
              await audioElement.play();
            }
            
          } catch (error) {
            // Try to skip to the next available track, but limit attempts
            let skipAttempts = 0;
            const maxSkipAttempts = Math.min(5, playlist.length); // Limit to 5 attempts or playlist length
            
            while (skipAttempts < maxSkipAttempts) {
              musicPlayerStore.nextTrack();
              skipAttempts++;
              
              // Wait a bit and try to play
              await new Promise(resolve => setTimeout(resolve, 300));
              
              try {
                if (audioElement && !audioElement.error) {
                  // Only play if this is still the current active audio
                  if (globalAudioManager.isCurrentAudio(audioElement)) {
                    await audioElement.play();
                    return; // Success, stop trying
                  } else {
                    // Register this audio as active and try to play
                    globalAudioManager.registerAudio(audioElement, audioId);
                    await audioElement.play();
                    return; // Success, stop trying
                  }
                }
              } catch (retryError) {
                // Continue to next attempt
              }
            }
            
            // If we've exhausted our skip attempts, stop playing
            musicPlayerStore.pause();
          }
        }
      }, 100);
    }
  }
  
  function handleCanPlay() {
    musicPlayerStore.setLoading(false);
    
    // For events, report that this track is playable for synchronization
    if (isInEvent && currentTrack && playerState.eventId) {
      eventSocketService.reportTrackAccessibility(
        playerState.eventId, 
        currentTrack.id, 
        true, 
        'track_loaded_successfully'
      );
    }
  }
  
  function handleLoadStart() {
    musicPlayerStore.setLoading(true);
  }
  
  function handleError(event: Event) {
    const audioError = audioElement?.error;
    if (audioError) {  
      // For events, report accessibility issues to maintain synchronization
      if (isInEvent && currentTrack && playerState.eventId) {
        const errorReason = audioError.code === 4 ? 'network_error' :
                           audioError.code === 2 ? 'loading_failed' :
                           audioError.code === 3 ? 'decode_error' : 'unknown_error';
        
        // Report that this user cannot play the track
        eventSocketService.reportTrackAccessibility(
          playerState.eventId, 
          currentTrack.id, 
          false, 
          errorReason
        );
        
        // Show message but don't remove track - let backend handle consensus
        showSkipMessage('Track unavailable on your device, checking with other users...');
        
        // Stop loading state
        musicPlayerStore.setLoading(false);
        
        // For events, don't automatically skip - wait for backend consensus
        return;
      }
      
      // For non-event playlists, handle locally as before
      if (currentTrack && 
          (audioError.code === 4 || // MEDIA_ELEMENT_ERROR: Media loading aborted
           audioError.code === 2 || // MEDIA_ELEMENT_ERROR: Network error
           audioError.code === 3)) { // MEDIA_ELEMENT_ERROR: Decode error
        musicPlayerStore.markTrackAsFailed(currentTrack.id);
      }
      
      // Show skip message
      showSkipMessage('Track unavailable, removing...');
      
      // Stop loading state
      musicPlayerStore.setLoading(false);
      
      // For playlists: let the store handle finding the next valid track
      // Use a timeout to avoid immediate recursive calls
      setTimeout(() => {
        // Check if all tracks are failed
        const currentPlayerState = $musicPlayerStore;
        const validTracks = playlist.filter(track => 
          track.track.previewUrl && !currentPlayerState.failedTrackIds.has(track.track.id)
        );
        
        if (validTracks.length === 0) {
          showSkipMessage('No playable tracks in playlist');
          musicPlayerStore.pause();
          return;
        }
        
        // Let the store's nextTrack handle finding the next valid track
        musicPlayerStore.nextTrack();
        
      }, 200);
    }
  }

    async function handlePlayPause() {
    if (!canControl) return;
    
    try {
      if (isInEvent && playerState.eventId) {
        // Use event socket for synchronized playback
        if (playerState.isPlaying) {
          eventSocketService.pauseTrack(playerState.eventId);
        } else {
          eventSocketService.playTrack(playerState.eventId, playerState.currentTrack?.id, playerState.currentTime);
        }
      } else if (playerState.deviceId) {
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
            globalAudioManager.unregisterAudio(audioElement, audioId);
            musicPlayerStore.pause();
          } else {
            // Check if audio has failed to load before trying to play
            if (audioElement.error) {
              showSkipMessage('Track unavailable, skipping...');
              setTimeout(() => {
                musicPlayerStore.nextTrack();
              }, 500);
              return;
            }
            
            // Register this audio as the active one and pause any others
            globalAudioManager.registerAudio(audioElement, audioId);
            await audioElement.play();
            musicPlayerStore.play();
          }
        } else if (!playerState.currentTrack?.previewUrl) {
          // Track has no preview URL available
        }
      }
    } catch (error) {
      const errorMessage = error instanceof Error ? error.message : String(error);
      showSkipMessage('Track unavailable, skipping...');
      musicPlayerStore.setLoading(false);
      
      // Auto-skip to next track on any playback error
      setTimeout(() => {
        musicPlayerStore.nextTrack();
      }, 500);
    }
  }

  async function handleNext() {
    if (!canControl) return;
    
    try {
      if (isInEvent && playerState.eventId) {
        // For events, find the next track and send it via socket
        const nextIndex = playerState.currentTrackIndex + 1;
        if (nextIndex < playlist.length) {
          const nextTrack = playlist[nextIndex];
          eventSocketService.changeTrack(playerState.eventId, nextTrack.track.id, nextIndex);
        }
      } else if (playerState.deviceId) {
        await devicesService.skipDevice(playerState.deviceId);
      }
      musicPlayerStore.nextTrack();
    } catch (error) {
      console.error('Next track error:', error);
    }
  }
  
  async function handlePrevious() {
    if (!canControl) return;
    
    // Prevent manual track skipping during events
    if (isInEvent) {
      return;
    }
    
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
      if (isInEvent && playerState.eventId) {
        eventSocketService.seekTrack(playerState.eventId, time);
      } else if (playerState.deviceId) {
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
  
  // Socket event handlers for real-time sync
  function setupSocketListeners() {
    if (!socketService.isConnected()) return;
    
    socketService.on('music-play', () => {
      musicPlayerStore.play();
      if (audioElement && !audioElement.paused) {
        globalAudioManager.registerAudio(audioElement, audioId);
        audioElement.play().catch(console.error);
      }
    });
    
    socketService.on('music-pause', () => {
      musicPlayerStore.pause();
      if (audioElement && !audioElement.paused) {
        audioElement.pause();
        globalAudioManager.unregisterAudio(audioElement, audioId);
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

  function setupEventSocketListeners() {
    if (!eventSocketService.isConnected()) return;
    
    // Event-specific music synchronization
    eventSocketService.on('music-play', (data) => {
      if (data.trackId && data.trackId !== playerState.currentTrack?.id) {
        // Different track, sync the track change first
        musicPlayerStore.syncWithEvent(data.trackId, true, data.startTime || 0);
      } else {
        musicPlayerStore.play();
      }
      
      if (audioElement) {
        if (data.startTime) {
          audioElement.currentTime = data.startTime;
        }
        globalAudioManager.registerAudio(audioElement, audioId);
        audioElement.play().catch(console.error);
      }
    });
    
    eventSocketService.on('music-pause', () => {
      musicPlayerStore.pause();
      if (audioElement && !audioElement.paused) {
        audioElement.pause();
        globalAudioManager.unregisterAudio(audioElement, audioId);
      }
    });
    
    eventSocketService.on('music-seek', (data) => {
      musicPlayerStore.seekTo(data.seekTime);
      if (audioElement) {
        audioElement.currentTime = data.seekTime;
      }
    });
    
    eventSocketService.on('music-volume', (data) => {
      musicPlayerStore.setVolume(data.volume);
      if (audioElement) {
        audioElement.volume = data.volume / 100;
      }
    });

    eventSocketService.on('playback-sync', (data) => {
      console.log('Received playback sync:', data);
      
      if (data.currentTrackId && data.currentTrack) {
        // Sync to the current track and position
        musicPlayerStore.syncWithEvent(data.currentTrackId, data.isPlaying, data.startTime);
        
        // Update audio element to sync position
        if (audioElement && data.isPlaying) {
          audioElement.currentTime = data.startTime;
          globalAudioManager.registerAudio(audioElement, audioId);
          audioElement.play().catch(error => {
            console.warn('Failed to sync audio playback:', error);
          });
        }
        
        console.log(`Synced to ongoing stream - track: ${data.currentTrackId}, position: ${data.startTime}s`);
      }
    });

    // Handle auto-skipped tracks due to accessibility issues
    eventSocketService.on('music-track-changed', (data) => {
      if (data.autoSkipped) {
        showSkipMessage(`Track auto-skipped: ${data.skipReason === 'majority_cannot_play' ? 'Most users cannot play this track' : 'Track issue detected'}`);
      }
      
      // Use backend signal for playing state, fallback to current state
      const shouldContinuePlaying = data.continuePlaying !== undefined ? 
        data.continuePlaying : 
        (playerState.isPlaying || (audioElement && !audioElement.paused));
      
      musicPlayerStore.syncWithEvent(data.trackId, shouldContinuePlaying, 0);
      
      // If we should continue playing, make sure to start the new track
      if (shouldContinuePlaying && audioElement) {
        setTimeout(() => {
          if (audioElement && audioElement.src && !audioElement.error) {
            globalAudioManager.registerAudio(audioElement, audioId);
            audioElement.play().catch(error => {
              console.warn('Failed to auto-play next track:', error);
            });
          }
        }, 100);
      }
    });
  }
  
  // Reactive updates using Svelte 5 effect
  $effect(() => {
    if (audioElement) {
      audioElement.volume = (isMuted ? 0 : volume) / 100;
    }
  });
  
  onMount(() => {
    console.log('MusicPlayer mounted with audio ID:', audioId);
    setupSocketListeners();
    
    // Set up event socket listeners if in event mode
    if (isInEvent) {
      setupEventSocketListeners();
    }
    
    // Set initial audio properties
    if (audioElement) {
      audioElement.volume = playerState.volume / 100;
      
      // If the music is supposed to be playing, register this audio
      if (isPlaying && currentTrack?.previewUrl) {
        globalAudioManager.registerAudio(audioElement, audioId);
      }
    }

    // Add page visibility change listener to pause audio when tab becomes hidden
    const handleVisibilityChange = () => {
      if (document.hidden && audioElement && !audioElement.paused) {
        audioElement.pause();
        globalAudioManager.unregisterAudio(audioElement, audioId);
        musicPlayerStore.pause();
      }
    };

    document.addEventListener('visibilitychange', handleVisibilityChange);

    // Cleanup function
    return () => {
      document.removeEventListener('visibilitychange', handleVisibilityChange);
    };
  });
  
  onDestroy(() => {
    // Clear any pending timeout
    if (loadTimeout) {
      clearTimeout(loadTimeout);
      loadTimeout = null;
    }
    
    // Clear skip message timeout
    if (skipMessageTimeout) {
      clearTimeout(skipMessageTimeout);
      skipMessageTimeout = null;
    }
    
    // Unregister audio element from global manager
    if (audioElement) {
      globalAudioManager.unregisterAudio(audioElement, audioId);
    }
    
    if (socketService.isConnected()) {
      socketService.off('music-play');
      socketService.off('music-pause');
      socketService.off('music-seek');
      socketService.off('music-volume');
      socketService.off('track-changed');
    }

    if (eventSocketService.isConnected()) {
      eventSocketService.off('music-play');
      eventSocketService.off('music-pause');
      eventSocketService.off('music-seek');
      eventSocketService.off('music-track-changed');
      eventSocketService.off('music-volume');
      eventSocketService.off('playback-sync');
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

<!-- Skip Message Notification -->
{#if skipMessage}
<div class="fixed bottom-20 left-1/2 transform -translate-x-1/2 z-50">
  <div class="bg-yellow-500 text-white px-4 py-2 rounded-lg shadow-lg flex items-center space-x-2">
    <svg class="w-4 h-4 animate-spin" fill="none" viewBox="0 0 24 24">
      <circle class="opacity-25" cx="12" cy="12" r="10" stroke="currentColor" stroke-width="4"></circle>
      <path class="opacity-75" fill="currentColor" d="m4 12a8 8 0 018-8V0C5.373 0 0 5.373 0 12h4zm2 5.291A7.962 7.962 0 014 12H0c0 3.042 1.135 5.824 3 7.938l3-2.647z"></path>
    </svg>
    <span class="text-sm font-medium">{skipMessage}</span>
  </div>
</div>
{/if}

<!-- Music Player UI -->
{#if shouldAlwaysShow || currentTrack || playlist.length > 0}
<div class="fixed bottom-0 left-0 right-0 bg-white border-t-2 border-secondary shadow-2xl z-50" style="min-height: 80px;">
  <div class="container mx-auto px-4 py-3">
    <!-- Progress Bar -->
    <div class="w-full mb-3">
      <input
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
            {currentTrack?.title || (isInEvent ? 'Waiting for tracks...' : isOnPlaylistPage ? 'Playlist player ready' : 'Ready to play')}
          </h4>
          <p class="text-xs text-gray-500 truncate">
            {#if currentTrack?.artist}
              {currentTrack.artist}
            {:else if isInEvent}
              {#if playlist.length === 0}
                Waiting for tracks from admins...
              {:else}
                {playlist.length} tracks in queue
              {/if}
            {:else if isOnPlaylistPage}
              {#if playlist.length === 0}
                Loading playlist...
              {:else}
                {playlist.length} tracks available
              {/if}
            {:else}
              {playlist.length} tracks available
            {/if}
          </p>
        </div>
      </div>

      <!-- Playback Controls -->
      <div class="flex items-center space-x-3 mx-6">
        <button
          onclick={handlePrevious}
          disabled={!canControl || playlist.length === 0 || isInEvent}
          class="p-2 rounded-full hover:bg-gray-100 disabled:opacity-50 disabled:cursor-not-allowed transition-colors"
          title={isInEvent ? "Track skipping disabled during events" : "Previous track"}
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
          disabled={!canControl || playlist.length === 0 || isInEvent}
          class="p-2 rounded-full hover:bg-gray-100 disabled:opacity-50 disabled:cursor-not-allowed transition-colors"
          title={isInEvent ? "Track skipping disabled during events" : "Next track"}
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