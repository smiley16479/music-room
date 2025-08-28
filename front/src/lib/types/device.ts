// Device-related type definitions to avoid circular imports

export enum DeviceType {
	PHONE = 'phone',
	TABLET = 'tablet',
	DESKTOP = 'desktop',
	SMART_SPEAKER = 'smart_speaker',
	TV = 'tv',
	OTHER = 'other'
}

export enum DeviceStatus {
	ONLINE = 'online',
	OFFLINE = 'offline',
	PLAYING = 'playing',
	PAUSED = 'paused'
}

export interface User {
	id: string;
	email: string;
	displayName?: string;
}

export interface DelegationPermissions {
	canPlay: boolean;
	canPause: boolean;
	canSkip: boolean;
	canChangeVolume: boolean;
	canChangePlaylist: boolean;
}

export interface PlaybackCommand {
	action: 'play' | 'pause' | 'skip' | 'previous' | 'stop' | 'seek' | 'volume';
	value?: number; // For seek position or volume level
	trackId?: string; // For play command with specific track
	playlistId?: string; // For changing playlist
}

export interface Device {
	id: string;
	name: string;
	type: DeviceType;
	status: DeviceStatus;
	deviceInfo?: {
		userAgent?: string;
		platform?: string;
		browser?: string;
		version?: string;
	};
	lastSeen: string; // Will be string when serialized from backend
	isActive: boolean;
	canBeControlled: boolean;
	delegatedToId: string | null;
	delegationExpiresAt: string | null; // Will be string when serialized from backend
	delegationPermissions: DelegationPermissions | null;
	createdAt: string; // Will be string when serialized from backend
	updatedAt: string; // Will be string when serialized from backend
	ownerId: string;
	owner?: User;
	delegatedTo?: User;
}

export interface CreateDeviceDto {
	name: string;
	type: DeviceType;
	canBeControlled: boolean;
}

export interface UpdateDeviceDto {
	name?: string;
	type?: DeviceType;
	canBeControlled?: boolean;
}

export interface DelegateControlDto {
	userId: string;
	expiresAt?: string;
	permissions: DelegationPermissions;
}

export interface ConnectDeviceDto {
	socketId?: string;
}

// Backend response wrapper
export interface ApiResponse<T> {
	success: boolean;
	data: T;
	pagination?: {
		page: number;
		limit: number;
		total: number;
		totalPages: number;
	};
	timestamp: string;
}
