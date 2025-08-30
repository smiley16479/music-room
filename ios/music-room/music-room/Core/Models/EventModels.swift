import Foundation

// MARK: - Vote Models
struct VoteResult: Codable, Identifiable {
    let id: String?
    let trackId: String
    let userId: String
    let type: VoteType
    let createdAt: String
    let track: Track?
    let user: User?
    
    enum VoteType: String, Codable {
        case like = "upvote"
        case dislike = "downvote"
    }
}

// MARK: - Track Suggestion Models
struct TrackSuggestion: Codable, Identifiable {
    let id: String
    let eventId: String
    let trackData: SuggestedTrackData
    let suggestedBy: User
    let status: SuggestionStatus
    let createdAt: String
    let approvedBy: User?
    let approvedAt: String?
    
    enum SuggestionStatus: String, Codable {
        case pending = "pending"
        case approved = "approved"
        case rejected = "rejected"
    }
}

struct SuggestedTrackData: Codable {
    let title: String
    let artist: String
    let album: String?
    let duration: Int
    let albumCoverUrl: String?
    let previewUrl: String?
    let deezerId: String?
    let spotifyId: String?
}

// MARK: - Event Playlist Models
struct EventPlaylist: Codable {
    let id: String
    let eventId: String
    let tracks: [PlaylistTrack]
    let currentTrack: Track?
    let currentPosition: Double?
    let isPlaying: Bool
    let createdAt: String
    let updatedAt: String
}

// MARK: - Now Playing Models
struct NowPlayingResponse: Codable {
    let success: Bool
    let currentTrack: Track?
    let position: Double?
    let isPlaying: Bool
    let nextTrack: Track?
    let previousTrack: Track?
}

// MARK: - Playback State Models
struct PlaybackStateResponse: Codable {
    let success: Bool
    let isPlaying: Bool
    let position: Double?
    let timestamp: String
    let currentTrack: Track?
}

// MARK: - Event Participation Models
struct EventParticipation: Codable {
    let id: String
    let eventId: String
    let userId: String
    let role: ParticipantRole
    let joinedAt: String
    let leftAt: String?
    let isActive: Bool
    
    enum ParticipantRole: String, Codable {
        case participant = "participant"
        case admin = "admin"
        case dj = "dj"
        case creator = "creator"
    }
}

// MARK: - Event Message Models
struct EventMessage: Codable, Identifiable {
    let id: String
    let eventId: String
    let content: String
    let type: MessageType
    let author: User
    let createdAt: String
    let metadata: MessageMetadata?
    
    enum MessageType: String, Codable {
        case text = "text"
        case system = "system"
        case trackSuggestion = "track_suggestion"
        case trackChange = "track_change"
        case userJoin = "user_join"
        case userLeave = "user_leave"
    }
}

struct MessageMetadata: Codable {
    let trackId: String?
    let userId: String?
    let action: String?
    let data: [String: AnyCodable]?
}

// MARK: - Socket Event Models
struct SocketEventData: Codable {
    let type: String
    let eventId: String
    let data: [String: AnyCodable]
    let timestamp: String
    let userId: String?
}

// MARK: - Real-time Update Models
struct VoteUpdateData: Codable {
    let eventId: String
    let trackId: String
    let vote: VoteResult
    let totalLikes: Int
    let totalDislikes: Int
    let voteScore: Int
}

struct TrackChangeData: Codable {
    let eventId: String
    let previousTrack: Track?
    let currentTrack: Track?
    let nextTrack: Track?
    let position: Double
    let isPlaying: Bool
    let timestamp: String
}

struct UserJoinLeaveData: Codable {
    let eventId: String
    let user: User
    let action: String // "join" ou "leave"
    let participantCount: Int
    let timestamp: String
}

struct PlaybackStateUpdateData: Codable {
    let eventId: String
    let isPlaying: Bool
    let position: Double
    let currentTrack: Track?
    let timestamp: String
}

struct TrackSuggestionUpdateData: Codable {
    let eventId: String
    let suggestion: TrackSuggestion
    let action: String // "suggested", "approved", "rejected"
    let timestamp: String
}

// MARK: - Helper for Any Codable Values
struct AnyCodable: Codable {
    let value: Any
    
    init<T>(_ value: T?) {
        self.value = value ?? ()
    }
    
    init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        
        if container.decodeNil() {
            value = ()
        } else if let bool = try? container.decode(Bool.self) {
            value = bool
        } else if let int = try? container.decode(Int.self) {
            value = int
        } else if let double = try? container.decode(Double.self) {
            value = double
        } else if let string = try? container.decode(String.self) {
            value = string
        } else if let array = try? container.decode([AnyCodable].self) {
            value = array.map { $0.value }
        } else if let dictionary = try? container.decode([String: AnyCodable].self) {
            value = dictionary.mapValues { $0.value }
        } else {
            throw DecodingError.dataCorruptedError(in: container, debugDescription: "AnyCodable value cannot be decoded")
        }
    }
    
    func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        
        switch value {
        case is Void:
            try container.encodeNil()
        case let bool as Bool:
            try container.encode(bool)
        case let int as Int:
            try container.encode(int)
        case let double as Double:
            try container.encode(double)
        case let string as String:
            try container.encode(string)
        case let array as [Any]:
            try container.encode(array.map { AnyCodable($0) })
        case let dictionary as [String: Any]:
            try container.encode(dictionary.mapValues { AnyCodable($0) })
        default:
            let context = EncodingError.Context(codingPath: container.codingPath, debugDescription: "AnyCodable value cannot be encoded")
            throw EncodingError.invalidValue(value, context)
        }
    }
}
