import SwiftUI

struct EventsView: View {
    @State private var editingEvent: Event? = nil
    @State private var events: [Event] = []
    @State private var isLoading = false
    @State private var searchText = ""
    @State private var showingCreateEvent = false
    @State private var selectedFilter: EventFilter = .all
    
    @EnvironmentObject private var authManager: AuthenticationManager

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
            // Exemple simple : filtre sur la même ville que l'utilisateur
            if let userLocation = authManager.currentUser?.location?.lowercased() {
                filtered = filtered.filter { event in
                    event.locationName?.lowercased().contains(userLocation) == true
                }
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
            CreateEventView()
        }
        .sheet(item: $editingEvent) { event in
            EventEditView(event: event, onEventUpdated: { updatedEvent in
                // Remplace l'event dans la liste
                if let idx = events.firstIndex(where: { $0.id == updatedEvent.id }) {
                    events[idx] = updatedEvent
                }
            }, onEventDeleted: { deletedEvent in
                // Retire l'event de la liste
                events.removeAll { $0.id == deletedEvent.id }
            })
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
            let allEvents = try await APIService.shared.getEvents()
            let myEvents = try await APIService.shared.getMyEvents()

            // Fusionner en supprimant les doublons (basé sur l'id)
            var combinedEvents = allEvents
            for event in myEvents {
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
            
            TextField("Search events...", text: $text)
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
                        Text(formatDate(eventDate))
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
    
    private func formatDate(_ dateString: String) -> String {
        // Format date string for display
        return dateString
    }
}

// MARK: - Create Event View (Form)
struct CreateEventView: View {
    @Environment(\.dismiss) private var dismiss
    @State private var name: String = ""
    @State private var description: String = ""
    @State private var location: String = ""
    @State private var date: Date = Date()
    @State private var isPublic: Bool = true
    @State private var isSaving = false
    @State private var errorMessage: String?

    var body: some View {
        NavigationView {
            Form {
                Section(header: Text("Event Info")) {
                    TextField("Name", text: $name)
                    TextField("Description", text: $description)
                }
                Section(header: Text("Location & Date")) {
                    TextField("Location", text: $location)
                    DatePicker("Date", selection: $date, displayedComponents: [.date, .hourAndMinute])
                }
                Section(header: Text("Visibility")) {
                    Toggle(isOn: $isPublic) {
                        Text("Public Event")
                    }
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
                    .disabled(isSaving || name.isEmpty)
                }
            }
        }
    }

    private func saveEvent() {
        isSaving = true
        errorMessage = nil
        let eventData: [String: Any] = [
            "name": name,
            "description": description,
            "location": location,
            "eventDate": ISO8601DateFormatter().string(from: date),
            "visibility": isPublic ? "public" : "private"
        ]
        Task {
            do {
                _ = try await APIService.shared.createEvent(eventData)
                await MainActor.run {
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

// MARK: - Event Edit View
struct EventEditView: View {
    @Environment(\.dismiss) private var dismiss
    @State var event: Event
    var onEventUpdated: (Event) -> Void
    var onEventDeleted: (Event) -> Void

    @State private var name: String = ""
    @State private var description: String = ""
    @State private var location: String = ""
    @State private var date: Date = Date()
    @State private var isPublic: Bool = true
    @State private var isSaving = false
    @State private var isDeleting = false
    @State private var errorMessage: String?

    @State private var invitedUsers: [User] = []
    @State private var allUsers: [User] = []
    @State private var admins: [User] = []
    @State private var isLoadingUsers = false

    @State private var showInviteUserSheet = false

    var body: some View {
        NavigationView {
            Form {
                Section(header: Text("Event Info")) {
                    TextField("Name", text: $name)
                    TextField("Description", text: $description)
                }
                Section(header: Text("Location & Date")) {
                    TextField("Location", text: $location)
                    DatePicker("Date", selection: $date, displayedComponents: [.date, .hourAndMinute])
                }
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
                        Button("Invite User") {
                            // inviteUser()
                            showInviteUserSheet = true
                        }
                        .sheet(isPresented: $showInviteUserSheet) {
                            InviteView(mode: .eventToUser(event: event))
                            // InviteUserToEventView(
                            //     event: event,
                            //     alreadyInvited: invitedUsers
                            // ) { newUsers in
                            //     invitedUsers.append(contentsOf: newUsers)
                            // }
                        }
                    }
                }
                Section(header: Text("Admins")) {
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
                    Button("Add Admin") {
                        addAdmin()
                    }
                }
                if let error = errorMessage {
                    Section {
                        Text(error).foregroundColor(.red)
                    }
                }
                Section {
                    Button("Delete Event", role: .destructive) {
                        deleteEvent()
                    }
                }
            }
            .navigationTitle("Edit Event")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Save") { saveEvent() }
                        .disabled(isSaving || name.isEmpty)
                }
            }
            .onAppear(perform: setup)
        }
    }

    private func setup() {
        name = event.name
        description = event.description ?? ""
        location = event.locationName ?? ""
        date = ISO8601DateFormatter().date(from: event.eventDate ?? "") ?? Date()
        isPublic = event.visibility == .public
        invitedUsers = event.participants ?? []
//        admins = event.admins ?? []
        loadAllUsers()
    }

    private func saveEvent() {
        isSaving = true
        errorMessage = nil
        let eventData: [String: Any] = [
            "name": name,
            "description": description,
            "locationName": location,
            "eventDate": ISO8601DateFormatter().string(from: date),
            "visibility": isPublic ? "public" : "private",
            "admins": admins.map { $0.id }, // il n'y a pas en db
            "participants": invitedUsers.map { $0.id } // il n'y a pas en db
        ]
        Task {
            do {
                let updated = try await APIService.shared.updateEvent(eventId: event.id, eventData)
                await MainActor.run {
                    event = updated
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
        // Ajoute le premier user non admin (à améliorer avec une vraie UI)
        if let user = invitedUsers.first(where: { u in !admins.contains(where: { $0.id == u.id }) }) {
            admins.append(user)
        }
    }

    private func removeAdmin(_ user: User) {
        admins.removeAll { $0.id == user.id }
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
                switch mode {
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
                    try await APIService.shared.inviteUsersToEvent(eventId: event.id, [user.email])
                    toastMessage = "Invitation envoyée à \(user.displayName)"
                case .eventToUser(let event):
                    let user = items[idx] as! User
                    try await APIService.shared.inviteUsersToEvent(eventId: event.id, [user.email])
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
