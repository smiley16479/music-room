import { writable } from 'svelte/store';
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
  deviceId: undefined
};

function createMusicPlayerStore() {
  const { subscribe, set, update } = writable<PlayerState>(initialState);

  return {
    subscribe,
    
    // Track Control
    setCurrentTrack: (track: CurrentTrack, playlist: PlaylistTrack[] = [], index: number = 0) => {
      update(state => ({
        ...state,
        currentTrack: track,
        playlist,
        currentTrackIndex: index,
        duration: track.duration
      }));
    },

    setPlaylist: (playlist: PlaylistTrack[], currentIndex: number = 0) => {
      update(state => {
        const newTrack = playlist[currentIndex];
        return {
          ...state,
          playlist,
          currentTrackIndex: currentIndex,
          currentTrack: newTrack ? {
            id: newTrack.track.id,
            title: newTrack.track.title,
            artist: newTrack.track.artist,
            album: newTrack.track.album,
            duration: newTrack.track.duration,
            albumCoverUrl: newTrack.track.albumCoverUrl,
            previewUrl: newTrack.track.previewUrl
          } : null
        };
      });
    },

    // Playback Control
    play: () => {
      update(state => ({ ...state, isPlaying: true }));
    },

    pause: () => {
      update(state => ({ ...state, isPlaying: false }));
    },

    togglePlay: () => {
      update(state => ({ ...state, isPlaying: !state.isPlaying }));
    },

    nextTrack: () => {
      update(state => {
        const nextIndex = state.currentTrackIndex + 1;
        if (nextIndex < state.playlist.length) {
          const nextTrack = state.playlist[nextIndex];
          return {
            ...state,
            currentTrackIndex: nextIndex,
            currentTrack: {
              id: nextTrack.track.id,
              title: nextTrack.track.title,
              artist: nextTrack.track.artist,
              album: nextTrack.track.album,
              duration: nextTrack.track.duration,
              albumCoverUrl: nextTrack.track.albumCoverUrl,
              previewUrl: nextTrack.track.previewUrl
            },
            currentTime: 0,
            // Keep playing state - the audio component will handle auto-play
            isPlaying: state.isPlaying
          };
        }
        return { ...state, isPlaying: false }; // Stop if no next track
      });
    },

    previousTrack: () => {
      update(state => {
        const prevIndex = state.currentTrackIndex - 1;
        if (prevIndex >= 0) {
          const prevTrack = state.playlist[prevIndex];
          return {
            ...state,
            currentTrackIndex: prevIndex,
            currentTrack: {
              id: prevTrack.track.id,
              title: prevTrack.track.title,
              artist: prevTrack.track.artist,
              album: prevTrack.track.album,
              duration: prevTrack.track.duration,
              albumCoverUrl: prevTrack.track.albumCoverUrl,
              previewUrl: prevTrack.track.previewUrl
            },
            currentTime: 0,
            // Keep playing state - the audio component will handle auto-play
            isPlaying: state.isPlaying
          };
        }
        return state;
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

    // Reset
    reset: () => {
      set(initialState);
    }
  };
}

export const musicPlayerStore = createMusicPlayerStore();
