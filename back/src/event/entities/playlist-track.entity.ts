import {
  Entity,
  PrimaryGeneratedColumn,
  Column,
  CreateDateColumn,
  ManyToOne,
  JoinColumn,
  Index,
  BeforeInsert,
  BeforeUpdate,
  OneToMany,
} from 'typeorm';
import { Event } from 'src/event/entities/event.entity';
import { Track } from 'src/music/entities/track.entity';
import { User } from 'src/user/entities/user.entity';
import { BadRequestException } from '@nestjs/common';
import { Vote } from 'src/event/entities/vote.entity';

/**
 * PlaylistTrack entity (tracks in an Event)
 * 
 * Since Playlist is merged into Event, this entity now links directly to Event.
 * For LISTENING_SESSION events, these are the playlist tracks.
 * For other event types, these can be the event's track queue.
 */
@Entity('playlist_tracks')
@Index(['event', 'position'])
export class PlaylistTrack {
  @PrimaryGeneratedColumn('uuid')
  id: string;

  @Column({ type: 'int' })
  position: number;

  @Column({ name: 'added_at', type: 'timestamp', default: () => 'CURRENT_TIMESTAMP' })
  addedAt: Date;

  @CreateDateColumn({ name: 'created_at' })
  createdAt: Date;

  // Relations - Now points to Event instead of Playlist
  @ManyToOne(() => Event, event => event.tracks, { onDelete: 'CASCADE' })
  @JoinColumn({ name: 'event_id' })
  event: Event;

  @Column({ name: 'event_id', nullable: false })
  eventId: string;

  @ManyToOne(() => Track, { onDelete: 'CASCADE' })
  @JoinColumn({ name: 'track_id' })
  track: Track;

  @Column({ name: 'track_id', nullable: false })
  trackId: string;

  @Column({ name: 'added_by_id', nullable: false })
  addedById: string;

  @OneToMany(() => Vote, (vote) => vote.playlistTrack)
  votes: Vote[];

  @BeforeInsert()
  @BeforeUpdate()
  validateRequiredFields() {
    if (!this.eventId || this.eventId.trim() === '') {
      throw new BadRequestException('Event ID is required');
    }
    if (!this.trackId || this.trackId.trim() === '') {
      throw new BadRequestException('Track ID is required');
    }
    if (!this.addedById || this.addedById.trim() === '') {
      throw new BadRequestException('Added by user ID is required');
    }
  }
}
