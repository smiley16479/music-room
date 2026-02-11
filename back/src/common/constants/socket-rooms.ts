export const SOCKET_ROOMS = {
  EVENT: (eventId: string) => `event:${eventId}`,
  EVENT_DETAIL: (eventId: string) => `event-detail:${eventId}`,
  EVENT_PLAYLIST: (eventId: string) => `event-playlist:${eventId}`,
  EVENTS: 'events',
  PLAYLIST: (playlistId: string) => `playlist:${playlistId}`,
  PLAYLISTS: 'playlists',
  USER: (userId: string) => `user:${userId}`,
  DEVICE: (deviceId: string) => `device:${deviceId}`,
  LOCATION: (lat: number, lng: number, precision = 2) => `location:${lat.toFixed(precision)}:${lng.toFixed(precision)}`,
} as const;
