import { musicPlayerStore } from '$lib/stores/musicPlayer';
import { authStore } from '$lib/stores/auth';
import { socketService } from './socket';
import { devicesService } from './devices';
import { playlistsService } from './playlists';
import type { PlaylistTrack } from './playlists';
import { get } from 'svelte/store';

export interface RoomContext {
  type: 'playlist' | 'event';
  id: string;
  ownerId: string;
  participants: string[];
  licenseType: 'open' | 'invited' | 'location-time';
  visibility: 'public' | 'private';
  adminIds?: string[]; // For events, list of admin user IDs
}

export interface MusicPermissions {
  canControl: boolean;
  canVote: boolean;
  canAddTracks: boolean;
  reason?: string;
}

class MusicPlayerService {
  private currentRoom: RoomContext | null = null;
  private socketConnected = false;

  /**
   * Initialize the music player for a specific room/context
   */
  async initializeForRoom(roomContext: RoomContext, playlist: PlaylistTrack[] = []): Promise<void> {
    this.currentRoom = roomContext;
    
    // Set event context based on room type
    musicPlayerStore.setInEvent(roomContext.type === 'event');
    
    // Set initial playlist (can be empty for live events)
    musicPlayerStore.setPlaylist(playlist, playlist.length > 0 ? 0 : -1);
    
    // Only set the first track as current if there are tracks
    if (playlist.length > 0) {
      const firstTrack = playlist[0];
      musicPlayerStore.setCurrentTrack({
        id: firstTrack.track.id,
        title: firstTrack.track.title,
        artist: firstTrack.track.artist,
        album: firstTrack.track.album,
        duration: firstTrack.track.duration || 30,
        albumCoverUrl: firstTrack.track.albumCoverUrl,
        previewUrl: firstTrack.track.previewUrl
      }, playlist, 0);
    }

    // Calculate permissions
    const permissions = await this.calculatePermissions(roomContext);
    musicPlayerStore.setCanControl(permissions.canControl);
    

    // Connect to room socket
    await this.connectToRoom(roomContext);
  }

  /**
   * Calculate user permissions based on room context and license
   */
  private async calculatePermissions(roomContext: RoomContext): Promise<MusicPermissions> {
    const user = get(authStore);
    if (!user) {
      return { canControl: false, canVote: false, canAddTracks: false, reason: 'Not authenticated' };
    }

    // Owner always has full permissions
    if (roomContext.ownerId === user.id) {
      return { canControl: true, canVote: true, canAddTracks: true };
    }

    // For events, check if user is an admin
    if (roomContext.type === 'event' && roomContext.adminIds?.includes(user.id)) {
      return { canControl: true, canVote: true, canAddTracks: true };
    }

    // Check if user is in participants list for private rooms
    if (roomContext.visibility === 'private' && !roomContext.participants.includes(user.id)) {
      return { 
        canControl: false, 
        canVote: false, 
        canAddTracks: false, 
        reason: 'Not invited to private room' 
      };
    }

    // Apply license restrictions
    switch (roomContext.licenseType) {
      case 'open':
        // For events, only admins/owners can control music, but everyone can view
        if (roomContext.type === 'event') {
          return { canControl: false, canVote: true, canAddTracks: false };
        }
        return { canControl: true, canVote: true, canAddTracks: true };
      
      case 'invited':
        const hasInvite = roomContext.participants.includes(user.id);
        
        // For playlists: public playlists allow playback control for all users, private only for invited
        // For events: only admins can control
        const canPlayback = roomContext.type === 'playlist' 
          ? (roomContext.visibility === 'public' || hasInvite)
          : false;
        
        return { 
          canControl: canPlayback, 
          canVote: hasInvite, 
          canAddTracks: hasInvite,
          reason: canPlayback ? undefined : 'Invitation required'
        };
      
      case 'location-time':
        // TODO: Implement location/time-based permissions
        // For now, return false as we need geolocation API
        return { 
          canControl: false, 
          canVote: false, 
          canAddTracks: false, 
          reason: 'Location/time restrictions not implemented' 
        };
      
      default:
        return { canControl: false, canVote: false, canAddTracks: false };
    }
  }

  /**
   * Connect to socket room for real-time updates
   */
  private async connectToRoom(roomContext: RoomContext): Promise<void> {
    try {
      const socket = await socketService.connect();
      
      // Join the appropriate room
      const roomName = roomContext.type === 'playlist' 
        ? `playlist-${roomContext.id}` 
        : `event-${roomContext.id}`;
      
      socket.emit('join-room', { room: roomName });

      // Set up music-specific event listeners
      this.setupMusicSocketListeners(socket);
      
      this.socketConnected = true;
    } catch (error) {
      
    }
  }

  /**
   * Set up socket listeners for music collaboration
   */
  private setupMusicSocketListeners(socket: any): void {
    // Track changes
    socket.on('track-changed', (data: {
      track: any;
      playlist: PlaylistTrack[];
      index: number;
      userId: string;
    }) => {
      musicPlayerStore.setCurrentTrack(data.track, data.playlist, data.index);
    });

    // Playback control events
    socket.on('music-play', (data: { userId: string; timestamp: string }) => {
      musicPlayerStore.play();
    });

    socket.on('music-pause', (data: { userId: string; timestamp: string }) => {
      musicPlayerStore.pause();
    });

    socket.on('music-seek', (data: { time: number; userId: string; timestamp: string }) => {
      musicPlayerStore.seekTo(data.time);
    });

    socket.on('music-volume', (data: { volume: number; userId: string; timestamp: string }) => {
      musicPlayerStore.setVolume(data.volume);
    });

    socket.on('music-next', (data: { userId: string; timestamp: string }) => {
      musicPlayerStore.nextTrack();
    });

    socket.on('music-previous', (data: { userId: string; timestamp: string }) => {
      musicPlayerStore.previousTrack();
    });

    // Voting events (for track voting feature)
    socket.on('track-voted', (data: {
      trackId: string;
      votes: number;
      newPosition?: number;
      userId: string;
    }) => {
      // Handle track voting and reordering
    });

    // Permission changes
    socket.on('permissions-updated', (data: {
      userId: string;
      permissions: MusicPermissions;
    }) => {
      const user = get(authStore);
      if (user && data.userId === user.id) {
        musicPlayerStore.setCanControl(data.permissions.canControl);
      }
    });
  }

  /**
   * Play a specific track from the playlist
   */
  async playTrack(trackIndex: number): Promise<void> {
    const playerState = get(musicPlayerStore);
    
    if (!playerState.canControl) {
      throw new Error('No permission to control music');
    }

    if (trackIndex < 0 || trackIndex >= playerState.playlist.length) {
      
      throw new Error('Invalid track index');
    }

    const track = playerState.playlist[trackIndex];
    
    // Set loading state when starting track selection
    musicPlayerStore.setLoading(true);
    
    musicPlayerStore.setCurrentTrack({
      id: track.track.id,
      title: track.track.title,
      artist: track.track.artist,
      album: track.track.album,
      duration: track.track.duration || 30, // Default to 30 seconds for previews
      albumCoverUrl: track.track.albumCoverUrl,
      previewUrl: track.track.previewUrl
    }, playerState.playlist, trackIndex);

    // Notify other participants
    if (this.socketConnected && socketService.isConnected()) {
      socketService.emit('track-changed', {
        roomId: this.currentRoom?.id,
        track: track.track,
        playlist: playerState.playlist,
        index: trackIndex
      });
    }

    // Start playback - the loading state will be cleared by the audio component
    musicPlayerStore.play();
  }

  /**
   * Vote for a track (moves it up in the playlist)
   */
  async voteForTrack(trackId: string): Promise<void> {
    const permissions = this.currentRoom ? await this.calculatePermissions(this.currentRoom) : null;
    
    if (!permissions?.canVote) {
      throw new Error('No permission to vote');
    }

    if (this.socketConnected && socketService.isConnected()) {
      socketService.emit('vote-track', {
        roomId: this.currentRoom?.id,
        trackId,
        type: this.currentRoom?.type
      });
    }
  }

  /**
   * Add a track to the current playlist
   * @param track - The full track object containing all required fields
   * @param position - Optional position in the playlist
   */
  async addTrack(track: {
    deezerId: string;
    title: string;
    artist: string;
    album: string;
    albumCoverUrl?: string;
    previewUrl?: string;
    duration?: number;
  }, position?: number): Promise<void> {
    if (!this.currentRoom || this.currentRoom.type !== 'playlist') {
      throw new Error('Can only add tracks to playlists');
    }

    const permissions = await this.calculatePermissions(this.currentRoom);
    if (!permissions.canAddTracks) {
      throw new Error('No permission to add tracks');
    }

    try {
      await playlistsService.addTrackToPlaylist(this.currentRoom.id, {
        ...track,
        position
      });
      // The socket event will update the UI
    } catch (error) {
      
      throw error;
    }
  }

  /**
   * Connect to a device for remote control
   */
  async connectToDevice(deviceId: string): Promise<void> {
    try {
      const device = await devicesService.getDevice(deviceId);
      musicPlayerStore.setDevice(deviceId);
      
      // Check if user has control permission for this device
      const permissions = await devicesService.getControlPermissions(deviceId);
      const user = get(authStore);
      const hasPermission = permissions.some(p => p.grantedTo === user?.id && p.isActive);
      
      musicPlayerStore.setCanControl(hasPermission);
    } catch (error) {
      
      throw error;
    }
  }

  /**
   * Disconnect from current device
   */
  disconnectFromDevice(): void {
    musicPlayerStore.clearDevice();
  }

  /**
   * Leave the current room
   */
  leaveRoom(): void {
    if (this.socketConnected && socketService.isConnected() && this.currentRoom) {
      const roomName = this.currentRoom.type === 'playlist' 
        ? `playlist-${this.currentRoom.id}` 
        : `event-${this.currentRoom.id}`;
      
      socketService.emit('leave-room', { room: roomName });
    }

    this.currentRoom = null;
    this.socketConnected = false;
    musicPlayerStore.reset();
  }

  /**
   * Get current room context
   */
  getCurrentRoom(): RoomContext | null {
    return this.currentRoom;
  }
}

export const musicPlayerService = new MusicPlayerService();
