import {
  Entity,
  PrimaryGeneratedColumn,
  Column,
  CreateDateColumn,
  UpdateDateColumn,
  OneToMany,
} from 'typeorm';
import { Vote } from 'src/event/entities/vote.entity';

@Entity('tracks')
export class Track {
  @PrimaryGeneratedColumn('uuid')
  id: string;

  @Column({ name: 'deezer_id', unique: true })
  deezerId: string;

  @Column()
  title: string;

  @Column()
  artist: string;

  @Column()
  album: string;

  @Column({ type: 'int', comment: 'Duration in seconds' })
  duration: number;

  @Column({ name: 'preview_url', nullable: true })
  previewUrl: string;

  @Column({ name: 'album_cover_url', nullable: true })
  albumCoverUrl: string;

  @Column({ name: 'album_cover_small_url', nullable: true })
  albumCoverSmallUrl: string;

  @Column({ name: 'album_cover_medium_url', nullable: true })
  albumCoverMediumUrl: string;

  @Column({ name: 'album_cover_big_url', nullable: true })
  albumCoverBigUrl: string;

  @Column({ name: 'deezer_url', nullable: true })
  deezerUrl: string;

  @Column({ type: 'json', nullable: true })
  genres: string[];

  @Column({ name: 'release_date', type: 'date', nullable: true })
  releaseDate: Date | null;

  @Column({ type: 'boolean', default: true })
  available: boolean;

  @CreateDateColumn({ name: 'created_at' })
  createdAt: Date;

  @UpdateDateColumn({ name: 'updated_at' })
  updatedAt: Date;

  // Relations
  @OneToMany(() => Vote, (vote) => vote.track)
  votes: Vote[];
}