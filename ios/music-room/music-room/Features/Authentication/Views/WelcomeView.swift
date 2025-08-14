import SwiftUI

struct WelcomeView: View {
    @EnvironmentObject private var themeManager: ThemeManager
    @State private var showingSignIn = false
    @State private var showingSignUp = false
    
    var body: some View {
        GeometryReader { geometry in
            ZStack {
                // Background gradient
                LinearGradient(
                    gradient: Gradient(colors: [
                        Color.musicBackground.opacity(0.8),
                        Color.musicSecondary.opacity(0.6),
                        Color.musicPrimary.opacity(0.4)
                    ]),
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
                .ignoresSafeArea()
                
                VStack(spacing: 30) {
                    Spacer()
                    
                    // Musical SVG Icon
                    MusicNotesIcon()
                        .frame(width: 120, height: 120)
                        .foregroundColor(.musicPrimary)
                        .scaleEffect(1.0)
                        .animation(.easeInOut(duration: 2.0).repeatForever(autoreverses: true), value: UUID())
                    
                    VStack(spacing: 16) {
                        Text("welcome_title".localized)
                            .font(.largeTitle)
                            .fontWeight(.bold)
                            .foregroundColor(.textPrimary)
                            .multilineTextAlignment(.center)
                        
                        Text("welcome_subtitle".localized)
                            .font(.title3)
                            .foregroundColor(.textSecondary)
                            .multilineTextAlignment(.center)
                            .padding(.horizontal, 20)
                    }
                    
                    Spacer()
                    
                    VStack(spacing: 16) {
                        // Get Started Button
                        Button(action: {
                            showingSignUp = true
                        }) {
                            HStack {
                                Text("get_started".localized)
                                    .font(.headline)
                                    .foregroundColor(.white)
                                Image(systemName: "arrow.right")
                                    .foregroundColor(.white)
                            }
                            .frame(maxWidth: .infinity)
                            .frame(height: 56)
                            .background(
                                LinearGradient(
                                    gradient: Gradient(colors: [Color.musicPrimary, Color.musicSecondary]),
                                    startPoint: .leading,
                                    endPoint: .trailing
                                )
                            )
                            .cornerRadius(28)
                        }
                        
                        // Sign In Button
                        Button(action: {
                            showingSignIn = true
                        }) {
                            VStack(spacing: 4) {
                                Text("already_have_account".localized)
                                    .font(.caption)
                                    .foregroundColor(.textSecondary)
                                Text("sign_in".localized)
                                    .font(.headline)
                                    .foregroundColor(.musicPrimary)
                            }
                        }
                    }
                    .padding(.horizontal, 32)
                    .padding(.bottom, 50)
                }
            }
        }
        .sheet(isPresented: $showingSignUp) {
            SignUpView()
        }
        .sheet(isPresented: $showingSignIn) {
            SignInView()
        }
    }
}

// MARK: - Musical SVG Icon
struct MusicNotesIcon: View {
    @State private var animateNotes = false
    
    var body: some View {
        ZStack {
            // Background circle
            Circle()
                .fill(Color.musicBackground.opacity(0.3))
                .frame(width: 100, height: 100)
            
            // Musical notes
            VStack(spacing: -5) {
                HStack(spacing: 10) {
                    // First note
                    VStack(spacing: 0) {
                        Circle()
                            .fill(Color.musicPrimary)
                            .frame(width: 12, height: 8)
                            .rotationEffect(.degrees(-20))
                        
                        Rectangle()
                            .fill(Color.musicPrimary)
                            .frame(width: 2, height: 25)
                            .offset(x: 4)
                    }
                    .offset(y: animateNotes ? -3 : 3)
                    
                    // Second note
                    VStack(spacing: 0) {
                        Circle()
                            .fill(Color.musicSecondary)
                            .frame(width: 10, height: 7)
                            .rotationEffect(.degrees(-20))
                        
                        Rectangle()
                            .fill(Color.musicSecondary)
                            .frame(width: 2, height: 20)
                            .offset(x: 3)
                    }
                    .offset(y: animateNotes ? 3 : -3)
                    
                    // Third note
                    VStack(spacing: 0) {
                        Circle()
                            .fill(Color.musicPrimary.opacity(0.8))
                            .frame(width: 8, height: 6)
                            .rotationEffect(.degrees(-20))
                        
                        Rectangle()
                            .fill(Color.musicPrimary.opacity(0.8))
                            .frame(width: 1.5, height: 15)
                            .offset(x: 2.5)
                    }
                    .offset(y: animateNotes ? -2 : 2)
                }
                
                // Musical staff lines (simplified)
                VStack(spacing: 3) {
                    Rectangle()
                        .fill(Color.textSecondary.opacity(0.3))
                        .frame(height: 1)
                    Rectangle()
                        .fill(Color.textSecondary.opacity(0.3))
                        .frame(height: 1)
                    Rectangle()
                        .fill(Color.textSecondary.opacity(0.3))
                        .frame(height: 1)
                }
                .frame(width: 60)
                .offset(y: 10)
            }
        }
        .onAppear {
            withAnimation(.easeInOut(duration: 1.5).repeatForever(autoreverses: true)) {
                animateNotes.toggle()
            }
        }
    }
}

#Preview {
    WelcomeView()
        .environmentObject(ThemeManager())
        .environmentObject(LocalizationManager())
}
