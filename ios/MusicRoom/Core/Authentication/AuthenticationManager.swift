import SwiftUI
import Foundation
import Combine

@MainActor
class AuthenticationManager: ObservableObject {
    @Published var isAuthenticated = false
    @Published var currentUser: User?
    @Published var isLoading = false
    @Published var errorMessage: String?
    
    private let apiService = APIService.shared
    private let keychainService = KeychainService.shared
    private var cancellables = Set<AnyCancellable>()
    
    init() {
        checkAuthenticationStatus()
    }
    
    func checkAuthenticationStatus() {
        if let token = keychainService.getAccessToken() {
            // Verify token with backend
            Task {
                await verifyToken(token)
            }
        }
    }
    
    // MARK: - Email/Password Authentication
    func signUp(email: String, password: String, displayName: String) async {
        isLoading = true
        errorMessage = nil
        
        do {
            let response = try await apiService.signUp(
                email: email,
                password: password,
                displayName: displayName
            )
            
            await MainActor.run {
                self.handleAuthenticationSuccess(response)
            }
        } catch {
            await MainActor.run {
                self.errorMessage = error.localizedDescription
                self.isLoading = false
            }
        }
    }
    
    func signIn(email: String, password: String) async {
        isLoading = true
        errorMessage = nil
        
        do {
            let response = try await apiService.signIn(email: email, password: password)
            await MainActor.run {
                self.handleAuthenticationSuccess(response)
            }
        } catch {
            await MainActor.run {
                self.errorMessage = error.localizedDescription
                self.isLoading = false
            }
        }
    }
    
    // MARK: - Social Authentication
    func signInWithGoogle() async {
        isLoading = true
        errorMessage = nil
        
        // Implementation will be added when Google OAuth is configured
        await MainActor.run {
            self.errorMessage = "Google sign-in not yet configured"
            self.isLoading = false
        }
    }
    
    func signInWithFacebook() async {
        isLoading = true
        errorMessage = nil
        
        // Implementation will be added when Facebook OAuth is configured
        await MainActor.run {
            self.errorMessage = "Facebook sign-in not yet configured"
            self.isLoading = false
        }
    }
    
    func signInWithDeezer() async {
        isLoading = true
        errorMessage = nil
        
        // Implementation will be added when Deezer OAuth is configured
        await MainActor.run {
            self.errorMessage = "Deezer sign-in not yet configured"
            self.isLoading = false
        }
    }
    
    // MARK: - Account Management
    func linkGoogleAccount() async {
        // Implementation for linking Google account
    }
    
    func linkFacebookAccount() async {
        // Implementation for linking Facebook account
    }
    
    func linkDeezerAccount() async {
        // Implementation for linking Deezer account
    }
    
    func forgotPassword(email: String) async {
        isLoading = true
        errorMessage = nil
        
        do {
            try await apiService.forgotPassword(email: email)
            await MainActor.run {
                self.isLoading = false
                // Show success message
            }
        } catch {
            await MainActor.run {
                self.errorMessage = error.localizedDescription
                self.isLoading = false
            }
        }
    }
    
    func signOut() async {
        isLoading = true
        
        do {
            try await apiService.signOut()
        } catch {
            print("Sign out error: \\(error)")
        }
        
        await MainActor.run {
            self.keychainService.clearAllTokens()
            self.isAuthenticated = false
            self.currentUser = nil
            self.isLoading = false
        }
    }
    
    // MARK: - Private Methods
    private func verifyToken(_ token: String) async {
        do {
            let user = try await apiService.getCurrentUser()
            await MainActor.run {
                self.currentUser = user
                self.isAuthenticated = true
            }
        } catch {
            await MainActor.run {
                self.keychainService.clearAllTokens()
                self.isAuthenticated = false
            }
        }
    }
    
    private func handleAuthenticationSuccess(_ response: AuthResponse) {
        keychainService.saveAccessToken(response.accessToken)
        if let refreshToken = response.refreshToken {
            keychainService.saveRefreshToken(refreshToken)
        }
        
        currentUser = response.user
        isAuthenticated = true
        isLoading = false
    }
}

// MARK: - Data Models
struct AuthResponse: Codable {
    let accessToken: String
    let refreshToken: String?
    let user: User
}

struct User: Codable, Identifiable {
    let id: String
    let email: String
    let displayName: String
    let avatarUrl: String?
    let bio: String?
    let birthDate: String?
    let location: String?
    let emailVerified: Bool
    let musicPreferences: [String]?
    let createdAt: String
    let updatedAt: String
    
    // Privacy settings
    let displayNameVisibility: VisibilityLevel
    let bioVisibility: VisibilityLevel
    let birthDateVisibility: VisibilityLevel
    let locationVisibility: VisibilityLevel
}

enum VisibilityLevel: String, Codable, CaseIterable {
    case public = "public"
    case friendsOnly = "friends_only"
    case private = "private"
    
    var localizedString: String {
        switch self {
        case .public:
            return "public".localized
        case .friendsOnly:
            return "friends_only".localized
        case .private:
            return "private".localized
        }
    }
}
