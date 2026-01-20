import SwiftUI
import CoreLocation

struct EventsView: View {
    @State private var editingEvent: Event? = nil
    @State private var events: [Event] = []
    @State private var isLoading = false
    @State private var searchText = ""
    @State private var showingCreateEvent = false
    @State private var selectedFilter: EventFilter = .all
    
    @EnvironmentObject private var authManager: AuthenticationManager

    @ObservedObject private var locationManager = LocationManager.shared

    var filteredEvents: [Event] {
        var filtered = events

        // Filtrage par texte
        if !searchText.isEmpty {
            filtered = filtered.filter { event in
                event.name.localizedCaseInsensitiveContains(searchText) ||
                event.description?.localizedCaseInsensitiveContains(searchText) == true
            }
        }

        // Filtrage par type
        switch selectedFilter {
        case .all:
            break
        case .myEvents:
            if let currentUserId = authManager.currentUser?.id {
                filtered = filtered.filter { $0.creatorId == currentUserId }
            }
        case .joined:
            if let currentUserId = authManager.currentUser?.id {
                filtered = filtered.filter { event in
                    event.participants?.contains(where: { $0.id == currentUserId }) == true
                }
            }
        case .nearby:
            // Filtrage géographique : user dans le rayon de l'event
            if let userCoord = locationManager.userLocation?.coordinate {
                filtered = filtered.filter { event in
                    if let eventLat = event.latitude, let eventLon = event.longitude, let radius = event.locationRadius {
                        let eventCoord = CLLocationCoordinate2D(latitude: eventLat, longitude: eventLon)
                      let distance = CLLocation(latitude: userCoord.latitude, longitude: userCoord.longitude)
                      .distance(from: CLLocation(latitude: eventLat, longitude: eventLon))
                      print("User: \(userCoord), Event: \(eventCoord), Distance: \(distance), Radius: \(radius)")
                      return distance <= Double(radius)
                        return LocationManager.shared.isWithinRadius(userCoord: userCoord, eventCoord: eventCoord, radius: Double(radius))
                    }
                    return false
                }
            } else {
                // Si pas de position user, ne rien afficher (ou tout afficher si tu préfères)
                filtered = []
            }
        }

        return filtered
    }
    
    var body: some View {
        NavigationView {
            VStack(spacing: 0) {
                // Search and Filter
                VStack(spacing: 12) {
                    SearchBar(text: $searchText)
                    
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 12) {
                            ForEach(EventFilter.allCases, id: \.self) { filter in
                                FilterChip(
                                    title: filter.localizedString,
                                    isSelected: selectedFilter == filter
                                ) {
                                    selectedFilter = filter
                                }
                            }
                        }
                        .padding(.horizontal, 20)
                    }
                }
                .padding(.vertical, 12)
                .background(Color.secondaryBackground)
                
                // Events List
                if isLoading {
                    LoadingView(message: "Loading events...")
                } else if filteredEvents.isEmpty {
                    EmptyStateView(
                        icon: "calendar.badge.exclamationmark",
                        title: "No Events Found",
                        message: searchText.isEmpty ? 
                            "No events available. Create your first event!" :
                            "No events match your search criteria.",
                        buttonTitle: searchText.isEmpty ? "create_event".localized : nil,
                        buttonAction: searchText.isEmpty ? { showingCreateEvent = true } : nil
                    )
                } else {
                    List(filteredEvents) { event in
                        Button {
                            editingEvent = event
                        } label: {
                            EventListItem(event: event)
                        }
                        .listRowInsets(EdgeInsets(top: 8, leading: 20, bottom: 8, trailing: 20))
                        .listRowBackground(Color.clear)
                    }
                    .listStyle(PlainListStyle())
                }
            }
            .navigationTitle("events".localized)
            .navigationBarTitleDisplayMode(.large)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button(action: {
                        showingCreateEvent = true
                    }) {
                        Image(systemName: "plus")
                            .foregroundColor(.musicPrimary)
                    }
                }
            }
        }
        .sheet(isPresented: $showingCreateEvent) {
            CreateEventView() { newEvent in
                events.append(newEvent)
            }
        }
        .sheet(item: $editingEvent) { event in
            if let idx = events.firstIndex(where: { $0.id == event.id }) {
                EventEditView(
                    event: $events[idx],
                    onEventUpdated: { updatedEvent in
                        events[idx] = updatedEvent
                    }, onEventDeleted: { deletedEvent in
                        events.removeAll { $0.id == deletedEvent.id }
                    })
                    .onDisappear {
                        editingEvent = nil
                    }
            }
        }
        .task {
          if !isLoading {
            await loadEvents()
          }
        }
        .refreshable {
            await loadEvents()
        }
    }
    
    private func loadEvents() async {
        isLoading = true
        print("🔄 loadEvents called")
        do {
            let myEvents = try await APIService.shared.getMyEvents()
            let allEvents = try await APIService.shared.getEvents()

            // Fusionner en supprimant les doublons (basé sur l'id)
            var combinedEvents = myEvents
            for event in allEvents {
                if !combinedEvents.contains(where: { $0.id == event.id }) {
                    combinedEvents.append(event)
                }
            }
            events = combinedEvents

        } catch {
            if let urlError = error as? URLError, urlError.code == .cancelled {
                // Ignore l’erreur d’annulation
            } else {
                print("Failed to load events: \(error)")
            }
        }
        
        isLoading = false
    }
}

// MARK: - Event Filter
enum EventFilter: CaseIterable {
    case all, myEvents, joined, nearby
    
    var localizedString: String {
        switch self {
        case .all:
            return "All Events"
        case .myEvents:
            return "My Events"
        case .joined:
            return "Joined"
        case .nearby:
            return "Nearby"
        }
    }
}

// MARK: - Filter Chip
struct FilterChip: View {
    let title: String
    let isSelected: Bool
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            Text(title)
                .font(.caption)
                .fontWeight(isSelected ? .semibold : .regular)
                .foregroundColor(isSelected ? .white : .textPrimary)
                .padding(.horizontal, 16)
                .padding(.vertical, 8)
                .background(
                    isSelected ? Color.musicPrimary : Color.cardBackground
                )
                .cornerRadius(20)
                .overlay(
                    RoundedRectangle(cornerRadius: 20)
                        .stroke(Color.gray.opacity(0.2), lineWidth: isSelected ? 0 : 1)
                )
        }
    }
}

// MARK: - Search Bar
struct SearchBar: View {
    @Binding var text: String
    
    var body: some View {
        HStack {
            Image(systemName: "magnifyingglass")
                .foregroundColor(.textSecondary)
            
            TextField("Search...", text: $text)
                .textFieldStyle(PlainTextFieldStyle())
            
            if !text.isEmpty {
                Button(action: {
                    text = ""
                }) {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundColor(.textSecondary)
                }
            }
        }
        .padding()
        .background(Color.cardBackground)
        .cornerRadius(12)
        .padding(.horizontal, 20)
    }
}

// MARK: - Event List Item
struct EventListItem: View {
    let event: Event
    
    var body: some View {
        CardView {
            VStack(alignment: .leading, spacing: 12) {
                HStack {
                    VStack(alignment: .leading, spacing: 4) {
                        Text(event.name)
                            .font(.headline)
                            .foregroundColor(.textPrimary)
                        
                        if let locationName = event.locationName {
                            Label(locationName, systemImage: "location")
                                .font(.caption)
                                .foregroundColor(.textSecondary)
                        }
                    }
                    
                    Spacer()
                    
                    VStack(alignment: .trailing, spacing: 4) {
                        Image(systemName: event.visibility == .public ? "globe" : "lock")
                            .foregroundColor(.musicSecondary)
                        
                        Text(event.status.localizedString)
                            .font(.caption)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 2)
                            .background(statusColor(for: event.status).opacity(0.2))
                            .foregroundColor(statusColor(for: event.status))
                            .cornerRadius(8)
                    }
                }
                
                if let description = event.description {
                    Text(description)
                        .font(.subheadline)
                        .foregroundColor(.textSecondary)
                        .lineLimit(2)
                }
                
                HStack {
                    Label("\(event.participants?.count ?? 0) participants", systemImage: "person.2")
                        .font(.caption)
                        .foregroundColor(.textSecondary)
                    
                    Spacer()
                    
                     if let eventDate = event.eventDate {
                        Text(eventDate.formatParisDate())
                            .font(.caption)
                            .foregroundColor(.textSecondary)
                     }
                }
            }
        }
    }
    
    private func statusColor(for status: EventStatus) -> Color {
        switch status {
        case .active:
            return .green
        case .paused:
            return .orange
        case .upcoming:
            return .blue
        case .ended:
            return .gray
        }
    }
}

// MARK: - Create Event View (Form)
struct CreateEventView: View {
    @Environment(\.dismiss) private var dismiss
    var onEventCreated: ((Event) -> Void)? = nil
    @State private var name: String = ""
    @State private var description: String = ""
    @State private var location: String = ""
    @State private var radius: Double = 100
    @State private var date: Date = Date()
    @State private var endDate: Date = Date()
    @State private var isPublic: Bool = true
    @State private var requireLocationForVoting: Bool = false
    @State private var votingStartTime: Date = {
        let calendar = Calendar.current
        return calendar.date(bySettingHour: 18, minute: 0, second: 0, of: Date()) ?? Date()
    }()
    @State private var votingEndTime: Date = {
        let calendar = Calendar.current
        return calendar.date(bySettingHour: 22, minute: 0, second: 0, of: Date()) ?? Date()
    }()
    @State private var isSaving = false
    @State private var errorMessage: String?
    @State private var playlistName: String = ""
    @State private var selectedPlaylist: Playlist? = nil
    @State private var showPlaylistPicker = false
    // @State private var createNewPlaylist = false

    // Computed property pour valider les dates
    private var isDateValid: Bool {
        DateValidation.isValid(startDate: date, endDate: endDate)
    }

    var body: some View {
        NavigationView {
            Form {
                Section(header: Text("Event Info")) {
                    TextField("Name", text: $name)
                    TextField("Description", text: $description)
                }
                
                EventDateSection(
                    startDate: $date,
                    endDate: $endDate,
                    location: $location,
                    radius: $radius,
                    requireLocationForVoting: $requireLocationForVoting,
                    votingStartTime: $votingStartTime,
                    votingEndTime: $votingEndTime,
                    showPastDateValidation: true,
                    minimumDurationHours: 1
                )
                Section(header: Text("Visibility")) {
                    Toggle(isOn: $isPublic) {
                        Text("Public Event")
                    }
                }
                Section(header: Text("Create Event Playlist")) {
                        TextField("Nom de la playlist", text: $playlistName)

                    /* Toggle("Créer une nouvelle playlist", isOn: $createNewPlaylist)
                    if createNewPlaylist {
                        TextField("Nom de la playlist", text: $playlistName)
                        // ... autres champs playlist ...
                    } else {
                        Button(action: { showPlaylistPicker = true }) {
                            Text(selectedPlaylist?.name ?? "Sélectionner une playlist existante")
                        }
                    } */
                }
                if let error = errorMessage {
                    Section {
                        Text(error).foregroundColor(.red)
                    }
                }
            }
            .navigationTitle("create_event".localized)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("cancel".localized) { dismiss() }
                }
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Save") {
                        saveEvent()
                    }
                    .disabled(isSaving || name.isEmpty || !isDateValid
                          || (/* createNewPlaylist &&  */playlistName.isEmpty)
                          /* || (!createNewPlaylist && selectedPlaylist == nil)*/
                    )
                }
            }
            .sheet(isPresented: $showPlaylistPicker) {
                PlaylistPickerView(selectedPlaylist: $selectedPlaylist, showPlaylistPicker: $showPlaylistPicker)
            }
        }
    }

    private func saveEvent() {
        // Validation des dates avant de sauvegarder
        guard isDateValid else {
            errorMessage = DateValidation.validationMessage(startDate: date, endDate: endDate)
            return
        }

        LocationManager.shared.getLongLatFromAddressString(place: location) { coordinate in
            isSaving = true
            errorMessage = nil
            var eventData: [String: Any] = [
                "name": name,
                "description": description,
                "locationName": location,
                "locationRadius": Int(radius),
                "latitude": coordinate?.latitude ?? 0,
                "longitude": coordinate?.longitude ?? 0,
                "eventDate": ISO8601DateFormatter().string(from: date),
                "eventEndDate": ISO8601DateFormatter().string(from: endDate),
                "visibility": isPublic ? "public" : "private",
                "licenseType": requireLocationForVoting ? "location_based" : "open",
                "selectedPlaylistId": selectedPlaylist?.id ?? "",
                "playlistName": playlistName //createNewPlaylist ? playlistName : selectedPlaylist?.name ?? ""
            ]
            
            // Ajouter les heures de vote pour les événements géolocalisés
            if requireLocationForVoting {
                let timeFormatter = DateFormatter()
                timeFormatter.dateFormat = "HH:mm"
                eventData["votingStartTime"] = timeFormatter.string(from: votingStartTime)
                eventData["votingEndTime"] = timeFormatter.string(from: votingEndTime)
            }
            Task {
                do {
                    print("🆕 Creating event with data: \(eventData)")
                    let createdEvent = try await APIService.shared.createEvent(eventData)
                    await MainActor.run {
                        onEventCreated?(createdEvent)
                        isSaving = false
                        dismiss()
                    }
                } catch {
                    await MainActor.run {
                        errorMessage = error.localizedDescription
                        isSaving = false
                    }
                }
            }
        }
    }

    // Composant interne
    struct PlaylistPickerView: View {
        @Binding var selectedPlaylist: Playlist?
        @Binding var showPlaylistPicker: Bool
        @State private var playlists: [Playlist] = []
        @State private var isLoading = false
        @State private var errorMessage: String?

        var body: some View {
            NavigationView {
                VStack {
                    Text("Si vous sélectionnez une playlist existante pour l'événement. Une copie librement éditable sera créée.")
                      .font(.footnote)
                      .foregroundColor(.gray)
                      .multilineTextAlignment(.center)
                      .padding(.horizontal)
                    Group {
                        if isLoading {
                            ProgressView("Chargement des playlists...")
                                .frame(maxWidth: .infinity, maxHeight: .infinity)
                        } else if let error = errorMessage {
                            VStack(spacing: 16) {
                                Text("Erreur: \(error)")
                                    .foregroundColor(.red)
                                Button("Réessayer") {
                                    Task { await loadPlaylists() }
                                }
                            }
                            .frame(maxWidth: .infinity, maxHeight: .infinity)
                        } else if playlists.isEmpty {
                            Text("Aucune playlist disponible.")
                                .foregroundColor(.textSecondary)
                                .frame(maxWidth: .infinity, maxHeight: .infinity)
                        } else {
                            List(playlists) { playlist in
                                Button {
                                    selectedPlaylist = playlist
                                } label: {
                                    HStack {
                                        Text(playlist.name)
                                            .foregroundColor(.textPrimary)
                                            .padding(.vertical, 8)
                                        if selectedPlaylist?.id == playlist.id {
                                            Spacer()
                                            Image(systemName: "checkmark")
                                                .foregroundColor(.musicPrimary)
                                        }
                                    }
                                }
                                .listRowInsets(EdgeInsets(top: 8, leading: 20, bottom: 8, trailing: 20))
                                .listRowBackground(Color.clear)
                            }
                            .listStyle(PlainListStyle())
                        }
                    }
                }
                .navigationBarTitle("Playlist disponibles")
                .navigationBarItems(trailing: Button("Terminer") {
                    showPlaylistPicker = false
                })
            }
            .task {
                await loadPlaylists()
            }
        }

        private func loadPlaylists() async {
            isLoading = true
            errorMessage = nil
            do {
                playlists = try await APIService.shared.getPlaylists()
            } catch {
                errorMessage = error.localizedDescription
            }
            isLoading = false
        }
    }
}

// MARK: - Event Edit View
struct EventEditView: View {
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject var tabManager: MainTabManager
    @EnvironmentObject var authManager: AuthenticationManager
    @Binding var event: Event
    var onEventUpdated: (Event) -> Void
    var onEventDeleted: (Event) -> Void

    @State private var name: String = ""
    @State private var description: String = ""
    @State private var location: String = ""
    @State private var radius: Double = 100
    @State private var date: Date = Date()
    @State private var endDate: Date = Date()
    @State private var isPublic: Bool = true
    @State private var requireLocationForVoting: Bool = false
    @State private var votingStartTime: Date = Date()
    @State private var votingEndTime: Date = Date()
    @State private var isSaving = false
    @State private var isDeleting = false
    @State private var errorMessage: String?
    
    // Computed property pour valider les dates
    private var isDateValid: Bool {
        DateValidation.isValid(startDate: date, endDate: endDate)
    }

    @State private var invitedUsers: [User] = []
    @State private var allUsers: [User] = []
    @State private var admins: [User] = []
    @State private var isLoadingUsers = false
    var isAdmin: Bool {
        guard let currentUser = authManager.currentUser else { return false }
        return event.admins?.contains(where: { $0.id == currentUser.id }) == true || event.creatorId == currentUser.id
    }

    @State private var activeSheet: ActiveSheet? = nil
    @State private var selectedAdminCandidate: User? = nil
    /// Enum to manage active sheets
    enum ActiveSheet: Identifiable {
        case inviteUser, adminPicker
        var id: Int {
            switch self {
            case .inviteUser: return 1
            case .adminPicker: return 2
            }
        }
    }

    var body: some View {
        NavigationView {
            Form {
                if let error = errorMessage {
                    Section {
                        Text(error).foregroundColor(.red)
                    }
                }
                Section(header: Text("Event Info")) {
                    TextField("Name", text: $name)
                    TextField("Description", text: $description)
                }
                
                EventDateSection(
                    startDate: $date,
                    endDate: $endDate,
                    location: $location,
                    radius: $radius,
                    requireLocationForVoting: $requireLocationForVoting,
                    votingStartTime: $votingStartTime,
                    votingEndTime: $votingEndTime,
                    showPastDateValidation: false,
                    minimumDurationHours: 1
                )

                if let playlist = event.playlist {
                    Section(header: Text("Go To Playslist")) {
                        Button(action: {
                            tabManager.selectedTab = 2 // Onglet Playlists
                            tabManager.selectedPlaylist = playlist
                            if let data = try? JSONEncoder().encode(playlist),
                                let jsonObject = try? JSONSerialization.jsonObject(with: data, options: []),
                                let prettyData = try? JSONSerialization.data(withJSONObject: jsonObject, options: [.prettyPrinted]),
                                let prettyString = String(data: prettyData, encoding: .utf8) {
                                print("✅ playlist:\n\(prettyString)")
                            }
                            dismiss()
                        }) {
                            HStack {
                                Text(playlist.name)
                                Spacer()
                                Image(systemName: "chevron.right")
                            }
                        }
                    }
                }

                if isAdmin {
                    Section(header: Text("Visibility")) {
                        Toggle(isOn: $isPublic) {
                            Text("Public Event")
                        }
                    }
                    Section(header: Text("Invited Users")) {
                        if isLoadingUsers {
                            ProgressView()
                        } else {
                            ForEach(invitedUsers) { user in
                                HStack {
                                    Text(user.displayName)
                                    Spacer()
                                    Button(role: .destructive) {
                                        removeUser(user)
                                    } label: {
                                        Image(systemName: "minus.circle")
                                    }
                                }
                            }
                            Button("Invite Friends") {
                                activeSheet = .inviteUser
                            }
                        }
                    }
                    Section(header: Text("Admins")) {
                        if admins.isEmpty {
                            Text("No admins yet (except creator)")
                                .foregroundColor(.textSecondary)
                        } else {
                            ForEach(admins) { user in
                                HStack {
                                    Text(user.displayName)
                                    Spacer()
                                    if user.id != event.creatorId {
                                        Button(role: .destructive) {
                                            removeAdmin(user)
                                        } label: {
                                            Image(systemName: "minus.circle")
                                        }
                                    }
                                }
                            }
                        }
                        Button("Add Admin") {
                            activeSheet = .adminPicker
                        }
                    }

                    Section {
                        Button("Delete Event", role: .destructive) {
                            deleteEvent()
                        }
                    }
                }
            }
            .navigationTitle("\(isAdmin ? "Edit " : "") Event")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") { dismiss() }
                }
                if isAdmin {
                    ToolbarItem(placement: .navigationBarTrailing) {
                        Button("Save") { saveEvent() }
                            .disabled(isSaving || name.isEmpty)
                    }
                }
            }
            .onAppear(perform: setup)
            .sheet(item: $activeSheet) { sheet in
                switch sheet {
                case .inviteUser:
                    InviteView(mode: .eventToUser(event: event))
                case .adminPicker:
                    NavigationView {
                        List {
                            ForEach(invitedUsers.filter { u in !admins.contains(where: { $0.id == u.id }) }) { user in
                                Button {
                                    selectedAdminCandidate = user
                                } label: {
                                    HStack {
                                        Text(user.displayName)
                                        if selectedAdminCandidate?.id == user.id {
                                            Spacer()
                                            Image(systemName: "checkmark")
                                                .foregroundColor(.musicPrimary)
                                        }
                                    }
                                }
                            }
                        }
                        .navigationTitle("Select Admin")
                        .toolbar {
                            ToolbarItem(placement: .navigationBarTrailing) {
                                Button("Promote") {
                                    promoteSelectedAdmin()
                                    activeSheet = nil
                                }
                                .disabled(selectedAdminCandidate == nil)
                            }
                            ToolbarItem(placement: .navigationBarLeading) {
                                Button("Cancel") {
                                    activeSheet = nil
                                    selectedAdminCandidate = nil
                                }
                            }
                        }
                    }
                }
            }
        }
    }

    private func setup() {
        // 🔍 LOGS DE DEBUG : //
        if DebugManager.shared.isDebugEnabled,
          let data = try? JSONEncoder().encode(event),
          let json = try? JSONSerialization.jsonObject(with: data),
          let prettyData = try? JSONSerialization.data(withJSONObject: json, options: [.prettyPrinted]),
          let prettyString = String(data: prettyData, encoding: .utf8) {
            print("🔄 EventEditView setup called\n\(prettyString)")
        }
        // 🔍 LOGS DE DEBUG : \\


        name = event.name
        description = event.description ?? ""
        location = event.locationName ?? ""
        radius = Double(event.locationRadius ?? 100)
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        if let d = formatter.date(from: event.eventDate ?? "") {
            date = d
        } else {
            formatter.formatOptions = [.withInternetDateTime]
            date = formatter.date(from: event.eventDate ?? "") ?? Date()
        }

        if let d = formatter.date(from: event.eventEndDate ?? "") {
            endDate = d
        } else {
            formatter.formatOptions = [.withInternetDateTime]
            endDate = formatter.date(from: event.eventEndDate ?? "") ?? Date()
        }
        isPublic = event.visibility == .public
        requireLocationForVoting = event.licenseType == .locationBased
        
        // Initialiser les heures de vote depuis l'événement
        if let votingStart = event.votingStartTime {
            print("🕐 Loading voting start time from event: '\(votingStart)'")
            let components = votingStart.split(separator: ":")
            if components.count >= 2, 
               let hour = Int(components[0]), 
               let minute = Int(components[1]) {
                let calendar = Calendar.current
                if let time = calendar.date(bySettingHour: hour, minute: minute, second: 0, of: Date()) {
                    votingStartTime = time
                    print("✅ Set voting start time to: \(time)")
                } else {
                    print("❌ Failed to create voting start time")
                }
            } else {
                print("❌ Invalid voting start time format: '\(votingStart)'")
            }
        }
        
        if let votingEnd = event.votingEndTime {
            print("🕐 Loading voting end time from event: '\(votingEnd)'")
            let components = votingEnd.split(separator: ":")
            if components.count >= 2, 
               let hour = Int(components[0]), 
               let minute = Int(components[1]) {
                let calendar = Calendar.current
                if let time = calendar.date(bySettingHour: hour, minute: minute, second: 0, of: Date()) {
                    votingEndTime = time
                    print("✅ Set voting end time to: \(time)")
                } else {
                    print("❌ Failed to create voting end time")
                }
            } else {
                print("❌ Invalid voting end time format: '\(votingEnd)'")
            }
        }
        
        invitedUsers = event.participants ?? []
        admins = event.admins ?? []
        loadAllUsers()
    }

    private func saveEvent() {
        // Validation des dates avant de sauvegarder
        guard isDateValid else {
            errorMessage = DateValidation.validationMessage(startDate: date, endDate: endDate)
            return
        }
        
        LocationManager.shared.getLongLatFromAddressString(place: location) { coordinate in
            isSaving = true
            errorMessage = nil
            var eventData: [String: Any] = [
                "name": name,
                "description": description,
                "locationName": location,
                "locationRadius": Int(radius),
                "latitude": coordinate?.latitude ?? 0,
                "longitude": coordinate?.longitude ?? 0,
                "eventDate": ISO8601DateFormatter().string(from: date),
                "eventEndDate": ISO8601DateFormatter().string(from: endDate),
                "visibility": isPublic ? "public" : "private",
                "licenseType": requireLocationForVoting ? "location_based" : "open",
                "admins": admins.map { $0.id }, // il n'y a pas en db
                "participants": invitedUsers.map { $0.id } // il n'y a pas en db
            ]
            
            // Ajouter les heures de vote pour les événements géolocalisés
            if requireLocationForVoting {
                let timeFormatter = DateFormatter()
                timeFormatter.dateFormat = "HH:mm"
                eventData["votingStartTime"] = timeFormatter.string(from: votingStartTime)
                eventData["votingEndTime"] = timeFormatter.string(from: votingEndTime)
            }
            Task {
                do {
                    let updated = try await APIService.shared.updateEvent(eventId: event.id, eventData)
                    await MainActor.run {
                        // event = updated
                        onEventUpdated(updated)
                        isSaving = false
                        dismiss()
                    }
                } catch {
                    await MainActor.run {
                        errorMessage = error.localizedDescription
                        isSaving = false
                    }
                }
            }
        }
        
    }

    private func deleteEvent() {
        isDeleting = true
        errorMessage = nil
        Task {
            do {
                _ = try await APIService.shared.deleteEvent(event.id)
                await MainActor.run {
                    onEventDeleted(event)
                    isDeleting = false
                    dismiss()
                }
            } catch {
                await MainActor.run {
                    errorMessage = error.localizedDescription
                    isDeleting = false
                }
            }
        }
    }

    private func loadAllUsers() {
        isLoadingUsers = true
        Task {
            do {
//                allUsers = try await APIService.shared.getAllUsers()
            } catch {
                // ignore pour l'instant
            }
            isLoadingUsers = false
        }
    }

    private func inviteUser() {
        // Affiche une liste d'utilisateurs à inviter (à améliorer avec une vraie UI)
        if let user = allUsers.first(where: { u in !invitedUsers.contains(where: { $0.id == u.id }) }) {
            invitedUsers.append(user)
        }
    }

    
    private func removeUser(_ user: User) {
        Task{
            do {
                _ = try await APIService.shared.removeUserFromEvent(id: event.id, userId: user.id)
                await MainActor.run {
                    invitedUsers.removeAll { $0.id == user.id }
                }
            }
            catch {
                await MainActor.run {
                    errorMessage = error.localizedDescription
                }
            }
        }

    }

    private func addAdmin() {
        activeSheet = .adminPicker
    }

    private func promoteSelectedAdmin() {
        guard let user = selectedAdminCandidate else { return }
        Task {
            do {
                try await APIService.shared.promoteUserToAdmin(eventId: event.id, userId: user.id)
                await MainActor.run {
                    admins.append(user)
                    // showAdminPicker = false
                    selectedAdminCandidate = nil
                }
            } catch {
                await MainActor.run {
                    errorMessage = error.localizedDescription
                }
            }
        }
    }

    private func removeAdmin(_ user: User) {
        Task {
            do {
                try await APIService.shared.removeAdminFromEvent(eventId: event.id, userId: user.id)
                await MainActor.run {
                    admins.removeAll { $0.id == user.id }
                }
            } catch {
                await MainActor.run {
                    errorMessage = error.localizedDescription
                }
            }
        }
    }
}

// MARK: - Invite To Event View
enum InviteMode {
    case userToEvent(user: User)
    case eventToUser(event: Event)
}

struct InviteView: View {
    let mode: InviteMode
    @State private var items: [Any] = []
    @State private var isLoading = false
    @State private var errorMessage: String?
    @State private var showToast = false
    @State private var toastMessage = ""

    var body: some View {
        NavigationView {
            List {
                if isLoading {
                    ProgressView()
                } else {
                    ForEach(items.indices, id: \.self) { idx in
                        Button {
                            invite(at: idx)
                        } label: {
                            switch mode {
                            case .userToEvent:
                                let event = items[idx] as! Event
                                Text(event.name)
                            case .eventToUser:
                                let user = items[idx] as! User
                                Text(user.displayName)
                            }
                        }
                    }
                }
            }
            .navigationTitle(modeTitle)
            .onAppear { loadItems() }
        }
        .toast(message: toastMessage, isShowing: $showToast, duration: 2.0)
    }

    private var modeTitle: String {
        switch mode {
        case .userToEvent: return "Inviter à un événement"
        case .eventToUser: return "Inviter un utilisateur"
        }
    }

    private func loadItems() {
        isLoading = true
        Task {
            do {
                switch mode { // assign:
                case .userToEvent(let user):
                    items = try await APIService.shared.getMyEvents().map { $0 as Any }
                case .eventToUser(let event):
                    items = try await APIService.shared.getUserFriends()
//                    To do:
//                    items = try await APIService.shared.getInvitableUsers(for: event.id).map { $0 as Any }
                }
            } catch {
                errorMessage = error.localizedDescription
            }
            isLoading = false
        }
    }

    private func invite(at idx: Int) {
        Task {
            do {
                switch mode {
                case .userToEvent(let user):
                    let event = items[idx] as! Event
                    try await APIService.shared.inviteUserToEvent(eventId: event.id, userId: user.id)
                    toastMessage = "Invitation envoyée à \(user.displayName)"
                case .eventToUser(let event):
                    let user = items[idx] as! User
                    try await APIService.shared.inviteUserToEvent(eventId: event.id, userId: user.id)
                    toastMessage = "Invitation envoyée à \(user.displayName)"
                }
                showToast = true
            } catch {
                toastMessage = error.localizedDescription
                showToast = true
            }
        }
    }
}

#Preview {
    EventsView()
        .environmentObject(ThemeManager())
        .environmentObject(LocalizationManager())
}
