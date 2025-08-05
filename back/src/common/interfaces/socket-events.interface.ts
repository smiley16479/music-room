export interface ServerToClientEvents {
  // Event-related events
  'event:updated': (event: any) => void;
  'event:participant-joined': (participant: any) => void;
  'event:participant-left': (participant: any) => void;
  'event:track-suggested': (track: any, user: any) => void;
  'event:vote-updated': (vote: any) => void;
  'event:playlist-updated': (playlist: any[]) => void;
  'event:now-playing': (track: any) => void;
  'event:track-ended': () => void;

  // Playlist-related events
  'playlist:updated': (playlist: any) => void;
  'playlist:track-added': (track: any, position: number, addedBy: any) => void;
  'playlist:track-removed': (trackId: string, removedBy: any) => void;
  'playlist:tracks-reordered': (trackIds: string[], reorderedBy: any) => void;
  'playlist:collaborator-joined': (collaborator: any) => void;
  'playlist:collaborator-left': (collaborator: any) => void;

  // Device-related events
  'device:status-updated': (device: any) => void;
  'device:control-delegated': (device: any, delegatedTo: any, permissions: any) => void;
  'device:control-revoked': (device: any, revokedBy: any) => void;
  'device:playback-command': (command: string, data?: any) => void;

  // General events
  'notification': (notification: any) => void;
  'error': (error: string) => void;
}

export interface ClientToServerEvents {
  // Event-related events
  'join-event': (eventId: string) => void;
  'leave-event': (eventId: string) => void;
  'suggest-track': (eventId: string, trackId: string) => void;
  'vote-track': (eventId: string, trackId: string, voteType: 'upvote' | 'downvote') => void;
  'remove-vote': (eventId: string, trackId: string) => void;

  // Playlist-related events
  'join-playlist': (playlistId: string) => void;
  'leave-playlist': (playlistId: string) => void;
  'add-track-to-playlist': (playlistId: string, trackId: string, position?: number) => void;
  'remove-track-from-playlist': (playlistId: string, trackId: string) => void;
  'reorder-playlist-tracks': (playlistId: string, trackIds: string[]) => void;

  // Device-related events
  'register-device': (deviceId: string, deviceInfo: any) => void;
  'update-device-status': (deviceId: string, status: string) => void;
  'delegate-device-control': (deviceId: string, delegatedToId: string, permissions: any) => void;
  'revoke-device-control': (deviceId: string) => void;
  'send-playback-command': (deviceId: string, command: string, data?: any) => void;

  // General events
  'user-location': (location: { latitude: number; longitude: number }) => void;
}