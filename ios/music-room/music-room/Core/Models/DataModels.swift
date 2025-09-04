import Foundation

// MARK: - AuthResponse Models
struct AuthResponse: Codable {
    let accessToken: String
    let refreshToken: String?
    let user: User
}

// MARK: - User Models
struct User: Codable, Identifiable {
    let id: String
    let email: String
    let displayName: String
    let avatarUrl: String?
    let bio: String?
    let birthDate: String?
    let location: String?
    let emailVerified: Bool?
    let musicPreferences: MusicPreferences?
    let lastSeen: String?
    let createdAt: String?
    let updatedAt: String?
    
    // Privacy settings
    let displayNameVisibility: VisibilityLevel?
    let bioVisibility: VisibilityLevel?
    let birthDateVisibility: VisibilityLevel?
    let locationVisibility: VisibilityLevel?
    
    enum CodingKeys: String, CodingKey {
        case id, email, displayName, avatarUrl, bio, birthDate, location, emailVerified, musicPreferences, lastSeen, createdAt, updatedAt
        case displayNameVisibility, bioVisibility, birthDateVisibility, locationVisibility
    }
    
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(String.self, forKey: .id)
        email = try container.decode(String.self, forKey: .email)
        displayName = try container.decodeIfPresent(String.self, forKey: .displayName) ?? "Unknown"
        avatarUrl = try container.decodeIfPresent(String.self, forKey: .avatarUrl)
        bio = try container.decodeIfPresent(String.self, forKey: .bio)
        birthDate = try container.decodeIfPresent(String.self, forKey: .birthDate)
        location = try container.decodeIfPresent(String.self, forKey: .location)
        emailVerified = try container.decodeIfPresent(Bool.self, forKey: .emailVerified)
        musicPreferences = try container.decodeIfPresent(MusicPreferences.self, forKey: .musicPreferences)
        lastSeen = try container.decodeIfPresent(String.self, forKey: .lastSeen)
        createdAt = try container.decodeIfPresent(String.self, forKey: .createdAt)
        updatedAt = try container.decodeIfPresent(String.self, forKey: .updatedAt)
        displayNameVisibility = try container.decodeIfPresent(VisibilityLevel.self, forKey: .displayNameVisibility)
        bioVisibility = try container.decodeIfPresent(VisibilityLevel.self, forKey: .bioVisibility)
        birthDateVisibility = try container.decodeIfPresent(VisibilityLevel.self, forKey: .birthDateVisibility)
        locationVisibility = try container.decodeIfPresent(VisibilityLevel.self, forKey: .locationVisibility)
    }

    // Public initializer for manual instantiation and mocks
    init(
        id: String,
        email: String,
        displayName: String,
        avatarUrl: String? = nil,
        bio: String? = nil,
        birthDate: String? = nil,
        location: String? = nil,
        emailVerified: Bool? = nil,
        musicPreferences: MusicPreferences? = nil,
        lastSeen: String? = nil,
        createdAt: String? = nil,
        updatedAt: String? = nil,
        displayNameVisibility: VisibilityLevel? = nil,
        bioVisibility: VisibilityLevel? = nil,
        birthDateVisibility: VisibilityLevel? = nil,
        locationVisibility: VisibilityLevel? = nil
    ) {
        self.id = id
        self.email = email
        self.displayName = displayName
        self.avatarUrl = avatarUrl
        self.bio = bio
        self.birthDate = birthDate
        self.location = location
        self.emailVerified = emailVerified
        self.musicPreferences = musicPreferences
        self.lastSeen = lastSeen
        self.createdAt = createdAt
        self.updatedAt = updatedAt
        self.displayNameVisibility = displayNameVisibility
        self.bioVisibility = bioVisibility
        self.birthDateVisibility = birthDateVisibility
        self.locationVisibility = locationVisibility
    }
}

extension User {
    static func mock(id: String = UUID().uuidString) -> User {
        User(
            id: id, email: "mock@user.com", displayName: "Mock"
        )
    }
}

struct MusicPreferences: Codable {
    let favoriteGenres: [String]?
    let favoriteArtists: [String]?
    let dislikedGenres: [String]?
}


enum VisibilityLevel: String, Codable, CaseIterable {
    case `public` = "public"
    case friendsOnly = "friends"
    case `private` = "private"
    
    var localizedString: String {
        switch self {
        case .public:
            return "public".localized
        case .friendsOnly:
            return "friends".localized
        case .private:
            return "private".localized
        }
    }
}

// MARK: - Track Model
struct Track: Codable, Identifiable {
    let id: String
    let deezerId: String?
    let title: String
    let artist: String
    let album: String?
    let duration: Int // Duration in seconds
    let previewUrl: String?
    let albumCoverUrl: String?
    let albumCoverSmallUrl: String?
    let albumCoverMediumUrl: String?
    let albumCoverBigUrl: String?
    let deezerUrl: String?
    let genres: [String]?
    let releaseDate: String?
    let available: Bool?
    let createdAt: String?
    let updatedAt: String?

    // UI-specific properties (optionnels)
    var likes: Int?
    var dislikes: Int?
    var hasPlayed: Bool?
    var isCurrentlyPlaying: Bool?
    var voteScore: Int { (likes ?? 0) - (dislikes ?? 0) }
    var preview: String? // URL de preview Deezer (30 secondes)
    
    var formattedDuration: String {
        let minutes = duration / 60
        let seconds = duration % 60
        return String(format: "%d:%02d", minutes, seconds)
    }

    init(
        id: String,
        title: String = "Unknown",
        artist: String = "Unknown Artist",
        duration: Int,
        deezerId: String? = nil,
        album: String? = nil,
        previewUrl: String? = nil,
        albumCoverUrl: String? = nil,
        albumCoverSmallUrl: String? = nil,
        albumCoverMediumUrl: String? = nil,
        albumCoverBigUrl: String? = nil,
        deezerUrl: String? = nil,
        genres: [String]? = nil,
        releaseDate: String? = nil,
        available: Bool? = nil,
        createdAt: String? = nil,
        updatedAt: String? = nil,
        likes: Int = 0,
        dislikes: Int = 0,
        hasPlayed: Bool = false,
        isCurrentlyPlaying: Bool = false,
        preview: String? = nil
    ) {
        self.id = id
        self.title = title
        self.artist = artist
        self.duration = duration
        self.deezerId = deezerId
        self.album = album
        self.previewUrl = previewUrl
        self.albumCoverUrl = albumCoverUrl
        self.albumCoverSmallUrl = albumCoverSmallUrl
        self.albumCoverMediumUrl = albumCoverMediumUrl
        self.albumCoverBigUrl = albumCoverBigUrl
        self.deezerUrl = deezerUrl
        self.genres = genres
        self.releaseDate = releaseDate
        self.available = available
        self.createdAt = createdAt
        self.updatedAt = updatedAt
        self.likes = likes
        self.dislikes = dislikes
        self.hasPlayed = hasPlayed
        self.isCurrentlyPlaying = isCurrentlyPlaying
        self.preview = preview
    }


    init?(from dict: [String: Any]) {
        guard let id = dict["id"] as? String,
              let title = dict["title"] as? String,
              let artist = dict["artist"] as? String,
              let duration = dict["duration"] as? Int else { return nil }
        self.id = id
        self.title = title
        self.artist = artist
        self.duration = duration
        self.deezerId = dict["deezerId"] as? String
        self.album = dict["album"] as? String
        self.previewUrl = dict["previewUrl"] as? String
        self.albumCoverUrl = dict["albumCoverUrl"] as? String
        self.albumCoverSmallUrl = dict["albumCoverSmallUrl"] as? String
        self.albumCoverMediumUrl = dict["albumCoverMediumUrl"] as? String
        self.albumCoverBigUrl = dict["albumCoverBigUrl"] as? String
        self.deezerUrl = dict["deezerUrl"] as? String
        self.genres = dict["genres"] as? [String]
        self.releaseDate = dict["releaseDate"] as? String
        self.available = dict["available"] as? Bool
        self.createdAt = dict["createdAt"] as? String
        self.updatedAt = dict["updatedAt"] as? String
        self.likes = dict["likes"] as? Int
        self.dislikes = dict["dislikes"] as? Int
        self.hasPlayed = dict["hasPlayed"] as? Bool
        self.isCurrentlyPlaying = dict["isCurrentlyPlaying"] as? Bool
        self.preview = dict["preview"] as? String
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
    let admins: [User]?
    let playlist: Playlist?
    
    // MARK: - Mock Event Data:
      static let mockEvent: [Event] = [
          Event(id: "UUID", name: "No Events",
          description: nil,
          visibility: VisibilityLevel.public, licenseType: LicenseType.open, status: EventStatus.upcoming,
          latitude: nil,
          longitude: nil,
          locationRadius: nil,
          locationName: nil,
          votingStartTime: nil,
          votingEndTime: nil,
          eventDate: nil,
          eventEndDate: nil,
          currentTrackId: nil,
          currentTrackStartedAt: nil,
          maxVotesPerUser: nil,
          createdAt: "",
          updatedAt: "",
          creatorId: "",
          creator: nil,
          participants: nil,
          admins: nil,
          playlist: nil
          )
      ]
}

enum EventStatus: String, Codable, CaseIterable {
    case upcoming = "upcoming"
    case active = "live"
    case paused = "paused"
    case ended = "ended"
    
    var localizedString: String {
        switch self {
        case .upcoming:
            return "upcoming".localized
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
    let eventId: String?
    let name: String
    let description: String?
    let visibility: VisibilityLevel
    let licenseType: LicenseType
    let coverImageUrl: String?
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

    // Custom initializer for easier instantiation
    init(
        id: String,
        eventId: String? = nil,
        name: String = "Untitled Playlist",
        description: String? = nil,
        visibility: VisibilityLevel = .public,
        licenseType: LicenseType = .open,
        coverImageUrl: String? = nil,
        totalDuration: Int? = nil,
        trackCount: Int = 0,
        createdAt: String = "",
        updatedAt: String = "",
        creatorId: String = "",
        creator: User? = nil,
        collaborators: [User]? = nil,
        tracks: [PlaylistTrack]? = nil
    ) {
        self.id = id
        self.eventId = eventId
        self.name = name
        self.description = description
        self.visibility = visibility
        self.licenseType = licenseType
        self.coverImageUrl = coverImageUrl
        self.totalDuration = totalDuration
        self.trackCount = trackCount
        self.createdAt = createdAt
        self.updatedAt = updatedAt
        self.creatorId = creatorId
        self.creator = creator
        self.collaborators = collaborators
        self.tracks = tracks
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
    let track: Track
    let addedBy: User
    // Custom initializer for easier instantiation
    init(
        id: String,
        position: Int = 0,
        addedAt: String = "",
        createdAt: String = "",
        addedById: String = "",
        playlistId: String = "",
        trackId: String = "",
        track: Track,
        addedBy: User
    ) {
        self.id = id
        self.position = position
        self.addedAt = addedAt
        self.createdAt = createdAt
        self.addedById = addedById
        self.playlistId = playlistId
        self.trackId = trackId
        self.track = track
        self.addedBy = addedBy
    }
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
    case open = "open"
    case inviteOnly = "invited"
    case locationBased = "location_based"
    
    var localizedString: String {
        switch self {
        case .open:
            return "open".localized
        case .inviteOnly:
            return "invited".localized
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

// MARK: - Deezer API Models
struct DeezerSearchResponse: Codable {
    let data: [DeezerTrack]
    let total: Int
    let next: String?
}

struct DeezerTrack: Codable {
    let id: Int
    let title: String
    let duration: Int
    let preview: String
    let artist: DeezerArtist
    let album: DeezerAlbum
    
    var asTrack: Track {
        Track(
            id: UUID().uuidString,
            title: title,
            artist: artist.name,
            duration: Int(TimeInterval(duration)),
            deezerId: String(id),
            previewUrl: preview,
            albumCoverUrl: album.cover_medium,
            preview: preview
        )
    }
}

struct DeezerArtist: Codable {
    let id: Int
    let name: String
}

struct DeezerAlbum: Codable {
    let id: Int
    let title: String
    let cover_small: String
    let cover_medium: String
    let cover_big: String
}
