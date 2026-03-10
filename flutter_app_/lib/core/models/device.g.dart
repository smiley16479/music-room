// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'device.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

Device _$DeviceFromJson(Map<String, dynamic> json) => Device(
  id: json['id'] as String,
  name: json['name'] as String,
  identifier: json['identifier'] as String?,
  type: $enumDecode(_$DeviceTypeEnumMap, json['type']),
  status: $enumDecode(_$DeviceStatusEnumMap, json['status']),
  deviceInfo: json['device_info'] as Map<String, dynamic>?,
  lastSeen: DateTime.parse(json['last_seen'] as String),
  isActive: json['is_active'] as bool,
  canBeControlled: json['can_be_controlled'] as bool,
  delegationExpiresAt: json['delegation_expires_at'] == null
      ? null
      : DateTime.parse(json['delegation_expires_at'] as String),
  delegationPermissions: json['delegation_permissions'] == null
      ? null
      : DelegationPermissions.fromJson(
          json['delegation_permissions'] as Map<String, dynamic>,
        ),
  createdAt: DateTime.parse(json['created_at'] as String),
  updatedAt: DateTime.parse(json['updated_at'] as String),
  ownerId: json['owner_id'] as String,
  delegatedToId: json['delegated_to_id'] as String?,
);

Map<String, dynamic> _$DeviceToJson(Device instance) => <String, dynamic>{
  'id': instance.id,
  'name': instance.name,
  'identifier': instance.identifier,
  'type': _$DeviceTypeEnumMap[instance.type]!,
  'status': _$DeviceStatusEnumMap[instance.status]!,
  'device_info': instance.deviceInfo,
  'last_seen': instance.lastSeen.toIso8601String(),
  'is_active': instance.isActive,
  'can_be_controlled': instance.canBeControlled,
  'delegation_expires_at': instance.delegationExpiresAt?.toIso8601String(),
  'delegation_permissions': instance.delegationPermissions,
  'created_at': instance.createdAt.toIso8601String(),
  'updated_at': instance.updatedAt.toIso8601String(),
  'owner_id': instance.ownerId,
  'delegated_to_id': instance.delegatedToId,
};

const _$DeviceTypeEnumMap = {
  DeviceType.phone: 'phone',
  DeviceType.tablet: 'tablet',
  DeviceType.desktop: 'desktop',
  DeviceType.smartSpeaker: 'smart_speaker',
  DeviceType.tv: 'tv',
  DeviceType.other: 'other',
};

const _$DeviceStatusEnumMap = {
  DeviceStatus.online: 'online',
  DeviceStatus.offline: 'offline',
  DeviceStatus.playing: 'playing',
  DeviceStatus.paused: 'paused',
};

DelegationPermissions _$DelegationPermissionsFromJson(
  Map<String, dynamic> json,
) => DelegationPermissions(
  canPlay: json['canPlay'] as bool?,
  canPause: json['canPause'] as bool?,
  canSkip: json['canSkip'] as bool?,
  canChangeVolume: json['canChangeVolume'] as bool?,
  canChangePlaylist: json['canChangePlaylist'] as bool?,
);

Map<String, dynamic> _$DelegationPermissionsToJson(
  DelegationPermissions instance,
) => <String, dynamic>{
  'canPlay': instance.canPlay,
  'canPause': instance.canPause,
  'canSkip': instance.canSkip,
  'canChangeVolume': instance.canChangeVolume,
  'canChangePlaylist': instance.canChangePlaylist,
};
