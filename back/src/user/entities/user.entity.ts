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
import { PlaylistTrack } from 'src/playlist/entities/playlist-track.entity';

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

  @Column({ nullable: true })
  password: string;

  @Column({ name: 'google_id', nullable: true })
  googleId: string;

  @Column({ name: 'facebook_id', nullable: true })
  facebookId: string;

  @Column({ name: 'email_verified', default: false })
  emailVerified: boolean;

  @Column({ name: 'reset_password_token', nullable: true })
  resetPasswordToken: string;

  @Column({ name: 'reset_password_expires', type: 'timestamp', nullable: true })
  resetPasswordExpires: Date;

  // Profile Information
  @Column({ name: 'display_name', nullable: true })
  displayName: string;

  @Column({ name: 'avatar_url', nullable: true })
  avatarUrl: string;

  @Column({ nullable: true })
  bio: string;

  @Column({ name: 'birth_date', type: 'date', nullable: true })
  birthDate: Date;

  @Column({ nullable: true })
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
  @OneToMany(() => Event, (event) => event.creator) // ok
  createdEvents: Event[];

  @OneToMany(() => Playlist, (playlist) => playlist.creator) // ok
  createdPlaylists: Playlist[];

  @OneToMany(() => PlaylistTrack, (playlistTrack) => playlistTrack.addedBy) // ok
  playlistTrack: PlaylistTrack[];

  @OneToMany(() => Device, (device) => device.owner)
  devices: Device[];

  @OneToMany(() => Vote, (vote) => vote.user) // ok
  votes: Vote[];

  @OneToMany(() => Invitation, (invitation) => invitation.inviter)  // ok
  sentInvitations: Invitation[];

  @OneToMany(() => Invitation, (invitation) => invitation.invitee) // ok
  receivedInvitations: Invitation[];

  // Many-to-many for friends
  @ManyToMany(() => User, (user) => user.friends) // ok
  @JoinTable({
    name: 'user_friends',
    joinColumn: { name: 'user_id', referencedColumnName: 'id' },
    inverseJoinColumn: { name: 'friend_id', referencedColumnName: 'id' },
  })
  friends: User[];

  // Many-to-many for participated events
  @ManyToMany(() => Event, (event) => event.participants) // ok
  participatedEvents: Event[];

  @ManyToMany(() => Event, (event) => event.admins) // ok
  adminOfEvents: Event[];

  // Many-to-many for collaborated playlists
  @ManyToMany(() => Playlist, (playlist) => playlist.collaborators) // ok
  collaboratedPlaylists: Playlist[];

  @OneToMany(() => Device, (device) => device.delegatedTo) // ok
  delegatedDevices: Device[];
}
