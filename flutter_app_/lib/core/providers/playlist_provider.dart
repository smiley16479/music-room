import 'event_provider.dart';

/// Playlist Provider - backward compatibility alias
/// Playlist is just an Event with type=playlist
/// Use EventProvider for all state management
typedef PlaylistProvider = EventProvider;
