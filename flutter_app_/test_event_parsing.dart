import 'dart:convert';
import 'package:flutter_app/core/models/event.dart';
import 'package:flutter/foundation.dart' show debugPrint;

void main() {
  final responseJson = '''
{
  "success": true,
  "message": "Event created successfully",
  "data": {
    "id": "63843862-67cf-46c8-ad68-f9e370370959",
    "name": "Test",
    "description": null,
    "playlistName": null,
    "visibility": "public",
    "licenseType": "open",
    "status": "upcoming",
    "latitude": null,
    "longitude": null,
    "locationRadius": 1000,
    "locationName": null,
    "votingStartTime": null,
    "votingEndTime": null,
    "eventDate": "2026-02-01T10:00:00.000Z",
    "eventEndDate": null,
    "isPlaying": false,
    "currentPosition": "0.000",
    "lastPositionUpdate": null,
    "maxVotesPerUser": 1,
    "createdAt": "2026-01-21T16:19:02.188Z",
    "updatedAt": "2026-01-21T16:19:02.188Z",
    "creator": {
      "id": "ab898f29-7943-4ad8-9898-19c069049495",
      "email": "test@example.com",
      "displayName": null,
      "avatarUrl": "data:image/svg+xml;base64,..."
    },
    "creatorId": "ab898f29-7943-4ad8-9898-19c069049495",
    "currentTrack": null,
    "currentTrackId": null,
    "currentTrackStartedAt": null,
    "votes": [],
    "participants": [
      {
        "id": "ab898f29-7943-4ad8-9898-19c069049495",
        "email": "test@example.com",
        "displayName": null,
        "avatarUrl": "data:image/svg+xml;base64,..."
      }
    ],
    "admins": [],
    "playlist": null,
    "stats": {
      "participantCount": 1,
      "voteCount": 0,
      "trackCount": 0,
      "isUserParticipating": true
    }
  },
  "timestamp": "2026-01-21T16:19:02.206Z"
}
  ''';

  try {
    final jsonData = jsonDecode(responseJson) as Map<String, dynamic>;
    final eventData = jsonData['data'] as Map<String, dynamic>;
    final event = Event.fromJson(eventData);
    debugPrint('Event parsed successfully!');
    debugPrint('Event ID: ${event.id}');
    debugPrint('Event Name: ${event.name}');
    debugPrint('Event Visibility: ${event.visibility}');
    debugPrint('Event Status: ${event.status}');
    debugPrint('Event Votes: ${event.votes}');
    debugPrint('Event Participants: ${event.participants?.length}');
  } catch (e) {
    debugPrint('Error parsing event: $e');
  }
}
