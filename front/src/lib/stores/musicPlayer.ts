import { writable, get } from 'svelte/store';
import type { PlaylistTrack } from '../services/playlists';

export interface CurrentTrack {
  id: string;
  title: string;
  artist: string;
  album: string;
  duration: number;
  albumCoverUrl?: string;
  previewUrl?: string;
}

export interface PlayerState {
  currentTrack: CurrentTrack | null;
  playlist: PlaylistTrack[];
  currentTrackIndex: number;
  isPlaying: boolean;
  volume: number;
  currentTime: number;
  duration: number;
  isLoading: boolean;
  isMuted: boolean;
  canControl: boolean; // User permission to control music
  deviceId?: string; // Connected device ID
  isInEvent: boolean; // Whether currently in an event context
  eventId?: string; // Current event ID if in event context
  failedTrackIds: Set<string>; // Track IDs that failed to load (CORS/licensing issues)
}

const initialState: PlayerState = {
  currentTrack: null,
  playlist: [],
  currentTrackIndex: -1,
  isPlaying: false,
  volume: 70,
  currentTime: 0,
  duration: 0,
  isLoading: false,
  isMuted: false,
  canControl: false,
  deviceId: undefined,
  isInEvent: false,
  eventId: undefined,
  failedTrackIds: new Set()
};

function createMusicPlayerStore() {
  const { subscribe, set, update } = writable<PlayerState>(initialState);

  // Store reference for internal access
  let currentState: PlayerState = initialState;

  // Helper function to find next valid track with preview URL
  const findNextValidTrack = (playlist: PlaylistTrack[], startIndex: number): number => {
    if (playlist.length === 0) return -1;
    
    // Track which indices we've checked to avoid infinite loops
    const checkedIndices = new Set<number>();
    let currentIndex = startIndex;
    
    while (checkedIndices.size < playlist.length) {
      // Wrap around to beginning if we reach the end
      if (currentIndex >= playlist.length) {
        currentIndex = 0;
      }
      
      // If we've already checked this index, we've gone full circle
      if (checkedIndices.has(currentIndex)) {
        break;
      }
      
      checkedIndices.add(currentIndex);
      
      // Check if this track has a valid preview URL and is not marked as failed
      if (playlist[currentIndex].track.previewUrl && 
          !currentState.failedTrackIds.has(playlist[currentIndex].track.id)) {
        return currentIndex;
      }
      
      currentIndex++;
    }
    
    return -1; // No valid track found
  };

  // Helper function to find previous valid track with preview URL
  const findPreviousValidTrack = (playlist: PlaylistTrack[], startIndex: number): number => {
    if (playlist.length === 0) return -1;
    
    // Track which indices we've checked to avoid infinite loops
    const checkedIndices = new Set<number>();
    let currentIndex = startIndex;
    
    while (checkedIndices.size < playlist.length) {
      // Wrap around to end if we reach the beginning
      if (currentIndex < 0) {
        currentIndex = playlist.length - 1;
      }
      
      // If we've already checked this index, we've gone full circle
      if (checkedIndices.has(currentIndex)) {
        break;
      }
      
      checkedIndices.add(currentIndex);
      
      // Check if this track has a valid preview URL and is not marked as failed
      if (playlist[currentIndex].track.previewUrl && 
          !currentState.failedTrackIds.has(playlist[currentIndex].track.id)) {
        return currentIndex;
      }
      
      currentIndex--;
    }
    
    return -1; // No valid track found
  };

  return {
    subscribe,
    
    // Track Control
    setCurrentTrack: (track: CurrentTrack, playlist: PlaylistTrack[] = [], index: number = 0) => {
      update(state => {
        currentState = {
          ...state,
          currentTrack: track,
          playlist,
          currentTrackIndex: index,
          duration: track.duration || 30 // Default to 30 seconds for previews
        };
        return currentState;
      });
    },

    setPlaylist: (playlist: PlaylistTrack[], currentIndex: number = 0) => {
      update(state => {
        const newTrack = playlist[currentIndex];
        currentState = {
          ...state,
          playlist,
          currentTrackIndex: currentIndex,
          currentTrack: newTrack ? {
            id: newTrack.track.id,
            title: newTrack.track.title,
            artist: newTrack.track.artist,
            album: newTrack.track.album,
            duration: newTrack.track.duration || 30, // Default to 30 seconds for previews
            albumCoverUrl: newTrack.track.albumCoverUrl,
            previewUrl: newTrack.track.previewUrl
          } : null,
          duration: newTrack?.track.duration || 30
        };
        return currentState;
      });
    },

    // Playback Control
    play: () => {
      update(state => {
        currentState = { ...state, isPlaying: true };
        return currentState;
      });
    },

    pause: () => {
      update(state => {
        currentState = { ...state, isPlaying: false };
        return currentState;
      });
    },

    togglePlay: () => {
      update(state => {
        currentState = { ...state, isPlaying: !state.isPlaying };
        return currentState;
      });
    },

    nextTrack: () => {
      update(state => {

        // For events: find next unplayed track, don't loop
        if (state.isInEvent) {
          let nextIndex = state.currentTrackIndex + 1;
          
          // Find next unplayed and unfailed track
          while (nextIndex < state.playlist.length) {
            const track = state.playlist[nextIndex];
            if (!state.failedTrackIds.has(track.track.id)) {
              // Found an unplayed, unfailed track
              const nextTrack = track;
              currentState = {
                ...state,
                currentTrackIndex: nextIndex,
                currentTrack: {
                  id: nextTrack.track.id,
                  title: nextTrack.track.title,
                  artist: nextTrack.track.artist,
                  album: nextTrack.track.album,
                  duration: nextTrack.track.duration || 30,
                  albumCoverUrl: nextTrack.track.albumCoverUrl,
                  previewUrl: nextTrack.track.previewUrl
                },
                currentTime: 0,
                duration: nextTrack.track.duration || 30,
              };
              return currentState;
            }
            nextIndex++;
          }
          
          // No unplayed tracks found, pause and wait for new tracks
          currentState = {
            ...state,
            isPlaying: false,
            currentTrack: null,
            currentTrackIndex: -1
          };
          return currentState;
        }

        // Original playlist behavior: loop through tracks
        let nextIndex = state.currentTrackIndex + 1;
        
        // If we're playing, try to find the next track with a valid preview URL
        if (state.isPlaying) {
          // If we've reached the end of the playlist, loop back to the beginning
          if (nextIndex >= state.playlist.length) {
            nextIndex = 0;
          }
          
          // Try to find the next valid track, starting from nextIndex
          const validIndex = findNextValidTrack(state.playlist, nextIndex);
          
          if (validIndex === -1) {
            // No valid tracks found anywhere in the playlist
            // Try to find from the beginning in case we missed something
            const validFromStart = findNextValidTrack(state.playlist, 0);
            
            if (validFromStart === -1) {
              // Really no valid tracks anywhere, stop playing
              console.warn('No tracks with valid preview URLs available in entire playlist');
              currentState = { ...state, isPlaying: false };
              return currentState;
            } else {
              nextIndex = validFromStart;
            }
          } else {
            nextIndex = validIndex;
          }
        } else {
          // If not playing, just go to the next track (even if no preview)
          if (nextIndex >= state.playlist.length) {
            // Loop back to beginning when not playing too
            nextIndex = 0;
          }
        }
        
        const nextTrack = state.playlist[nextIndex];
        currentState = {
          ...state,
          currentTrackIndex: nextIndex,
          currentTrack: {
            id: nextTrack.track.id,
            title: nextTrack.track.title,
            artist: nextTrack.track.artist,
            album: nextTrack.track.album,
            duration: nextTrack.track.duration || 30, // Default to 30 seconds for previews
            albumCoverUrl: nextTrack.track.albumCoverUrl,
            previewUrl: nextTrack.track.previewUrl
          },
          currentTime: 0,
          duration: nextTrack.track.duration || 30,
          // Keep playing state - the audio component will handle auto-play
          isPlaying: state.isPlaying
        };
        return currentState;
      });
    },

    previousTrack: () => {
      update(state => {
        let prevIndex = state.currentTrackIndex - 1;
        
        // If we're playing, try to find the previous track with a valid preview URL
        if (state.isPlaying) {
          prevIndex = findPreviousValidTrack(state.playlist, prevIndex);
          
          if (prevIndex === -1) {
            // No valid tracks found, stay on current track
            console.warn('No previous tracks with valid preview URLs available');
            return state;
          }
        } else {
          // If not playing, just go to the previous track (even if no preview)
          if (prevIndex < 0) {
            return state;
          }
        }
        
        const prevTrack = state.playlist[prevIndex];
        return {
          ...state,
          currentTrackIndex: prevIndex,
          currentTrack: {
            id: prevTrack.track.id,
            title: prevTrack.track.title,
            artist: prevTrack.track.artist,
            album: prevTrack.track.album,
            duration: prevTrack.track.duration || 30, // Default to 30 seconds for previews
            albumCoverUrl: prevTrack.track.albumCoverUrl,
            previewUrl: prevTrack.track.previewUrl
          },
          currentTime: 0,
          duration: prevTrack.track.duration || 30,
          // Keep playing state - the audio component will handle auto-play
          isPlaying: state.isPlaying
        };
      });
    },

    // Volume Control
    setVolume: (volume: number) => {
      update(state => ({ ...state, volume: Math.max(0, Math.min(100, volume)) }));
    },

    toggleMute: () => {
      update(state => ({ ...state, isMuted: !state.isMuted }));
    },

    // Time Control
    setCurrentTime: (time: number) => {
      update(state => ({ ...state, currentTime: time }));
    },

    seekTo: (time: number) => {
      update(state => ({ 
        ...state, 
        currentTime: Math.max(0, Math.min(state.duration, time)) 
      }));
    },

    // Loading State
    setLoading: (loading: boolean) => {
      update(state => ({ ...state, isLoading: loading }));
    },

    // Permission Control
    setCanControl: (canControl: boolean) => {
      update(state => ({ ...state, canControl }));
    },

    // Device Control
    setDevice: (deviceId: string) => {
      update(state => ({ ...state, deviceId }));
    },

    clearDevice: () => {
      update(state => ({ ...state, deviceId: undefined, canControl: false }));
    },

    // Event Context Control
    setInEvent: (isInEvent: boolean, eventId?: string) => {
      update(state => {
        currentState = { 
          ...state, 
          isInEvent, 
          eventId,
          failedTrackIds: isInEvent ? new Set() : new Set()
        };
        return currentState;
      });
    },

    // Sync with event state
    syncWithEvent: (trackId: string, isPlaying: boolean | undefined, currentTime: number = 0) => {
      update(state => {
        const trackIndex = state.playlist.findIndex(pt => pt.track.id === trackId);
        if (trackIndex >= 0) {
          const track = state.playlist[trackIndex];
          currentState = {
            ...state,
            currentTrack: {
              id: track.track.id,
              title: track.track.title,
              artist: track.track.artist,
              album: track.track.album,
              duration: track.track.duration || 30,
              albumCoverUrl: track.track.albumCoverUrl,
              previewUrl: track.track.previewUrl
            },
            currentTrackIndex: trackIndex,
            isPlaying: isPlaying !== undefined ? isPlaying : state.isPlaying,
            currentTime
          };
        }
        return currentState;
      });
    },

    // Event Track Management
    clearPlayedTracks: () => {
      update(state => {
        currentState = { ...state, failedTrackIds: new Set() };
        return currentState;
      });
    },

    markTrackAsFailed: (trackId: string) => {
      update(state => {
        const newFailedTracks = new Set(state.failedTrackIds);
        newFailedTracks.add(trackId);
        return { ...state, failedTrackIds: newFailedTracks };
      });
    },

    clearFailedTracks: () => {
      update(state => ({ ...state, failedTrackIds: new Set() }));
    },

    getUnplayedTracksCount: () => {
      if (!currentState.isInEvent) return currentState.playlist.length;
      return currentState.playlist.filter((track: PlaylistTrack) => 
        !currentState.failedTrackIds.has(track.track.id)
      ).length;
    },

    // Reset
    reset: () => {
      set(initialState);
    }
  };
}

export const musicPlayerStore = createMusicPlayerStore();
