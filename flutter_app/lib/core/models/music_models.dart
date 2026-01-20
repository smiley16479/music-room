class Event {
  final String id;
  final String name;
  final String? description;
  final DateTime startTime;
  final DateTime endTime;
  final String location;
  final String creatorId;
  final List<String> participantIds;
  final String status;

  Event({
    required this.id,
    required this.name,
    this.description,
    required this.startTime,
    required this.endTime,
    required this.location,
    required this.creatorId,
    required this.participantIds,
    required this.status,
  });

  factory Event.fromJson(Map<String, dynamic> json) {
    return Event(
      id: json['id'] ?? '',
      name: json['name'] ?? '',
      description: json['description'],
      startTime: DateTime.parse(json['startTime'] ?? DateTime.now().toIso8601String()),
      endTime: DateTime.parse(json['endTime'] ?? DateTime.now().toIso8601String()),
      location: json['location'] ?? '',
      creatorId: json['creatorId'] ?? '',
      participantIds: List<String>.from(json['participantIds'] ?? []),
      status: json['status'] ?? 'active',
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'description': description,
      'startTime': startTime.toIso8601String(),
      'endTime': endTime.toIso8601String(),
      'location': location,
      'creatorId': creatorId,
      'participantIds': participantIds,
      'status': status,
    };
  }
}

class Playlist {
  final String id;
  final String name;
  final String? description;
  final String ownerId;
  final List<String> trackIds;
  final DateTime createdAt;
  final DateTime updatedAt;

  Playlist({
    required this.id,
    required this.name,
    this.description,
    required this.ownerId,
    required this.trackIds,
    required this.createdAt,
    required this.updatedAt,
  });

  factory Playlist.fromJson(Map<String, dynamic> json) {
    return Playlist(
      id: json['id'] ?? '',
      name: json['name'] ?? '',
      description: json['description'],
      ownerId: json['ownerId'] ?? '',
      trackIds: List<String>.from(json['trackIds'] ?? []),
      createdAt: DateTime.parse(json['createdAt'] ?? DateTime.now().toIso8601String()),
      updatedAt: DateTime.parse(json['updatedAt'] ?? DateTime.now().toIso8601String()),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'description': description,
      'ownerId': ownerId,
      'trackIds': trackIds,
      'createdAt': createdAt.toIso8601String(),
      'updatedAt': updatedAt.toIso8601String(),
    };
  }
}

class Device {
  final String id;
  final String name;
  final String type;
  final String ownerId;
  final String status;
  final String currentTrackId;
  final bool isActive;

  Device({
    required this.id,
    required this.name,
    required this.type,
    required this.ownerId,
    required this.status,
    required this.currentTrackId,
    required this.isActive,
  });

  factory Device.fromJson(Map<String, dynamic> json) {
    return Device(
      id: json['id'] ?? '',
      name: json['name'] ?? '',
      type: json['type'] ?? '',
      ownerId: json['ownerId'] ?? '',
      status: json['status'] ?? 'offline',
      currentTrackId: json['currentTrackId'] ?? '',
      isActive: json['isActive'] ?? false,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'type': type,
      'ownerId': ownerId,
      'status': status,
      'currentTrackId': currentTrackId,
      'isActive': isActive,
    };
  }
}
