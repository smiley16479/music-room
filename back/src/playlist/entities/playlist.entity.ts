import {
  Entity,
  PrimaryGeneratedColumn,
  Column,
  CreateDateColumn,
  UpdateDateColumn,
  ManyToOne,
  JoinColumn,
  OneToMany,
  OneToOne,
} from 'typeorm';
import { User } from 'src/user/entities/user.entity';
import { Event } from 'src/event/entities/event.entity';
import { PlaylistTrack } from './playlist-track.entity';

// Removed: PlaylistVisibility, PlaylistLicenseType
// All permissions are now handled via Event entity

@Entity('playlists')
export class Playlist {
  @PrimaryGeneratedColumn('uuid')
  id: string;

  @Column()
  name: string;

  @Column({ type: 'text', nullable: true })
  description: string;

  @Column({ name: 'is_public', type: 'boolean', default: false })
  isPublic: boolean; // Simple visibility flag (different from Event permissions)

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

  /* // Relations
  @ManyToOne(() => User, (user) => user.createdPlaylists, { onDelete: 'CASCADE' })
  @JoinColumn({ name: 'creator_id' })
  creator: User;

  @Column({ name: 'creator_id' })
  creatorId: string; */

  // Removed: collaborators - now managed via event_participants
  // Removed: licenseType, visibility - now in Event entity

  @OneToMany(() => PlaylistTrack, (playlistTrack) => playlistTrack.playlist, { cascade: true })
  playlistTracks: PlaylistTrack[];

  // MANDATORY 1:1 relation with Event
  @OneToOne(() => Event, (event) => event.playlist, { nullable: false, onDelete: 'CASCADE' })
  @JoinColumn({ name: 'event_id' })
  event: Event;

  @Column({ name: 'event_id', nullable: false })
  eventId: string;

  // Removed: invitations - now only on Event
}

