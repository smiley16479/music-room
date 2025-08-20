import {
  Entity,
  PrimaryGeneratedColumn,
  Column,
  CreateDateColumn,
  UpdateDateColumn,
  OneToMany,
  ManyToMany,
  JoinTable,
} from 'typeorm';
import { Event } from 'src/event/entities/event.entity';
import { Playlist } from 'src/playlist/entities/playlist.entity';
import { Device } from 'src/device/entities/device.entity';
import { Vote } from 'src/event/entities/vote.entity';
import { Invitation } from 'src/invitation/entities/invitation.entity';

export enum VisibilityLevel {
  PUBLIC = 'public',
  FRIENDS = 'friends',
  PRIVATE = 'private',
}

@Entity('users')
export class User {
  @PrimaryGeneratedColumn('uuid')
  id: string;

  @Column({ unique: true })
  email: string;

  @Column({ type: 'varchar', nullable: true })
  password: string;

  @Column({ name: 'google_id', type: 'varchar', nullable: true })
  googleId: string | null;

  @Column({ name: 'facebook_id', type: 'varchar', nullable: true })
  facebookId: string | null;

  @Column({ name: 'email_verified', default: false })
  emailVerified: boolean;

  @Column({ name: 'reset_password_token', type: 'varchar', nullable: true })
  resetPasswordToken: string;

  @Column({ name: 'reset_password_expires', type: 'timestamp', nullable: true })
  resetPasswordExpires: Date;

  // Profile Information
  @Column({ name: 'display_name', type: 'varchar', nullable: true })
  displayName: string;

  @Column({ name: 'avatar_url', type: 'text', nullable: true })
  avatarUrl: string;

  @Column({ type: 'text', nullable: true })
  bio: string;

  @Column({ name: 'birth_date', type: 'date', nullable: true })
  birthDate: Date;

  @Column({ type: 'varchar', nullable: true })
  location: string;

  // Privacy Settings
  @Column({
    name: 'display_name_visibility',
    type: 'enum',
    enum: VisibilityLevel,
    default: VisibilityLevel.PUBLIC,
  })
  displayNameVisibility: VisibilityLevel;

  @Column({
    name: 'bio_visibility',
    type: 'enum',
    enum: VisibilityLevel,
    default: VisibilityLevel.PUBLIC,
  })
  bioVisibility: VisibilityLevel;

  @Column({
    name: 'birth_date_visibility',
    type: 'enum',
    enum: VisibilityLevel,
    default: VisibilityLevel.FRIENDS,
  })
  birthDateVisibility: VisibilityLevel;

  @Column({
    name: 'location_visibility',
    type: 'enum',
    enum: VisibilityLevel,
    default: VisibilityLevel.FRIENDS,
  })
  locationVisibility: VisibilityLevel;

  // Music Preferences (JSON)
  @Column({ name: 'music_preferences', type: 'json', nullable: true })
  musicPreferences: {
    favoriteGenres?: string[];
    favoriteArtists?: string[];
    dislikedGenres?: string[];
  };

  @Column({ name: 'last_seen', type: 'timestamp', default: () => 'CURRENT_TIMESTAMP' })
  lastSeen: Date;

  @CreateDateColumn({ name: 'created_at' })
  createdAt: Date;

  @UpdateDateColumn({ name: 'updated_at' })
  updatedAt: Date;

  // Relations
  @OneToMany(() => Event, (event) => event.creator)
  createdEvents: Event[];

  @OneToMany(() => Playlist, (playlist) => playlist.creator)
  createdPlaylists: Playlist[];

  @OneToMany(() => Device, (device) => device.owner)
  devices: Device[];

  @OneToMany(() => Vote, (vote) => vote.user)
  votes: Vote[];

  @OneToMany(() => Invitation, (invitation) => invitation.inviter)
  sentInvitations: Invitation[];

  @OneToMany(() => Invitation, (invitation) => invitation.invitee)
  receivedInvitations: Invitation[];

  // Many-to-many for friends
  @ManyToMany(() => User, (user) => user.friends)
  @JoinTable({
    name: 'user_friends',
    joinColumn: { name: 'user_id', referencedColumnName: 'id' },
    inverseJoinColumn: { name: 'friend_id', referencedColumnName: 'id' },
  })
  friends: User[];

  // Many-to-many for participated events
  @ManyToMany(() => Event, (event) => event.participants)
  participatedEvents: Event[];

  @ManyToMany(() => Event, (event) => event.admins)
  adminOfEvents: Event[];

  // Many-to-many for collaborated playlists
  @ManyToMany(() => Playlist, (playlist) => playlist.collaborators)
  collaboratedPlaylists: Playlist[];
}
