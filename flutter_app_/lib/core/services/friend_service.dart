import '../models/index.dart';
import 'api_service.dart';

/// Friend Service - manages friend relationships and friend invitations
class FriendService {
  final ApiService apiService;

  FriendService({required this.apiService});

  // ==================== Friend Management ====================

  /// Get current user's friends list
  Future<List<User>> getFriends() async {
    final response = await apiService.get('/users/me/friends');
    final data = response['data'] as List? ?? response as List? ?? [];
    return data.map((u) => User.fromJson(u as Map<String, dynamic>)).toList();
  }

  /// Remove a friend
  Future<void> removeFriend(String friendId) async {
    await apiService.delete('/users/me/friends/$friendId');
  }

  // ==================== User Search ====================

  /// Search for users by query (displayName, email, etc.)
  Future<List<User>> searchUsers({
    required String query,
    int limit = 20,
    List<String>? genres,
  }) async {
    final queryParams = <String, String>{
      'q': query,  // Backend expects 'q' not 'query'
      'limit': limit.toString(),
    };
    if (genres != null && genres.isNotEmpty) {
      queryParams['genres'] = genres.join(',');
    }
    
    final queryString = queryParams.entries
        .map((e) => '${Uri.encodeComponent(e.key)}=${Uri.encodeComponent(e.value)}')
        .join('&');
    
    try {
      final response = await apiService.get('/users/search?$queryString');
      
      // Extract data list from response
      final data = response['data'] as List?;
      if (data == null) {
        return [];
      }
      
      final users = data.map((u) {
        try {
          return User.fromJson(u as Map<String, dynamic>);
        } catch (e) {
          rethrow;
        }
      }).toList();
      
      return users;
    } catch (e) {
      rethrow;
    }
  }

  /// Get a user's public profile (respects privacy settings)
  Future<User> getUserProfile(String userId) async {
    final response = await apiService.get('/users/$userId');
    final data = response['data'] as Map<String, dynamic>? ?? response as Map<String, dynamic>;
    return User.fromJson(data);
  }

  // ==================== Friend Invitations ====================

  /// Send a friend invitation
  Future<Invitation> sendFriendInvitation({
    required String inviteeId,
    String? message,
  }) async {
    final response = await apiService.post(
      '/invitations',
      body: {
        'inviteeId': inviteeId,
        'type': 'friend',
        if (message != null) 'message': message,
      },
    );
    final data = response['data'] as Map<String, dynamic>? ?? response as Map<String, dynamic>;
    return Invitation.fromJson(data);
  }

  /// Get received invitations (friend and event invitations)
  Future<List<Invitation>> getReceivedInvitations({
    String? status,
  }) async {
    // Get both friend and event invitations that have been received
    final friendUrl = '/invitations/received?type=friend${status != null ? '&status=$status' : ''}';
    final eventUrl = '/invitations/received?type=event${status != null ? '&status=$status' : ''}';
    
    try {
      final results = await Future.wait([
        apiService.get(friendUrl),
        apiService.get(eventUrl),
      ]);
      
      final friendInvitations = (results[0]['data'] as List? ?? results[0] as List? ?? [])
          .map((i) => Invitation.fromJson(i as Map<String, dynamic>))
          .toList();
      
      final eventInvitations = (results[1]['data'] as List? ?? results[1] as List? ?? [])
          .map((i) => Invitation.fromJson(i as Map<String, dynamic>))
          .toList();
      
      // Combine and sort by creation date (newest first)
      final combined = [...friendInvitations, ...eventInvitations];
      combined.sort((a, b) => b.createdAt.compareTo(a.createdAt));
      
      return combined;
    } catch (e) {
      // Fallback to friend invitations only if event fetch fails
      final response = await apiService.get('/invitations/received?type=friend${status != null ? '&status=$status' : ''}');
      final data = response['data'] as List? ?? response as List? ?? [];
      return data.map((i) => Invitation.fromJson(i as Map<String, dynamic>)).toList();
    }
  }

  /// Get sent friend invitations
  Future<List<Invitation>> getSentInvitations({
    String? status,
  }) async {
    String url = '/invitations/sent?type=friend';
    if (status != null) {
      url += '&status=$status';
    }
    
    final response = await apiService.get(url);
    final data = response['data'] as List? ?? response as List? ?? [];
    return data.map((i) => Invitation.fromJson(i as Map<String, dynamic>)).toList();
  }

  /// Accept a friend invitation
  Future<Invitation> acceptInvitation(String invitationId) async {
    try {
      final response = await apiService.post(
        '/invitations/$invitationId/accept',
        body: {}, // Send empty object instead of null
      );
      
      if (response == null) {
        throw Exception('Empty response from server');
      }
      
      final data = response['data'] as Map<String, dynamic>? ?? response as Map<String, dynamic>;
      return Invitation.fromJson(data);
    } catch (e) {
      rethrow;
    }
  }

  /// Decline a friend invitation
  Future<Invitation> declineInvitation(String invitationId) async {
    try {
      final response = await apiService.post(
        '/invitations/$invitationId/decline',
        body: {}, // Send empty object instead of null
      );
      
      if (response == null) {
        throw Exception('Empty response from server');
      }
      
      final data = response['data'] as Map<String, dynamic>? ?? response as Map<String, dynamic>;
      return Invitation.fromJson(data);
    } catch (e) {
      rethrow;
    }
  }

  /// Cancel a sent invitation
  Future<void> cancelInvitation(String invitationId) async {
    await apiService.delete('/invitations/$invitationId/cancel');
  }

  /// Get invitation statistics
  Future<Map<String, dynamic>> getInvitationStats() async {
    final response = await apiService.get('/invitations/stats');
    return response['data'] as Map<String, dynamic>? ?? response as Map<String, dynamic>;
  }
}
