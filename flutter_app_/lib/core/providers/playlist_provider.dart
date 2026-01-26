import 'event_provider.dart';

/// Playlist Provider - backward compatibility alias
/// Playlist is just an Event with type=LISTENING_SESSION
/// Use EventProvider for all state management
typedef PlaylistProvider = EventProvider;
