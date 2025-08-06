import {
  Entity,
  PrimaryGeneratedColumn,
  Column,
  CreateDateColumn,
  UpdateDateColumn,
  ManyToOne,
  OneToMany,
  ManyToMany,
  JoinTable,
  JoinColumn,
} from 'typeorm';
import { User } from 'src/user/entities/user.entity';
import { Track } from 'src/track/entities/track.entity';
import { Vote } from 'src/event/entities/vote.entity';
import { Invitation } from 'src/invitation/entities/invitation.entity';

export enum EventVisibility {
  PUBLIC = 'public',
  PRIVATE = 'private',
}

export enum EventLicenseType {
  OPEN = 'open', // Everyone can vote
  INVITED = 'invited', // Only invited users can vote
  LOCATION_BASED = 'location_based', // Location + time based voting
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

  // Location data for location-based voting
  @Column({ type: 'decimal', precision: 10, scale: 8, nullable: true })
  latitude: number;

  @Column({ type: 'decimal', precision: 11, scale: 8, nullable: true })
  longitude: number;

  @Column({ name: 'location_radius', type: 'int', nullable: true, comment: 'Radius in meters' })
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

  @Column({ name: 'event_end_date', type: 'timestamp', nullable: true })
  eventEndDate: Date;

  // Current playing track
  @Column({ name: 'current_track_id', nullable: true })
  currentTrackId: string;

  @Column({ name: 'current_track_started_at', type: 'timestamp', nullable: true })
  currentTrackStartedAt: Date;

  @Column({ name: 'max_votes_per_user', type: 'int', default: 1 })
  maxVotesPerUser: number;

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

  @ManyToOne(() => Track, { nullable: true })
  @JoinColumn({ name: 'current_track_id' })
  currentTrack: Track;

  @OneToMany(() => Vote, (vote) => vote.event)
  votes: Vote[];

  @OneToMany(() => Invitation, (invitation) => invitation.event)
  invitations: Invitation[];

  @ManyToMany(() => User, (user) => user.participatedEvents)
  @JoinTable({
    name: 'event_participants',
    joinColumn: { name: 'event_id', referencedColumnName: 'id' },
    inverseJoinColumn: { name: 'user_id', referencedColumnName: 'id' },
  })
  participants: User[];

  @ManyToMany(() => Track)
  @JoinTable({
    name: 'event_playlist',
    joinColumn: { name: 'event_id', referencedColumnName: 'id' },
    inverseJoinColumn: { name: 'track_id', referencedColumnName: 'id' },
  })
  playlist: Track[];
}
