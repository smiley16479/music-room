import Foundation

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
    
    // MARK: - User Endpoints
    func updateProfile(_ updateData: [String: Any]) async throws -> User {
        let endpoint = "/users/me"
        return try await performAuthenticatedRequest(endpoint: endpoint, method: "PATCH", body: updateData)
    }
    
    func searchUsers(query: String) async throws -> [User] {
        let endpoint = "/users/search?q=\(query.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? "")"
        return try await performAuthenticatedRequest(endpoint: endpoint, method: "GET")
    }

    func searchUserFriends() async throws -> [User] {
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
    
    func createEvent(_ eventData: [String: Any]) async throws -> Event {
        let endpoint = "/events"
        return try await performAuthenticatedRequest(endpoint: endpoint, method: "POST", body: eventData)
    }
    
    // MARK: - Playlists Endpoints
    func getPlaylists() async throws -> [Playlist] {
        let endpoint = "/playlists"
        return try await performAuthenticatedRequest(endpoint: endpoint, method: "GET")
    }
    
    func createPlaylist(_ playlistData: [String: Any]) async throws -> Playlist {
        let endpoint = "/playlists"
        return try await performAuthenticatedRequest(endpoint: endpoint, method: "POST", body: playlistData)
    }
    
    // MARK: - Devices Endpoints
    func getDevices() async throws -> [Device] {
        let endpoint = "/devices/my-devices"
        return try await performAuthenticatedRequest(endpoint: endpoint, method: "GET")
    }
    
    func createDevice(_ deviceData: [String: Any]) async throws -> Device {
        let endpoint = "/devices"
        return try await performAuthenticatedRequest(endpoint: endpoint, method: "POST", body: deviceData)
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
            
            if let jsonObject = try? JSONSerialization.jsonObject(with: data, options: []),
               let prettyData = try? JSONSerialization.data(withJSONObject: jsonObject, options: [.prettyPrinted]),
               let prettyString = String(data: prettyData, encoding: .utf8) {
                print("✅ Response body:\n\(prettyString)")
            } else {
                print("⚠️ Response body: No data")
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

                if let dataValue = apiResponse.data {
                    print("✅ APIResponse decoder done")
                } else {
                    print("❌ APIResponse decoder failed")
                }
                
                // Vérifier le succès et extraire data
                if apiResponse.success, let responseData = apiResponse.data {
                    return responseData
                } else {
                    // Si pas de succès, utiliser le message d'erreur
                    let errorMessage = apiResponse.message ?? apiResponse.error ?? "Unknown error"
                    print("❌ API Error: \(errorMessage)")
                    throw APIError.serverError
                }

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
    
    // Pour gérer les cas où data pourrait être absent en cas d'erreur
    var isSuccess: Bool {
        return success && data != nil
    }
}
