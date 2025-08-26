import {
  Entity,
  PrimaryGeneratedColumn,
  Column,
  CreateDateColumn,
  ManyToOne,
  JoinColumn,
  Index,
  OneToMany,
} from 'typeorm';
import { Playlist } from 'src/playlist/entities/playlist.entity';
import { Track } from 'src/music/entities/track.entity';
import { User } from 'src/user/entities/user.entity';
import { Vote } from 'src/event/entities/vote.entity';

@Entity('playlist_tracks')
@Index(['playlist', 'position'])
export class PlaylistTrack {
  @PrimaryGeneratedColumn('uuid')
  id: string;

  @Column({ type: 'int' })
  position: number;

  @Column({ name: 'added_at', type: 'timestamp', default: () => 'CURRENT_TIMESTAMP' })
  addedAt: Date;

  @CreateDateColumn({ name: 'created_at' })
  createdAt: Date;

  // Relations
  @ManyToOne(() => Playlist, { onDelete: 'CASCADE' }) // ok
  @JoinColumn({ name: 'playlist_id' })
  playlist: Playlist;

  @Column({ name: 'playlist_id' })
  playlistId: string;

  @ManyToOne(() => Track, { onDelete: 'CASCADE' }) // ok
  @JoinColumn({ name: 'track_id' })
  track: Track;

  @Column({ name: 'track_id' })
  trackId: string;

  @ManyToOne(() => User, { onDelete: 'CASCADE' }) // ok
  @JoinColumn({ name: 'added_by_id' })
  addedBy: User;

  @Column({ name: 'added_by_id' })
  addedById: string;

  @OneToMany(() => Vote, (vote) => vote.playlistTrack) // ok
  votes: Vote[];
}