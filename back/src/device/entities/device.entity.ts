import {
  Entity,
  PrimaryGeneratedColumn,
  Column,
  CreateDateColumn,
  UpdateDateColumn,
  ManyToOne,
  JoinColumn,
} from 'typeorm';
import { User } from 'src/user/entities/user.entity';

export enum DeviceType {
  PHONE = 'phone',
  TABLET = 'tablet',
  DESKTOP = 'desktop',
  SMART_SPEAKER = 'smart_speaker',
  TV = 'tv',
  OTHER = 'other',
}

export enum DeviceStatus {
  ONLINE = 'online',
  OFFLINE = 'offline',
  PLAYING = 'playing',
  PAUSED = 'paused',
}

@Entity('devices')
export class Device {
  @PrimaryGeneratedColumn('uuid')
  id: string;

  @Column()
  name: string;

  @Column({
    type: 'enum',
    enum: DeviceType,
    default: DeviceType.OTHER,
  })
  type: DeviceType;

  @Column({
    type: 'enum',
    enum: DeviceStatus,
    default: DeviceStatus.OFFLINE,
  })
  status: DeviceStatus;

  @Column({ name: 'device_info', type: 'json', nullable: true })
  deviceInfo: {
    userAgent?: string;
    platform?: string;
    browser?: string;
    version?: string;
  };

  @Column({ name: 'last_seen', type: 'timestamp', default: () => 'CURRENT_TIMESTAMP' })
  lastSeen: Date;

  @Column({ name: 'is_active', default: true })
  isActive: boolean;

  // Control delegation
  @Column({ name: 'can_be_controlled', default: false })
  canBeControlled: boolean;

  @Column({ name: 'delegated_to_id', nullable: true })
  delegatedToId: string;

  @Column({ name: 'delegation_expires_at', type: 'timestamp', nullable: true })
  delegationExpiresAt: Date;

  @Column({ name: 'delegation_permissions', type: 'json', nullable: true })
  delegationPermissions: {
    canPlay?: boolean;
    canPause?: boolean;
    canSkip?: boolean;
    canChangeVolume?: boolean;
    canChangePlaylist?: boolean;
  };

  @CreateDateColumn({ name: 'created_at' })
  createdAt: Date;

  @UpdateDateColumn({ name: 'updated_at' })
  updatedAt: Date;

  // Relations
  @ManyToOne(() => User, (user) => user.devices, { onDelete: 'CASCADE' })
  @JoinColumn({ name: 'owner_id' })
  owner: User;

  @Column({ name: 'owner_id' })
  ownerId: string;

  @ManyToOne(() => User, { nullable: true })
  @JoinColumn({ name: 'delegated_to_id' })
  delegatedTo: User;
}