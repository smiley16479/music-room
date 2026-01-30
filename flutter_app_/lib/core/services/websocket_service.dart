import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:socket_io_client/socket_io_client.dart' as IO;

import '../../config/app_config.dart';

/** MARK: Pour utiliser les WebSockets dans les screens :
// Récupérer le service
final wsService = context.read<WebSocketService>();

// Rejoindre un event
wsService.joinEvent(eventId);

// Écouter des événements
wsService.on('track-added', (data) {
  print('New track added: $data');
  // Refresh UI
});

// Envoyer des événements
wsService.playTrack(eventId, trackId: trackId);

// Quitter l'event
wsService.leaveEvent(eventId);

 */

/// WebSocket Service for real-time event updates
class WebSocketService {
  IO.Socket? _socket;
  String? _token;
  bool _isConnected = false;
  String? _currentEventId;

  // Callbacks for different events
  final Map<String, List<Function(dynamic)>> _eventCallbacks = {};

  bool get isConnected => _isConnected;
  String? get currentEventId => _currentEventId;

  /// Initialize WebSocket connection with authentication token
  Future<void> connect(String token) async {
    if (_isConnected && _token == token) {
      debugPrint('✅ WebSocket already connected');
      return;
    }

    _token = token;
    debugPrint('🔌 Connecting to WebSocket: ${AppConfig.wsUrl}/events');

    _socket = IO.io(
      '${AppConfig.wsUrl}/events',
      IO.OptionBuilder()
          .setTransports(['websocket'])
          .enableAutoConnect()
          .enableReconnection()
          .setReconnectionDelay(1000)
          .setReconnectionAttempts(5)
          .setAuth({'token': token})
          .build(),
    );

    _setupEventHandlers();

    _socket!.connect();
    // Wait until socket actually connects (or timeout)
    final completer = Completer<void>();
    void onConnected(_) {
      if (!completer.isCompleted) completer.complete();
    }

    // Temporary one-shot listener to await connection
    _socket!.once('connect', onConnected);

    try {
      // Wait for connection up to 5 seconds
      await completer.future.timeout(const Duration(seconds: 5));
      debugPrint('🔌 WebSocket connection established (awaited)');
    } catch (e) {
      debugPrint('⚠️ WebSocket connection timed out or failed: $e');
    }
  }

  /// Setup all WebSocket event handlers
  void _setupEventHandlers() {
    _socket!.onConnect((_) {
      _isConnected = true;
      debugPrint('✅ WebSocket connected');
      _notifyCallbacks('connected', null);
    });

    _socket!.onDisconnect((_) {
      _isConnected = false;
      debugPrint('❌ WebSocket disconnected');
      _notifyCallbacks('disconnected', null);
    });

    _socket!.onConnectError((error) {
      debugPrint('❌ WebSocket connection error: $error');
      _notifyCallbacks('error', error);
    });

    _socket!.onError((error) {
      debugPrint('❌ WebSocket error: $error');
      _notifyCallbacks('error', error);
    });

    // Event room events
    _socket!.on('joined-events-room', (data) {
      debugPrint('📡 Joined events room: $data');
      _notifyCallbacks('joined-events-room', data);
    });

    _socket!.on('joined-event', (data) {
      debugPrint('📡 Joined event: $data');
      _notifyCallbacks('joined-event', data);
    });

    _socket!.on('left-event', (data) {
      debugPrint('📡 Left event: $data');
      _notifyCallbacks('left-event', data);
    });

    // User events
    _socket!.on('user-joined', (data) {
      debugPrint('👤 User joined: $data');
      _notifyCallbacks('user-joined', data);
    });

    _socket!.on('user-left', (data) {
      debugPrint('👤 User left: $data');
      _notifyCallbacks('user-left', data);
    });

    _socket!.on('current-participants', (data) {
      debugPrint('👥 Current participants: $data');
      _notifyCallbacks('current-participants', data);
    });

    // Event updates
    _socket!.on('event-created', (data) {
      debugPrint('🎉 Event created: $data');
      _notifyCallbacks('event-created', data);
    });

    _socket!.on('event-updated', (data) {
      debugPrint('📝 Event updated: $data');
      _notifyCallbacks('event-updated', data);
    });

    _socket!.on('event-deleted', (data) {
      debugPrint('🗑️ Event deleted: $data');
      _notifyCallbacks('event-deleted', data);
    });

    // Participant events
    _socket!.on('participant-joined', (data) {
      debugPrint('👤 Participant joined: $data');
      _notifyCallbacks('participant-joined', data);
    });

    _socket!.on('participant-left', (data) {
      debugPrint('👤 Participant left: $data');
      _notifyCallbacks('participant-left', data);
    });

    // Track events
    _socket!.on('track-suggested', (data) {
      debugPrint('🎵 Track suggested: $data');
      _notifyCallbacks('track-suggested', data);
    });

    _socket!.on('track-added', (data) {
      debugPrint('➕ Track added: $data');
      _notifyCallbacks('track-added', data);
    });

    _socket!.on('track-removed', (data) {
      debugPrint('➖ Track removed: $data');
      _notifyCallbacks('track-removed', data);
    });

    _socket!.on('tracks-reordered', (data) {
      debugPrint('🔄 Tracks reordered: $data');
      _notifyCallbacks('tracks-reordered', data);
    });

    _socket!.on('track-ended', (data) {
      debugPrint('⏹️ Track ended: $data');
      _notifyCallbacks('track-ended', data);
    });

    _socket!.on('track-skipped', (data) {
      debugPrint('⏭️ Track skipped: $data');
      _notifyCallbacks('track-skipped', data);
    });

    // Voting events
    _socket!.on('vote-updated', (data) {
      debugPrint('🗳️ ✅ Vote updated: $data');
      _notifyCallbacks('vote-updated', data);
    });

    _socket!.on('vote-removed', (data) {
      debugPrint('🗳️ ❌ Vote removed: $data');
      _notifyCallbacks('vote-removed', data);
    });

    // Playback events
    _socket!.on('music-play', (data) {
      debugPrint('▶️ Music play: $data');
      _notifyCallbacks('music-play', data);
    });

    _socket!.on('music-pause', (data) {
      debugPrint('⏸️ Music pause: $data');
      _notifyCallbacks('music-pause', data);
    });

    _socket!.on('music-seek', (data) {
      debugPrint('⏩ Music seek: $data');
      _notifyCallbacks('music-seek', data);
    });

    _socket!.on('music-track-changed', (data) {
      debugPrint('🔄 Track changed: $data');
      _notifyCallbacks('music-track-changed', data);
    });

    _socket!.on('music-volume', (data) {
      debugPrint('🔊 Volume changed: $data');
      _notifyCallbacks('music-volume', data);
    });

    _socket!.on('playback-sync', (data) {
      debugPrint('🔄 Playback sync: $data');
      _notifyCallbacks('playback-sync', data);
    });

    _socket!.on('time-sync', (data) {
      debugPrint('⏰ Time sync: $data');
      _notifyCallbacks('time-sync', data);
    });

    _socket!.on('playback-state-updated', (data) {
      debugPrint('📊 Playback state updated: $data');
      _notifyCallbacks('playback-state-updated', data);
    });

    // Queue reordering (based on votes)
    _socket!.on('queue-reordered', (data) {
      debugPrint('🔀 Queue reordered by votes: $data');
      _notifyCallbacks('queue-reordered', data);
    });

    // Track vote changes
    _socket!.on('track-votes-changed', (data) {
      debugPrint('📊 Track votes changed: $data');
      _notifyCallbacks('track-votes-changed', data);
    });

    // Voting results
    _socket!.on('voting-results', (data) {
      debugPrint('🗳️ Voting results received: $data');
      _notifyCallbacks('voting-results', data);
    });

    // Invitation events
    _socket!.on('invitation-received', (data) {
      debugPrint('📩 Invitation received: $data');
      _notifyCallbacks('invitation-received', data);
    });

    _socket!.on('invitation-responded', (data) {
      debugPrint('📨 Invitation responded: $data');
      _notifyCallbacks('invitation-responded', data);
    });

    _socket!.on('invitation-accepted', (data) {
      debugPrint('✅ Invitation accepted: $data');
      _notifyCallbacks('invitation-accepted', data);
    });

    _socket!.on('joined-user-room', (data) {
      debugPrint('🏠 Joined user room: $data');
      _notifyCallbacks('joined-user-room', data);
    });

    // Chat events
    _socket!.on('new-message', (data) {
      debugPrint('💬 New message: $data');
      _notifyCallbacks('new-message', data);
    });

    // Playlist events
    _socket!.on('playlist-created', (data) {
      debugPrint('🎵 Playlist created: $data');
      _notifyCallbacks('playlist-created', data);
    });

    _socket!.on('playlist-updated', (data) {
      debugPrint('📝 Playlist updated: $data');
      _notifyCallbacks('playlist-updated', data);
    });

    _socket!.on('playlist-deleted', (data) {
      debugPrint('🗑️ Playlist deleted: $data');
      _notifyCallbacks('playlist-deleted', data);
    });

    // Error events
    _socket!.on('error', (data) {
      debugPrint('❌ Error from server: $data');
      _notifyCallbacks('error', data);
    });
  }

  /// Register a callback for a specific event
  void on(String event, Function(dynamic) callback) {
    if (!_eventCallbacks.containsKey(event)) {
      _eventCallbacks[event] = [];
    }
    _eventCallbacks[event]!.add(callback);
  }

  /// Unregister a callback for a specific event
  void off(String event, [Function(dynamic)? callback]) {
    if (callback == null) {
      _eventCallbacks.remove(event);
    } else {
      _eventCallbacks[event]?.remove(callback);
    }
  }

  /// Notify all callbacks for a specific event
  void _notifyCallbacks(String event, dynamic data) {
    if (_eventCallbacks.containsKey(event)) {
      for (var callback in _eventCallbacks[event]!) {
        try {
          callback(data);
        } catch (e) {
          debugPrint('Error in callback for $event: $e');
        }
      }
    }
  }

  // ========== EMIT METHODS ==========

  /// Join global events room
  void joinEventsRoom() {
    if (!_isConnected) {
      debugPrint('⚠️ Cannot join events room: not connected');
      return;
    }
    _socket!.emit('join-events-room');
    debugPrint('📤 Joining events room');
  }

  /// Join a specific event room
  void joinEvent(String eventId) {
    if (!_isConnected) {
      debugPrint('⚠️ Cannot join event: not connected');
      return;
    }
    _currentEventId = eventId;
    _socket!.emit('join-event', {'eventId': eventId});
    debugPrint('📤 Joining event: $eventId');
  }

  /// Leave a specific event room
  void leaveEvent(String eventId) {
    if (!_isConnected) {
      return;
    }
    _socket!.emit('leave-event', {'eventId': eventId});
    debugPrint('📤 Leaving event: $eventId');
    if (_currentEventId == eventId) {
      _currentEventId = null;
    }
  }

  /// Suggest a track
  void suggestTrack(
    String eventId,
    String trackId,
    Map<String, dynamic> trackData,
  ) {
    if (!_isConnected) return;
    _socket!.emit('suggest-track', {
      'eventId': eventId,
      'trackId': trackId,
      'trackData': trackData,
    });
    debugPrint('📤 Suggesting track: $trackId');
  }

  /// Send a chat message
  void sendMessage(String eventId, String message) {
    if (!_isConnected) return;
    _socket!.emit('send-message', {'eventId': eventId, 'message': message});
    debugPrint('📤 Sending message: $message');
  }

  /// Play track
  void playTrack(String eventId, {String? trackId, double? startTime}) {
    if (!_isConnected) return;
    _socket!.emit('play-track', {
      'eventId': eventId,
      if (trackId != null) 'trackId': trackId,
      if (startTime != null) 'startTime': startTime,
    });
    debugPrint('📤 Play track: $trackId at ${startTime}s');
  }

  /// Pause track
  void pauseTrack(String eventId, {double? currentTime}) {
    if (!_isConnected) return;
    _socket!.emit('pause-track', {
      'eventId': eventId,
      if (currentTime != null) 'currentTime': currentTime,
    });
    debugPrint('📤 Pause track at ${currentTime}s');
  }

  /// Seek in track
  void seekTrack(String eventId, double seekTime) {
    if (!_isConnected) return;
    _socket!.emit('seek-track', {'eventId': eventId, 'seekTime': seekTime});
    debugPrint('📤 Seek to ${seekTime}s');
  }

  /// Change track
  void changeTrack(String eventId, String trackId, {int? trackIndex}) {
    if (!_isConnected) return;
    _socket!.emit('change-track', {
      'eventId': eventId,
      'trackId': trackId,
      if (trackIndex != null) 'trackIndex': trackIndex,
    });
    debugPrint('📤 Change track: $trackId');
  }

  /// Set volume
  void setVolume(String eventId, int volume) {
    if (!_isConnected) return;
    _socket!.emit('set-volume', {'eventId': eventId, 'volume': volume});
    debugPrint('📤 Set volume: $volume');
  }

  /// Skip track
  void skipTrack(String eventId) {
    if (!_isConnected) return;
    _socket!.emit('skip-track', {'eventId': eventId});
    debugPrint('📤 Skip track');
  }

  /// Notify track ended
  void trackEnded(String eventId, String trackId) {
    if (!_isConnected) return;
    _socket!.emit('track-ended', {'eventId': eventId, 'trackId': trackId});
    debugPrint('📤 Track ended: $trackId');
  }

  /// Send playback state
  void sendPlaybackState(String eventId, Map<String, dynamic> state) {
    if (!_isConnected) return;
    _socket!.emit('playback-state', {'eventId': eventId, 'state': state});
    debugPrint('📤 Playback state: $state');
  }

  // ========== VOTING METHODS ==========

  /// Upvote a track via WebSocket
  void upvoteTrack(String eventId, String trackId) {
    if (!_isConnected) return;
    _socket!.emit('upvote-track', {'eventId': eventId, 'trackId': trackId});
    debugPrint('📤 Upvote track: $trackId');
  }

  /// Downvote a track via WebSocket
  void downvoteTrack(String eventId, String trackId) {
    if (!_isConnected) return;
    _socket!.emit('downvote-track', {'eventId': eventId, 'trackId': trackId});
    debugPrint('📤 Downvote track: $trackId');
  }

  /// Remove vote for a track via WebSocket
  void removeVote(String eventId, String trackId) {
    if (!_isConnected) return;
    _socket!.emit('remove-vote', {'eventId': eventId, 'trackId': trackId});
    debugPrint('📤 Remove vote for track: $trackId');
  }

  /// Request current voting results
  void getVotingResults(String eventId) {
    if (!_isConnected) return;
    _socket!.emit('get-voting-results', {'eventId': eventId});
    debugPrint('📤 Get voting results for event: $eventId');
  }

  /// Request queue reorder based on votes
  void reorderQueue(String eventId) {
    if (!_isConnected) return;
    _socket!.emit('reorder-queue', {'eventId': eventId});
    debugPrint('📤 Reorder queue for event: $eventId');
  }

  // ========== USER ROOM ==========

  /// Join user's personal notification room for invitations, etc.
  void joinUserRoom() {
    if (!_isConnected) return;
    _socket!.emit('join-user-room');
    debugPrint('📤 Joining user room for notifications');
  }

  /// Disconnect WebSocket
  void disconnect() {
    if (_socket != null) {
      _socket!.disconnect();
      _socket!.dispose();
      _socket = null;
      _isConnected = false;
      _currentEventId = null;
      _eventCallbacks.clear();
      debugPrint('🔌 WebSocket disconnected');
    }
  }

  /// Cleanup
  void dispose() {
    disconnect();
  }
}
