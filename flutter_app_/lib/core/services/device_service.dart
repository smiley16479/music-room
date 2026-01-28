import 'package:flutter/material.dart';
import '../models/device.dart';
import 'api_service.dart';

class DeviceService {
  final ApiService apiService;

  DeviceService({required this.apiService});

  /// Get all devices of a user by their ID
  Future<List<Device>> getUserDevices(String userId) async {
    try {
      final response = await apiService.get('/devices?ownerId=$userId');
      debugPrint('Device response: $response');

      if (response['data'] is List) {
        return (response['data'] as List).map((deviceJson) {
          final device = deviceJson as Map<String, dynamic>;
          // Remove relation objects that Device model doesn't expect
          device.remove('stats');
          device.remove('owner');
          device.remove('delegatedTo');
          return Device.fromJson(device);
        }).toList();
      }
      return [];
    } catch (e) {
      debugPrint('Error fetching user devices: $e');
      return [];
    }
  }

  /// Delegate control of a device to a friend
  Future<Device?> delegateControl({
    required String deviceId,
    required String delegatedToId,
    Duration expiresIn = const Duration(hours: 24),
    Map<String, bool>? permissions,
  }) async {
    try {
      final expiresAt = DateTime.now().add(expiresIn).toIso8601String();

      // Build request body
      final body = <String, dynamic>{
        'delegatedToId': delegatedToId,
        'expiresAt': expiresAt,
      };

      // Add permissions if provided, otherwise backend uses defaults
      if (permissions != null && permissions.isNotEmpty) {
        body['permissions'] = {
          'canPlay': permissions['canPlay'] ?? true,
          'canPause': permissions['canPause'] ?? true,
          'canSkip': permissions['canSkip'] ?? true,
          'canChangeVolume': permissions['canChangeVolume'] ?? true,
          'canChangePlaylist': permissions['canChangePlaylist'] ?? false,
        };
      }

      final response = await apiService.post(
        '/devices/$deviceId/delegate',
        body: body,
      );

      if (response['data'] != null) {
        return Device.fromJson(response['data'] as Map<String, dynamic>);
      }
      return null;
    } catch (e) {
      debugPrint('Error delegating device control: $e');
      return null;
    }
  }

  /// Revoke device control delegation
  Future<Device?> revokeControl(String deviceId) async {
    try {
      final response = await apiService.post(
        '/devices/$deviceId/revoke',
        body: {},
      );

      if (response['data'] != null) {
        return Device.fromJson(response['data'] as Map<String, dynamic>);
      }
      return null;
    } catch (e) {
      debugPrint('Error revoking device control: $e');
      return null;
    }
  }

  /// Extend device control delegation
  Future<Device?> extendDelegation(String deviceId, int hours) async {
    try {
      final response = await apiService.post(
        '/devices/$deviceId/extend',
        body: {'hours': hours},
      );

      if (response['data'] != null) {
        return Device.fromJson(response['data'] as Map<String, dynamic>);
      }
      return null;
    } catch (e) {
      debugPrint('Error extending delegation: $e');
      return null;
    }
  }

  /// Get delegated devices (devices delegated to the current user)
  Future<List<Device>> getDelegatedDevices() async {
    try {
      final response = await apiService.get('/devices/delegated-to-me');
      if (response['data'] is List) {
        return (response['data'] as List)
            .map((device) => Device.fromJson(device as Map<String, dynamic>))
            .toList();
      }
      return [];
    } catch (e) {
      debugPrint('Error fetching delegated devices: $e');
      return [];
    }
  }
}
