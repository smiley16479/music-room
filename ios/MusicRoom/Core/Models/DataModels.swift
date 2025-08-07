import Foundation

// MARK: - Track Model
struct Track: Codable, Identifiable {
    let id: String
    let deezerId: String?
    let title: String
    let artist: String
    let album: String
    let duration: Int // Duration in seconds
    let previewUrl: String?
    let albumCoverUrl: String?
    let albumCoverSmallUrl: String?
    let albumCoverMediumUrl: String?
    let albumCoverBigUrl: String?
    let deezerUrl: String?
    let genres: [String]?
    let releaseDate: String?
    let available: Bool
    let createdAt: String
    let updatedAt: String
    
    var formattedDuration: String {
        let minutes = duration / 60
        let seconds = duration % 60
        return String(format: "%d:%02d", minutes, seconds)
    }
}

// MARK: - Event Model
struct Event: Codable, Identifiable {
    let id: String
    let name: String
    let description: String?
    let visibility: VisibilityLevel
    let licenseType: LicenseType
    let status: EventStatus
    let latitude: Double?
    let longitude: Double?
    let locationRadius: Double?
    let locationName: String?
    let votingStartTime: String?
    let votingEndTime: String?
    let eventDate: String?
    let eventEndDate: String?
    let currentTrackId: String?
    let currentTrackStartedAt: String?
    let maxVotesPerUser: Int?
    let createdAt: String
    let updatedAt: String
    let creatorId: String
    let creator: User?
    let participants: [User]?
    let playlist: [Track]?
}

enum EventStatus: String, Codable, CaseIterable {
    case draft = "draft"
    case active = "active"
    case paused = "paused"
    case ended = "ended"
    
    var localizedString: String {
        switch self {
        case .draft:
            return "draft".localized
        case .active:
            return "active".localized
        case .paused:
            return "paused".localized
        case .ended:
            return "ended".localized
        }
    }
}

// MARK: - Playlist Model
struct Playlist: Codable, Identifiable {
    let id: String
    let name: String
    let description: String?
    let visibility: VisibilityLevel
    let licenseType: LicenseType
    let coverImageUrl: String?
    let isCollaborative: Bool
    let totalDuration: Int?
    let trackCount: Int
    let createdAt: String
    let updatedAt: String
    let creatorId: String
    let creator: User?
    let collaborators: [User]?
    let tracks: [PlaylistTrack]?
    
    var formattedDuration: String? {
        guard let totalDuration = totalDuration else { return nil }
        let hours = totalDuration / 3600
        let minutes = (totalDuration % 3600) / 60
        
        if hours > 0 {
            return String(format: "%d:%02d:00", hours, minutes)
        } else {
            return String(format: "%d:00", minutes)
        }
    }
}

struct PlaylistTrack: Codable, Identifiable {
    let id: String
    let position: Int
    let addedAt: String
    let createdAt: String
    let addedById: String
    let playlistId: String
    let trackId: String
    let track: Track?
    let addedBy: User?
}

// MARK: - Device Model
struct Device: Codable, Identifiable {
    let id: String
    let name: String
    let type: DeviceType
    let status: DeviceStatus
    let deviceInfo: String?
    let lastSeen: String
    let isActive: Bool
    let canBeControlled: Bool
    let delegatedToId: String?
    let delegationExpiresAt: String?
    let delegationPermissions: [String]?
    let createdAt: String
    let updatedAt: String
    let ownerId: String
    let owner: User?
    let delegatedTo: User?
}

enum DeviceType: String, Codable, CaseIterable {
    case speaker = "speaker"
    case phone = "phone"
    case computer = "computer"
    case tablet = "tablet"
    case other = "other"
    
    var localizedString: String {
        switch self {
        case .speaker:
            return "speaker".localized
        case .phone:
            return "phone".localized
        case .computer:
            return "computer".localized
        case .tablet:
            return "tablet".localized
        case .other:
            return "other".localized
        }
    }
    
    var iconName: String {
        switch self {
        case .speaker:
            return "speaker.wave.3"
        case .phone:
            return "iphone"
        case .computer:
            return "desktopcomputer"
        case .tablet:
            return "ipad"
        case .other:
            return "questionmark.circle"
        }
    }
}

enum DeviceStatus: String, Codable, CaseIterable {
    case online = "online"
    case offline = "offline"
    case playing = "playing"
    case paused = "paused"
    case error = "error"
    
    var localizedString: String {
        switch self {
        case .online:
            return "online".localized
        case .offline:
            return "offline".localized
        case .playing:
            return "playing".localized
        case .paused:
            return "paused".localized
        case .error:
            return "error".localized
        }
    }
    
    var color: String {
        switch self {
        case .online:
            return "green"
        case .offline:
            return "gray"
        case .playing:
            return "blue"
        case .paused:
            return "orange"
        case .error:
            return "red"
        }
    }
}

// MARK: - License Type
enum LicenseType: String, Codable, CaseIterable {
    case `public` = "public"
    case inviteOnly = "invite_only"
    case locationBased = "location_based"
    
    var localizedString: String {
        switch self {
        case .public:
            return "public".localized
        case .inviteOnly:
            return "invite_only".localized
        case .locationBased:
            return "location_based".localized
        }
    }
}

// MARK: - Vote Model
struct Vote: Codable, Identifiable {
    let id: String
    let type: VoteType
    let weight: Int
    let createdAt: String
    let userId: String
    let eventId: String?
    let trackId: String
    let user: User?
    let track: Track?
}

enum VoteType: String, Codable, CaseIterable {
    case up = "up"
    case down = "down"
    
    var localizedString: String {
        switch self {
        case .up:
            return "upvote".localized
        case .down:
            return "downvote".localized
        }
    }
}

// MARK: - Invitation Model
struct Invitation: Codable, Identifiable {
    let id: String
    let type: InvitationType
    let status: InvitationStatus
    let message: String?
    let expiresAt: String?
    let createdAt: String
    let updatedAt: String
    let inviterId: String
    let inviteeId: String
    let eventId: String?
    let playlistId: String?
    let inviter: User?
    let invitee: User?
    let event: Event?
    let playlist: Playlist?
}

enum InvitationType: String, Codable, CaseIterable {
    case event = "event"
    case playlist = "playlist"
    case friend = "friend"
    
    var localizedString: String {
        switch self {
        case .event:
            return "event_invitation".localized
        case .playlist:
            return "playlist_invitation".localized
        case .friend:
            return "friend_request".localized
        }
    }
}

enum InvitationStatus: String, Codable, CaseIterable {
    case pending = "pending"
    case accepted = "accepted"
    case declined = "declined"
    case expired = "expired"
    
    var localizedString: String {
        switch self {
        case .pending:
            return "pending".localized
        case .accepted:
            return "accepted".localized
        case .declined:
            return "declined".localized
        case .expired:
            return "expired".localized
        }
    }
}
