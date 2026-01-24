import {
  Entity,
  PrimaryGeneratedColumn,
  Column,
  CreateDateColumn,
  UpdateDateColumn,
  ManyToOne,
  OneToMany,
  JoinColumn,
  OneToOne,
} from 'typeorm'
import { User } from 'src/user/entities/user.entity';
import { Track } from 'src/music/entities/track.entity';
import { Vote } from 'src/event/entities/vote.entity';
import { Invitation } from 'src/invitation/entities/invitation.entity';
import { Playlist } from 'src/playlist/entities/playlist.entity';
import { EventType } from './event-type.enum';
import { EventParticipant } from './event-participant.entity';

export enum EventVisibility {
  PUBLIC = 'public',
  PRIVATE = 'private',
}

export enum EventLicenseType {
  OPEN = 'open', // Everyone can vote/edit
  INVITED = 'invited', // Only invited users can vote/edit
  ADMIN = 'admin', // Only creator can edit
  LOCATION_BASED = 'location_based', // Access based on location (not implemented yet)
}

export enum EventStatus {
  UPCOMING = 'upcoming',
  LIVE = 'live',
  ENDED = 'ended',
}

@Entity('events')
export class Event {
  @PrimaryGeneratedColumn('uuid')
  id: string;

  @Column()
  name: string;

  @Column({ type: 'text', nullable: true })
  description: string;

  @Column({
    type: 'enum',
    enum: EventType,
    default: EventType.LISTENING_SESSION,
  })
  type: EventType;

  @Column({
    type: 'enum',
    enum: EventVisibility,
    default: EventVisibility.PUBLIC,
  })
  visibility: EventVisibility;

  @Column({
    name: 'license_type',
    type: 'enum',
    enum: EventLicenseType,
    default: EventLicenseType.OPEN,
  })
  licenseType: EventLicenseType;

  @Column({
    type: 'enum',
    enum: EventStatus,
    default: EventStatus.UPCOMING,
  })
  status: EventStatus;

  @Column({ name: 'voting_enabled', type: 'boolean', default: true })
  votingEnabled: boolean;

  // Location data for location-based voting
  @Column({ type: 'decimal', precision: 10, scale: 8, nullable: true, transformer: {
    to: (value: number) => value,
    from: (value: string) => parseFloat(value),
  }})
  latitude: number;

  @Column({ type: 'decimal', precision: 11, scale: 8, nullable: true, transformer: {
    to: (value: number) => value,
    from: (value: string) => parseFloat(value),
  }})
  longitude: number;

  @Column({ name: 'location_radius', type: 'int', nullable: true, comment: 'Radius in meters', default: 1000 })
  locationRadius: number;

  @Column({ name: 'location_name', nullable: true })
  locationName: string;

  // Time constraints for location-based voting
  @Column({ name: 'voting_start_time', type: 'time', nullable: true })
  votingStartTime: string;

  @Column({ name: 'voting_end_time', type: 'time', nullable: true })
  votingEndTime: string;

  @Column({ name: 'event_date', type: 'timestamp', nullable: true })
  eventDate: Date;

  // Event dates (optional, for PARTY type events)
  @Column({ name: 'start_date', type: 'timestamp', nullable: true })
  startDate: Date;

  @Column({ name: 'end_date', type: 'timestamp', nullable: true })
  endDate: Date;

  // Playback state tracking for accurate synchronization
  @Column({ name: 'is_playing', type: 'boolean', default: false })
  isPlaying: boolean;

  @Column({ name: 'current_position', type: 'decimal', precision: 10, scale: 3, default: 0 })
  currentPosition: number; // Current position in seconds when paused

  @Column({ name: 'last_position_update', type: 'timestamp', nullable: true })
  lastPositionUpdate: Date; // When position was last updated

  @CreateDateColumn({ name: 'created_at' })
  createdAt: Date;

  @UpdateDateColumn({ name: 'updated_at' })
  updatedAt: Date;

  // Relations
  @ManyToOne(() => User, (user) => user.createdEvents, { onDelete: 'CASCADE' })
  @JoinColumn({ name: 'creator_id' })
  creator: User;

  @Column({ name: 'creator_id' })
  creatorId: string;

  // Current playing track
  @ManyToOne(() => Track, { nullable: true })
  @JoinColumn({ name: 'current_track_id' })
  currentTrack: Track;

  @Column({ name: 'current_track_id', nullable: true })
  currentTrackId: string;

  @Column({ name: 'current_track_started_at', type: 'timestamp', nullable: true })
  currentTrackStartedAt: Date;

  @OneToMany(() => Vote, (vote) => vote.event)
  votes: Vote[];

  @OneToMany(() => Invitation, (invitation) => invitation.event)
  invitations: Invitation[];

  @OneToMany(() => EventParticipant, (participant) => participant.event, { cascade: true })
  participants: EventParticipant[];

  // Removed: ManyToMany participants and admins - now using EventParticipant entity

  @OneToOne(() => Playlist, (playlist) => playlist.event, { cascade: true })
  @JoinColumn({ name: 'playlist_id' })
  playlist: Playlist;

  @Column({ name: 'playlist_id', nullable: true })
  playlistId: string;
}
