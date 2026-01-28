import 'dart:async';

import 'package:flutter/material.dart';

import '../models/index.dart';
import '../services/friend_service.dart';

/// Friend Provider - manages friend relationships and invitations state
class FriendProvider extends ChangeNotifier {
  final FriendService friendService;

  List<User> _friends = [];
  List<User> _searchResults = [];
  List<Invitation> _receivedInvitations = [];
  List<Invitation> _sentInvitations = [];
  User? _selectedUserProfile;
  
  bool _isLoading = false;
  bool _isSearching = false;
  String? _error;

  // Debounce timer for search
  Timer? _searchDebounceTimer;
  static const Duration _searchDebounceDelay = Duration(milliseconds: 500);

  FriendProvider({required this.friendService});

  // Getters
  List<User> get friends => _friends;
  List<User> get searchResults => _searchResults;
  List<Invitation> get receivedInvitations => _receivedInvitations;
  List<Invitation> get sentInvitations => _sentInvitations;
  User? get selectedUserProfile => _selectedUserProfile;
  bool get isLoading => _isLoading;
  bool get isSearching => _isSearching;
  String? get error => _error;

  // Computed getters
  List<Invitation> get pendingReceivedInvitations =>
      _receivedInvitations.where((i) => i.isPending).toList();
  
  List<Invitation> get pendingSentInvitations =>
      _sentInvitations.where((i) => i.isPending).toList();

  // ==================== Friend Management ====================

  /// Load friends list
  Future<void> loadFriends() async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      _friends = await friendService.getFriends();
    } catch (e) {
      _error = e.toString();
    }

    _isLoading = false;
    notifyListeners();
  }

  /// Remove a friend
  Future<bool> removeFriend(String friendId) async {
    _error = null;
    
    try {
      await friendService.removeFriend(friendId);
      _friends.removeWhere((f) => f.id == friendId);
      notifyListeners();
      return true;
    } catch (e) {
      _error = e.toString();
      notifyListeners();
      return false;
    }
  }

  /// Check if a user is a friend
  bool isFriend(String userId) {
    return _friends.any((f) => f.id == userId);
  }

  // ==================== User Search ====================

  /// Search for users with debounce (500ms delay)
  void searchUsers(String query) {
    // Cancel previous debounce timer
    _searchDebounceTimer?.cancel();

    if (query.trim().isEmpty) {
      _searchResults = [];
      notifyListeners();
      return;
    }

    // Set a new debounce timer
    _searchDebounceTimer = Timer(_searchDebounceDelay, () async {
      await _performSearch(query);
    });
  }

  /// Actually perform the search (called after debounce)
  Future<void> _performSearch(String query) async {
    _isSearching = true;
    _error = null;
    notifyListeners();

    try {
      _searchResults = await friendService.searchUsers(query: query);
    } catch (e) {
      _error = e.toString();
      _searchResults = [];
    }

    _isSearching = false;
    notifyListeners();
  }

  /// Clear search results
  void clearSearch() {
    _searchResults = [];
    notifyListeners();
  }

  /// Load a user's profile
  Future<User?> loadUserProfile(String userId) async {
    _error = null;
    
    try {
      _selectedUserProfile = await friendService.getUserProfile(userId);
      notifyListeners();
      return _selectedUserProfile;
    } catch (e) {
      _error = e.toString();
      notifyListeners();
      return null;
    }
  }

  /// Clear selected user profile
  void clearSelectedProfile() {
    _selectedUserProfile = null;
    notifyListeners();
  }

  // ==================== Friend Invitations ====================

  /// Load all invitations (received and sent)
  Future<void> loadInvitations() async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      final results = await Future.wait([
        friendService.getReceivedInvitations(),
        friendService.getSentInvitations(),
      ]);
      _receivedInvitations = results[0];
      _sentInvitations = results[1];
    } catch (e) {
      _error = e.toString();
    }

    _isLoading = false;
    notifyListeners();
  }

  /// Load received invitations only
  Future<void> loadReceivedInvitations({String? status}) async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      _receivedInvitations = await friendService.getReceivedInvitations(status: status);
    } catch (e) {
      _error = e.toString();
    }

    _isLoading = false;
    notifyListeners();
  }

  /// Load sent invitations only
  Future<void> loadSentInvitations({String? status}) async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      _sentInvitations = await friendService.getSentInvitations(status: status);
    } catch (e) {
      _error = e.toString();
    }

    _isLoading = false;
    notifyListeners();
  }

  /// Send a friend invitation
  Future<bool> sendFriendInvitation({
    required String inviteeId,
    String? message,
  }) async {
    _error = null;

    try {
      final invitation = await friendService.sendFriendInvitation(
        inviteeId: inviteeId,
        message: message,
      );
      _sentInvitations.insert(0, invitation);
      notifyListeners();
      return true;
    } catch (e) {
      _error = e.toString();
      notifyListeners();
      return false;
    }
  }

  /// Accept a friend invitation
  Future<bool> acceptInvitation(String invitationId) async {
    _error = null;

    try {
      await friendService.acceptInvitation(invitationId);
      
      // Remove the invitation from the list (backend deletes it after accepting)
      final index = _receivedInvitations.indexWhere((i) => i.id == invitationId);
      if (index != -1) {
        final invitation = _receivedInvitations[index];
        _receivedInvitations.removeAt(index);
        
        // Add the inviter to friends list if available
        if (invitation.inviter != null) {
          _friends.add(invitation.inviter!);
        }
      }
      
      notifyListeners();
      return true;
    } catch (e) {
      _error = e.toString();
      notifyListeners();
      return false;
    }
  }

  /// Decline a friend invitation
  Future<bool> declineInvitation(String invitationId) async {
    _error = null;

    try {
      final updatedInvitation = await friendService.declineInvitation(invitationId);
      
      // Update the invitation in the list
      final index = _receivedInvitations.indexWhere((i) => i.id == invitationId);
      if (index != -1) {
        _receivedInvitations[index] = updatedInvitation;
      }
      
      notifyListeners();
      return true;
    } catch (e) {
      _error = e.toString();
      notifyListeners();
      return false;
    }
  }

  /// Cancel a sent invitation
  Future<bool> cancelInvitation(String invitationId) async {
    _error = null;

    try {
      await friendService.cancelInvitation(invitationId);
      _sentInvitations.removeWhere((i) => i.id == invitationId);
      notifyListeners();
      return true;
    } catch (e) {
      _error = e.toString();
      notifyListeners();
      return false;
    }
  }

  /// Check if an invitation has already been sent to a user
  bool hasPendingInvitationTo(String userId) {
    return _sentInvitations.any((i) => i.recipientId == userId && i.isPending);
  }

  /// Check if there's a pending invitation from a user
  bool hasPendingInvitationFrom(String userId) {
    return _receivedInvitations.any((i) => i.senderId == userId && i.isPending);
  }

  /// Refresh all data
  Future<void> refreshAll() async {
    await Future.wait([
      loadFriends(),
      loadInvitations(),
    ]);
  }

  @override
  void dispose() {
    _searchDebounceTimer?.cancel();
    super.dispose();
  }
}
