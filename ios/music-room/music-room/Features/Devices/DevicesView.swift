import SwiftUI

@Observable
class DevicesViewModel {
    let devicesSocket = DevicesSocketService.shared
    var connectedUsers: [[String: Any]] = []

    init() {
        /* // Configure les écouteurs d'événements socket ici si nécessaire
        devicesSocket.on("device-connections") { data, ack in
            guard let dict = data.first as? [String: Any],
                  let connections = dict["connections"] as? [[String: Any]] else { return }
            // connections est un tableau de DeviceConnectionInfo (userId, deviceName, userAgent, connectedAt)
            print("connections: \(connections)")
            DispatchQueue.main.async {
                // Mets à jour ton @State ou ViewModel ici
                self.connectedUsers = connections
            }
        }

        devicesSocket.onDeviceDisconnected { data, ack in
            print("device-disconnected-notification reçu :", data)
            if let dict = data.first as? [String: Any] {
                print("Infos device déconnecté :", dict)
                // Tu peux aussi traiter dict ici (deviceId, userId, timestamp, etc)
            }
        }

        devicesSocket.onDeviceControlRevoked { data, ack in
            print("device-control-revoked reçu :", data)
            if let dict = data.first as? [String: Any] {
                print("Infos device contrôle révoqué :", dict)
                // Tu peux aussi traiter dict ici (deviceId, userId, timestamp, etc)
            }
        } */
    }

    func getConnectedDevices(_ deviceId: String) {
        print("Requesting connections for deviceId: \(deviceId)")
        devicesSocket.emit("get-device-connections", with: [["deviceId": deviceId]])
    }
}

struct DevicesView: View {
    @State private var devices: [Device] = []
    @State private var delegatedDevices: [Device] = []
    @State private var isLoading = false
    @State private var showingAddDevice = false
    @State private var selectedTab: DeviceTab = .myDevices

    @State var viewModel: DevicesViewModel
    init() {
        let vm = DevicesViewModel()
        _viewModel = State(wrappedValue: vm)
    }

    var body: some View {
        NavigationView {
            VStack(spacing: 0) {
                // Tab Selector
                Picker("Device Tab", selection: $selectedTab) {
                    Text("my_devices".localized).tag(DeviceTab.myDevices)
                    Text("delegated_devices".localized).tag(DeviceTab.delegated)
                }
                .pickerStyle(SegmentedPickerStyle())
                .padding()
                .background(Color.secondaryBackground)
                
                // Content based on selected tab
                if isLoading {
                    LoadingView(message: "Loading devices...")
                } else {
                    switch selectedTab {
                    case .myDevices:
                        MyDevicesView(
                            devices: devices,
                            onRefresh: loadDevices,
                            viewModel: viewModel,
                            onDelegationRevoked: { revokedDevice in
                                if let idx = devices.firstIndex(where: { $0.id == revokedDevice.id }) {
                                    devices[idx].delegatedToId = nil
                                    devices[idx].delegatedTo = nil
                                    devices[idx].delegationExpiresAt = nil
                                }
                            }
                        )
                    case .delegated:
                        DelegatedDevicesView(devices: delegatedDevices, onRefresh: loadDevices)
                    }
                }
            }
            .navigationTitle("devices".localized)
            .navigationBarTitleDisplayMode(.large)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button(action: {
                        showingAddDevice = true
                    }) {
                        Image(systemName: "plus")
                            .foregroundColor(.musicPrimary)
                    }
                }
            }
        }
        .onAppear {
            viewModel.devicesSocket.onDeviceControlRevoked { data, ack in
                // data est [Any], ack est SocketAckEmitter
                print("Device control revoked event received in View: \(data)")
                if let dict = data.first as? [String: Any] {

                  DispatchQueue.main.async {
                      print("Device control revoked event received in View: \(dict)")
                      delegatedDevices.removeAll { $0.identifier == (dict["deviceId"] as? String ?? "")}
                  }
                }
            }
        }
        .sheet(isPresented: $showingAddDevice) {
            AddDeviceView()
        }
        .task {
            await loadDevices()
            await detectAndRegisterDeviceIfNeeded()
        }
        .refreshable {
            await loadDevices()
        }
    }

    private func detectAndRegisterDeviceIfNeeded() async {
        let deviceName = UIDevice.current.name
        let deviceType: String = {
            #if targetEnvironment(macCatalyst)
            return "desktop"
            #else
            switch UIDevice.current.userInterfaceIdiom {
            case .phone:
                return "phone"
            case .pad:
                return "tablet"
            case .tv:
                return "tv"
            default:
                return "other"
            }
            #endif
        }()
        let deviceModel = UIDevice.current.model
        let systemName = UIDevice.current.systemName
        let systemVersion = UIDevice.current.systemVersion
        let identifier = UIDevice.current.identifierForVendor?.uuidString ?? ""
        let canBeControlled = true // Par défaut, on permet le contrôle
        // Vérifie si le device existe déjà dans `devices`
        let deviceData: [String: Any] = [
            "name": deviceName,
            "type": deviceType,
            "model": deviceModel,
            "systemName": systemName,
            "systemVersion": systemVersion,
            "identifier": identifier,
            "canBeControlled": canBeControlled,
        ]
        print("Detected device: \(deviceData)")
        if !devices.contains(where: { $0.name == deviceName }) {

            do {
                print("Registering device")
                _ = try await APIService.shared.createDevice(deviceData)
            } catch {
                print("Device registration failed: \(error)")
            }
        }
    }

    private func loadDevices() async {
        isLoading = true
        
        do {
            // Load user's devices
            devices = try await APIService.shared.getDevices()

            // Met à jour le status du device courant s'il est dans la liste
            let currentIdentifier = UIDevice.current.identifierForVendor?.uuidString ?? ""
            if let index = devices.firstIndex(where: { $0.identifier == currentIdentifier }) {
                devices[index].status = .online
            }
            
            // Load delegated devices
            delegatedDevices = try await APIService.shared.getDelegatedDevices()
        } catch {
            print("Failed to load devices: \(error)")
        }
        
        isLoading = false
    }
}

// MARK: - Device Tab
enum DeviceTab: CaseIterable {
    case myDevices, delegated
}

// MARK: - My Devices View
struct MyDevicesView: View {
    let devices: [Device]
    let onRefresh: () async -> Void
    var viewModel: DevicesViewModel
    var onDelegationRevoked: ((Device) -> Void)?

    var body: some View {
        if devices.isEmpty {
            EmptyStateView(
                icon: "speaker.wave.3",
                title: "No Devices",
                message: "Add your first device to start controlling music remotely.",
                buttonTitle: "add_device".localized,
                buttonAction: { /* Add device action */ }
            )
        } else {
            List(devices) { device in
                DeviceListItem(device: device, viewModel: viewModel, onDelegationRevoked: onDelegationRevoked)
                    .listRowInsets(EdgeInsets(top: 8, leading: 20, bottom: 8, trailing: 20))
                    .listRowBackground(Color.clear)
            }
            .listStyle(PlainListStyle())
            .refreshable {
                await onRefresh()
            }
        }
    }
}

// MARK: - Delegated Devices View
struct DelegatedDevicesView: View {
    let devices: [Device]
    let onRefresh: () async -> Void
    
    var body: some View {
        if devices.isEmpty {
            EmptyStateView(
                icon: "person.2.wave.2",
                title: "No Delegated Devices",
                message: "You don't have control over any devices yet. Ask friends to delegate control to you!",
                buttonTitle: nil,
                buttonAction: nil
            )
        } else {
            List(devices) { device in
                DelegatedDeviceListItem(device: device)
                    .listRowInsets(EdgeInsets(top: 8, leading: 20, bottom: 8, trailing: 20))
                    .listRowBackground(Color.clear)
            }
            .listStyle(PlainListStyle())
            .refreshable {
                await onRefresh()
            }
        }
    }
}

// MARK: - Device List Item
struct DeviceListItem: View {
    let device: Device
    var viewModel: DevicesViewModel
    @State private var showingControls = false
    @State private var showingDelegationSheet = false
    @State private var isRevoking = false
    @State private var errorMessage: String?
    @EnvironmentObject var authManager: AuthenticationManager
    @Environment(\.refresh) private var refresh
    var onDelegationRevoked: ((Device) -> Void)?

    var body: some View {
        CardView {
            VStack(spacing: 12) {
                HStack {
                    // Device Icon
                    Image(systemName: device.type.iconName)
                        .font(.system(size: 24))
                        .foregroundColor(.musicPrimary)
                        .frame(width: 40, height: 40)
                        .background(Color.musicBackground.opacity(0.3))
                        .clipShape(Circle())
                    // Device Info
                    VStack(alignment: .leading, spacing: 4) {
                        Text(device.name)
                            .font(.headline)
                            .foregroundColor(.textPrimary)
                        Text(device.type.localizedString)
                            .font(.caption)
                            .foregroundColor(.textSecondary)
                    }
                    Spacer()
                    // Status IN/offline...
                    VStack(alignment: .trailing, spacing: 4) {
                        // StatusIndicator(status: device.status) // TO DO: Ne fonctionne pas bien encore
                        Text("Last seen: \(device.lastSeen.formatParisDate())")
                            .font(.caption)
                            .foregroundColor(.textSecondary)
                    }
                }
                // Device Controls
                if device.canBeControlled && device.delegatedToId == nil /* && device.isActive */ {
                    Divider()
                    HStack(spacing: 16) {
                        /* DeviceControlButton(
                            icon: "play.fill",
                            action: { /* Play action */ }
                        )
                        DeviceControlButton(
                            icon: "pause.fill",
                            action: { /* Pause action */ }
                        )
                        DeviceControlButton(
                            icon: "forward.fill",
                            action: { /* Skip action */ }
                        )
                        Spacer() */
                        Button(action: {
                            showingDelegationSheet = true
                        }) {
                            Text("delegate_control".localized)
                                .font(.caption)
                                .foregroundColor(.musicPrimary)
                        }
                        .buttonStyle(PlainButtonStyle())
                    }
                }
                // Delegation Info
                if device.delegatedToId != nil {
                    Divider()
                    HStack {
                        Image(systemName: "person.crop.circle.badge.checkmark")
                            .foregroundColor(.green)
                        Text("Delegated to \(device.delegatedTo?.displayName ?? "User")")
                            .font(.caption)
                            .foregroundColor(.textSecondary)
                        Spacer()
                        if let expiresAt = device.delegationExpiresAt {
                            Text("Expires: \(expiresAt.formatParisDate())")
                                .font(.caption)
                                .foregroundColor(.textSecondary)
                        }
                    }
                    // Bouton pour révoquer la délégation
                    Button(role: .destructive, action: { revokeDelegation() }) {
                        if isRevoking {
                            ProgressView()
                        } else {
                            Label("Revoke Delegation", systemImage: "xmark.circle")
                        }
                    }
                    .disabled(isRevoking)
                    .buttonStyle(PlainButtonStyle())

                    if let error = errorMessage {
                        Text(error).foregroundColor(.red).font(.caption)
                    }

                    if device.delegatedToId != nil {
                        Button("Voir utilisateurs connectés") {
                            print("button pushed: \(device.id)")
                            viewModel.getConnectedDevices(device.id)
                            // DevicesSocketService.shared.emit("get-device-connections", with: [["deviceId": device.id]])
                        }
                        .font(.caption)
                        .foregroundColor(.blue)
                        .buttonStyle(PlainButtonStyle())
                    }

                    Button("whichRoomsAmIIn") {
                        print("button whichRoomsAmIIn pushed")
                        viewModel.devicesSocket.whichRoomsAmIIn()
                        // DevicesSocketService.shared.emit("get-device-connections", with: [["deviceId": device.id]])
                    }
                    .font(.caption)
                    .foregroundColor(.blue)
                    .buttonStyle(PlainButtonStyle())
                }
            }
        }
        .sheet(isPresented: $showingDelegationSheet) {
            DelegateControlView(device: device)
        }
    }

    private func revokeDelegation() {
        isRevoking = true
        errorMessage = nil
        Task {
            do {
                print("Revoking delegation for device \(device.id)")
                _ = try await APIService.shared.revokeDeviceDelegation(device.id)
                isRevoking = false
                onDelegationRevoked?(device)
                await refresh?()
            } catch {
                errorMessage = error.localizedDescription
                isRevoking = false
            }
        }
    }
}

// MARK: - Delegated Device List Item
struct DelegatedDeviceListItem: View {
    let device: Device
    var body: some View {
        CardView {
            VStack(spacing: 12) {
                HStack {
                    // Device Icon
                    Image(systemName: device.type.iconName)
                        .font(.system(size: 24))
                        .foregroundColor(.musicSecondary)
                        .frame(width: 40, height: 40)
                        .background(Color.musicSecondary.opacity(0.2))
                        .clipShape(Circle())
                    // Device Info
                    VStack(alignment: .leading, spacing: 4) {
                        Text(device.name)
                            .font(.headline)
                            .foregroundColor(.textPrimary)
                        Text("Owned by \(device.owner?.displayName ?? "User")")
                            .font(.caption)
                            .foregroundColor(.textSecondary)
                    }
                    Spacer()
                    // Status and Delegation Info
                    VStack(alignment: .trailing, spacing: 4) {
                        // StatusIndicator(status: device.status) // TO DO: Ne fonctionne pas bien encore
                        if let expiresAt = device.delegationExpiresAt {
                            Text("Until \(formatTime(expiresAt))")
                                .font(.caption)
                                .foregroundColor(.orange)
                        }
                    }
                }
                // Music Controls
                if device.canBeControlled && device.isActive {
                    Divider()
                    MusicControlsView(device: device)
                }
            }
        }
    }

    private func formatTime(_ timeString: String) -> String {
        // Format expiration time
        return timeString
    }
}

// MARK: - Status Indicator
struct StatusIndicator: View {
    let status: DeviceStatus
    
    var body: some View {
        HStack(spacing: 4) {
            Circle()
                .fill(statusColor)
                .frame(width: 8, height: 8)
            
            Text(status.localizedString)
                .font(.caption)
                .foregroundColor(.textSecondary)
        }
    }
    
    private var statusColor: Color {
        switch status {
        case .online, .playing:
            return .green
        case .paused:
            return .orange
        case .offline:
            return .gray
        case .error:
            return .red
        }
    }
}

// MARK: - Device Control Button
struct DeviceControlButton: View {
    let icon: String
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            Image(systemName: icon)
                .font(.system(size: 16))
                .foregroundColor(.white)
                .frame(width: 36, height: 36)
                .background(Color.musicPrimary)
                .clipShape(Circle())
        }
    }
}

// MARK: - Music Controls View
struct MusicControlsView: View {
    let device: Device
    @State private var isLoading = false
    @State private var errorMessage: String?
    @State private var volume: Double = 0.5

    var body: some View {
        VStack(spacing: 12) {
            // Control Buttons
            HStack(spacing: 20) {
                DeviceControlButton(
                    icon: "backward.fill",
                    action: previousTrack
                )
                DeviceControlButton(
                    icon: device.status == .playing ? "pause.fill" : "play.fill",
                    action: playPause
                )
                DeviceControlButton(
                    icon: "forward.fill",
                    action: nextTrack
                )
                Spacer()
                // Volume Control
                HStack {
                    Image(systemName: "speaker.wave.1")
                        .foregroundColor(.textSecondary)
                    Slider(value: $volume, in: 0...1, step: 0.01, onEditingChanged: { editing in
                        if !editing { setVolume() }
                    })
                        .accentColor(.musicPrimary)
                        .frame(width: 80)
                    Image(systemName: "speaker.wave.3")
                        .foregroundColor(.textSecondary)
                }
            }
            if let error = errorMessage {
                Text(error).foregroundColor(.red).font(.caption)
            }
        }
    }

    private func playPause() {
        isLoading = true
        errorMessage = nil
        Task {
            do {
                if device.status == .playing {
                    // _ = try await APIService.shared.pauseDevice(device.id)
                } else {
                    // _ = try await APIService.shared.playDevice(device.id)
                }
                isLoading = false
            } catch {
                errorMessage = error.localizedDescription
                isLoading = false
            }
        }
    }

    private func nextTrack() {
        isLoading = true
        errorMessage = nil
        Task {
            do {
                // _ = try await APIService.shared.nextTrackOnDevice(device.id)
                isLoading = false
            } catch {
                errorMessage = error.localizedDescription
                isLoading = false
            }
        }
    }

    private func previousTrack() {
        isLoading = true
        errorMessage = nil
        Task {
            do {
                // _ = try await APIService.shared.previousTrackOnDevice(device.id)
                isLoading = false
            } catch {
                errorMessage = error.localizedDescription
                isLoading = false
            }
        }
    }

    private func setVolume() {
        isLoading = true
        errorMessage = nil
        Task {
            do {
                // _ = try await APIService.shared.setDeviceVolume(device.id, volume)
                isLoading = false
            } catch {
                errorMessage = error.localizedDescription
                isLoading = false
            }
        }
    }
}

// MARK: - Add Device View (Form)
struct AddDeviceView: View {
    @Environment(\.dismiss) private var dismiss
    @State private var name: String = ""
    @State private var type: DeviceType = .speaker
    @State private var isSaving = false
    @State private var errorMessage: String?

    var body: some View {
        NavigationView {
            Form {
                Section(header: Text("Device Info")) {
                    TextField("Name", text: $name)
                    Picker("Type", selection: $type) {
                        ForEach(DeviceType.allCases, id: \.self) { t in
                            Text(t.localizedString).tag(t)
                        }
                    }
                }
                if let error = errorMessage {
                    Section {
                        Text(error).foregroundColor(.red)
                    }
                }
            }
            .navigationTitle("add_device".localized)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("cancel".localized) { dismiss() }
                }
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Save") {
                        saveDevice()
                    }
                    .disabled(isSaving || name.isEmpty)
                }
            }
        }
    }

    private func saveDevice() {
        isSaving = true
        errorMessage = nil
        let deviceData: [String: Any] = [
            "name": name,
            "type": type.rawValue
        ]
        Task {
            do {
                _ = try await APIService.shared.createDevice(deviceData)
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

// MARK: - Delegate Control View (Form for Delegation)
struct DelegateControlView: View {
    let device: Device
    @Environment(\.dismiss) private var dismiss
    @State private var selectedFriendId: String = ""
    @State private var friends: [User] = []
    @State private var expiresAt: Date = Calendar.current.date(byAdding: .day, value: 1, to: Date()) ?? Date()
    @State private var canPlay = true
    @State private var canPause = true
    @State private var canSkip = true
    @State private var canChangeVolume = false
    @State private var canChangePlaylist = false
    @State private var isSaving = false
    @State private var errorMessage: String?

    /* @EnvironmentObject var authManager: AuthenticationManager
    @State private var isRevoking = false


    private func revokeDelegation() {
        isRevoking = true
        errorMessage = nil
        Task {
            do {
                _ = try await APIService.shared.revokeDeviceDelegation(device.id)
                // Optionnel: rafraîchir la liste des devices après révocation
                isRevoking = false
            } catch {
                errorMessage = error.localizedDescription
                isRevoking = false
            }
        }
    } */

    var body: some View {
        NavigationView {
            Form {
                Section(header: Text("Select Friend")) {
                    Picker("Friend", selection: $selectedFriendId) {
                        ForEach(friends) { friend in
                            Text(friend.displayName).tag(friend.id)
                        }
                    }
                }
                Section(header: Text("Permissions")) {
                    Toggle("Play", isOn: $canPlay)
                    Toggle("Pause", isOn: $canPause)
                    Toggle("Skip", isOn: $canSkip)
                    Toggle("Change Volume", isOn: $canChangeVolume)
                    Toggle("Change Playlist", isOn: $canChangePlaylist)
                }
                Section(header: Text("Expiration")) {
                    DatePicker("Expires At", selection: $expiresAt, in: Date()..., displayedComponents: .date)
                }
                if let error = errorMessage {
                    Section {
                        Text(error).foregroundColor(.red)
                    }
                }
            }
            .navigationTitle("delegate_control".localized)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("cancel".localized) { dismiss() }
                }
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Delegate") { delegateDevice() }
                        .disabled(isSaving || selectedFriendId.isEmpty)
                }
            }
            .onAppear { loadFriends() }
            // Bouton pour révoquer la délégation
            /* if let currentUserId = authManager.currentUser?.id, device.delegatedToId == currentUserId {
                Divider()
                Button(role: .destructive, action: { revokeDelegation() }) {
                    if isRevoking {
                        ProgressView()
                    } else {
                        Label("Revoke Delegation", systemImage: "xmark.circle")
                    }
                }
                .disabled(isRevoking)
                if let error = errorMessage {
                    Text(error).foregroundColor(.red).font(.caption)
                }
            } */
        }
    }

    private func loadFriends() {
        // À remplacer par un vrai appel API pour récupérer les amis
        Task {
            do {
                friends = try await APIService.shared.getUserFriends()
                if let first = friends.first { selectedFriendId = first.id }
            } catch {
                errorMessage = "Failed to load friends: \(error.localizedDescription)"
            }
        }
    }

    private func delegateDevice() {
        isSaving = true
        errorMessage = nil
        let permissions: [String: Bool] = [
            "canPlay": canPlay,
            "canPause": canPause,
            "canSkip": canSkip,
            "canChangeVolume": canChangeVolume,
            "canChangePlaylist": canChangePlaylist
        ]
        let payload: [String: Any] = [
            "delegatedToId": selectedFriendId,
            "delegationExpiresAt": ISO8601DateFormatter().string(from: expiresAt),
            "delegationPermissions": permissions
        ]
        Task {
            do {
                _ = try await APIService.shared.delegateDevice(device.id, payload)
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

// MARK: - Delegate Control View (Placeholder)
/* struct DelegateControlView: View {
    let device: Device
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        NavigationView {
            VStack {
                Text("Delegate Control")
                    .font(.title)
                Text("Device delegation form for \(device.name)")
                    .foregroundColor(.textSecondary)
                Spacer()
            }
            .padding()
            .navigationTitle("delegate_control".localized)
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
} */

#Preview {
    DevicesView()
        .environmentObject(ThemeManager())
        .environmentObject(LocalizationManager())
}
