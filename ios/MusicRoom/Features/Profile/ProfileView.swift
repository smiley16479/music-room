import SwiftUI

struct ProfileView: View {
    @EnvironmentObject private var authManager: AuthenticationManager
    @EnvironmentObject private var themeManager: ThemeManager
    @EnvironmentObject private var localizationManager: LocalizationManager
    
    @State private var showingEditProfile = false
    @State private var showingSettings = false
    @State private var showingSignOutAlert = false
    
    var body: some View {
        NavigationView {
            ScrollView {
                VStack(spacing: 24) {
                    // Profile Header
                    ProfileHeaderView()
                    
                    // Quick Stats
                    QuickStatsView()
                    
                    // Profile Sections
                    VStack(spacing: 16) {
                        ProfileSectionButton(
                            icon: "person.crop.circle",
                            title: "edit_profile".localized,
                            subtitle: "Manage your profile information",
                            action: {
                                showingEditProfile = true
                            }
                        )
                        
                        ProfileSectionButton(
                            icon: "heart.circle",
                            title: "music_preferences".localized,
                            subtitle: "Set your favorite genres and artists",
                            action: {
                                // Navigate to music preferences
                            }
                        )
                        
                        ProfileSectionButton(
                            icon: "person.2.circle",
                            title: "Friends",
                            subtitle: "Manage your friends and connections",
                            action: {
                                // Navigate to friends
                            }
                        )
                        
                        ProfileSectionButton(
                            icon: "bell.circle",
                            title: "notification_settings".localized,
                            subtitle: "Configure push and email notifications",
                            action: {
                                // Navigate to notification settings
                            }
                        )
                        
                        ProfileSectionButton(
                            icon: "gear.circle",
                            title: "app_settings".localized,
                            subtitle: "Language, theme, and app preferences",
                            action: {
                                showingSettings = true
                            }
                        )
                        
                        ProfileSectionButton(
                            icon: "questionmark.circle",
                            title: "Help & Support",
                            subtitle: "Get help and contact support",
                            action: {
                                // Navigate to help
                            }
                        )
                        
                        // Sign Out Button
                        Button(action: {
                            showingSignOutAlert = true
                        }) {
                            HStack {
                                Image(systemName: "rectangle.portrait.and.arrow.right")
                                    .foregroundColor(.red)
                                
                                Text("sign_out".localized)
                                    .fontWeight(.medium)
                                    .foregroundColor(.red)
                                
                                Spacer()
                            }
                            .padding()
                            .background(Color.cardBackground)
                            .cornerRadius(12)
                            .overlay(
                                RoundedRectangle(cornerRadius: 12)
                                    .stroke(Color.red.opacity(0.2), lineWidth: 1)
                            )
                        }
                    }
                    .padding(.horizontal, 20)
                    
                    Spacer()
                }
            }
            .navigationTitle("profile".localized)
            .navigationBarTitleDisplayMode(.large)
        }
        .sheet(isPresented: $showingEditProfile) {
            EditProfileView()
        }
        .sheet(isPresented: $showingSettings) {
            AppSettingsView()
        }
        .alert("Sign Out", isPresented: $showingSignOutAlert) {
            Button("cancel".localized, role: .cancel) { }
            Button("sign_out".localized, role: .destructive) {
                Task {
                    await authManager.signOut()
                }
            }
        } message: {
            Text("Are you sure you want to sign out?")
        }
    }
}

// MARK: - Profile Header
struct ProfileHeaderView: View {
    @EnvironmentObject private var authManager: AuthenticationManager
    
    var body: some View {
        VStack(spacing: 16) {
            // Profile Picture
            AsyncImage(url: URL(string: authManager.currentUser?.avatarUrl ?? "")) { image in
                image
                    .resizable()
                    .aspectRatio(contentMode: .fill)
            } placeholder: {
                Image(systemName: "person.circle.fill")
                    .font(.system(size: 80))
                    .foregroundColor(.musicSecondary)
            }
            .frame(width: 100, height: 100)
            .clipShape(Circle())
            .overlay(
                Circle()
                    .stroke(Color.musicPrimary, lineWidth: 3)
            )
            
            // User Info
            VStack(spacing: 8) {
                Text(authManager.currentUser?.displayName ?? "User")
                    .font(.title2)
                    .fontWeight(.bold)
                    .foregroundColor(.textPrimary)
                
                Text(authManager.currentUser?.email ?? "")
                    .font(.subheadline)
                    .foregroundColor(.textSecondary)
                
                if let bio = authManager.currentUser?.bio {
                    Text(bio)
                        .font(.caption)
                        .foregroundColor(.textSecondary)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 40)
                }
            }
        }
        .padding(.vertical, 20)
        .background(
            LinearGradient(
                gradient: Gradient(colors: [
                    Color.musicBackground.opacity(0.3),
                    Color.musicSecondary.opacity(0.1)
                ]),
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        )
        .cornerRadius(20)
        .padding(.horizontal, 20)
    }
}

// MARK: - Quick Stats
struct QuickStatsView: View {
    var body: some View {
        HStack(spacing: 20) {
            StatItemView(
                icon: "music.note.list",
                value: "12",
                label: "Playlists"
            )
            
            StatItemView(
                icon: "calendar.badge.checkmark",
                value: "5",
                label: "Events"
            )
            
            StatItemView(
                icon: "person.2.fill",
                value: "24",
                label: "Friends"
            )
        }
        .padding(.horizontal, 20)
    }
}

struct StatItemView: View {
    let icon: String
    let value: String
    let label: String
    
    var body: some View {
        VStack(spacing: 8) {
            Image(systemName: icon)
                .font(.system(size: 24))
                .foregroundColor(.musicPrimary)
            
            Text(value)
                .font(.title2)
                .fontWeight(.bold)
                .foregroundColor(.textPrimary)
            
            Text(label)
                .font(.caption)
                .foregroundColor(.textSecondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 16)
        .background(Color.cardBackground)
        .cornerRadius(12)
    }
}

// MARK: - Profile Section Button
struct ProfileSectionButton: View {
    let icon: String
    let title: String
    let subtitle: String
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            HStack(spacing: 16) {
                Image(systemName: icon)
                    .font(.system(size: 24))
                    .foregroundColor(.musicPrimary)
                    .frame(width: 30)
                
                VStack(alignment: .leading, spacing: 4) {
                    Text(title)
                        .font(.headline)
                        .foregroundColor(.textPrimary)
                    
                    Text(subtitle)
                        .font(.caption)
                        .foregroundColor(.textSecondary)
                        .multilineTextAlignment(.leading)
                }
                
                Spacer()
                
                Image(systemName: "chevron.right")
                    .font(.system(size: 14))
                    .foregroundColor(.textSecondary)
            }
            .padding()
            .background(Color.cardBackground)
            .cornerRadius(12)
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .stroke(Color.gray.opacity(0.1), lineWidth: 1)
            )
        }
    }
}

// MARK: - Edit Profile View (Placeholder)
struct EditProfileView: View {
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject private var authManager: AuthenticationManager
    
    @State private var displayName = ""
    @State private var bio = ""
    @State private var location = ""
    
    var body: some View {
        NavigationView {
            VStack {
                Text("Edit Profile")
                    .font(.title)
                Text("Profile editing form will be implemented here")
                    .foregroundColor(.textSecondary)
                
                // Form fields would go here
                CustomTextField(
                    text: $displayName,
                    title: "display_name".localized,
                    placeholder: "Enter display name",
                    icon: "person"
                )
                
                CustomTextField(
                    text: $bio,
                    title: "bio".localized,
                    placeholder: "Tell us about yourself",
                    icon: "text.alignleft"
                )
                
                CustomTextField(
                    text: $location,
                    title: "location".localized,
                    placeholder: "Your location",
                    icon: "location"
                )
                
                Spacer()
            }
            .padding()
            .navigationTitle("edit_profile".localized)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("cancel".localized) {
                        dismiss()
                    }
                }
                
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("save".localized) {
                        // Save profile changes
                        dismiss()
                    }
                    .foregroundColor(.musicPrimary)
                }
            }
        }
        .onAppear {
            displayName = authManager.currentUser?.displayName ?? ""
            bio = authManager.currentUser?.bio ?? ""
            location = authManager.currentUser?.location ?? ""
        }
    }
}

// MARK: - App Settings View
struct AppSettingsView: View {
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject private var themeManager: ThemeManager
    @EnvironmentObject private var localizationManager: LocalizationManager
    
    var body: some View {
        NavigationView {
            List {
                // Language Section
                Section("language".localized) {
                    ForEach(LocalizationManager.supportedLanguages, id: \\.self) { languageCode in
                        HStack {
                            Text(LocalizationManager.languageNames[languageCode] ?? languageCode)
                            
                            Spacer()
                            
                            if localizationManager.currentLanguage == languageCode {
                                Image(systemName: "checkmark")
                                    .foregroundColor(.musicPrimary)
                            }
                        }
                        .contentShape(Rectangle())
                        .onTapGesture {
                            localizationManager.setLanguage(languageCode)
                        }
                    }
                }
                
                // Appearance Section
                Section("Appearance") {
                    HStack {
                        Image(systemName: "moon.circle")
                            .foregroundColor(.musicPrimary)
                        
                        Text("dark_mode".localized)
                        
                        Spacer()
                        
                        Toggle("", isOn: $themeManager.isDarkMode)
                            .labelsHidden()
                    }
                }
                
                // Notifications Section
                Section("Notifications") {
                    NavigationLink(destination: NotificationSettingsView()) {
                        HStack {
                            Image(systemName: "bell.circle")
                                .foregroundColor(.musicPrimary)
                            
                            Text("notification_settings".localized)
                        }
                    }
                }
                
                // Privacy Section
                Section("Privacy") {
                    NavigationLink(destination: PrivacySettingsView()) {
                        HStack {
                            Image(systemName: "lock.circle")
                                .foregroundColor(.musicPrimary)
                            
                            Text("privacy_settings".localized)
                        }
                    }
                }
            }
            .navigationTitle("app_settings".localized)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("done".localized) {
                        dismiss()
                    }
                }
            }
        }
    }
}

// MARK: - Notification Settings View (Placeholder)
struct NotificationSettingsView: View {
    @State private var pushNotifications = true
    @State private var emailNotifications = true
    @State private var eventInvitations = true
    @State private var playlistUpdates = true
    @State private var friendRequests = true
    @State private var musicRecommendations = false
    
    var body: some View {
        List {
            Section("push_notifications".localized) {
                ToggleSettingRow(
                    title: "event_invitations".localized,
                    isOn: $eventInvitations
                )
                
                ToggleSettingRow(
                    title: "playlist_updates".localized,
                    isOn: $playlistUpdates
                )
                
                ToggleSettingRow(
                    title: "friend_requests".localized,
                    isOn: $friendRequests
                )
                
                ToggleSettingRow(
                    title: "music_recommendations".localized,
                    isOn: $musicRecommendations
                )
            }
            
            Section("email_notifications".localized) {
                ToggleSettingRow(
                    title: "Enable Email Notifications",
                    isOn: $emailNotifications
                )
            }
        }
        .navigationTitle("notification_settings".localized)
        .navigationBarTitleDisplayMode(.inline)
    }
}

// MARK: - Privacy Settings View (Placeholder)
struct PrivacySettingsView: View {
    var body: some View {
        List {
            Section("Profile Visibility") {
                NavigationLink("Display Name") {
                    Text("Display Name Privacy Settings")
                }
                
                NavigationLink("Bio") {
                    Text("Bio Privacy Settings")
                }
                
                NavigationLink("Location") {
                    Text("Location Privacy Settings")
                }
            }
        }
        .navigationTitle("privacy_settings".localized)
        .navigationBarTitleDisplayMode(.inline)
    }
}

// MARK: - Toggle Setting Row
struct ToggleSettingRow: View {
    let title: String
    @Binding var isOn: Bool
    
    var body: some View {
        HStack {
            Text(title)
            Spacer()
            Toggle("", isOn: $isOn)
                .labelsHidden()
        }
    }
}

#Preview {
    ProfileView()
        .environmentObject(ThemeManager())
        .environmentObject(LocalizationManager())
        .environmentObject(AuthenticationManager())
}
