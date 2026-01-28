import 'package:flutter/material.dart';

import '../models/index.dart';
import '../services/index.dart';

/// Device Provider - manages user devices and delegation
class DeviceProvider extends ChangeNotifier {
  final DeviceService deviceService;

  List<Device> _devices = [];
  List<Device> _delegatedDevices = [];
  bool _isLoading = false;
  String? _error;

  DeviceProvider({required this.deviceService});

  // Getters
  List<Device> get devices => _devices;
  List<Device> get delegatedDevices => _delegatedDevices;
  bool get isLoading => _isLoading;
  String? get error => _error;

  /// Load user's own devices
  Future<void> loadMyDevices() async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      // Get current user's devices from /devices/my-devices endpoint
      final response = await deviceService.apiService.get(
        '/devices/my-devices',
      );
      if (response['data'] is List) {
        _devices = (response['data'] as List)
            .map((device) => Device.fromJson(device as Map<String, dynamic>))
            .toList();
      } else {
        _devices = [];
      }
      _error = null;
    } catch (e) {
      debugPrint('Error loading my devices: $e');
      _error = e.toString();
      _devices = [];
    }

    _isLoading = false;
    notifyListeners();
  }

  /// Load delegated devices (devices delegated to current user)
  Future<void> loadDelegatedDevices() async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      _delegatedDevices = await deviceService.getDelegatedDevices();
      _error = null;
    } catch (e) {
      debugPrint('Error loading delegated devices: $e');
      _error = e.toString();
      _delegatedDevices = [];
    }

    _isLoading = false;
    notifyListeners();
  }

  /// Refresh all devices
  Future<void> refreshAll() async {
    await Future.wait([loadMyDevices(), loadDelegatedDevices()]);
  }

  /// Delegate a device to a user
  Future<bool> delegateDevice({
    required String deviceId,
    required String delegatedToId,
    required Duration expiresIn,
    Map<String, bool>? permissions,
  }) async {
    try {
      final device = await deviceService.delegateControl(
        deviceId: deviceId,
        delegatedToId: delegatedToId,
        expiresIn: expiresIn,
        permissions: permissions,
      );

      if (device != null) {
        // Update device in local list
        final index = _devices.indexWhere((d) => d.id == deviceId);
        if (index != -1) {
          _devices[index] = device;
          notifyListeners();
        }
        return true;
      }
      return false;
    } catch (e) {
      debugPrint('Error delegating device: $e');
      _error = e.toString();
      notifyListeners();
      return false;
    }
  }

  /// Revoke device delegation
  Future<bool> revokeDevice(String deviceId) async {
    try {
      final device = await deviceService.revokeControl(deviceId);

      if (device != null) {
        final index = _devices.indexWhere((d) => d.id == deviceId);
        if (index != -1) {
          _devices[index] = device;
          notifyListeners();
        }
        return true;
      }
      return false;
    } catch (e) {
      debugPrint('Error revoking device: $e');
      _error = e.toString();
      notifyListeners();
      return false;
    }
  }

  /// Extend device delegation
  Future<bool> extendDevice(String deviceId, int hours) async {
    try {
      final device = await deviceService.extendDelegation(deviceId, hours);

      if (device != null) {
        final index = _devices.indexWhere((d) => d.id == deviceId);
        if (index != -1) {
          _devices[index] = device;
          notifyListeners();
        }
        return true;
      }
      return false;
    } catch (e) {
      debugPrint('Error extending delegation: $e');
      _error = e.toString();
      notifyListeners();
      return false;
    }
  }

  /// Clear all data (on logout)
  void clear() {
    _devices = [];
    _delegatedDevices = [];
    _isLoading = false;
    _error = null;
    notifyListeners();
  }
}
