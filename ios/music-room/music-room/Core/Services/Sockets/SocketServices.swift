import Foundation
import SocketIO

protocol NamespaceSocketService {
    var manager: SocketManager { get }
    var socket: SocketIOClient { get }
    func connect()
    func disconnect()
    func on(_ event: String, callback: @escaping ([Any], SocketAckEmitter) -> Void)
    func emit(_ event: String, with items: [Any])
}

// MARK: - Events Namespace
class EventsSocketService: NamespaceSocketService {
    static let shared = EventsSocketService()
    let manager: SocketManager
    let socket: SocketIOClient

    private var isConnected = false
    private var joinedRooms: Set<String> = []

    private init() {
        let url = URL(string: "http://localhost:3000/events")!
        let token = KeychainService.shared.getAccessToken() ?? ""
        print("🚀 Initializing EventsSocketService with token: \(token)")
        manager = SocketManager(socketURL: url, config: [/* .log(true), */ .compress, .connectParams(["token": token]), .extraHeaders(["Authorization": "Bearer \(token)"])])
        socket = manager.socket(forNamespace: "/events")

        connect()
        setupConnectionListeners()
    }

    private func setupConnectionListeners() {
        socket.on("connect") { [weak self] data, ack in
            print("✅ EventsSocket connected")
            self?.isConnected = true
        }
        
        socket.on("disconnect") { [weak self] data, ack in
            print("❌ EventsSocket disconnected")
            self?.isConnected = false
            self?.joinedRooms.removeAll()
        }
    }

    func connect() { 
        guard !isConnected else {
            print("🔌 EventsSocket already connected")
            return
        }
        socket.connect()
        print("✅ EventsSocket connection initiated")
    }
    
    func disconnect() { 
        socket.disconnect()
        isConnected = false
        joinedRooms.removeAll()
    }
    
    func on(_ event: String, callback: @escaping ([Any], SocketAckEmitter) -> Void) { socket.on(event, callback: callback) }
    func emit(_ event: String, with items: [Any]) { socket.emit(event, items) }
}

// MARK: - Playlists Namespace
class PlaylistsSocketService: NamespaceSocketService {
    static let shared = PlaylistsSocketService()
    let manager: SocketManager
    let socket: SocketIOClient

    private init() {
        let url = URL(string: "http://localhost:3000/playlists")!
        let token = KeychainService.shared.getAccessToken() ?? ""
        manager = SocketManager(socketURL: url, config: [.log(true), .compress, .extraHeaders(["Authorization": "Bearer \(token)"])])
        socket = manager.socket(forNamespace: "/playlists")
    }

    func connect() { socket.connect() }
    func disconnect() { socket.disconnect() }
    func on(_ event: String, callback: @escaping ([Any], SocketAckEmitter) -> Void) { socket.on(event, callback: callback) }
    func emit(_ event: String, with items: [Any]) { socket.emit(event, items) }
}

// MARK: - Devices Namespace
class DevicesSocketService: NamespaceSocketService {
    static let shared = DevicesSocketService()
    let manager: SocketManager
    let socket: SocketIOClient

    private init() {
        let url = URL(string: "http://localhost:3000/devices")!
        let token = KeychainService.shared.getAccessToken() ?? ""
        manager = SocketManager(socketURL: url, config: [.log(true), .compress, .extraHeaders(["Authorization": "Bearer \(token)"])])
        socket = manager.socket(forNamespace: "/devices")
    }

    func connect() { socket.connect() }
    func disconnect() { socket.disconnect() }
    func on(_ event: String, callback: @escaping ([Any], SocketAckEmitter) -> Void) { socket.on(event, callback: callback) }
    func emit(_ event: String, with items: [Any]) { socket.emit(event, items) }
}

// MARK: - EventsSocketService: Events Gateway Events
extension EventsSocketService {

    func joinEvent(eventId: String) {
        guard !joinedRooms.contains(eventId) else {
            print("🏠 Already in event: \(eventId)")
            return
        }
        print("🏠 Attempting to join event room: \(eventId)")
        if !isConnected {
            socket.once("connect") { [weak self] _, _ in
                self?.emit("join-events-room", with: [["eventId": eventId]])
                self?.joinedRooms.insert(eventId)
            }
            connect()
        } else {
            emit("join-events-room", with: [["eventId": eventId]])
            joinedRooms.insert(eventId)
        }
    }

    func leaveEvent(eventId: String) {
        guard joinedRooms.contains(eventId) else {
            print("🚪 Not in event: \(eventId)")
            return
        }

        emit("leave-event", with: [["eventId": eventId]])
        joinedRooms.remove(eventId)
    }

    func test() {
        emit("test", with: [[ "message": "message"]])
    }

    func sendMessage(eventId: String, message: String) {
        emit("send-message", with: [["eventId": eventId, "message": message]])
    }
    func suggestTrack(eventId: String, trackId: String, trackData: [String: Any]) {
        emit("suggest-track", with: [["eventId": eventId, "trackId": trackId, "trackData": trackData]])
    }
    func updateLocation(eventId: String, latitude: Double, longitude: Double) {
        emit("update-location", with: [["eventId": eventId, "location": ["latitude": latitude, "longitude": longitude]]])
    }
    func onUserJoined(callback: @escaping ([Any], SocketAckEmitter) -> Void) {
        on("user-joined", callback: callback)
    }
    func onUserLeft(callback: @escaping ([Any], SocketAckEmitter) -> Void) {
        on("user-left", callback: callback)
    }
    func onNewMessage(callback: @escaping ([Any], SocketAckEmitter) -> Void) {
        on("new-message", callback: callback)
    }
    func onTrackSuggested(callback: @escaping ([Any], SocketAckEmitter) -> Void) {
        on("track-suggested", callback: callback)
    }
    func onEventUpdated(callback: @escaping ([Any], SocketAckEmitter) -> Void) {
        on("event-updated", callback: callback)
    }
    func onNowPlaying(callback: @escaping ([Any], SocketAckEmitter) -> Void) {
        on("now-playing", callback: callback)
    }
    func onTrackEnded(callback: @escaping ([Any], SocketAckEmitter) -> Void) {
        on("track-ended", callback: callback)
    }
}

// MARK: - PlaylistsSocketService: Playlists Gateway Events
extension PlaylistsSocketService {
    func joinPlaylist(playlistId: String) {
        emit("join-playlist", with: [["playlistId": playlistId]])
    }
    func leavePlaylist(playlistId: String) {
        emit("leave-playlist", with: [["playlistId": playlistId]])
    }
    func sendPlaylistMessage(playlistId: String, message: String) {
        emit("send-playlist-message", with: [["playlistId": playlistId, "message": message]])
    }
    func startTrackOperation(playlistId: String, operation: String, trackId: String? = nil, position: Int? = nil) {
        var payload: [String: Any] = ["playlistId": playlistId, "operation": operation]
        if let trackId = trackId { payload["trackId"] = trackId }
        if let position = position { payload["position"] = position }
        emit("start-track-operation", with: [[payload]])
    }
    func trackDragPreview(playlistId: String, trackId: String, fromPosition: Int, toPosition: Int) {
        emit("track-drag-preview", with: [["playlistId": playlistId, "trackId": trackId, "fromPosition": fromPosition, "toPosition": toPosition]])
    }
    func cancelTrackOperation(playlistId: String, operation: String) {
        emit("cancel-track-operation", with: [["playlistId": playlistId, "operation": operation]])
    }
    func updateEditingStatus(playlistId: String, isEditing: Bool, editingTrackId: String? = nil) {
        var payload: [String: Any] = ["playlistId": playlistId, "isEditing": isEditing]
        if let editingTrackId = editingTrackId { payload["editingTrackId"] = editingTrackId }
        emit("update-editing-status", with: [[payload]])
    }
    func onCollaboratorJoined(callback: @escaping ([Any], SocketAckEmitter) -> Void) {
        on("collaborator-joined", callback: callback)
    }
    func onCollaboratorLeft(callback: @escaping ([Any], SocketAckEmitter) -> Void) {
        on("collaborator-left", callback: callback)
    }
    func onNewPlaylistMessage(callback: @escaping ([Any], SocketAckEmitter) -> Void) {
        on("new-playlist-message", callback: callback)
    }
    func onTrackAdded(callback: @escaping ([Any], SocketAckEmitter) -> Void) {
        on("track-added", callback: callback)
    }
    func onTrackRemoved(callback: @escaping ([Any], SocketAckEmitter) -> Void) {
        on("track-removed", callback: callback)
    }
    func onTracksReordered(callback: @escaping ([Any], SocketAckEmitter) -> Void) {
        on("tracks-reordered", callback: callback)
    }
    func onPlaylistUpdated(callback: @escaping ([Any], SocketAckEmitter) -> Void) {
        on("playlist-updated", callback: callback)
    }
}

// MARK: - DevicesSocketService: Devices Gateway Events
extension DevicesSocketService {
    func connectDevice(deviceId: String, deviceInfo: [String: Any]? = nil) {
        emit("connect-device", with: [["deviceId": deviceId, "deviceInfo": deviceInfo ?? [:]]])
    }
    func disconnectDevice(deviceId: String) {
        emit("disconnect-device", with: [["deviceId": deviceId]])
    }
    func updateDeviceStatus(deviceId: String, status: String, metadata: [String: Any]? = nil) {
        emit("update-device-status", with: [["deviceId": deviceId, "status": status, "metadata": metadata ?? [:]]])
    }
    func sendPlaybackState(deviceId: String, state: [String: Any]) {
        emit("playback-state", with: [["deviceId": deviceId, "state": state]])
    }
    func requestDeviceInfo(deviceId: String) {
        emit("request-device-info", with: [["deviceId": deviceId]])
    }
    func onDeviceConnected(callback: @escaping ([Any], SocketAckEmitter) -> Void) {
        on("device-connected", callback: callback)
    }
    func onDeviceDisconnected(callback: @escaping ([Any], SocketAckEmitter) -> Void) {
        on("device-disconnected", callback: callback)
    }
    func onDeviceStatusUpdated(callback: @escaping ([Any], SocketAckEmitter) -> Void) {
        on("device-status-updated", callback: callback)
    }
    func onPlaybackStateUpdated(callback: @escaping ([Any], SocketAckEmitter) -> Void) {
        on("playback-state-updated", callback: callback)
    }
    func onDeviceInfoReceived(callback: @escaping ([Any], SocketAckEmitter) -> Void) {
        on("device-info-received", callback: callback)
    }
}
