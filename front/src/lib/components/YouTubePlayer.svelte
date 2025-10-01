<script lang="ts">
  import type { YTPlayer } from '$lib/types/youtube';
  
  interface Props {
    videoUrl?: string;
    isPlaying?: boolean;
    volume?: number;
    currentTime?: number;
    duration?: number;
    onTimeUpdate?: (time: number) => void;
    onDurationChange?: (duration: number) => void;
    onEnded?: () => void;
    onReady?: () => void;
    onError?: (error: any) => void;
    onCanPlay?: () => void;
    onLoadStart?: () => void;
    isEventStream?: boolean; // For optimizing event streaming
    isSyncing?: boolean; // External sync lock from parent component
  }
  
  let {
    videoUrl = $bindable(''),
    isPlaying = $bindable(false),
    volume = $bindable(50),
    currentTime = $bindable(0),
    duration = $bindable(0),
    onTimeUpdate = () => {},
    onDurationChange = () => {},
    onEnded = () => {},
    onReady = () => {},
    onError = () => {},
    onCanPlay = () => {},
    onLoadStart = () => {},
    isEventStream = false,
    isSyncing = false
  }: Props = $props();
  
  let playerElement = $state<HTMLDivElement>();
  let player = $state<YTPlayer | null>(null);
  let playerReady = $state(false);
  let isInitialized = $state(false);
  let seekTimeout: NodeJS.Timeout | null = null;
  let isAdminSeeking = $state(false); // Flag to prevent time updates during admin seeks
  let initTimeout: NodeJS.Timeout | null = null;
  let lastVideoUrl = '';
  let lastInitTime = 0;
  const MIN_INIT_INTERVAL = 1000; // Minimum 1 second between initializations
  
  // Extract video ID from YouTube URL
  function extractVideoId(url: string): string | null {
    const patterns = [
      /(?:youtube\.com\/watch\?v=|youtu\.be\/|youtube\.com\/embed\/)([^&\n?#]+)/,
      /youtube\.com\/watch\?.*v=([^&\n?#]+)/,
    ];

    for (const pattern of patterns) {
      const match = url.match(pattern);
      if (match) {
        return match[1];
      }
    }
    return null;
  }
  
  // Load YouTube IFrame API
  function loadYouTubeAPI(): Promise<void> {
    return new Promise((resolve) => {
      // Check if API is already loaded
      if (window.YT && window.YT.Player) {
        resolve();
        return;
      }
      
      // Check if API is being loaded
      if (window.onYouTubeIframeAPIReady) {
        // Wait for it to load
        const originalCallback = window.onYouTubeIframeAPIReady;
        window.onYouTubeIframeAPIReady = () => {
          originalCallback();
          resolve();
        };
        return;
      }
      
      // Load the API
      window.onYouTubeIframeAPIReady = () => {
        resolve();
      };
      
      const script = document.createElement('script');
      script.src = 'https://www.youtube.com/iframe_api';
      document.head.appendChild(script);
    });
  }
  
  // Initialize YouTube player
  async function initializePlayer() {
    if (!videoUrl || isInitialized || !playerElement) {
      return;
    }
    
    const videoId = extractVideoId(videoUrl);
    if (!videoId) {
      onError({ message: 'Invalid YouTube URL' });
      return;
    }
    
    try {
      await loadYouTubeAPI();
      
      if (player) {
        try {
          player.destroy();
        } catch (e) {
          // Error handling without logging
        }
        player = null;
        playerReady = false;
      }
      
      player = new window.YT!.Player(playerElement, {
        height: '0',
        width: '0',
        videoId: videoId,
        playerVars: {
          autoplay: 0,
          controls: 0,
          disablekb: 1,
          modestbranding: 1,
          rel: 0,
          showinfo: 0,
          fs: 0,
          cc_load_policy: 0,
          iv_load_policy: 3,
          start: Math.floor(currentTime),
          enablejsapi: 1,
          origin: window.location.origin,
          playsinline: 1,
          ...(isEventStream && {
            hd720: 0,
            hd: 0,
            preload: 'none'
          })
        } as any,
        events: {
          onReady: handlePlayerReady,
          onStateChange: handleStateChange,
          onError: handlePlayerError
        }
      });
      
      isInitialized = true;
      onLoadStart();
      
    } catch (error) {
      isInitialized = false;
      playerReady = false;
      onError(error);
    }
  }
  
  function handlePlayerReady(event: any) {
    playerReady = true;
    
    if (player && player.setVolume) {
      player.setVolume(volume);
    }
    
    if (player && (player as any).setPlaybackQuality) {
      const qualities = ['tiny', 'small', 'medium'];
      for (const quality of qualities) {
        try {
          (player as any).setPlaybackQuality(quality);
          break;
        } catch (e) {
          // Error handling without logging
        }
      }
    }
    
    if (isEventStream && player && (player as any).setPlaybackRate) {
      (player as any).setPlaybackRate(1);
      
      try {
        if ((player as any).setPlaybackQualityRange) {
          (player as any).setPlaybackQualityRange('small', 'tiny');
        }
        
        if ((player as any).setSuggestedQuality) {
          (player as any).setSuggestedQuality('small');
        }
      } catch (e) {
        // Error handling without logging
      }
    }
    
    if (player && player.getDuration) {
      const dur = player.getDuration();
      if (dur > 0) {
        duration = dur;
        onDurationChange(dur);
      }
    }
    
    onReady();
    onCanPlay();
    
    startTimeUpdateInterval();
  }
  
  function handleStateChange(event: any) {
    const state = event.data;
    
    // YouTube Player States:
    // -1 (unstarted)
    // 0 (ended)
    // 1 (playing)
    // 2 (paused)
    // 3 (buffering)
    // 5 (video cued)
    
    if (state === 0) { // ended
      onEnded();
    } else if (state === 1) { // playing
      // Update duration if not set
      if (duration === 0 && player && player.getDuration) {
        const dur = player.getDuration();
        if (dur > 0) {
          duration = dur;
          onDurationChange(dur);
        }
      }
    } else if (state === 5) {
      if (player && player.getDuration) {
        const dur = player.getDuration();
        if (dur > 0 && duration !== dur) {
          duration = dur;
          onDurationChange(dur);
        }
      }
    } else if (state === 3) {
      if (duration === 0 && player && player.getDuration) {
        const dur = player.getDuration();
        if (dur > 0) {
          duration = dur;
          onDurationChange(dur);
        }
      }
    }
  }
  
  function handlePlayerError(event: any) {
    onError({ 
      code: event.data,
      message: `YouTube player error: ${event.data}`
    });
  }
  
  let timeUpdateInterval: NodeJS.Timeout | null = null;
  
  function startTimeUpdateInterval() {
    if (timeUpdateInterval) {
      clearInterval(timeUpdateInterval);
    }
    
    // Use different update intervals based on usage
    const updateInterval = isEventStream ? 250 : 100; // Slower updates for event streaming
    
    timeUpdateInterval = setInterval(() => {
      if (player && player.getCurrentTime && playerReady && !isAdminSeeking && !isSyncing) {
        const time = player.getCurrentTime();
        
        if (isEventStream && isSyncing) {
          return;
        }
        
        if (Math.abs(time - currentTime) > 0.1) {
          currentTime = time;
          onTimeUpdate(time);
        }
      }
    }, updateInterval);
  }
  
  function stopTimeUpdateInterval() {
    if (timeUpdateInterval) {
      clearInterval(timeUpdateInterval);
      timeUpdateInterval = null;
    }
  }
  
  $effect(() => {
    if (player && playerReady) {
      if (isPlaying) {
        player.playVideo();
        if (!timeUpdateInterval && !isSyncing && !isAdminSeeking) {
          startTimeUpdateInterval();
        }
      } else {
        player.pauseVideo();
        stopTimeUpdateInterval();
      }
    }
  });
  
  // Effect to handle volume changes
  $effect(() => {
    if (player && playerReady && player.setVolume) {
      player.setVolume(volume);
    }
  });
  
  $effect(() => {
    if (videoUrl && videoUrl !== '' && videoUrl !== lastVideoUrl) {
      lastVideoUrl = videoUrl;
      
      if (initTimeout) {
        clearTimeout(initTimeout);
      }
      
      const videoId = extractVideoId(videoUrl);
      
      if (!videoId) {
        onError({ message: 'Invalid YouTube URL' });
        return;
      }
      
      const now = Date.now();
      const timeSinceLastInit = now - lastInitTime;
      const delay = Math.max(100, MIN_INIT_INTERVAL - timeSinceLastInit);
      
      initTimeout = setTimeout(() => {
        if (player && playerReady && player.getVideoUrl && player.getVideoUrl().includes(videoId)) {
          return;
        }
        
        lastInitTime = Date.now();
        
        if (isInitialized && player) {
          if (player.loadVideoById) {
            player.loadVideoById(videoId);
            onLoadStart();
          }
        } else {
          initializePlayer();
        }
      }, delay);
    }
  });
  
  export function seekTo(time: number, isAdminSync: boolean = false) {
    if (player && playerReady && player.seekTo) {
      if (isAdminSync) {
        isAdminSeeking = true;
        
        stopTimeUpdateInterval();
        
        player.seekTo(time, true);
        currentTime = time;
        
        setTimeout(() => {
          isAdminSeeking = false;
          if (isPlaying) {
            startTimeUpdateInterval();
          }
        }, 700);
      } else {
        if (seekTimeout) {
          clearTimeout(seekTimeout);
        }
        
        seekTimeout = setTimeout(() => {
          if (player && player.seekTo) {
            player.seekTo(time, true);
            currentTime = time;
          }
        }, 150);
      }
    } else if (player && player.seekTo) {
      player.seekTo(time, true);
      currentTime = time;
    }
  }

  export function resetPlayerState() {
    if (player && playerReady) {
      try {
        if (player.pauseVideo) {
          player.pauseVideo();
        }
        
        if (player.seekTo) {
          player.seekTo(0, true);
        }
        
        if (seekTimeout) {
          clearTimeout(seekTimeout);
          seekTimeout = null;
        }
        
        isAdminSeeking = false;
        currentTime = 0;
      } catch (error) {
        // Error handling without logging
      }
    }
  }
  
  export function getCurrentTime(): number {
    if (player && playerReady && player.getCurrentTime) {
      return player.getCurrentTime();
    }
    return currentTime;
  }
  
  export function getDuration(): number {
    if (player && playerReady && player.getDuration) {
      return player.getDuration();
    }
    return duration;
  }
  
  export function getPlayerState(): number {
    if (player && playerReady && player.getPlayerState) {
      return player.getPlayerState();
    }
    return -1; // unstarted
  }
  
  $effect(() => {
    if (videoUrl && playerElement) {
      const initDelay = setTimeout(() => {
        initializePlayer();
      }, 50);
      
      return () => {
        clearTimeout(initDelay);
      };
    }
    
    return () => {
      stopTimeUpdateInterval();
      if (seekTimeout) {
        clearTimeout(seekTimeout);
      }
      if (initTimeout) {
        clearTimeout(initTimeout);
      }
      if (player) {
        try {
          player.destroy();
        } catch (e) {
          // Error handling without logging
        }
        player = null;
      }
      isInitialized = false;
      playerReady = false;
      isAdminSeeking = false;
      lastVideoUrl = '';
    };
  });
</script>

<!-- Hidden YouTube player -->
<div bind:this={playerElement} class="youtube-player" style="position: fixed; top: -9999px; left: -9999px; width: 1px; height: 1px; opacity: 0; pointer-events: none; z-index: -999; visibility: hidden;"></div>

<style>
  :global(.youtube-player) {
    position: fixed !important;
    top: -9999px !important;
    left: -9999px !important;
    width: 1px !important;
    height: 1px !important;
    opacity: 0 !important;
    pointer-events: none !important;
    z-index: -999 !important;
    visibility: hidden !important;
  }
  
  :global(.youtube-player iframe) {
    width: 1px !important;
    height: 1px !important;
    opacity: 0 !important;
    visibility: hidden !important;
  }
</style>
