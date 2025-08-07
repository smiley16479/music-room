import SwiftUI

struct ForgotPasswordView: View {
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject private var authManager: AuthenticationManager
    
    @State private var email = ""
    @State private var showingAlert = false
    @State private var alertTitle = ""
    @State private var alertMessage = ""
    @State private var emailSent = false
    
    private var isEmailValid: Bool {
        !email.isEmpty && email.contains("@")
    }
    
    var body: some View {
        NavigationView {
            VStack(spacing: 32) {
                // Header
                VStack(spacing: 16) {
                    Image(systemName: "key")
                        .font(.system(size: 60))
                        .foregroundColor(.musicPrimary)
                    
                    Text("forgot_password".localized)
                        .font(.largeTitle)
                        .fontWeight(.bold)
                        .foregroundColor(.textPrimary)
                    
                    Text("Enter your email address and we'll send you a link to reset your password.")
                        .font(.subheadline)
                        .foregroundColor(.textSecondary)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 20)
                }
                
                if !emailSent {
                    VStack(spacing: 24) {
                        // Email Field
                        CustomTextField(
                            text: $email,
                            title: "email".localized,
                            placeholder: "Enter your email",
                            icon: "envelope",
                            keyboardType: .emailAddress
                        )
                        
                        // Send Reset Link Button
                        CustomButton(
                            title: "Send Reset Link",
                            action: sendResetLink,
                            isEnabled: isEmailValid,
                            isLoading: authManager.isLoading
                        )
                    }
                } else {
                    VStack(spacing: 20) {
                        Image(systemName: "envelope.circle.fill")
                            .font(.system(size: 80))
                            .foregroundColor(.green)
                        
                        VStack(spacing: 8) {
                            Text("Email Sent!")
                                .font(.title2)
                                .fontWeight(.bold)
                                .foregroundColor(.textPrimary)
                            
                            Text("Check your email for a link to reset your password.")
                                .font(.subheadline)
                                .foregroundColor(.textSecondary)
                                .multilineTextAlignment(.center)
                        }
                        
                        Button("Send Another Email") {
                            emailSent = false
                        }
                        .foregroundColor(.musicPrimary)
                    }
                }
                
                Spacer()
            }
            .padding(.horizontal, 32)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("cancel".localized) {
                        dismiss()
                    }
                }
            }
        }
        .alert(alertTitle, isPresented: $showingAlert) {
            Button("ok".localized) { }
        } message: {
            Text(alertMessage)
        }
    }
    
    private func sendResetLink() {
        Task {
            await authManager.forgotPassword(email: email)
            
            await MainActor.run {
                if authManager.errorMessage == nil {
                    emailSent = true
                } else {
                    alertTitle = "error".localized
                    alertMessage = authManager.errorMessage ?? "An error occurred"
                    showingAlert = true
                }
            }
        }
    }
}

#Preview {
    ForgotPasswordView()
        .environmentObject(AuthenticationManager())
}
