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
  import YouTubePlayer from '$lib/components/YouTubePlayer.svelte';
  
  let youtubePlayer = $state<any>(null);
  let isDragging = $state(false);
  let showVolumeControl = $state(false);
  let skipMessage = $state<string | null>(null);
  let skipMessageTimeout: NodeJS.Timeout | null = null;
  let isSyncing = $state(false);
  
  const audioId = `music-player-${Math.random().toString(36).substr(2, 9)}`;
  
  let playerState = $derived($musicPlayerStore);
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
  
  let currentPage = $derived($page);
  let isOnEventPage = $derived(currentPage?.route?.id?.includes('/events/[id]') || false);
  let isOnPlaylistPage = $derived(currentPage?.route?.id?.includes('/playlists/[id]') || false);
  let shouldAlwaysShow = $derived(isOnEventPage || isOnPlaylistPage);
  
  let currentVideoUrl = '';
  let loadTimeout: NodeJS.Timeout | null = null;
  
  function isYouTubeUrl(url: string): boolean {
    return url.includes('youtube.com') || url.includes('youtu.be');
  }
  
  $effect(() => {
    if (currentTrack?.previewUrl && currentVideoUrl !== currentTrack.previewUrl) {
      if (loadTimeout) {
        clearTimeout(loadTimeout);
        loadTimeout = null;
      }
      
      currentVideoUrl = currentTrack.previewUrl;
      
      if (isYouTubeUrl(currentVideoUrl)) {
        musicPlayerStore.setLoading(true);
        
        setTimeout(() => {
          musicPlayerStore.setLoading(false);
        }, 500);
        
        loadTimeout = setTimeout(() => {
          if (musicPlayerStore && currentTrack && currentVideoUrl === currentTrack.previewUrl && duration === 0) {
            musicPlayerStore.markTrackAsFailed(currentTrack.id);
            
            if (isPlaying) {
              showSkipMessage('Track failed to load, skipping...');
              setTimeout(() => {
                musicPlayerStore.nextTrack();
              }, 500);
            }
          }
        }, 30000);
      } else {
        musicPlayerStore.setLoading(false);
        if (currentTrack) {
          musicPlayerStore.markTrackAsFailed(currentTrack.id);
        }
      }
    }
  });

  $effect(() => {
    if (currentTrack && (!currentTrack.previewUrl || !isYouTubeUrl(currentTrack.previewUrl))) {
      if (loadTimeout) {
        clearTimeout(loadTimeout);
        loadTimeout = null;
      }
      musicPlayerStore.setLoading(false);
      
      if (currentTrack && !currentTrack.previewUrl) {
        musicPlayerStore.markTrackAsFailed(currentTrack.id);
      } else if (currentTrack?.previewUrl && !isYouTubeUrl(currentTrack.previewUrl)) {
        musicPlayerStore.markTrackAsFailed(currentTrack.id);
      }
    }
  });

  $effect(() => {
    const shouldBeActive = shouldAlwaysShow || currentTrack || playlist.length > 0;
    
    if (youtubePlayer && currentTrack?.previewUrl && isYouTubeUrl(currentTrack.previewUrl) && shouldBeActive) {
      if (isPlaying) {
        globalAudioManager.registerAudio(youtubePlayer, audioId);
      } else {
        globalAudioManager.unregisterAudio(youtubePlayer, audioId);
      }
    } else if (!shouldBeActive && youtubePlayer) {
      globalAudioManager.unregisterAudio(youtubePlayer, audioId);
    }
  });

  $effect(() => {
    if (isLoading && currentTrack?.previewUrl && isYouTubeUrl(currentTrack.previewUrl)) {
      const fallbackTimeout = setTimeout(() => {
        if (isLoading) {
          musicPlayerStore.setLoading(false);
        }
      }, 5000);
      
      return () => clearTimeout(fallbackTimeout);
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
  
  function handleYouTubeReady() {
    if (loadTimeout) {
      clearTimeout(loadTimeout);
      loadTimeout = null;
    }
    
    musicPlayerStore.setLoading(false);
    
    if (currentTrack) {
      musicPlayerStore.setCurrentTime(0);
    }
  }
  
  function handleYouTubeTimeUpdate(time: number) {
    if (isInEvent && isSyncing) {
      return;
    }
    
    if (duration > 0 && time > duration + 5) {
      if (youtubePlayer && youtubePlayer.getDuration) {
        const actualDuration = youtubePlayer.getDuration();
        if (actualDuration > duration) {
          musicPlayerStore.setDuration(actualDuration);
        }
      }
    }
    
    if (!isDragging && !isSyncing) {
      musicPlayerStore.setCurrentTime(time);
    }
  }
  
  function handleYouTubeDurationChange(newDuration: number) {
    musicPlayerStore.setDuration(newDuration);
    
    if (newDuration > 0) {
      if (loadTimeout) {
        clearTimeout(loadTimeout);
        loadTimeout = null;
      }
      
      musicPlayerStore.setLoading(false);
    }
  }
  
  function handleEnded() {
    if (isInEvent && currentTrack && playerState.eventId) {
      const finishedTrackId = currentTrack.id;
      
      if (canControl) {
        eventSocketService.notifyTrackEnded(playerState.eventId, finishedTrackId);
        showSkipMessage('Track finished, selecting next track...');
        
        setTimeout(() => {
          eventSocketService.requestPlaylistSync(playerState.eventId!);
        }, 100);
      } else {
        showSkipMessage('Track finished, waiting for admin to select next track...');
      }
      
      return;
    } else {
      musicPlayerStore.nextTrack();
      
      setTimeout(async () => {
        const newPlayerState = $musicPlayerStore;
        
        if (isPlaying && newPlayerState.currentTrack) {
          // Reactive effects will handle audio registration
        }
      }, 100);
    }
  }
  
  function handleYouTubeCanPlay() {
    if (loadTimeout) {
      clearTimeout(loadTimeout);
      loadTimeout = null;
    }
    
    musicPlayerStore.setLoading(false);
    
    if (isInEvent && currentTrack && playerState.eventId) {
      eventSocketService.reportTrackAccessibility(
        playerState.eventId, 
        currentTrack.id, 
        true, 
        'track_loaded_successfully'
      );
    }
  }
  
  function handleYouTubeLoadStart() {
    musicPlayerStore.setLoading(true);
  }
  
  function handleYouTubeError(error: any) {
    if (loadTimeout) {
      clearTimeout(loadTimeout);
      loadTimeout = null;
    }
    
    musicPlayerStore.setLoading(false);
    
    if (isInEvent && currentTrack && playerState.eventId) {
      const errorReason = 'youtube_playback_error';
      
      eventSocketService.reportTrackAccessibility(
        playerState.eventId, 
        currentTrack.id, 
        false, 
        errorReason
      );
      
      showSkipMessage('Track unavailable on your device, checking with other users...');
      return;
    }
    
    const errorCode = error?.code || error?.data;
    const isUnrecoverableError = errorCode === 100 || errorCode === 101 || errorCode === 150;
    
    if (currentTrack && isUnrecoverableError) {
      musicPlayerStore.markTrackAsFailed(currentTrack.id);
      showSkipMessage('Track unavailable, skipping...');
      
      setTimeout(() => {
        musicPlayerStore.nextTrack();
      }, 1000);
    } else {
      showSkipMessage('Playback issue detected, try seeking or skipping manually');
    }
  }

  async function handlePlayPause() {
    if (!canControl) {
      return;
    }
    
    try {
      if (isInEvent && playerState.eventId) {
        let currentTimestamp = playerState.currentTime;
        if (youtubePlayer && youtubePlayer.getCurrentTime) {
          currentTimestamp = youtubePlayer.getCurrentTime();
        }
        
        if (playerState.isPlaying) {
          eventSocketService.pauseTrack(playerState.eventId, currentTimestamp);
        } else {
          eventSocketService.playTrack(playerState.eventId, playerState.currentTrack?.id);
        }
      } else if (playerState.deviceId) {
        if (playerState.isPlaying) {
          await devicesService.pauseDevice(playerState.deviceId);
        } else {
          await devicesService.playDevice(playerState.deviceId, {
            trackId: playerState.currentTrack?.id
          });
        }
      } else {
        if (playerState.currentTrack?.previewUrl && isYouTubeUrl(playerState.currentTrack.previewUrl)) {
          if (playerState.isPlaying) {
            musicPlayerStore.pause();
          } else {
            musicPlayerStore.play();
          }
        } else if (!playerState.currentTrack?.previewUrl || !isYouTubeUrl(playerState.currentTrack.previewUrl)) {
          showSkipMessage('Track not available for playback');
          setTimeout(() => {
            musicPlayerStore.nextTrack();
          }, 1000);
        }
      }
    } catch (error) {
      showSkipMessage('Track unavailable, skipping...');
      musicPlayerStore.setLoading(false);
      
      setTimeout(() => {
        musicPlayerStore.nextTrack();
      }, 500);
    }
  }

  async function handleNext() {
    if (!canControl) return;
    
    try {
      if (isInEvent && playerState.eventId) {
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
      // Error handling without logging
    }
  }
  
  async function handlePrevious() {
    if (!canControl) return;
    
    if (isInEvent) {
      return;
    }
    
    try {
      if (playerState.deviceId) {
        await devicesService.previousDevice(playerState.deviceId);
      }
      musicPlayerStore.previousTrack();
    } catch (error) {
      // Error handling without logging
    }
  }
  
  async function handleVolumeChange(event: Event) {
    const target = event.target as HTMLInputElement;
    const volume = parseInt(target.value);
    
    try {
      if (playerState.deviceId) {
        await devicesService.setDeviceVolume(playerState.deviceId, volume);
      }
      musicPlayerStore.setVolume(volume);
    } catch (error) {
      // Error handling without logging
    }
  }
  
  function handleSeek(event: Event) {
    if (!canControl) return;
    
    const target = event.target as HTMLInputElement;
    const time = parseFloat(target.value);
    
    try {
      if (isInEvent && playerState.eventId) {
        eventSocketService.seekTrack(playerState.eventId, time);
        if (youtubePlayer) {
          youtubePlayer.seekTo(time, true);
        }
        musicPlayerStore.seekTo(time);
      } else if (playerState.deviceId) {
        devicesService.seekDevice(playerState.deviceId, time);
        musicPlayerStore.seekTo(time);
      } else if (youtubePlayer) {
        youtubePlayer.seekTo(time);
        musicPlayerStore.seekTo(time);
      }
    } catch (error) {
      // Error handling without logging
    }
  }
  
  function handleProgressMouseDown() {
    isDragging = true;
  }
  
  function handleProgressMouseUp() {
    isDragging = false;
  }
  
  function setupSocketListeners() {
    // Regular socket service handlers are not needed in event context
  }

  function cleanupEventSocketListeners() {
    if (eventSocketService.isConnected()) {
      eventSocketService.off('music-play');
      eventSocketService.off('music-pause');
      eventSocketService.off('music-seek');
      eventSocketService.off('music-track-changed');
      eventSocketService.off('music-volume');
      eventSocketService.off('playback-sync');
      eventSocketService.off('time-sync');
    }
  }

  function setupEventSocketListeners() {
    cleanupEventSocketListeners();
    
    eventSocketService.on('music-play', (data) => {
      isSyncing = true;
      
      if (data.trackId && data.trackId !== playerState.currentTrack?.id) {
        if (youtubePlayer && youtubePlayer.resetPlayerState) {
          youtubePlayer.resetPlayerState();
        }
        
        musicPlayerStore.syncWithEvent(data.trackId, true, data.startTime || 0);
        
        setTimeout(() => {
          if (youtubePlayer && youtubePlayer.seekTo) {
            youtubePlayer.seekTo(data.startTime || 0, true);
          }
        }, 300);
      } else {
        musicPlayerStore.play();
        
        if (data.startTime !== undefined) {
          musicPlayerStore.seekTo(data.startTime);
          
          if (youtubePlayer && youtubePlayer.seekTo) {
            youtubePlayer.seekTo(data.startTime, true);
          }
        }
      }
      
      setTimeout(() => {
        isSyncing = false;
      }, 2000);
    });
    
    eventSocketService.on('music-pause', (data) => {
      isSyncing = true;
      
      if (data.currentTime !== undefined) {
        musicPlayerStore.seekTo(data.currentTime);
        if (youtubePlayer && youtubePlayer.seekTo) {
          youtubePlayer.seekTo(data.currentTime, true);
        }
      }
      
      musicPlayerStore.pause();
      
      setTimeout(() => {
        isSyncing = false;
      }, 1500);
    });
    
    eventSocketService.on('music-seek', (data) => {
      isSyncing = true;
      
      musicPlayerStore.seekTo(data.seekTime);
      
      if (youtubePlayer && youtubePlayer.seekTo) {
        youtubePlayer.seekTo(data.seekTime, true);
      }
      
      setTimeout(() => {
        isSyncing = false;
      }, 2000);
    });
    
    eventSocketService.on('music-volume', (data) => {
      musicPlayerStore.setVolume(data.volume);
    });

    eventSocketService.on('playback-sync', (data) => {
      // Only sync if there's actually a track to sync with
      if (data.currentTrackId && data.currentTrack) {
        if (youtubePlayer && data.syncType === 'initial-join') {
          if (youtubePlayer.resetPlayerState) {
            youtubePlayer.resetPlayerState();
          }
          
          setTimeout(() => {
            performInitialSync();
          }, 300);
        } else {
          performInitialSync();
        }

        function performInitialSync() {
          isSyncing = true;
          
          musicPlayerStore.syncWithEvent(data.currentTrackId, data.isPlaying, data.startTime);
          
          const waitForPlayerReady = (attempts = 0) => {
            const maxAttempts = 10;
            
            if (!youtubePlayer) {
              if (attempts < maxAttempts) {
                setTimeout(() => waitForPlayerReady(attempts + 1), 200);
              }
              return;
            }
            
            const playerState = youtubePlayer.getPlayerState ? youtubePlayer.getPlayerState() : -1;
            const duration = youtubePlayer.getDuration ? youtubePlayer.getDuration() : 0;
            
            if (playerState === -1 || duration <= 0) {
              if (attempts < maxAttempts) {
                setTimeout(() => waitForPlayerReady(attempts + 1), 300);
              } else {
                performSeekOperation();
              }
              return;
            }
            
            performSeekOperation();
          };
          
          const performSeekOperation = () => {
            if (youtubePlayer && youtubePlayer.seekTo) {
              let seekAttempts = 0;
              const maxSeekAttempts = 3;
              
              const attemptSeek = () => {
                seekAttempts++;
                youtubePlayer.seekTo(data.startTime, true);
                
                setTimeout(() => {
                  const actualTime = youtubePlayer.getCurrentTime ? youtubePlayer.getCurrentTime() : 0;
                  const timeDiff = Math.abs(actualTime - data.startTime);
                  
                  if (timeDiff > 2 && seekAttempts < maxSeekAttempts) {
                    setTimeout(attemptSeek, 500);
                  }
                }, 300);
              };
              
              attemptSeek();
            }
            
            if (!data.isPlaying && youtubePlayer.pauseVideo) {
              youtubePlayer.pauseVideo();
            }
          };
          
          waitForPlayerReady();
        }
        
        setTimeout(() => {
          isSyncing = false;
        }, 3000);
      } else {
        // If there's no current track but sync data was received, ensure player is paused
        musicPlayerStore.pause();
        musicPlayerStore.setCurrentTime(0);
      }
    });

    eventSocketService.on('time-sync', (data) => {
      if (isInEvent && data.trackId === playerState.currentTrack?.id) {
        musicPlayerStore.setCurrentTime(data.currentTime);
      }
    });

    eventSocketService.on('music-track-changed', (data) => {
      if (data.autoSkipped) {
        showSkipMessage(`Track auto-skipped: ${data.skipReason === 'majority_cannot_play' ? 'Most users cannot play this track' : 'Track issue detected'}`);
      }
      
      isSyncing = false;
      
      if (youtubePlayer && youtubePlayer.resetPlayerState) {
        youtubePlayer.resetPlayerState();
      }
      
      const shouldContinuePlaying = data.continuePlaying !== undefined ? 
        data.continuePlaying : 
        playerState.isPlaying;
      
      musicPlayerStore.syncWithEvent(data.trackId, shouldContinuePlaying, 0);
    });
  }
  
  // Volume is handled by the YouTube player through reactive props
  // No need for a separate effect
  
  let eventListenersSetup = $state(false);

  $effect(() => {
    if (isInEvent && !eventListenersSetup) {
      if (eventSocketService.isConnected()) {
        setupEventSocketListeners();
        eventListenersSetup = true;
      } else {
        const handleConnect = () => {
          if (isInEvent && !eventListenersSetup) {
            setupEventSocketListeners();
            eventListenersSetup = true;
          }
          (eventSocketService as any).off('connect', handleConnect);
        };
        (eventSocketService as any).on('connect', handleConnect);
      }
    } else if (!isInEvent && eventListenersSetup) {
      cleanupEventSocketListeners();
      eventListenersSetup = false;
    }
  });

  onMount(() => {
    setupSocketListeners();

    const handleVisibilityChange = () => {
      if (document.hidden && isPlaying) {
        musicPlayerStore.pause();
      }
    };

    document.addEventListener('visibilitychange', handleVisibilityChange);

    return () => {
      document.removeEventListener('visibilitychange', handleVisibilityChange);
    };
  });
  
  onDestroy(() => {
    if (loadTimeout) {
      clearTimeout(loadTimeout);
      loadTimeout = null;
    }
    
    if (skipMessageTimeout) {
      clearTimeout(skipMessageTimeout);
      skipMessageTimeout = null;
    }
    
    if (youtubePlayer) {
      globalAudioManager.unregisterAudio(youtubePlayer, audioId);
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
      eventSocketService.off('time-sync');
    }
  });
</script>

<!-- YouTube Player for playback (with improved safeguards) -->
{#if currentTrack?.previewUrl && isYouTubeUrl(currentTrack.previewUrl)}
<YouTubePlayer
  bind:this={youtubePlayer}
  videoUrl={currentTrack.previewUrl}
  isPlaying={isPlaying}
  volume={isMuted ? 0 : volume}
  currentTime={currentTime}
  duration={duration}
  isEventStream={isInEvent}
  isSyncing={isSyncing}
  onTimeUpdate={handleYouTubeTimeUpdate}
  onDurationChange={handleYouTubeDurationChange}
  onEnded={handleEnded}
  onReady={handleYouTubeReady}
  onError={handleYouTubeError}
  onCanPlay={handleYouTubeCanPlay}
  onLoadStart={handleYouTubeLoadStart}
/>
{/if}

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
        readonly={isInEvent && !canControl}
        class="w-full h-1 bg-gray-200 rounded-lg appearance-none cursor-pointer slider"
        class:disabled={!canControl}
        class:readonly={isInEvent && !canControl}
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
          disabled={!canControl || (!currentTrack && playlist.length === 0) || (!!currentTrack?.previewUrl && !isYouTubeUrl(currentTrack.previewUrl))}
          class="p-3 bg-secondary text-white rounded-full hover:bg-secondary/90 disabled:opacity-50 disabled:cursor-not-allowed transition-colors"
          title={
            !currentTrack ? 'Select a track to play' :
            currentTrack?.previewUrl && !isYouTubeUrl(currentTrack.previewUrl) ? 'Only YouTube videos are supported' :
            !currentTrack?.previewUrl ? 'No video available for this track' :
            isLoading ? 'Loading video...' :
            isPlaying ? 'Pause video' : 'Play video'
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
              class="w-20 h-1 bg-gray-200 rounded-lg appearance-none cursor-pointer slider"
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