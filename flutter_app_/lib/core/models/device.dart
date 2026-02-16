import 'package:equatable/equatable.dart';
import 'package:flutter/foundation.dart';
import 'package:json_annotation/json_annotation.dart';

part 'device.g.dart';

/// Device Type enum
enum DeviceType {
  @JsonValue('phone')
  phone,
  @JsonValue('tablet')
  tablet,
  @JsonValue('desktop')
  desktop,
  @JsonValue('smart_speaker')
  smartSpeaker,
  @JsonValue('tv')
  tv,
  @JsonValue('other')
  other,
}

/// Device Status enum
enum DeviceStatus {
  @JsonValue('online')
  online,
  @JsonValue('offline')
  offline,
  @JsonValue('playing')
  playing,
  @JsonValue('paused')
  paused,
}

/// Device model
@JsonSerializable()
class Device extends Equatable {
  final String id;
  final String name;
  final String? identifier;
  final DeviceType type;
  final DeviceStatus status;

  @JsonKey(name: 'device_info')
  final Map<String, dynamic>? deviceInfo;

  @JsonKey(name: 'last_seen')
  final DateTime lastSeen;

  @JsonKey(name: 'is_active')
  final bool isActive;

  @JsonKey(name: 'can_be_controlled')
  final bool canBeControlled;

  @JsonKey(name: 'delegation_expires_at')
  final DateTime? delegationExpiresAt;

  @JsonKey(name: 'delegation_permissions')
  final DelegationPermissions? delegationPermissions;

  @JsonKey(name: 'created_at')
  final DateTime createdAt;

  @JsonKey(name: 'updated_at')
  final DateTime updatedAt;

  @JsonKey(name: 'owner_id')
  final String ownerId;

  @JsonKey(name: 'delegated_to_id')
  final String? delegatedToId;

  const Device({
    required this.id,
    required this.name,
    this.identifier,
    required this.type,
    required this.status,
    this.deviceInfo,
    required this.lastSeen,
    required this.isActive,
    required this.canBeControlled,
    this.delegationExpiresAt,
    this.delegationPermissions,
    required this.createdAt,
    required this.updatedAt,
    required this.ownerId,
    this.delegatedToId,
  });

  /// Helper: Is this device currently delegated to someone?
  bool get isDelegated {
    if (delegatedToId == null || delegationExpiresAt == null) return false;
    return delegationExpiresAt!.isAfter(DateTime.now());
  }

  /// Helper: Time left in delegation (in seconds)
  int? get delegationTimeLeft {
    if (!isDelegated) return null;
    final diff = delegationExpiresAt!.difference(DateTime.now());
    return diff.inSeconds > 0 ? diff.inSeconds : 0;
  }

  /// Helper: Format delegation time left in human-readable format
  String get delegationTimeLeftFormatted {
    if (!isDelegated) return 'Expired';
    final timeLeft = delegationTimeLeft ?? 0;

    if (timeLeft < 60) return '$timeLeft seconds';
    if (timeLeft < 3600) return '${(timeLeft / 60).floor()} minutes';
    if (timeLeft < 86400) return '${(timeLeft / 3600).floor()} hours';
    return '${(timeLeft / 86400).floor()} days';
  }

  factory Device.fromJson(Map<String, dynamic> json) {
    try {
      // Safely parse DeviceType enum
      final typeString = json['type'] as String?;
      final DeviceType type = typeString == null
          ? DeviceType.other
          : DeviceType.values.firstWhere(
              (e) =>
                  e.name == typeString ||
                  (e.name == 'smartSpeaker' && typeString == 'smart_speaker'),
              orElse: () => DeviceType.other,
            );

      // Safely parse DeviceStatus enum
      final statusString = json['status'] as String?;
      final DeviceStatus status = statusString == null
          ? DeviceStatus.offline
          : DeviceStatus.values.firstWhere(
              (e) => e.name == statusString,
              orElse: () => DeviceStatus.offline,
            );

      return Device(
        id: json['id'] as String? ?? '',
        name: json['name'] as String? ?? '',
        identifier: json['identifier'] as String?,
        type: type,
        status: status,
        deviceInfo: json['deviceInfo'] as Map<String, dynamic>?,
        lastSeen: json['lastSeen'] != null
            ? DateTime.parse(json['lastSeen'] as String)
            : DateTime.now(),
        isActive: json['isActive'] as bool? ?? true,
        canBeControlled: json['canBeControlled'] as bool? ?? false,
        delegationExpiresAt: json['delegationExpiresAt'] != null
            ? DateTime.parse(json['delegationExpiresAt'] as String)
            : null,
        delegationPermissions: json['delegationPermissions'] != null
            ? DelegationPermissions.fromJson(
                json['delegationPermissions'] as Map<String, dynamic>,
              )
            : null,
        createdAt: json['createdAt'] != null
            ? DateTime.parse(json['createdAt'] as String)
            : DateTime.now(),
        updatedAt: json['updatedAt'] != null
            ? DateTime.parse(json['updatedAt'] as String)
            : DateTime.now(),
        ownerId: json['ownerId'] as String? ?? '',
        delegatedToId: json['delegatedToId'] as String?,
      );
    } catch (e) {
      debugPrint('Error parsing Device from JSON: $e');
      throw Exception('Failed to parse Device: $e');
    }
  }

  Map<String, dynamic> toJson() => _$DeviceToJson(this);

  @override
  List<Object?> get props => [
    id,
    name,
    identifier,
    type,
    status,
    deviceInfo,
    lastSeen,
    isActive,
    canBeControlled,
    delegationExpiresAt,
    delegationPermissions,
    createdAt,
    updatedAt,
    ownerId,
    delegatedToId,
  ];
}

/// Delegation Permissions model
@JsonSerializable()
class DelegationPermissions extends Equatable {
  @JsonKey(name: 'canPlay')
  final bool? canPlay;

  @JsonKey(name: 'canPause')
  final bool? canPause;

  @JsonKey(name: 'canSkip')
  final bool? canSkip;

  @JsonKey(name: 'canChangeVolume')
  final bool? canChangeVolume;

  @JsonKey(name: 'canChangePlaylist')
  final bool? canChangePlaylist;

  const DelegationPermissions({
    this.canPlay,
    this.canPause,
    this.canSkip,
    this.canChangeVolume,
    this.canChangePlaylist,
  });

  /// Get all permissions as a list for easier iteration
  List<MapEntry<String, bool>> asPermissionList() => [
    MapEntry('Play', canPlay ?? false),
    MapEntry('Pause', canPause ?? false),
    MapEntry('Skip', canSkip ?? false),
    MapEntry('Change Volume', canChangeVolume ?? false),
    MapEntry('Change Playlist', canChangePlaylist ?? false),
  ];

  factory DelegationPermissions.fromJson(Map<String, dynamic> json) {
    return DelegationPermissions(
      canPlay: json['canPlay'] as bool? ?? false,
      canPause: json['canPause'] as bool? ?? false,
      canSkip: json['canSkip'] as bool? ?? false,
      canChangeVolume: json['canChangeVolume'] as bool? ?? false,
      canChangePlaylist: json['canChangePlaylist'] as bool? ?? false,
    );
  }

  Map<String, dynamic> toJson() => _$DelegationPermissionsToJson(this);

  @override
  List<Object?> get props => [
    canPlay,
    canPause,
    canSkip,
    canChangeVolume,
    canChangePlaylist,
  ];
}
