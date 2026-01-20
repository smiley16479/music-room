import '../models/index.dart';
import 'api_service.dart';

/// Invitation Service - manages playlist invitations
class InvitationService {
  final ApiService apiService;

  InvitationService({required this.apiService});

  /// Get received invitations
  Future<List<Invitation>> getReceivedInvitations() async {
    final response = await apiService.get('/playlists/invitations/received');
    final data = response['data'] as List;
    return data
        .map((i) => Invitation.fromJson(i as Map<String, dynamic>))
        .toList();
  }

  /// Accept invitation
  Future<Invitation> acceptInvitation(String invitationId) async {
    final response = await apiService.patch(
      '/playlists/invitations/$invitationId/accept',
    );
    final data = response['data'] as Map<String, dynamic>;
    return Invitation.fromJson(data);
  }

  /// Decline invitation
  Future<Invitation> declineInvitation(String invitationId) async {
    final response = await apiService.patch(
      '/playlists/invitations/$invitationId/decline',
    );
    final data = response['data'] as Map<String, dynamic>;
    return Invitation.fromJson(data);
  }
}
