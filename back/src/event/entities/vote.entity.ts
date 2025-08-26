import {
  Entity,
  PrimaryGeneratedColumn,
  Column,
  CreateDateColumn,
  ManyToOne,
  JoinColumn,
  Index,
} from 'typeorm';
import { User } from 'src/user/entities/user.entity';
import { Event } from 'src/event/entities/event.entity';
import { Track } from 'src/music/entities/track.entity';
import { PlaylistTrack } from 'src/playlist/entities/playlist-track.entity';

export enum VoteType {
  UPVOTE = 'upvote',
  DOWNVOTE = 'downvote',
}

@Entity('votes')
@Index(['user', 'event', 'track'], { unique: true }) // Prevent duplicate votes
export class Vote {
  @PrimaryGeneratedColumn('uuid')
  id: string;

  @Column({
    type: 'enum',
    enum: VoteType,
    default: VoteType.UPVOTE,
  })
  type: VoteType;

  @Column({ type: 'int', default: 1 })
  weight: number;

  @CreateDateColumn({ name: 'created_at' })
  createdAt: Date;

  // Relations
  @ManyToOne(() => User, (user) => user.votes, { onDelete: 'CASCADE' })
  @JoinColumn({ name: 'user_id' })
  user: User;

  @Column({ name: 'user_id' })
  userId: string;

  @ManyToOne(() => Event, (event) => event.votes, { onDelete: 'CASCADE' })
  @JoinColumn({ name: 'event_id' })
  event: Event;

  @Column({ name: 'event_id' })
  eventId: string;

  @ManyToOne(() => Track, (track) => track.votes, { onDelete: 'CASCADE' })
  @JoinColumn({ name: 'track_id' })
  track: Track;

  @Column({ name: 'track_id' })
  trackId: string;

  @ManyToOne(() => PlaylistTrack, playlistTrack => playlistTrack.votes, /* { onDelete: 'CASCADE', nullable: true } */)
  @JoinColumn({ name: 'playlist_track_id' })
  playlistTrack: PlaylistTrack;
}
