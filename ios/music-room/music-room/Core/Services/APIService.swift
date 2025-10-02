import Foundation
import Combine

class APIService {
    static let shared = APIService()
    private init() {}
    
    // TODO: Replace with your actual backend URL
    private let baseURL = "http://localhost:3000/api"
    
    private var session: URLSession {
        let config = URLSessionConfiguration.default
        config.timeoutIntervalForRequest = 30
        config.timeoutIntervalForResource = 60
        return URLSession(configuration: config)
    }
    
    // MARK: - Authentication Endpoints
    func signUp(email: String, password: String, displayName: String) async throws -> AuthResponse {
        let endpoint = "/auth/register"
        let body: [String: Any] = [
            "email": email,
            "password": password,
            "displayName": displayName
        ]
        
        return try await performRequest(endpoint: endpoint, method: "POST", body: body)
    }
    
    func signIn(email: String, password: String) async throws -> AuthResponse {
        let endpoint = "/auth/login"
        let body: [String: Any] = [
            "email": email,
            "password": password
        ]
        print("body \(body)")
        return try await performRequest(endpoint: endpoint, method: "POST", body: body)
    }
    
    func forgotPassword(email: String) async throws {
        let endpoint = "/auth/forgot-password"
        let body: [String: Any] = ["email": email]
        
        let _: EmptyResponse = try await performRequest(endpoint: endpoint, method: "POST", body: body)
    }
    
    func signOut() async throws {
        let endpoint = "/auth/logout"
        let _: EmptyResponse = try await performAuthenticatedRequest(endpoint: endpoint, method: "POST")
    }
    
    func getCurrentUser() async throws -> User {
        let endpoint = "/auth/me"
        return try await performAuthenticatedRequest(endpoint: endpoint, method: "GET")
    }
    
    // MARK: - Social Account Linking
    func linkGoogleAccount(code: String, redirectUri: String) async throws -> User {
        let endpoint = "/auth/google/mobile-token"
        let body: [String: Any] = [
            "code": code,
            "redirectUri": redirectUri,
            "platform": "ios",
            "linkingMode": "link"
        ]
        
        print("🔗 Linking Google account with body: \(body)")
        
        let response: User = try await performAuthenticatedRequest(endpoint: endpoint, method: "POST", body: body)
        
        print("🔗 Link response user googleId: \(response.googleId ?? "nil")")
        
        return response
    }
    
    func linkFacebookAccount(token: String) async throws -> User {
        let endpoint = "/auth/facebook/mobile-login"
        let body: [String: Any] = [
            "access_token": token,
            "linkingMode": "link"
        ]
        let response: User = try await performAuthenticatedRequest(endpoint: endpoint, method: "POST", body: body)
        
        return response
    }
    
    func unlinkGoogleAccount() async throws {
        let endpoint = "/auth/unlink-google"
        let _: EmptyResponse = try await performAuthenticatedRequest(endpoint: endpoint, method: "POST")
    }
    
    func unlinkFacebookAccount() async throws {
        let endpoint = "/auth/unlink-facebook"
        let _: EmptyResponse = try await performAuthenticatedRequest(endpoint: endpoint, method: "POST")
    }
    
    // MARK: - User Endpoints
    func getUserProfile() async throws -> User {
        let endpoint = "/users/me"
        return try await performAuthenticatedRequest(endpoint: endpoint, method: "GET")
    }
    
    func updateProfile(_ updateData: [String: Any]) async throws -> User {
        let endpoint = "/users/me"
        return try await performAuthenticatedRequest(endpoint: endpoint, method: "PATCH", body: updateData)
    }

    func updateMusicPreferences(_ updateData: [String: Any]) async throws -> User {
        let endpoint = "/users/me/preferences"
        return try await performAuthenticatedRequest(endpoint: endpoint, method: "PATCH", body: updateData)
    }

    func updatePrivacySettings(_ privacySettings: [String: Any]) async throws -> User {
        let endpoint = "/users/me/privacy"
        return try await performAuthenticatedRequest(endpoint: endpoint, method: "PATCH", body: privacySettings)
    }

    func updatePassword(_ passwordData: [String: Any]) async throws -> EmptyResponse {
        let endpoint = "/users/me/password"
        return try await performAuthenticatedRequest(endpoint: endpoint, method: "PATCH", body: passwordData)
    }

    func searchUsers(query: String) async throws -> [User] {
        let endpoint = "/users/search?q=\(query.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? "")"
        return try await performAuthenticatedRequest(endpoint: endpoint, method: "GET")
    }

    func getUserFriends() async throws -> [User] {
      let endpoint = "/users/me/friends"
      return try await performAuthenticatedRequest(endpoint: endpoint, method: "GET")
    }
    
    // MARK: - Friendship Endpoints
    
    func removeFriend(friendId: String) async throws {
      let endpoint = "/users/me/friends/\(friendId)"
      let _: EmptyResponse = try await performAuthenticatedRequest(endpoint: endpoint, method: "DELETE")
    }
    
    // MARK: - Invitations
    func sendFriendRequest(inviteeId: String) async throws {
        let endpoint = "/invitations"
        let body: [String: Any] = [
            "inviteeId": inviteeId,
            "type": "friend"
        ]
        let _: EmptyResponse = try await performAuthenticatedRequest(endpoint: endpoint, method: "POST", body: body)
    }

    func getInvitations() async throws -> [Invitation] {
        let endpoint = "/invitations/received"
        return try await performAuthenticatedRequest(endpoint: endpoint, method: "GET")
    }
    
    func getMyRequestedInvitations() async throws -> [Invitation] {
        let endpoint = "/invitations/sent"
        return try await performAuthenticatedRequest(endpoint: endpoint, method: "GET")
    }

    func acceptInvitation(invitationId: String) async throws -> Invitation {
        let endpoint = "/invitations/\(invitationId)/respond"
        let body: [String: Any] = ["status": "accepted"]
        return try await performAuthenticatedRequest(endpoint: endpoint, method: "PATCH", body: body)
    }

    func declineInvitation(invitationId: String) async throws -> Invitation {
        let endpoint = "/invitations/\(invitationId)/respond"
        let body: [String: Any] = ["status": "declined"]
        return try await performAuthenticatedRequest(endpoint: endpoint, method: "PATCH", body: body)
    }
    
    // MARK: - Music Endpoints
    func searchMusic(query: String) async throws -> [Track] {
        let endpoint = "/music/search?q=\(query.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? "")"
        return try await performAuthenticatedRequest(endpoint: endpoint, method: "GET")
    }
    
    func getTopTracks() async throws -> [Track] {
        let endpoint = "/music/top"
        return try await performAuthenticatedRequest(endpoint: endpoint, method: "GET")
    }
    
    func getMusicGenres() async throws -> [String] {
        let endpoint = "/music/genres"
        return try await performAuthenticatedRequest(endpoint: endpoint, method: "GET")
    }
    
    // MARK: - Events Endpoints
    func getEvents() async throws -> [Event] {
        let endpoint = "/events"
        return try await performAuthenticatedRequest(endpoint: endpoint, method: "GET")
    }

    func getMyEvents() async throws -> [Event] {
        let endpoint = "/events/my-event"
        return try await performAuthenticatedRequest(endpoint: endpoint, method: "GET")
    }
    
    func getEvent(eventId: String) async throws -> Event {
        let endpoint = "/events/\(eventId)"
        return try await performAuthenticatedRequest(endpoint: endpoint, method: "GET")
    }

    /// Promote a user to admin for an event
    func promoteUserToAdmin(eventId: String, userId: String) async throws {
        let endpoint = "/events/" + eventId + "/admins/" + userId
        let _: EmptyResponse = try await performAuthenticatedRequest(endpoint: endpoint, method: "POST")
    }

    func removeAdminFromEvent(eventId: String, userId: String) async throws {
        let endpoint = "/events/\(eventId)/admins/\(userId)"
        let _: EmptyResponse = try await performAuthenticatedRequest(endpoint: endpoint, method: "DELETE")
    }
    
    func createEvent(_ eventData: [String: Any]) async throws -> Event {
        let endpoint = "/events"
        return try await performAuthenticatedRequest(endpoint: endpoint, method: "POST", body: eventData)
    }
    
    func deleteEvent(_ id: String) async throws {
        let endpoint = "/events/\(id)"
        let _: EmptyResponse = try await performAuthenticatedRequest(endpoint: endpoint, method: "DELETE")
    }
    
    func updateEvent(eventId: String, _ updateData: [String: Any]) async throws -> Event {
        let endpoint = "/events/\(eventId)"
        return try await performAuthenticatedRequest(endpoint: endpoint, method: "PATCH", body: updateData)
    }
    
    func inviteUserToEvent(eventId: String, userId: String, message: String? = nil) async throws {
        let endpoint = "/events/\(eventId)/invite"
        var body: [String: Any] = [
            "userIds": [userId]
        ]
        if let message = message {
            body["message"] = message
        }

        let _: EmptyResponse = try await performAuthenticatedRequest(endpoint: endpoint, method: "POST", body: body)
    }

    func inviteUsersToEvent(eventId: String, userIds: [String], message: String? = nil) async throws {
        let endpoint = "/events/\(eventId)/invite"
        var body: [String: Any] = [
            "userIds": userIds
        ]
        if let message = message {
            body["message"] = message
        }

        let _: EmptyResponse = try await performAuthenticatedRequest(endpoint: endpoint, method: "POST", body: body)
    }
    
    func removeUserFromEvent(id: String, userId: String) async throws {
        let endpoint = "/events/\(id)/participant/\(userId)"
        let _: EmptyResponse = try await performAuthenticatedRequest(endpoint: endpoint, method: "DELETE")
    }
    
    // MARK: - Playlists Endpoints
    func getPlaylists() async throws -> [Playlist] {
        let endpoint = "/playlists"
        return try await performAuthenticatedRequest(endpoint: endpoint, method: "GET")
    }
    
    func getPlaylistTracks(_ playlistId: String) async throws -> [PlaylistTrack] {
        let endpoint = "/playlists/\(playlistId)/tracks"
        return try await performAuthenticatedRequest(endpoint: endpoint, method: "GET")
    }
    
    func createPlaylist(_ playlistData: [String: Any]) async throws -> Playlist {
        let endpoint = "/playlists"
        return try await performAuthenticatedRequest(endpoint: endpoint, method: "POST", body: playlistData)
    }

    func updatePlaylist(_ playlistId: String, _ playlistData: [String: Any]) async throws -> Playlist {
        let endpoint = "/playlists/\(playlistId)"
        print("playlistData", playlistData)
        return try await performAuthenticatedRequest(endpoint: endpoint, method: "PATCH", body: playlistData)
    }

    func addMusicToPlaylist(_ playlistId: String, _ playlistData: [String: Any]) async throws -> PlaylistTrack {
        let endpoint = "/playlists/\(playlistId)/tracks"
        return try await performAuthenticatedRequest(endpoint: endpoint, method: "POST", body: playlistData)
    }
    
    func deletePlaylist(_ playlistId: String) async throws {
        let endpoint = "/playlists/\(playlistId)"
        let _: EmptyResponse = try await performAuthenticatedRequest(endpoint: endpoint, method: "DELETE")
    }

    func removeMusicFromPlaylist(_ playlistId: String, trackId: String) async throws {
        let endpoint = "/playlists/\(playlistId)/tracks/\(trackId)"
        let _: EmptyResponse = try await performAuthenticatedRequest(endpoint: endpoint, method: "DELETE")
    }
    
    // MARK: - Playlist Invitations
    func inviteUserToPlaylist(playlistId: String, userId: String, message: String? = nil) async throws {
        let endpoint = "/playlists/\(playlistId)/invite"
        var body: [String: Any] = [
            "userId": userId
        ]
        if let message = message {
            body["message"] = message
        }
        let _: EmptyResponse = try await performAuthenticatedRequest(endpoint: endpoint, method: "POST", body: body)
    }
    
    func getPlaylistInvitations() async throws -> [Invitation] {
        let endpoint = "/playlists/invitations/received"
        return try await performAuthenticatedRequest(endpoint: endpoint, method: "GET")
    }
    
    func acceptPlaylistInvitation(invitationId: String) async throws -> Invitation {
        let endpoint = "/playlists/invitations/\(invitationId)/accept"
        return try await performAuthenticatedRequest(endpoint: endpoint, method: "PATCH")
    }
    
    func declinePlaylistInvitation(invitationId: String) async throws -> Invitation {
        let endpoint = "/playlists/invitations/\(invitationId)/decline"
        return try await performAuthenticatedRequest(endpoint: endpoint, method: "PATCH")
    }
    
    // MARK: - Event Voting & Music Management
    func voteForTrack(eventId: String, trackId: String, voteType: String) async throws {
        let endpoint = "/events/\(eventId)/vote"
        let body: [String: Any] = [
            "trackId": trackId,
            "type": voteType // "like" ou "dislike"
        ]
        let _: EmptyResponse = try await performAuthenticatedRequest(endpoint: endpoint, method: "POST", body: body)
    }
    
    func removeVote(eventId: String, trackId: String) async throws {
        let endpoint = "/events/\(eventId)/vote/\(trackId)"
        let _: EmptyResponse = try await performAuthenticatedRequest(endpoint: endpoint, method: "DELETE")
    }
    
    func suggestTrack(eventId: String, trackData: SuggestedTrackData) async throws -> Track {
        let endpoint = "/events/\(eventId)/suggest-track"
        // Convertir SuggestedTrackData en [String: Any]
        let body: [String: Any] = [
            "title": trackData.title,
            "artist": trackData.artist,
            "album": trackData.album ?? "",
            "duration": trackData.duration,
            "albumCoverUrl": trackData.albumCoverUrl ?? "",
            "previewUrl": trackData.previewUrl ?? "",
            "deezerId": trackData.deezerId ?? ""
        ]
        
        return try await performAuthenticatedRequest(endpoint: endpoint, method: "POST", body: body)
    }
    
    func approveTrackSuggestion(eventId: String, suggestionId: String) async throws -> Track {
        let endpoint = "/events/\(eventId)/suggestions/\(suggestionId)/approve"
        return try await performAuthenticatedRequest(endpoint: endpoint, method: "POST")
    }
    
    func rejectTrackSuggestion(eventId: String, suggestionId: String) async throws {
        let endpoint = "/events/\(eventId)/suggestions/\(suggestionId)/reject"
        let _: EmptyResponse = try await performAuthenticatedRequest(endpoint: endpoint, method: "POST")
    }
    
    func getTrackSuggestions(eventId: String) async throws -> [TrackSuggestion] {
        let endpoint = "/events/\(eventId)/suggestions"
        return try await performAuthenticatedRequest(endpoint: endpoint, method: "GET")
    }
    
    func getEventPlaylist(eventId: String) async throws -> EventPlaylist {
        let endpoint = "/events/\(eventId)/playlist"
        return try await performAuthenticatedRequest(endpoint: endpoint, method: "GET")
    }
    
    func updateNowPlaying(eventId: String, trackId: String) async throws {
        let endpoint = "/events/\(eventId)/now-playing/\(trackId)"
        let body: [String: Any] = [
            "trackId": trackId
        ]
        /* return */let _: EmptyResponse = try await performAuthenticatedRequest(endpoint: endpoint, method: "PATCH", body: body)
    }
    
    func skipTrack(eventId: String) async throws -> NowPlayingResponse {
        let endpoint = "/events/\(eventId)/skip"
        return try await performAuthenticatedRequest(endpoint: endpoint, method: "POST")
    }
    
    func updatePlaybackState(eventId: String, isPlaying: Bool, position: Double? = nil) async throws -> PlaybackStateResponse {
        let endpoint = "/events/\(eventId)/playback"
        var body: [String: Any] = [
            "isPlaying": isPlaying
        ]
        if let position = position {
            body["position"] = position
        }
        return try await performAuthenticatedRequest(endpoint: endpoint, method: "PATCH", body: body)
    }
    
    func getEventVotes(eventId: String) async throws -> [VoteResult] {
        let endpoint = "/events/\(eventId)/votes"
        return try await performAuthenticatedRequest(endpoint: endpoint, method: "GET")
    }
    
    func joinEvent(eventId: String) async throws -> EventParticipation {
        let endpoint = "/events/\(eventId)/join"
        return try await performAuthenticatedRequest(endpoint: endpoint, method: "POST")
    }
    
    func leaveEvent(eventId: String) async throws {
        let endpoint = "/events/\(eventId)/leave"
        let _: EmptyResponse = try await performAuthenticatedRequest(endpoint: endpoint, method: "POST")
    }
    
    func getEventParticipants(eventId: String) async throws -> [User] {
        let endpoint = "/events/\(eventId)/participants"
        return try await performAuthenticatedRequest(endpoint: endpoint, method: "GET")
    }
    
    // MARK: - Event Chat
    func sendEventMessage(eventId: String, message: String) async throws -> EventMessage {
        let endpoint = "/events/\(eventId)/messages"
        let body: [String: Any] = [
            "content": message
        ]
        return try await performAuthenticatedRequest(endpoint: endpoint, method: "POST", body: body)
    }
    
    func getEventMessages(eventId: String, limit: Int = 50, offset: Int = 0) async throws -> [EventMessage] {
        let endpoint = "/events/\(eventId)/messages?limit=\(limit)&offset=\(offset)"
        return try await performAuthenticatedRequest(endpoint: endpoint, method: "GET")
    }
    
    // MARK: - Devices Endpoints
    func getDevices() async throws -> [Device] {
        let endpoint = "/devices/my-devices"
        return try await performAuthenticatedRequest(endpoint: endpoint, method: "GET")
    }
    
    func getDelegatedDevices() async throws -> [Device] {
        let endpoint = "/devices/delegated-to-me"
        return try await performAuthenticatedRequest(endpoint: endpoint, method: "GET")
    }
    
    func createDevice(_ deviceData: [String: Any]) async throws -> Device {
        let endpoint = "/devices"
        return try await performAuthenticatedRequest(endpoint: endpoint, method: "POST", body: deviceData)
    }

    func delegateDevice(_ deviceId: String, _ deviceData: [String: Any]) async throws -> Device {
        let endpoint = "/devices/\(deviceId)/delegate" // pas le bon endpoint
        return try await performAuthenticatedRequest(endpoint: endpoint, method: "POST", body: deviceData)
    }

    func revokeDeviceDelegation(_ deviceId: String) async throws -> Device {
        let endpoint = "/devices/\(deviceId)/revoke" // pas le bon endpoint
        return try await performAuthenticatedRequest(endpoint: endpoint, method: "POST")
    }
    
    // MARK: - Private Helper Methods
    private func performRequest<T: Codable>(
        endpoint: String,
        method: String,
        body: [String: Any]? = nil,
        headers: [String: String] = [:]
    ) async throws -> T {
        guard let url = URL(string: baseURL + endpoint) else {
            throw APIError.invalidURL
        }
        
        var request = URLRequest(url: url)
        request.httpMethod = method
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        
        // Add custom headers
        for (key, value) in headers {
            request.setValue(value, forHTTPHeaderField: key)
        }
        
        // Add body if provided
        if let body = body {
            do {
                request.httpBody = try JSONSerialization.data(withJSONObject: body)
            } catch {
                throw APIError.invalidRequestBody
            }
        }
        
        do {
            let (data, response) = try await session.data(for: request)
            
            // 🔍 LOGS DE DEBUG : //
            if DebugManager.shared.isDebugEnabled {
                if let jsonObject = try? JSONSerialization.jsonObject(with: data, options: []),
                  let prettyData = try? JSONSerialization.data(withJSONObject: jsonObject, options: [.prettyPrinted]),
                  let prettyString = String(data: prettyData, encoding: .utf8) {
                    print("✅ Response body:\n\(prettyString)")
                } else {
                    print("⚠️ Response body: No data")
                }
            }
            // 🔍 LOGS DE DEBUG : \\

            guard let httpResponse = response as? HTTPURLResponse else {
                throw APIError.invalidResponse
            }
            
            // Handle different status codes
            switch httpResponse.statusCode {
                case 200...299:

                // Décoder d'abord le wrapper
                let decoder = JSONDecoder()
                let apiResponse = try decoder.decode(APIResponse<T>.self, from: data)
                
                // Vérifier le succès et extraire data
                if apiResponse.success, let responseData = apiResponse.data {
                    print("✅ APIResponse contain data")
                    return responseData
                } else if T.self == EmptyResponse.self {
                    return EmptyResponse() as! T
                } else {
                    let errorMessage = apiResponse.message ?? apiResponse.error ?? "Unknown error"
                    print("❌ APIResponse don't contain data: \(errorMessage)")
                    throw APIError.serverError
                }

                case 400:
                    if let apiError = try? JSONDecoder().decode(APIResponse<T>.self, from: data) {
                        throw APIError.serverMessage(apiError.message ?? "")
                    } else if
                        let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
                        let message = json["message"] {
                        if let arr = message as? [String] {
                            throw APIError.serverMessage(arr.joined(separator: "\n"))
                        } else if let str = message as? String {
                            throw APIError.serverMessage(str)
                        }
                    }
                    throw APIError.unknownError(httpResponse.statusCode)
                case 401:
                    throw APIError.unauthorized
                case 403:
                    throw APIError.forbidden
                case 404:
                    throw APIError.notFound
                case 409:
                    throw APIError.conflict
                case 500...599:
                    throw APIError.serverError
                default:
                    throw APIError.unknownError(httpResponse.statusCode)
            }
            
        } catch {
            print("❌ Request error:", error)
            if error is APIError {
                throw error
            } else {
                throw APIError.networkError
            }
        }
    }
    
    private func performAuthenticatedRequest<T: Codable>(
        endpoint: String,
        method: String,
        body: [String: Any]? = nil
    ) async throws -> T {
        guard let token = KeychainService.shared.getAccessToken() else {
            throw APIError.unauthorized
        }
        
        let headers = ["Authorization": "Bearer \(token)"]
        print("Sending Request... \(endpoint)")
        let data: T = try await performRequest(endpoint: endpoint, method: method, body: body, headers: headers)
        return data

    }
}

// MARK: - API Error Types
enum APIError: LocalizedError {
    case invalidURL
    case invalidRequestBody
    case invalidResponse
    case unauthorized
    case forbidden
    case notFound
    case conflict
    case serverError
    case networkError
    case decodingFailed
    case unknownError(Int)
    case serverMessage(String)

    var errorDescription: String? {
        switch self {
        case .invalidURL:
            return "invalid_url_error".localized
        case .invalidRequestBody:
            return "invalid_request_error".localized
        case .invalidResponse:
            return "invalid_response_error".localized
        case .unauthorized:
            return "authentication_error".localized
        case .forbidden:
            return "permission_denied".localized
        case .notFound:
            return "not_found_error".localized
        case .conflict:
            return "conflict".localized
        case .serverError:
            return "server_error".localized
        case .networkError:
            return "network_error".localized
        case .decodingFailed:
            return "decoding_error".localized
        case .unknownError(let code):
            return "unknown_error".localized + " (\(code))"
        default:
            return String(describing: self)
        }
    }
}

// MARK: - Helper Types
struct EmptyResponse: Codable {
    init() {}
}


// MARK: - Api Response Struct
// MARK: - Wrapper générique pour les réponses API
struct APIResponse<T: Codable>: Codable {
    let success: Bool
    let message: String?
    let data: T?
    let timestamp: String?
    let error: String?
    let statusCode: Int?

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        success = try container.decodeIfPresent(Bool.self, forKey: .success) ?? false
        message = try container.decodeIfPresent(String.self, forKey: .message)
        data = try container.decodeIfPresent(T.self, forKey: .data)
        timestamp = try container.decodeIfPresent(String.self, forKey: .timestamp)
        error = try container.decodeIfPresent(String.self, forKey: .error)
        statusCode = try container.decodeIfPresent(Int.self, forKey: .statusCode)
    }
    
    private enum CodingKeys: String, CodingKey {
        case success, message, data, timestamp, error, statusCode
    }
}


// MARK: - Deezer API Service
class DeezerService: ObservableObject {
    @Published var searchResults: [DeezerTrack] = []
    @Published var isSearching: Bool = false
    @Published var searchError: String?
    
    private var cancellables = Set<AnyCancellable>()
    
    func searchTracks(query: String) {
        guard !query.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            searchResults = []
            return
        }
        
        isSearching = true
        searchError = nil
        
        // URL encode the query
        guard let encodedQuery = query.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) else {
            searchError = "Erreur d'encodage de la requête"
            isSearching = false
            return
        }
        
        // Deezer API endpoint (CORS proxy needed for web/iOS)
        // Note: En production, utilisez votre propre backend pour éviter les problèmes CORS
        let urlString = "https://api.deezer.com/search?q=\(encodedQuery)&limit=20"
        
        guard let url = URL(string: urlString) else {
            searchError = "URL invalide"
            isSearching = false
            return
        }
        
        URLSession.shared.dataTaskPublisher(for: url)
            .map(\.data)
            .decode(type: DeezerSearchResponse.self, decoder: JSONDecoder())
            .receive(on: DispatchQueue.main)
            .sink(
                receiveCompletion: { [weak self] completion in
                    self?.isSearching = false
                    if case .failure(let error) = completion {
                        self?.searchError = "Erreur de recherche: \(error.localizedDescription)"
                        // Utiliser des données mock en cas d'erreur (pour le développement)
                        self?.loadMockSearchResults(for: query)
                    }
                },
                receiveValue: { [weak self] response in
                    // MARK: - DEBUG DEEZER
                    // print("Deezer Search Results: \(response.data) tracks found")
                    self?.searchResults = response.data
                }
            )
            .store(in: &cancellables)
    }
    
    // Mock data pour le développement (en cas d'erreur API)
    private func loadMockSearchResults(for query: String) {
        searchResults = [
            DeezerTrack(
                id: 1,
                title: "Mock: \(query) - Song 1",
                duration: 200,
                preview: "https://example.com/preview1.mp3",
                artist: DeezerArtist(id: 1, name: "Artist 1"),
                album: DeezerAlbum(
                    id: 1,
                    title: "Album 1",
                    cover_small: "https://via.placeholder.com/56",
                    cover_medium: "https://via.placeholder.com/250",
                    cover_big: "https://via.placeholder.com/500"
                )
            ),
            DeezerTrack(
                id: 2,
                title: "Mock: \(query) - Song 2",
                duration: 180,
                preview: "https://example.com/preview2.mp3",
                artist: DeezerArtist(id: 2, name: "Artist 2"),
                album: DeezerAlbum(
                    id: 2,
                    title: "Album 2",
                    cover_small: "https://via.placeholder.com/56",
                    cover_medium: "https://via.placeholder.com/250",
                    cover_big: "https://via.placeholder.com/500"
                )
            )
        ]
    }
}
