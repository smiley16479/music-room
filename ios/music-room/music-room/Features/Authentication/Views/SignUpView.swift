import SwiftUI

struct SignUpView: View {
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject private var authManager: AuthenticationManager
    
    @State private var email = ""
    @State private var password = ""
    @State private var confirmPassword = ""
    @State private var displayName = ""
    @State private var showPassword = false
    @State private var showConfirmPassword = false
    @State private var showingAlert = false
    @State private var alertMessage = ""
    
    private var isFormValid: Bool {
        !email.isEmpty &&
        !password.isEmpty &&
        !confirmPassword.isEmpty &&
        !displayName.isEmpty &&
        password == confirmPassword &&
        email.contains("@") &&
        password.count >= 6
    }
    
    var body: some View {
        NavigationView {
            ScrollView {
                VStack(spacing: 24) {
                    // Header
                    VStack(spacing: 8) {
                        Image(systemName: "music.note.list")
                            .font(.system(size: 60))
                            .foregroundColor(.musicPrimary)
                        
                        Text("sign_up".localized)
                            .font(.largeTitle)
                            .fontWeight(.bold)
                            .foregroundColor(.textPrimary)
                        
                        Text("Create your MusicRoom account")
                            .font(.subheadline)
                            .foregroundColor(.textSecondary)
                    }
                    .padding(.top, 20)
                    
                    // Form
                    VStack(spacing: 16) {
                        // Display Name Field
                        CustomTextField(
                            text: $displayName,
                            title: "display_name".localized,
                            placeholder: "Enter your display name",
                            icon: "person"
                        )
                        
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
                        
                        // Confirm Password Field
                        CustomSecureField(
                            text: $confirmPassword,
                            title: "confirm_password".localized,
                            placeholder: "Confirm your password",
                            showPassword: $showConfirmPassword
                        )
                        
                        // Password validation
                        if !password.isEmpty {
                            VStack(alignment: .leading, spacing: 4) {
                                PasswordValidationRow(
                                    text: "At least 6 characters",
                                    isValid: password.count >= 6
                                )
                                PasswordValidationRow(
                                    text: "Passwords match",
                                    isValid: password == confirmPassword && !confirmPassword.isEmpty
                                )
                            }
                            .padding(.horizontal, 16)
                        }
                    }
                    
                    // Sign Up Button
                    Button(action: signUp) {
                        HStack {
                            if authManager.isLoading {
                                ProgressView()
                                    .scaleEffect(0.8)
                                    .foregroundColor(.white)
                            } else {
                                Text("create_account".localized)
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
        .alert("Error", isPresented: $showingAlert) {
            Button("ok".localized) { }
        } message: {
            Text(alertMessage)
        }
        .onChange(of: authManager.errorMessage) {  olderrorMessage , errorMessage in
            if let errorMessage = errorMessage {
                alertMessage = errorMessage
                showingAlert = true
            }
        }
        .onChange(of: authManager.isAuthenticated) { oldIsAuthenticated, isAuthenticated in
            if isAuthenticated {
                dismiss()
            }
        }
    }
    
    private func signUp() {
        Task {
            await authManager.signUp(
                email: email,
                password: password,
                displayName: displayName
            )
        }
    }
}

#Preview {
    SignUpView()
        .environmentObject(AuthenticationManager())
        .environmentObject(ThemeManager())
}
