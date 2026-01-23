import {
  Entity,
  PrimaryColumn,
  Column,
  CreateDateColumn,
  ManyToOne,
  JoinColumn,
} from 'typeorm';
import { User } from 'src/user/entities/user.entity';
import { Event } from 'src/event/entities/event.entity';

export enum ParticipantRole {
  ADMIN = 'admin',
  CREATOR = 'creator',
  COLLABORATOR = 'collaborator',
  PARTICIPANT = 'participant', // Simple viewer/voter
}

@Entity('event_participants')
export class EventParticipant {
  @PrimaryColumn({ name: 'event_id' })
  eventId: string;

  @PrimaryColumn({ name: 'user_id' })
  userId: string;

  @Column({
    type: 'enum',
    enum: ParticipantRole,
    default: ParticipantRole.PARTICIPANT,
  })
  role: ParticipantRole;

  @CreateDateColumn({ name: 'joined_at' })
  joinedAt: Date;

  // Relations
  @ManyToOne(() => Event, { onDelete: 'CASCADE' })
  @JoinColumn({ name: 'event_id' })
  event: Event;

  @ManyToOne(() => User, { onDelete: 'CASCADE' })
  @JoinColumn({ name: 'user_id' })
  user: User;
}
