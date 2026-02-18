import 'package:flutter/material.dart';

import 'websocket_service.dart';

/// Global notification service to display WebSocket notifications
/// from anywhere in the app without needing BuildContext
class NotificationService {
  final WebSocketService webSocketService;
  final GlobalKey<ScaffoldMessengerState> scaffoldMessengerKey;
  
  bool _listenersSetup = false;

  NotificationService({
    required this.webSocketService,
    required this.scaffoldMessengerKey,
  });

  /// Initialize WebSocket listeners for notifications
  void initialize() {
    if (_listenersSetup) return;
    _listenersSetup = true;

    debugPrint('🔔 NotificationService: Setting up global listeners');

    // Device delegation notifications
    webSocketService.on('device-control-received', (data) {
      final delegatedByData = data['delegatedBy'];
      final delegatedByName = delegatedByData is Map 
          ? delegatedByData['displayName'] as String? ?? 'Unknown'
          : delegatedByData as String? ?? 'Unknown';
      
      _showNotification(
        message: '🎮 You received control of a device from $delegatedByName',
        backgroundColor: Colors.green,
        duration: const Duration(seconds: 5),
      );
    });

    webSocketService.on('device-control-revoked', (data) {
      final revokedByData = data['revokedBy'];
      final revokedByName = revokedByData is Map 
          ? revokedByData['displayName'] as String? ?? 'Unknown'
          : revokedByData as String? ?? 'System';
      
      _showNotification(
        message: '🚫 Your device control was revoked by $revokedByName',
        backgroundColor: Colors.orange,
        duration: const Duration(seconds: 4),
      );
    });

    // ⚠️ ICI
    // Add more WebSocket notification listeners here as needed
    // Example: event invitations, friend requests, etc.

    debugPrint('✅ NotificationService: Global listeners configured');
  }

  /// Show a notification using the global ScaffoldMessenger
  void _showNotification({
    required String message,
    Color? backgroundColor,
    Duration duration = const Duration(seconds: 3),
    SnackBarAction? action,
  }) {
    final messenger = scaffoldMessengerKey.currentState;
    if (messenger == null) {
      debugPrint('⚠️ NotificationService: ScaffoldMessenger not available');
      return;
    }

    messenger.showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: backgroundColor,
        duration: duration,
        action: action,
      ),
    );
  }

  /// Dispose and cleanup listeners
  void dispose() {
    if (!_listenersSetup) return;
    
    debugPrint('🔔 NotificationService: Cleaning up listeners');
    webSocketService.off('device-control-received');
    webSocketService.off('device-control-revoked');
    _listenersSetup = false;
  }
}
