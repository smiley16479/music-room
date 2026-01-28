import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:device_info_plus/device_info_plus.dart';
import 'package:uuid/uuid.dart';

import '../models/device.dart';
import 'api_service.dart';

/// Service for device identification and registration
class DeviceRegistrationService {
  static const String _deviceIdKey = 'device_uuid';
  static const String _deviceNameKey = 'device_name';

  final ApiService apiService;

  DeviceRegistrationService({required this.apiService});

  /// Get or generate device UUID
  Future<String> getDeviceId() async {
    final prefs = await SharedPreferences.getInstance();
    String? deviceId = prefs.getString(_deviceIdKey);

    if (deviceId == null) {
      // Generate new UUID for this device
      deviceId = const Uuid().v4();
      await prefs.setString(_deviceIdKey, deviceId);
      debugPrint('Generated new device UUID: $deviceId');
    }

    return deviceId;
  }

  /// Get stored device name
  Future<String?> getStoredDeviceName() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_deviceNameKey);
  }

  /// Store device name
  Future<void> storeDeviceName(String name) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_deviceNameKey, name);
  }

  /// Detect device type
  Future<DeviceType> detectDeviceType() async {
    try {
      final deviceInfo = DeviceInfoPlugin();

      // Try to get iOS info
      try {
        final iosInfo = await deviceInfo.iosInfo;
        final model = iosInfo.model.toLowerCase();

        if (model.contains('ipad')) {
          return DeviceType.tablet;
        } else if (model.contains('iphone')) {
          return DeviceType.phone;
        }
      } catch (_) {}

      // Try to get Android info
      try {
        final androidInfo = await deviceInfo.androidInfo;
        final model = androidInfo.model.toLowerCase();

        if (model.contains('tablet')) {
          return DeviceType.tablet;
        } else {
          return DeviceType.phone;
        }
      } catch (_) {}

      // Default to desktop/web
      return DeviceType.desktop;
    } catch (e) {
      debugPrint('Error detecting device type: $e');
      return DeviceType.desktop;
    }
  }

  /// Get platform name (iOS, Android, Linux, macOS, Windows)
  Future<String> getPlatformName() async {
    try {
      final deviceInfo = DeviceInfoPlugin();

      try {
        await deviceInfo.iosInfo;
        return 'iOS';
      } catch (_) {}

      try {
        await deviceInfo.androidInfo;
        return 'Android';
      } catch (_) {}

      // For web/other platforms
      return 'Unknown';
    } catch (e) {
      debugPrint('Error getting platform name: $e');
      return 'Unknown';
    }
  }

  /// Generate device name from detected info
  Future<String> generateDeviceName() async {
    try {
      final deviceInfo = DeviceInfoPlugin();

      try {
        final iosInfo = await deviceInfo.iosInfo;
        return iosInfo.model; // e.g., "iPhone 14 Pro"
      } catch (_) {}

      try {
        final androidInfo = await deviceInfo.androidInfo;
        return '${androidInfo.model}'; // e.g., "Pixel 6"
      } catch (_) {}

      return 'My Device';
    } catch (e) {
      debugPrint('Error generating device name: $e');
      return 'My Device';
    }
  }

  /// Register device on backend (create or update)
  /// Returns true if successful, false otherwise
  Future<bool> registerDevice() async {
    try {
      final deviceId = await getDeviceId();
      final deviceType = await detectDeviceType();
      final platformName = await getPlatformName();

      // Get stored name or generate new one
      String? deviceName = await getStoredDeviceName();
      if (deviceName == null) {
        deviceName = await generateDeviceName();
        await storeDeviceName(deviceName);
      }

      // Prepare request body
      final body = {
        'identifier': deviceId,
        'name': deviceName,
        'type': deviceType.name.toLowerCase(),
        'deviceInfo': {'platform': platformName},
      };

      debugPrint('Registering device: $body');

      // POST to backend
      final response = await apiService.post('/devices', body: body);

      if (response['success'] == true) {
        debugPrint('Device registered successfully');
        return true;
      }

      return false;
    } catch (e) {
      debugPrint('Error registering device: $e');
      return false;
    }
  }

  /// Clear device registration (on logout)
  Future<void> clearDeviceRegistration() async {
    final prefs = await SharedPreferences.getInstance();
    // Keep device UUID but clear other data if needed
    // Don't delete the UUID so same device is recognized on re-login
  }
}
