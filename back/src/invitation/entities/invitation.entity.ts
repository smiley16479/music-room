import {
  Entity,
  PrimaryGeneratedColumn,
  Column,
  CreateDateColumn,
  UpdateDateColumn,
  ManyToOne,
  JoinColumn,
  Index,
} from 'typeorm';
import { User } from 'src/user/entities/user.entity';
import { Event } from 'src/event/entities/event.entity';

// Keep InvitationType for FRIEND invitations (non-event based)
export enum InvitationType {
  EVENT = 'event',
  PLAYLIST = 'playlist',
  FRIEND = 'friend',
}

export enum InvitationStatus {
  PENDING = 'pending',
  ACCEPTED = 'accepted',
  DECLINED = 'declined',
  EXPIRED = 'expired',
}

@Entity('invitations')
@Index(['invitee', 'type', 'status'])
export class Invitation {
  @PrimaryGeneratedColumn('uuid')
  id: string;

  @Column({
    type: 'enum',
    enum: InvitationType,
  })
  type: InvitationType;

  @Column({
    type: 'enum',
    enum: InvitationStatus,
    default: InvitationStatus.PENDING,
  })
  status: InvitationStatus;

  @Column({ type: 'text', nullable: true })
  message?: string;

  @Column({ name: 'expires_at', type: 'timestamp', nullable: true })
  expiresAt: Date;

  @CreateDateColumn({ name: 'created_at' })
  createdAt: Date;

  @UpdateDateColumn({ name: 'updated_at' })
  updatedAt: Date;

  // Relations
  @ManyToOne(() => User, (user) => user.sentInvitations, { onDelete: 'CASCADE' })
  @JoinColumn({ name: 'inviter_id' })
  inviter: User;

  @Column({ name: 'inviter_id' })
  inviterId: string;

  @ManyToOne(() => User, (user) => user.receivedInvitations, { onDelete: 'CASCADE' })
  @JoinColumn({ name: 'invitee_id' })
  invitee: User;

  @Column({ name: 'invitee_id' })
  inviteeId: string;

  // Event invitations (nullable for friend requests)
  @ManyToOne(() => Event, (event) => event.invitations, { onDelete: 'CASCADE', nullable: true })
  @JoinColumn({ name: 'event_id' })
  event?: Event;

  @Column({ name: 'event_id', nullable: true })
  eventId?: string;

  // Removed: playlist relation and playlistId
}