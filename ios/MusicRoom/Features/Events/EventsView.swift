import SwiftUI

struct EventsView: View {
    @State private var events: [Event] = []
    @State private var isLoading = false
    @State private var searchText = ""
    @State private var showingCreateEvent = false
    @State private var selectedFilter: EventFilter = .all
    
    var filteredEvents: [Event] {
        var filtered = events
        
        if !searchText.isEmpty {
            filtered = filtered.filter { event in
                event.name.localizedCaseInsensitiveContains(searchText) ||
                event.description?.localizedCaseInsensitiveContains(searchText) == true
            }
        }
        
        switch selectedFilter {
        case .all:
            break
        case .myEvents:
            // Filter events created by current user
            break
        case .joined:
            // Filter events user has joined
            break
        case .nearby:
            // Filter events based on location
            break
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
                            ForEach(EventFilter.allCases, id: \\.self) { filter in
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
                        EventListItem(event: event)
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
        .task {
            await loadEvents()
        }
        .refreshable {
            await loadEvents()
        }
    }
    
    private func loadEvents() async {
        isLoading = true
        
        do {
            events = try await APIService.shared.getEvents()
        } catch {
            print("Failed to load events: \\(error)")
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
                    Label("\\(event.participants?.count ?? 0) participants", systemImage: "person.2")
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
        case .draft:
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

// MARK: - Create Event View (Placeholder)
struct CreateEventView: View {
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        NavigationView {
            VStack {
                Text("Create Event")
                    .font(.title)
                Text("Event creation form will be implemented here")
                    .foregroundColor(.textSecondary)
                Spacer()
            }
            .padding()
            .navigationTitle("create_event".localized)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("cancel".localized) {
                        dismiss()
                    }
                }
            }
        }
    }
}

#Preview {
    EventsView()
        .environmentObject(ThemeManager())
        .environmentObject(LocalizationManager())
}
