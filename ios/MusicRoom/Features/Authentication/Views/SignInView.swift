import SwiftUI

struct SignInView: View {
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject private var authManager: AuthenticationManager
    
    @State private var email = ""
    @State private var password = ""
    @State private var showPassword = false
    @State private var showingForgotPassword = false
    @State private var showingAlert = false
    @State private var alertMessage = ""
    
    private var isFormValid: Bool {
        !email.isEmpty &&
        !password.isEmpty &&
        email.contains("@")
    }
    
    var body: some View {
        NavigationView {
            ScrollView {
                VStack(spacing: 32) {
                    // Header
                    VStack(spacing: 8) {
                        Image(systemName: "music.note.list")
                            .font(.system(size: 60))
                            .foregroundColor(.musicPrimary)
                        
                        Text("sign_in".localized)
                            .font(.largeTitle)
                            .fontWeight(.bold)
                            .foregroundColor(.textPrimary)
                        
                        Text("Welcome back to MusicRoom")
                            .font(.subheadline)
                            .foregroundColor(.textSecondary)
                    }
                    .padding(.top, 20)
                    
                    // Form
                    VStack(spacing: 20) {
                        // Email Field
                        CustomTextField(
                            text: $email,
                            title: "email".localized,
                            placeholder: "Enter your email",
                            icon: "envelope",
                            keyboardType: .emailAddress
                        )
                        
                        // Password Field
                        CustomSecureField(
                            text: $password,
                            title: "password".localized,
                            placeholder: "Enter your password",
                            showPassword: $showPassword
                        )
                        
                        // Forgot Password
                        HStack {
                            Spacer()
                            Button("forgot_password".localized) {
                                showingForgotPassword = true
                            }
                            .font(.caption)
                            .foregroundColor(.musicPrimary)
                        }
                        .padding(.horizontal, 16)
                    }
                    
                    // Sign In Button
                    Button(action: signIn) {
                        HStack {
                            if authManager.isLoading {
                                ProgressView()
                                    .scaleEffect(0.8)
                                    .foregroundColor(.white)
                            } else {
                                Text("sign_in".localized)
                                    .fontWeight(.semibold)
                            }
                        }
                        .frame(maxWidth: .infinity)
                        .frame(height: 56)
                        .background(isFormValid ? Color.musicPrimary : Color.gray.opacity(0.3))
                        .foregroundColor(.white)
                        .cornerRadius(28)
                    }
                    .disabled(!isFormValid || authManager.isLoading)
                    
                    // Divider
                    HStack {
                        Rectangle()
                            .fill(Color.gray.opacity(0.3))
                            .frame(height: 1)
                        Text("or_continue_with".localized)
                            .font(.caption)
                            .foregroundColor(.textSecondary)
                            .padding(.horizontal, 16)
                        Rectangle()
                            .fill(Color.gray.opacity(0.3))
                            .frame(height: 1)
                    }
                    
                    // Social Login Buttons
                    VStack(spacing: 12) {
                        SocialLoginButton(
                            title: "google".localized,
                            icon: "globe",
                            color: .red
                        ) {
                            Task { await authManager.signInWithGoogle() }
                        }
                        
                        SocialLoginButton(
                            title: "facebook".localized,
                            icon: "f.cursive",
                            color: .blue
                        ) {
                            Task { await authManager.signInWithFacebook() }
                        }
                        
                        SocialLoginButton(
                            title: "deezer".localized,
                            icon: "music.note",
                            color: .orange
                        ) {
                            Task { await authManager.signInWithDeezer() }
                        }
                    }
                    
                    Spacer()
                }
                .padding(.horizontal, 32)
            }
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("cancel".localized) {
                        dismiss()
                    }
                }
            }
        }
        .sheet(isPresented: $showingForgotPassword) {
            ForgotPasswordView()
        }
        .alert("Error", isPresented: $showingAlert) {
            Button("ok".localized) { }
        } message: {
            Text(alertMessage)
        }
        .onChange(of: authManager.errorMessage) { errorMessage in
            if let errorMessage = errorMessage {
                alertMessage = errorMessage
                showingAlert = true
            }
        }
        .onChange(of: authManager.isAuthenticated) { isAuthenticated in
            if isAuthenticated {
                dismiss()
            }
        }
    }
    
    private func signIn() {
        Task {
            await authManager.signIn(email: email, password: password)
        }
    }
}

#Preview {
    SignInView()
        .environmentObject(AuthenticationManager())
        .environmentObject(ThemeManager())
}
