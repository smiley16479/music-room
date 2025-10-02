import SwiftUI
import Foundation
import Combine
import AuthenticationServices
import FacebookLogin
import FacebookCore

extension AuthenticationManager: ASWebAuthenticationPresentationContextProviding {
    func presentationAnchor(for session: ASWebAuthenticationSession) -> ASPresentationAnchor {
        // Pour iOS 15+, on récupère la scène active, puis ses fenêtres, et on choisit la fenêtre clé
        return UIApplication.shared.connectedScenes
            .compactMap { $0 as? UIWindowScene }
            .first?
            .windows
            .first { $0.isKeyWindow } ?? ASPresentationAnchor()
    }
}

@MainActor
class AuthenticationManager:  NSObject, ObservableObject {
    @Published var isAuthenticated = false
    @Published var currentUser: User?
    @Published var isLoading = false
    @Published var errorMessage: String?
    
    private let apiService = APIService.shared
    private let keychainService = KeychainService.shared
    private var cancellables = Set<AnyCancellable>()
    
    private var currentWebAuthSession: ASWebAuthenticationSession?

    override init() {
        super.init()
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

        print("📝 Setting isLoading = true on MainActor")
        
        do {
            let response = try await apiService.signUp(
                email: email,
                password: password,
                displayName: displayName
            )

            print("✅ API call completed successfully")
            
            // Utilisez @MainActor uniquement pour les updates UI
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

// MARK: - Social Authentication Google  
    func signInWithGoogle() async {
        isLoading = true
        errorMessage = nil
        
        // IMPORTANT: Utilisez le client ID iOS, pas le web
        let clientId = AppConfig.googleClientId // Celui qui commence par "734605703797-..."
        
        // Pour iOS sans SDK, utilisez le redirect URI standard
        let redirectUri = "\(AppConfig.googleSchemaIOS)://"
        
        // Scopes standards
        let scope = "openid email profile"
        
        // Construction de l'URL d'autorisation
        var components = URLComponents(string: "https://accounts.google.com/o/oauth2/v2/auth")!
        components.queryItems = [
            URLQueryItem(name: "response_type", value: "code"),
            URLQueryItem(name: "client_id", value: clientId),
            URLQueryItem(name: "redirect_uri", value: redirectUri),
            URLQueryItem(name: "scope", value: scope),
            URLQueryItem(name: "access_type", value: "offline"), // Pour obtenir un refresh token
            URLQueryItem(name: "prompt", value: "select_account") // Force la sélection du compte
        ]
        
        guard let authURL = components.url else {
            errorMessage = "Invalid authentication URL"
            isLoading = false
            return
        }
        
        print("✅ Starting Google OAuth with URL: \(authURL)")
        
        currentWebAuthSession = ASWebAuthenticationSession(
            url: authURL,
            callbackURLScheme: AppConfig.googleSchemaIOS
        ) { callbackURL, error in
            DispatchQueue.main.async {
                self.isLoading = false
                
                if let error = error {
                    if error.localizedDescription.contains("cancelled") {
                        self.errorMessage = "Sign-in cancelled"
                    } else {
                        self.errorMessage = "Authentication error: \(error.localizedDescription)"
                    }
                    return
                }
                
                guard let callbackURL = callbackURL,
                      let components = URLComponents(string: callbackURL.absoluteString),
                      let queryItems = components.queryItems else {
                    self.errorMessage = "Invalid callback URL"
                    return
                }
                
                // Vérifier s'il y a une erreur dans la réponse
                if let error = queryItems.first(where: { $0.name == "error" })?.value {
                    self.errorMessage = "Authentication failed: \(error)"
                    return
                }
                
                // Récupérer le code d'autorisation
                guard let code = queryItems.first(where: { $0.name == "code" })?.value else {
                    self.errorMessage = "No authorization code received"
                    return
                }
                
                print("✅ Received authorization code: \(code)")
                
                // Échanger le code contre un token
                Task {
                    await self.exchangeGoogleCodeForToken(code: code)
                }
            }
        }
        
        currentWebAuthSession?.presentationContextProvider = self
        currentWebAuthSession?.prefersEphemeralWebBrowserSession = true
        
        if !currentWebAuthSession!.start() {
            isLoading = false
            errorMessage = "Failed to start authentication session"
        }
    }

    func exchangeGoogleCodeForToken(code: String, isLinking: Bool = false) async {
        guard let url = URL(string: "\(AppConfig.baseURL)/auth/google/mobile-token") else {
            await MainActor.run {
                self.errorMessage = "Invalid backend URL"
            }
            return
        }
        
        print("✅ Exchanging code with backend: \(url)")
        
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        
        // Envoyer le code ET le redirect_uri utilisé
        let body: [String: Any] = [
            "code": code,
            "redirectUri": "\(AppConfig.googleSchemaIOS)://",
            "platform": "ios"
        ]
        
        do {
            request.httpBody = try JSONSerialization.data(withJSONObject: body)
            
            let (data, response) = try await URLSession.shared.data(for: request)
            
            guard let httpResponse = response as? HTTPURLResponse else {
                await MainActor.run {
                    self.errorMessage = "Invalid server response"
                }
                return
            }
            
            print("📱 Server response status: \(httpResponse.statusCode)")
            
            
            if !(200...299).contains(httpResponse.statusCode) {
                if let errorData = try? JSONDecoder().decode([String: String].self, from: data),
                   let message = errorData["message"] {
                    await MainActor.run {
                        self.errorMessage = message
                    }
                } else if let errorString = String(data: data, encoding: .utf8) {
                      await MainActor.run {
                          self.errorMessage = "Server error (\(httpResponse.statusCode)): \(errorString)"
                      }
                } else {
                    await MainActor.run {
                        self.errorMessage = "Server error: \(httpResponse.statusCode)"
                    }
                }
                return
            }
            
            // Décoder la réponse du serveur
            let authResponse = try JSONDecoder().decode(AuthResponse.self, from: data)
            
            await MainActor.run {
                // Sauvegarder les tokens
                keychainService.saveAccessToken(authResponse.accessToken)
                keychainService.saveRefreshToken(authResponse.refreshToken!)

                // Mettre à jour l'état d'authentification
                self.isAuthenticated = true
                self.currentUser = authResponse.user
                self.errorMessage = nil
                
                print("✅ Authentication successful!")
            }
            
        } catch {
            await MainActor.run {
                self.errorMessage = "Failed to exchange code: \(error.localizedDescription)"
            }
        }
    }


    // MARK: - Social Authentication FB
    func signInWithFacebook() async {
        isLoading = true
        errorMessage = nil
        
        print("✅ signInWithFacebook")
        let loginManager = LoginManager()
        
        // Configuration pour SDK v23.0+ avec Limited Login
        let configuration = LoginConfiguration(
            permissions: ["public_profile", "email"],
            tracking: .enabled,
            nonce: UUID().uuidString
        )
        
        loginManager.logIn(configuration: configuration) { result in
            Task { @MainActor in
                // Dans SDK v23.0+, vérifier si l'utilisateur a annulé ou s'il y a des tokens
                switch result {
                case .cancelled:
                    self.errorMessage = "Facebook login was cancelled."
                    self.isLoading = false
                    return
                case .failed(let error):
                    self.errorMessage = "Facebook login failed: \(error.localizedDescription)"
                    self.isLoading = false
                    return
                case .success:
                    // Succès - vérifier les tokens disponibles
                    break
                }
                
                // Gestion du Limited Login (SDK v23.0+) - priorité à AuthenticationToken
                if let authenticationToken = AuthenticationToken.current {
                    print("✅ Using Limited Login with authentication token")
                    await self.exchangeFacebookAuthTokenForAppToken(authToken: authenticationToken.tokenString)
                } else if let accessToken = AccessToken.current {
                    print("✅ Using Classic Login with access token")
                    await self.exchangeFacebookTokenForAppToken(token: accessToken.tokenString)
                } else {
                    self.errorMessage = "No authentication token found after successful login"
                    self.isLoading = false
                }
            }
        }
    }
    
    
    
    // Nouvelle méthode pour gérer les AuthenticationToken (Limited Login)
    @MainActor
    func exchangeFacebookAuthTokenForAppToken(authToken: String) async {
        do {
            let endpoint = "\(AppConfig.baseURL)/auth/facebook/limited-login"
            print("✅ exchangeFacebookAuthTokenForAppToken \(endpoint)")
            
            var request = URLRequest(url: URL(string: endpoint)!)
            request.httpMethod = "POST"
            request.setValue("application/json", forHTTPHeaderField: "Content-Type")
            
            let body: [String: String] = ["authentication_token": authToken]
            request.httpBody = try JSONEncoder().encode(body)
            
            let (data, response) = try await URLSession.shared.data(for: request)
            
            guard let httpResponse = response as? HTTPURLResponse,
                  (200...299).contains(httpResponse.statusCode) else {
                throw NSError(domain: "AuthError", code: 1, userInfo: [NSLocalizedDescriptionKey: "Server error"])
            }
            
            let authResponse = try JSONDecoder().decode(AuthResponse.self, from: data)
            
            print("🔒 Facebook Limited Login successful")
            keychainService.saveAccessToken(authResponse.accessToken)
            if let refreshToken = authResponse.refreshToken {
                keychainService.saveRefreshToken(refreshToken)
            }
            
            self.currentUser = authResponse.user
            self.isAuthenticated = true
            self.isLoading = false
            
        } catch {
            self.errorMessage = "Failed to authenticate with Limited Login: \(error.localizedDescription)"
            self.isLoading = false
        }
    }

    @MainActor
    func exchangeFacebookTokenForAppToken(token: String, isLinking: Bool = false) async {
        // Appel API vers ton backend
        do {
            let endpoint = "\(AppConfig.baseURL)/auth/facebook/mobile-login"
            print("✅ exchangeFacebookTokenForAppToken \(endpoint) \(token)")
            
            var request = URLRequest(url: URL(string: endpoint)!)
            request.httpMethod = "POST"
            request.setValue("application/json", forHTTPHeaderField: "Content-Type")
            
            let body: [String: String] = ["access_token": token]
            request.httpBody = try JSONEncoder().encode(body)
            
            let (data, response) = try await URLSession.shared.data(for: request)
            
            // 🔍 LOGS DE DEBUG : //
            print("📊 Response type: \(type(of: response))")
            if let httpResponse = response as? HTTPURLResponse {
                print("📊 Status Code: \(httpResponse.statusCode)")
                print("📊 Headers: \(httpResponse.allHeaderFields)")
            } else {
                print("❌ Response is not HTTPURLResponse!")
            }

            print("📦 Response Data: \(String(data: data, encoding: .utf8) ?? "No data")")
            // 🔍 LOGS DE DEBUG : \\
            
            guard let httpResponse = response as? HTTPURLResponse,
                  (200...299).contains(httpResponse.statusCode) else {
                print("❌ Guard failed")
                throw NSError(domain: "AuthError", code: 1, userInfo: [NSLocalizedDescriptionKey: "Server error"])
            }
            
            do {
                let _ = try JSONDecoder().decode(AuthResponse.self, from: data)
            } catch let DecodingError.keyNotFound(key, context) {
                print("❌ Clé manquante: \(key.stringValue)")
                print("❌ Contexte: \(context)")
            } catch let DecodingError.typeMismatch(type, context) {
                print("❌ Type incorrect: attendu \(type)")
                print("❌ Contexte: \(context)")
            } catch let DecodingError.valueNotFound(type, _) { //<- _context
                print("❌ Valeur null inattendue pour: \(type)")
            } catch {
                print("❌ Autre erreur: \(error)")
            }
            // Stocke le token dans ton gestionnaire de session
            // Exemple : ton backend retourne un JSON { token: "jwt" }
            let tokenResponse = try JSONDecoder().decode(AuthResponse.self, from: data)
            
            print("🔒 tokenResponse : \(tokenResponse)")
            keychainService.saveAccessToken(tokenResponse.accessToken)
            
            self.isAuthenticated = true
            self.isLoading = false
        } catch {
            self.errorMessage = "Failed to authenticate: \(error.localizedDescription)"
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
    func linkGoogleAccount() async throws {
        isLoading = true
        errorMessage = nil
        
        // Use the same Google OAuth flow as sign-in but for linking
        let clientId = AppConfig.googleClientId
        let redirectUri = "\(AppConfig.googleSchemaIOS)://"
        let scope = "openid email profile"
        
        var components = URLComponents(string: "https://accounts.google.com/o/oauth2/v2/auth")!
        components.queryItems = [
            URLQueryItem(name: "response_type", value: "code"),
            URLQueryItem(name: "client_id", value: clientId),
            URLQueryItem(name: "redirect_uri", value: redirectUri),
            URLQueryItem(name: "scope", value: scope),
            URLQueryItem(name: "access_type", value: "offline"),
            URLQueryItem(name: "prompt", value: "select_account")
        ]
        
        guard let authURL = components.url else {
            await MainActor.run {
                self.errorMessage = "Invalid authentication URL"
                self.isLoading = false
            }
            throw APIError.invalidURL
        }
        
        // Start web authentication session
        await MainActor.run {
            self.currentWebAuthSession = ASWebAuthenticationSession(
                url: authURL,
                callbackURLScheme: AppConfig.googleSchemaIOS
            ) { [weak self] callbackURL, error in
                Task {
                    await self?.handleGoogleLinkCallback(callbackURL: callbackURL, error: error)
                }
            }
            self.currentWebAuthSession?.presentationContextProvider = self
            self.currentWebAuthSession?.start()
        }
    }
    
    func linkFacebookAccount() async throws {
        isLoading = true
        errorMessage = nil
        
        let loginManager = LoginManager()
        
        // Use the same configuration approach as signInWithFacebook
        let configuration = LoginConfiguration(
            permissions: ["public_profile", "email"],
            tracking: .enabled,
            nonce: UUID().uuidString
        )
        
        await withCheckedContinuation { continuation in
            loginManager.logIn(configuration: configuration) { result in
                Task { @MainActor in
                    self.isLoading = false
                    
                    // Use the same switch logic as signInWithFacebook
                    switch result {
                    case .cancelled:
                        self.errorMessage = "Facebook login was cancelled"
                    case .failed(let error):
                        self.errorMessage = "Facebook login failed: \(error.localizedDescription)"
                    case .success:
                        // Check for available tokens - same logic as signInWithFacebook
                        if let authenticationToken = AuthenticationToken.current {
                            await self.linkFacebookAccountWithToken(token: authenticationToken.tokenString)
                        } else if let accessToken = AccessToken.current {
                            await self.linkFacebookAccountWithToken(token: accessToken.tokenString)
                        } else {
                            self.errorMessage = "No access token received from Facebook"
                        }
                    @unknown default:
                        self.errorMessage = "Unknown Facebook login result"
                    }
                    
                    continuation.resume()
                }
            }
        }
    }
    
    func unlinkGoogleAccount() async throws {
        isLoading = true
        errorMessage = nil
        
        do {
            try await apiService.unlinkGoogleAccount()
            
            // Refresh user data to reflect changes
            let updatedUser = try await apiService.getCurrentUser()
            await MainActor.run {
                self.currentUser = updatedUser
                self.isLoading = false
            }
        } catch {
            await MainActor.run {
                self.errorMessage = error.localizedDescription
                self.isLoading = false
            }
            throw error
        }
    }
    
    func unlinkFacebookAccount() async throws {
        isLoading = true
        errorMessage = nil
        
        do {
            try await apiService.unlinkFacebookAccount()
            
            // Refresh user data to reflect changes
            let updatedUser = try await apiService.getCurrentUser()
            await MainActor.run {
                self.currentUser = updatedUser
                self.isLoading = false
            }
        } catch {
            await MainActor.run {
                self.errorMessage = error.localizedDescription
                self.isLoading = false
            }
            throw error
        }
    }
    
    func linkDeezerAccount() async {
        // Implementation for linking Deezer account
    }
    
    // MARK: - Account Linking Callbacks
    @MainActor
    private func handleGoogleLinkCallback(callbackURL: URL?, error: Error?) async {
        isLoading = false
        
        if let error = error {
            if error.localizedDescription.contains("cancelled") {
                self.errorMessage = "Linking cancelled"
            } else {
                self.errorMessage = "Authentication error: \(error.localizedDescription)"
            }
            return
        }
        
        guard let callbackURL = callbackURL,
              let components = URLComponents(string: callbackURL.absoluteString),
              let queryItems = components.queryItems else {
            self.errorMessage = "Invalid callback URL"
            return
        }
        
        if let error = queryItems.first(where: { $0.name == "error" })?.value {
            self.errorMessage = "Authentication failed: \(error)"
            return
        }
        
        guard let code = queryItems.first(where: { $0.name == "code" })?.value else {
            self.errorMessage = "No authorization code received"
            return
        }
        
        // Exchange code for linking (similar to sign-in but for linking)
        await linkGoogleAccountWithCode(code: code)
    }
    

    
    private func linkGoogleAccountWithCode(code: String) async {
        isLoading = true
        errorMessage = nil
        
        do {
            let redirectUri = "\(AppConfig.googleSchemaIOS)://"
            let updatedUser = try await apiService.linkGoogleAccount(code: code, redirectUri: redirectUri)
            
            print("🔗 Google account linked successfully!")
            print("🔗 Updated user googleId: \(updatedUser.googleId ?? "nil")")
            
            await MainActor.run {
                self.currentUser = updatedUser
                self.isLoading = false
            }
        } catch {
            print("❌ Failed to link Google account: \(error)")
            await MainActor.run {
                self.errorMessage = "Failed to link Google account: \(error.localizedDescription)"
                self.isLoading = false
            }
        }
    }
    
    private func linkFacebookAccountWithToken(token: String) async {
        isLoading = true
        errorMessage = nil
        
        do {
            let updatedUser = try await apiService.linkFacebookAccount(token: token)
            
            await MainActor.run {
                self.currentUser = updatedUser
                self.isLoading = false
            }
        } catch {
            await MainActor.run {
                self.errorMessage = "Failed to link Facebook account: \(error.localizedDescription)"
                self.isLoading = false
            }
        }
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
            print("Sign out error: \(error)")
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
