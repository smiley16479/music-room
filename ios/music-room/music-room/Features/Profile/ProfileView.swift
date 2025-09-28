import SwiftUI

struct ProfileView: View {
    @EnvironmentObject private var authManager: AuthenticationManager
    @EnvironmentObject private var themeManager: ThemeManager
    @EnvironmentObject private var localizationManager: LocalizationManager
    
    @State private var showingEditProfile = false
    @State private var showingSettings = false
    @State private var showingMusicPreferences = false
    @State private var showingFriends = false
    @State private var showingHelp = false
    @State private var showingSignOutAlert = false
    @State private var userStats: UserStats? = nil
    
    var body: some View {
        NavigationView {
            ScrollView {
                VStack(spacing: 24) {
                    // Profile Header
                    ProfileHeaderView()
                    
                    // Quick Stats
                    QuickStatsView(stats: userStats)
                    
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
                                showingMusicPreferences = true
                            }
                        )
                        ProfileSectionButton(
                            icon: "person.2.circle",
                            title: "Friends",
                            subtitle: "Manage your friends and connections",
                            action: {
                                showingFriends = true
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
                                showingHelp = true
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
        }.task {
            do {
                let userProfil = try await APIService.shared.getUserProfile()
                await MainActor.run {
                    userStats = UserStats(
                        playlistsCount: userProfil.createdPlaylists?.count ?? 0,
                        eventsCount: userProfil.createdEvents?.count ?? 0,
                        friendsCount: userProfil.friends?.count ?? 0
                    )
                }
            } catch {
                print("Erreur chargement stats:", error)
            }
        }
        .sheet(isPresented: $showingEditProfile) {
            EditProfileView()
        }
        .sheet(isPresented: $showingSettings) {
            AppSettingsView()
        }
        .sheet(isPresented: $showingMusicPreferences) {
            MusicPreferencesView()
        }
        .sheet(isPresented: $showingFriends) {
            FriendsView(showingFriends: $showingFriends)
        }
        .sheet(isPresented: $showingHelp) {
            HelpSupportView()
        }.alert("Sign Out", isPresented: $showingSignOutAlert) {
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

// MARK: - Music Preferences 
struct MusicPreferencesView: View {
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject private var authManager: AuthenticationManager

    @State private var favoriteGenres: [String] = []
    @State private var favoriteArtists: String = ""
    @State private var isSaving = false
    @State private var errorMessage: String?
    @State private var showToast = false
    @State private var toastMessage = ""

    var body: some View {
        NavigationView {
            Form {
                Section(header: Text("Favorite Genres")) {
                    TextField("Add genres (comma separated)", text: Binding(
                        get: { favoriteGenres.joined(separator: ", ") },
                        set: { favoriteGenres = $0.components(separatedBy: ",").map { $0.trimmingCharacters(in: .whitespaces) } }
                    ))
                }
                Section(header: Text("Favorite Artists")) {
                    TextField("Add artists (comma separated)", text: $favoriteArtists)
                }
                if let error = errorMessage {
                    Text(error).foregroundColor(.red)
                }
            }
            .navigationTitle("music_preferences".localized)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("cancel".localized) { dismiss() }
                }
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("save".localized) {
                        Task { await savePreferences() }
                    }
                    .disabled(isSaving)
                }
            }
        }
        .toast(message: toastMessage, isShowing: $showToast, duration: 2.0)
        .onAppear {
            // Pré-remplir avec les préférences existantes
            if let prefs = authManager.currentUser?.musicPreferences {
                favoriteGenres = prefs.favoriteGenres ?? []
                favoriteArtists = prefs.favoriteArtists?.joined(separator: ", ") ?? ""
            }
        }
    }

    private func savePreferences() async {
        isSaving = true
        errorMessage = nil
        let genres = favoriteGenres.filter { !$0.isEmpty }
        let artists = favoriteArtists
            .components(separatedBy: ",")
            .map { $0.trimmingCharacters(in: .whitespaces) }
            .filter { !$0.isEmpty }

        let prefs: [String: Any] = [
            "favoriteGenres": genres,
            "favoriteArtists": artists
        ]
        do {
            let updatedUser = try await APIService.shared.updateMusicPreferences(prefs)
            await MainActor.run {
                authManager.currentUser = updatedUser
                toastMessage = "Preferences saved ✓"
                showToast = true
                dismiss()
            }
        } catch {
            await MainActor.run {
                errorMessage = error.localizedDescription
                toastMessage = "Error: \(error.localizedDescription)"
                showToast = true
            }
        }
        isSaving = false
    }
}
// MARK: - Friends
struct FriendsView: View {
    @Binding var showingFriends: Bool
    @Environment(\.dismiss) private var dismiss
    @State private var friends: [User] = []
    @State private var search: String = ""
    @State private var searchResults: [User] = []
    @State private var isSearching = false
    @State private var selectedFriend: User?
    @State private var showProfile = false
    @State private var isLoading = false
    @State private var errorMessage: String?

    @State private var showToast = false
    @State private var toastMessage = ""

    var body: some View {
        NavigationView {
            VStack {
                List {

                    SearchingFriendsView(
                      friends: $friends,
                      selectedFriend: $selectedFriend,
                      showProfile : $showProfile,
                      searchResults: $searchResults,
                      search: $search,
                      isSearching: $isSearching,
                      isLoading: $isLoading,
                      showToast: $showToast,
                      errorMessage: $errorMessage,
                      toastMessage: $toastMessage
                    )
                }
                .listStyle(InsetGroupedListStyle())
                .searchable(text: $search, prompt: "Search friends or users")
                .onChange(of: search) { old, newValue in
                    if newValue.isEmpty {
                        isSearching = false
                        searchResults = []
                    } else {
                        isSearching = true
                        searchUsers(query: newValue)
                    }
                }
                .sheet(isPresented: $showProfile) {
                    if let user = selectedFriend {
                        FriendProfileView(user: user, showingFriends: $showingFriends) { removedUser in
                            // Mise à jour locale de la liste friends
                            friends.removeAll { $0.id == removedUser.id }
                        }
                    }
                }
                if let error = errorMessage {
                    Text(error).foregroundColor(.red)
                }
                Spacer()
                Button("done".localized) { dismiss() }
                    .padding()
            }
            .navigationTitle("Friends")
            .navigationBarTitleDisplayMode(.inline)
            .onAppear {
                loadFriends()
            }
        }.toast(message: toastMessage, isShowing: $showToast, duration: 2.0)
    }

    private func loadFriends() {
        isLoading = true
        errorMessage = nil
        Task {
            do {
                friends = try await APIService.shared.getUserFriends()
            } catch {
                errorMessage = error.localizedDescription
            }
            isLoading = false
        }
    }

    private func searchUsers(query: String) {
        isLoading = true
        errorMessage = nil
        Task {
            do {
                let users = try await APIService.shared.searchUsers(query: query)
                // Exclure les amis déjà ajoutés
                let friendIds = Set(friends.map { $0.id })
                searchResults = users.filter { !friendIds.contains($0.id) }
            } catch {
                errorMessage = error.localizedDescription
            }
            isLoading = false
        }
    }
}

// MARK: - Searching Friends
struct SearchingFriendsView: View {
    @Binding var friends: [User]
    @Binding var selectedFriend: User?
    @Binding var showProfile: Bool
    @Binding var searchResults: [User]
    @Binding var search: String 
    @Binding var isSearching: Bool
    @Binding var isLoading: Bool
    @Binding var showToast: Bool
    @Binding var errorMessage: String?
    @Binding var toastMessage: String
    
    var body: some View {
        
        Section(header: Text("Your Friends")) {
            if friends.isEmpty {
                Text("No friends yet.").foregroundColor(.secondary)
            } else {
                ForEach(friends.filter { search.isEmpty ? true : $0.displayName.localizedCaseInsensitiveContains(search) }, id: \.id) { friend in
                    Button(action: {
                        selectedFriend = friend
                        showProfile = true
                    }) {
                        HStack {
                            if let url = friend.avatarUrl, let imageUrl = URL(string: url) {
                                AsyncImage(url: imageUrl) { img in
                                    img.resizable().aspectRatio(contentMode: .fill)
                                } placeholder: {
                                    Image(systemName: "person.crop.circle").foregroundColor(.gray)
                                }
                                .frame(width: 40, height: 40)
                                .clipShape(Circle())
                            } else {
                                Image(systemName: "person.crop.circle").foregroundColor(.gray)
                                    .frame(width: 40, height: 40)
                            }
                            Text(friend.displayName)
                                .font(.body)
                            Spacer()
                        }
                    }
                }
            }
        }
        if isSearching {
            Section(header: Text("Find new friends")) {
                if isLoading {
                    ProgressView()
                } else if !searchResults.isEmpty {
                    ForEach(searchResults, id: \.id) { user in
                        HStack {
                            if let url = user.avatarUrl, let imageUrl = URL(string: url) {
                                AsyncImage(url: imageUrl) { img in
                                    img.resizable().aspectRatio(contentMode: .fill)
                                } placeholder: {
                                    Image(systemName: "person.crop.circle").foregroundColor(.gray)
                                }
                                .frame(width: 40, height: 40)
                                .clipShape(Circle())
                            } else {
                                Image(systemName: "person.crop.circle").foregroundColor(.gray)
                                    .frame(width: 40, height: 40)
                            }
                            VStack(alignment: .leading) {
                                Text(user.displayName).font(.body)
                                if let email = user.email {
                                    Text(email).font(.caption).foregroundColor(.secondary)
                                }
                            }
                            Spacer()
                            Button("Add") {
                                Task {
                                    do {
                                        try await APIService.shared.sendFriendRequest(inviteeId: user.id)
                                        // Optionnel : feedback visuel
                                        await MainActor.run {
                                            toastMessage = "Invitation envoyée ✓"
                                            errorMessage = nil
                                            showToast = true
                                        }
                                    } catch {
                                        errorMessage = error.localizedDescription
                                        await MainActor.run {
                                            toastMessage = "Erreur : \(error.localizedDescription)"
                                            showToast = true
                                        }
                                    }
                                }
                            }
                            .buttonStyle(.borderedProminent)
                        }
                    }
                } else {
                    Text("No users found.").foregroundColor(.secondary)
                }
            }
        }
    }
}

// MARK: - Friend Profile
struct FriendProfileView: View {
    let user: User
    @Binding var showingFriends: Bool
    var onFriendRemoved: ((User) -> Void)? = nil
    @Environment(\.dismiss) private var dismiss
    @State private var showInviteToEvent = false
    @State private var showInviteToPlaylist = false
    @EnvironmentObject var tabManager: MainTabManager
    @State private var showCancelAlert = false
    @State private var errorMessage: String?

    var body: some View {
        NavigationView {
            ScrollView {
                VStack(spacing: 20) {
                    if let url = user.avatarUrl, let imageUrl = URL(string: url) {
                        AsyncImage(url: imageUrl) { img in
                            img.resizable().aspectRatio(contentMode: .fill)
                        } placeholder: {
                            Image(systemName: "person.crop.circle").foregroundColor(.gray)
                        }
                        .frame(width: 100, height: 100)
                        .clipShape(Circle())
                    } else {
                        Image(systemName: "person.crop.circle").foregroundColor(.gray)
                            .frame(width: 100, height: 100)
                    }
                    // Champs selon visibilité ⚠️ à ajuster ne fonctionne pas encore
                    if user.displayNameVisibility != .private {
                        Text(user.displayName).font(.title2).fontWeight(.bold)
                    }
                    if user.bioVisibility != .private, let bio = user.bio {
                        Text(bio).font(.body).foregroundColor(.secondary)
                    }
                    if user.birthDateVisibility != .private, let birth = user.birthDate {
                        Text("Birth: \(birth)").font(.caption)
                    }
                    if user.locationVisibility != .private, let loc = user.location {
                        Text("Location: \(loc)").font(.caption)
                    }
                    if let prefs = user.musicPreferences?.favoriteGenres, !prefs.isEmpty {
                        VStack(alignment: .leading) {
                            Text("Music Preferences:").font(.caption).bold()
                            Text(prefs.joined(separator: ", "))
                        }
                    }
                    if let lastSeen = user.lastSeen {
                        Text("Last seen: \(lastSeen)").font(.caption).foregroundColor(.secondary)
                    }
                    HStack(spacing: 16) {
                        Button("Invite to Event") {
                            showInviteToEvent = true
                        }
                        .buttonStyle(.borderedProminent)
                        Button("Invite to Playlist") {
                            showInviteToPlaylist = true
                        }
                        .buttonStyle(.bordered)
                        Button("Cancel this friendship") {
                            showCancelAlert = true
                        }
                        .buttonStyle(.bordered)
                        .tint(.red)
                        .alert("Cancel this friendship?", isPresented: $showCancelAlert) {
                            Button("Yes, cancel", role: .destructive) {
                                Task {
                                    do {
                                        await MainActor.run {
                                            onFriendRemoved?(user)
                                            dismiss()
                                        }
                                        try await APIService.shared.removeFriend(friendId: user.id)
                                    } catch {
                                        errorMessage = error.localizedDescription
                                    }
                                }
                            }
                            Button("No", role: .cancel) { }
                        } message: {
                            Text("Are you sure you want to cancel this friendship? This action cannot be undone.")
                        }
                    }
                }
                .padding()
            }
            .navigationTitle("Friend Profile")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("done".localized) { dismiss() }
                }
            }
            .sheet(isPresented: $showInviteToEvent) {
              InviteView(mode: .userToEvent(user: user))
            }
            // Sheet pour playlist à ajouter plus tard
        }
    }
}


// MARK: - Help & Support 
struct HelpSupportView: View {
    @EnvironmentObject var debugManager: DebugManager
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationView {
            VStack(spacing: 24) {
                Text("Help & Support")
                    .font(.title)
                    .padding(.top, 32)
                Text("For help, contact support@musicroom.app or visit our FAQ.")
                    .multilineTextAlignment(.center)
                    .padding(.horizontal)

                #if DEBUG
                    Toggle("Activer le debug print", isOn: $debugManager.isDebugEnabled)
                        .padding()
                #endif
      
                Spacer()
            }
            .navigationTitle("Help & Support")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("done".localized) { dismiss() }
                }
            }
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
  let stats: UserStats?

    var body: some View {
        HStack(spacing: 20) {
            StatItemView(
                icon: "music.note.list",
                value: String(stats?.playlistsCount ?? 0),
                label: "Playlists"
            )
            
            StatItemView(
                icon: "calendar.badge.checkmark",
                value: String(stats?.eventsCount ?? 0),
                label: "Events"
            )
            
            StatItemView(
                icon: "person.2.fill",
                value: String(stats?.friendsCount ?? 0),
                label: "Friends"
            )
        }
        .padding(.horizontal, 20)
    }
}

struct UserStats {
    let playlistsCount: Int
    let eventsCount: Int
    let friendsCount: Int
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
    
    @State private var isSaving = false
    @State private var errorMessage: String?

    private func updateProfile() async {
        isSaving = true
        errorMessage = nil
        let updateData: [String: Any] = [
            "displayName": displayName,
            "bio": bio,
            "location": location
        ]
        do {
            let updatedUser = try await APIService.shared.updateProfile(updateData)
            await MainActor.run {
                authManager.currentUser = updatedUser
                dismiss()
            }
        } catch {
            await MainActor.run {
                errorMessage = error.localizedDescription
            }
        }
        isSaving = false
    }

    var body: some View {
        NavigationView {
            VStack {
                Text("Edit Profile")
                    .font(.title)
                // Form fields
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
                if let error = errorMessage {
                    Text(error).foregroundColor(.red)
                }
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
                        Task { await updateProfile() }
                    }
                    .foregroundColor(.musicPrimary)
                    .disabled(isSaving)
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

// MARK: - App Settings
struct AppSettingsView: View {
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject private var themeManager: ThemeManager
    @EnvironmentObject private var localizationManager: LocalizationManager
    
    var body: some View {
        NavigationView {
            List {
                // Language Section
                Section("language".localized) {
                    ForEach(LocalizationManager.supportedLanguages, id: \.self) { languageCode in
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

// MARK: - Privacy Settings View
struct PrivacySettingsView: View {
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject private var authManager: AuthenticationManager
    
    @State private var displayNamePrivacy: PrivacyLevel = .public
    @State private var bioPrivacy: PrivacyLevel = .friends
    @State private var musicPreferencePrivacy: PrivacyLevel = .friends
    @State private var locationPrivacy: PrivacyLevel = .private
    @State private var birthDatePrivacy: PrivacyLevel = .friends
    
    @State private var isSaving = false
    @State private var errorMessage: String?
    @State private var showToast = false
    @State private var toastMessage = ""
    @State private var hasChanges = false

    var body: some View {
        List {
           /*  Section("Profile Visibility") {
                NavigationLink("Display Name") {
                    Text("Display Name Privacy Settings")
                }
                
                NavigationLink("Bio") {
                    Text("Bio Privacy Settings")
                }
                
                NavigationLink("Location") {
                    Text("Location Privacy Settings")
                }
            } */
            Section("Profile Visibility") {
                PrivacyToggleRow(
                    title: "Display Name",
                    selection: $displayNamePrivacy
                )
                .onChange(of: displayNamePrivacy) { _ in hasChanges = true }
                
                PrivacyToggleRow(
                    title: "Bio",
                    selection: $bioPrivacy
                )
                .onChange(of: bioPrivacy) { _ in hasChanges = true }
                
                PrivacyToggleRow(
                    title: "Birth Date",
                    selection: $birthDatePrivacy
                )
                .onChange(of: birthDatePrivacy) { _ in hasChanges = true }
                
                PrivacyToggleRow(
                    title: "Location",
                    selection: $locationPrivacy
                )
                .onChange(of: locationPrivacy) { _ in hasChanges = true }
                
                PrivacyToggleRow(
                    title: "Music Preferences",
                    selection: $musicPreferencePrivacy
                )
                .onChange(of: musicPreferencePrivacy) { _ in hasChanges = true }
            }
            
            if let error = errorMessage {
                Section {
                    Text(error)
                        .foregroundColor(.red)
                        .font(.caption)
                }
            }
        }
        .navigationTitle("privacy_settings".localized)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                Button("Save") {
                    Task { await savePrivacySettings() }
                }
                .disabled(!hasChanges || isSaving)
                .foregroundColor(.musicPrimary)
            }
        }
        .onAppear {
            loadCurrentPrivacySettings()
        }
        .toast(message: toastMessage, isShowing: $showToast, duration: 2.0)
    }
    
    private func loadCurrentPrivacySettings() {
        guard let user = authManager.currentUser else { return }
        
        // Convert VisibilityLevel to PrivacyLevel
        displayNamePrivacy = PrivacyLevel(rawValue: user.displayNameVisibility?.rawValue ?? "public") ?? .public
        bioPrivacy = PrivacyLevel(rawValue: user.bioVisibility?.rawValue ?? "friends") ?? .friends
        birthDatePrivacy = PrivacyLevel(rawValue: user.birthDateVisibility?.rawValue ?? "friends") ?? .friends
        locationPrivacy = PrivacyLevel(rawValue: user.locationVisibility?.rawValue ?? "friends") ?? .friends
        musicPreferencePrivacy = PrivacyLevel(rawValue: user.musicPreferenceVisibility?.rawValue ?? "friends") ?? .friends
    }
    
    private func savePrivacySettings() async {
        isSaving = true
        errorMessage = nil
        
        let privacySettings: [String: Any] = [
            "displayNameVisibility": displayNamePrivacy.rawValue,
            "bioVisibility": bioPrivacy.rawValue,
            "birthDateVisibility": birthDatePrivacy.rawValue,
            "locationVisibility": locationPrivacy.rawValue,
            "musicPreferenceVisibility": musicPreferencePrivacy.rawValue
        ]
        
        do {
            let updatedUser = try await APIService.shared.updatePrivacySettings(privacySettings)
            await MainActor.run {
                authManager.currentUser = updatedUser
                hasChanges = false
                toastMessage = "Privacy settings updated successfully"
                showToast = true
            }
        } catch {
            await MainActor.run {
                errorMessage = error.localizedDescription
            }
        }
        
        isSaving = false
    }
}

/* Relicat avec NavigationLink vers autre page
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
 */

// MARK: - Toggle Privacy Setting Row
enum PrivacyLevel: String, CaseIterable, Identifiable {
    case `public` = "public"
    case friends = "friends"
    case `private` = "private"
    
    var id: String { rawValue }
    
    var displayName: String {
        switch self {
        case .public: return "Public"
        case .friends: return "Friends Only"
        case .private: return "Private"
        }
    }
}

struct PrivacyToggleRow: View {
    let title: String
    @Binding var selection: PrivacyLevel

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title)
                .font(.headline)
            Picker("", selection: $selection) {
                ForEach(PrivacyLevel.allCases) { level in
                    Text(level.displayName).tag(level)
                }
            }
            .pickerStyle(.segmented)
        }
        .padding(.vertical, 4)
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
