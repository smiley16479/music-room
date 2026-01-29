import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:device_info_plus/device_info_plus.dart';
import 'package:uuid/uuid.dart';
import 'package:crypto/crypto.dart';
import 'dart:convert';

import '../models/device.dart';
import 'api_service.dart';

/// Service for device identification and registration
class DeviceRegistrationService {
  static const String _deviceIdKey = 'device_uuid';
  static const String _deviceNameKey = 'device_name';
  static const String _deviceFingerprintKey = 'device_fingerprint';

  final ApiService apiService;

  DeviceRegistrationService({required this.apiService});

  /// Generate a device fingerprint based on system characteristics
  /// More reliable than UUID for persistent identification
  Future<String> generateDeviceFingerprint() async {
    try {
      final deviceInfo = DeviceInfoPlugin();
      String fingerprintData = '';

      try {
        final iosInfo = await deviceInfo.iosInfo;
        fingerprintData = '${iosInfo.model}_${iosInfo.identifierForVendor}_${iosInfo.systemVersion}';
      } catch (_) {
        try {
          final androidInfo = await deviceInfo.androidInfo;
          fingerprintData = '${androidInfo.model}_${androidInfo.id}_${androidInfo.version.release}';
        } catch (_) {
          try {
            final windowsInfo = await deviceInfo.windowsInfo;
            fingerprintData = '${windowsInfo.computerName}_${windowsInfo.productId}_${windowsInfo.buildNumber}';
          } catch (_) {
            try {
              final macOsInfo = await deviceInfo.macOsInfo;
              fingerprintData = '${macOsInfo.model}_${macOsInfo.systemGUID}_${macOsInfo.osRelease}';
            } catch (_) {
              try {
                final linuxInfo = await deviceInfo.linuxInfo;
                fingerprintData = '${linuxInfo.id}_${linuxInfo.versionId}_${linuxInfo.machineId}';
              } catch (_) {
                fingerprintData = 'unknown_device';
              }
            }
          }
        }
      }

      // Create a hash from the fingerprint data
      final fingerprint = sha256.convert(utf8.encode(fingerprintData)).toString();
      debugPrint('Generated device fingerprint: $fingerprint');
      return fingerprint;
    } catch (e) {
      debugPrint('Error generating device fingerprint: $e');
      return 'unknown';
    }
  }

  /// Get or generate device UUID with fallback to fingerprint
  Future<String> getDeviceId() async {
    final prefs = await SharedPreferences.getInstance();
    
    // Try to get stored UUID first
    String? deviceId = prefs.getString(_deviceIdKey);
    if (deviceId != null) {
      debugPrint('Using stored device UUID: $deviceId');
      return deviceId;
    }

    // Fallback: use fingerprint (reliable across sessions)
    String? fingerprint = prefs.getString(_deviceFingerprintKey);
    if (fingerprint == null) {
      fingerprint = await generateDeviceFingerprint();
      try {
        await prefs.setString(_deviceFingerprintKey, fingerprint);
      } catch (e) {
        debugPrint('Warning: Could not store fingerprint (might be in private mode): $e');
      }
    }

    // If SharedPreferences is available, also store a UUID
    if (deviceId == null) {
      deviceId = const Uuid().v4();
      try {
        await prefs.setString(_deviceIdKey, deviceId);
      } catch (e) {
        debugPrint('Warning: Could not store UUID (might be in private mode): $e');
      }
    }

    debugPrint('Using device fingerprint as ID: $fingerprint');
    return fingerprint;
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
