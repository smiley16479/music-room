import {
  Entity,
  PrimaryGeneratedColumn,
  Column,
  CreateDateColumn,
  UpdateDateColumn,
  ManyToOne,
  ManyToMany,
  JoinTable,
  JoinColumn,
  OneToMany,
  OneToOne,
} from 'typeorm';
import { User } from 'src/user/entities/user.entity';
import { Event } from 'src/event/entities/event.entity';
import { PlaylistTrack } from './playlist-track.entity';
import { Invitation } from 'src/invitation/entities/invitation.entity';

export enum PlaylistVisibility {
  PUBLIC = 'public',
  PRIVATE = 'private',
}

export enum PlaylistLicenseType {
  OPEN = 'open', // Everyone can edit
  INVITED = 'invited', // Only invited users can edit
}

@Entity('playlists')
export class Playlist {
  @PrimaryGeneratedColumn('uuid')
  id: string;

  @Column()
  name: string;

  @Column({ type: 'text', nullable: true })
  description: string;

  @Column({
    type: 'enum',
    enum: PlaylistVisibility,
    default: PlaylistVisibility.PUBLIC,
  })
  visibility: PlaylistVisibility;

  @Column({
    name: 'license_type',
    type: 'enum',
    enum: PlaylistLicenseType,
    default: PlaylistLicenseType.OPEN,
  })
  licenseType: PlaylistLicenseType;

  @Column({ name: 'cover_image_url', nullable: true })
  coverImageUrl: string;

  @Column({ name: 'total_duration', type: 'int', default: 0, comment: 'Duration in seconds' })
  totalDuration: number;

  @Column({ name: 'track_count', type: 'int', default: 0 })
  trackCount: number;

  @CreateDateColumn({ name: 'created_at' })
  createdAt: Date;

  @UpdateDateColumn({ name: 'updated_at' })
  updatedAt: Date;

  // Relations
  @ManyToOne(() => User, (user) => user.createdPlaylists, { onDelete: 'CASCADE' }) // ok
  @JoinColumn({ name: 'creator_id' })
  creator: User;

  @Column({ name: 'creator_id' })
  creatorId: string;

  @ManyToMany(() => User, (user) => user.collaboratedPlaylists) // ok
  @JoinTable({
    name: 'playlist_collaborators',
    joinColumn: { name: 'playlist_id', referencedColumnName: 'id' },
    inverseJoinColumn: { name: 'user_id', referencedColumnName: 'id' },
  })
  collaborators: User[];

  @OneToMany(() => PlaylistTrack, (playlistTrack) => playlistTrack.playlist) // ok
  playlistTracks: PlaylistTrack[];

  @OneToOne(() => Event, (event)=> event.playlist, { nullable: true, onDelete: 'CASCADE' }) // ok
  event: Event;

  @Column({ name: 'event_id', nullable: true })
  eventId: string;

  @OneToMany(() => Invitation, (invitation) => invitation.playlist) // ok
  invitations: Invitation[];
}

