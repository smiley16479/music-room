import SwiftUI

struct DevicesView: View {
    @State private var devices: [Device] = []
    @State private var delegatedDevices: [Device] = []
    @State private var isLoading = false
    @State private var showingAddDevice = false
    @State private var selectedTab: DeviceTab = .myDevices
    
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
                        MyDevicesView(devices: devices, onRefresh: loadDevices)
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
        .sheet(isPresented: $showingAddDevice) {
            AddDeviceView()
        }
        .task {
            await loadDevices()
        }
        .refreshable {
            await loadDevices()
        }
    }
    
    private func loadDevices() async {
        isLoading = true
        
        do {
            // Load user's devices
            devices = try await APIService.shared.getDevices()
            
            // Load delegated devices
            // delegatedDevices = try await APIService.shared.getDelegatedDevices()
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
                DeviceListItem(device: device)
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
    @State private var showingControls = false
    @State private var showingDelegationSheet = false
    
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
                    
                    // Status
                    VStack(alignment: .trailing, spacing: 4) {
                        StatusIndicator(status: device.status)
                        
                        Text(formatLastSeen(device.lastSeen))
                            .font(.caption)
                            .foregroundColor(.textSecondary)
                    }
                }
                
                // Device Controls
                if device.canBeControlled && device.isActive {
                    Divider()
                    
                    HStack(spacing: 16) {
                        DeviceControlButton(
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
                        
                        Spacer()
                        
                        Button(action: {
                            showingDelegationSheet = true
                        }) {
                            Text("delegate_control".localized)
                                .font(.caption)
                                .foregroundColor(.musicPrimary)
                        }
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
                            Text("Expires: \(formatDate(expiresAt))")
                                .font(.caption)
                                .foregroundColor(.textSecondary)
                        }
                    }
                }
            }
        }
        .sheet(isPresented: $showingDelegationSheet) {
            DelegateControlView(device: device)
        }
    }
    
    private func formatLastSeen(_ lastSeen: String) -> String {
        // Format last seen time
        return "Last seen: \(lastSeen)"
    }
    
    private func formatDate(_ dateString: String) -> String {
        // Format date string
        return dateString
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
                        StatusIndicator(status: device.status)
                        
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
    
    var body: some View {
        VStack(spacing: 12) {
            // Currently Playing (if any)
            // This would show current track info
            
            // Control Buttons
            HStack(spacing: 20) {
                DeviceControlButton(
                    icon: "backward.fill",
                    action: { /* Previous track */ }
                )
                
                DeviceControlButton(
                    icon: device.status == .playing ? "pause.fill" : "play.fill",
                    action: { /* Play/Pause */ }
                )
                
                DeviceControlButton(
                    icon: "forward.fill",
                    action: { /* Next track */ }
                )
                
                Spacer()
                
                // Volume Control
                HStack {
                    Image(systemName: "speaker.wave.1")
                        .foregroundColor(.textSecondary)
                    
                    Slider(value: .constant(0.5))
                        .accentColor(.musicPrimary)
                        .frame(width: 80)
                    
                    Image(systemName: "speaker.wave.3")
                        .foregroundColor(.textSecondary)
                }
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

// MARK: - Delegate Control View (Placeholder)
struct DelegateControlView: View {
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
}

#Preview {
    DevicesView()
        .environmentObject(ThemeManager())
        .environmentObject(LocalizationManager())
}
