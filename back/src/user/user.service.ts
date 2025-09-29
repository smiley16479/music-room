import {
  Injectable,
  NotFoundException,
  ConflictException,
  BadRequestException,
} from '@nestjs/common';
import { InjectRepository } from '@nestjs/typeorm';
import { Repository, FindOptionsWhere, Like } from 'typeorm';
import * as bcrypt from 'bcrypt';

import { User, VisibilityLevel } from 'src/user/entities/user.entity';
import { CreateUserDto } from './dto/create-user.dto';
import { UpdateUserDto } from './dto/update-user.dto';
import { UpdatePasswordDto } from './dto/update-password.dto';
import { PaginationDto } from '../common/dto/pagination.dto';
import { PaginatedResponse } from '../common/dto/response.dto';
import { generateGenericAvatar, getFacebookProfilePictureUrl } from 'src/common/utils/avatar.utils';
import { MusicPreferencesDto } from './dto/music-preferences.dto';
import { UpdatePrivacySettingsDto } from './dto/update-privacy-settings.dto';

@Injectable()
export class UserService {
  constructor(
    @InjectRepository(User)
    private readonly userRepository: Repository<User>,
  ) {}

  // Basic CRUD operations
  async create(createUserDto: CreateUserDto): Promise<User> {
    const { email, password, ...userData } = createUserDto;

    // Check if user already exists
    const existingUser = await this.findByEmail(email);
    if (existingUser) {
      throw new ConflictException('User with this email already exists');
    }

    // Hash password if provided
    let hashedPassword: string | undefined;
    if (password) {
      hashedPassword = await bcrypt.hash(password, 12);
    }

    // Create user
    const user = this.userRepository.create({
      email,
      password: hashedPassword,
      emailVerified: false,
      ...userData,
    });

    return this.userRepository.save(user);
  }

  async findAll(paginationDto: PaginationDto): Promise<PaginatedResponse<User>> {
    const { page, limit, skip } = paginationDto;

    const [users, total] = await this.userRepository.findAndCount({
      select: {
        id: true,
        email: true,
        displayName: true,
        avatarUrl: true,
        bio: true,
        location: true,
        emailVerified: true,
        createdAt: true,
        lastSeen: true,
        // Exclude sensitive fields
        password: false,
        resetPasswordToken: false,
        resetPasswordExpires: false,
      },
      skip,
      take: limit,
      order: { createdAt: 'DESC' },
    });

    const totalPages = Math.ceil(total / limit);

    return {
      success: true,
      data: users,
      pagination: {
        page,
        limit,
        total,
        totalPages,
        hasNext: page < totalPages,
        hasPrev: page > 1,
      },
      timestamp: new Date().toISOString(),
    };
  }

  async findById(id: string, relations: string[] = []): Promise<User> {
    const user = await this.userRepository.findOne({
      where: { id },
      relations,
      select: {
        // Always exclude sensitive fields
        password: false,
        resetPasswordToken: false,
        resetPasswordExpires: false,
      },
    });

    if (!user) {
      throw new NotFoundException('User not found');
    }

    return user;
  }

  async findByEmail(email: string): Promise<User | null> {
    return this.userRepository.findOne({
      where: { email },
    });
  }

  async findByGoogleId(googleId: string): Promise<User | null> {
    return this.userRepository.findOne({
      where: { googleId },
    });
  }

  async findByFacebookId(facebookId: string): Promise<User | null> {
    return this.userRepository.findOne({
      where: { facebookId },
    });
  }

  async findByResetToken(token: string): Promise<User | null> {
    return this.userRepository.findOne({
      where: { 
        resetPasswordToken: token,
      },
    });
  }

  async update(id: string, updateUserDto: UpdateUserDto): Promise<User> {
    const user = await this.findById(id);

    // Handle avatar URL logic
    const updateData = { ...updateUserDto };
    
    // If avatarUrl is provided and not empty, use it
    // If avatarUrl is empty or not provided, keep the existing avatar
    if (updateData.avatarUrl !== undefined) {
      if (!updateData.avatarUrl || updateData.avatarUrl.trim() === '') {
        // Remove avatarUrl from update if it's empty - keep existing avatar
        delete updateData.avatarUrl;
      }
      // If it's a valid URL, it will be validated by the DTO and used as-is
    }

    // Update user fields
    Object.assign(user, updateData);

    return this.userRepository.save(user);
  }

  async updatePassword(id: string, updatePasswordDto: UpdatePasswordDto): Promise<void> {
    const { currentPassword, newPassword } = updatePasswordDto;
    
    const user = await this.userRepository.findOne({
      where: { id },
      select: ['id', 'password'],
    });

    if (!user || !user.password) {
      throw new NotFoundException('User not found or password not set');
    }

    // Verify current password
    const isCurrentPasswordValid = await bcrypt.compare(currentPassword, user.password);
    if (!isCurrentPasswordValid) {
      throw new BadRequestException('Current password is incorrect');
    }

    // Hash new password
    const hashedNewPassword = await bcrypt.hash(newPassword, 12);

    // Update password
    await this.userRepository.update(id, {
      password: hashedNewPassword,
    });
  }

    async setNewPassword(id: string, hashedPassword: string): Promise<void> {
    // Update password directly without checking the current password
    // Only use this method for authorized operations like admin reset or password reset via token
    await this.userRepository.update(id, {
      password: hashedPassword,
    });
  }

  async remove(id: string): Promise<void> {
    const user = await this.findById(id);
    await this.userRepository.remove(user);
  }

  async linkGoogleAccount(userId: string, googleId: string): Promise<User> {
    await this.userRepository.update(userId, { googleId });
    return await this.findById(userId);
  }

  async linkFacebookAccount(userId: string, facebookId: string): Promise<User> {
    await this.userRepository.update(userId, { facebookId });
    return await this.findById(userId);
  }

  async unlinkGoogleAccount(userId: string): Promise<void> {
    await this.userRepository.update(userId, { googleId: null });
  }

  async unlinkFacebookAccount(userId: string): Promise<void> {
    await this.userRepository.update(userId, { facebookId: null });
  }

  // Friend management
  async getFriends(userId: string): Promise<User[]> {
    const user = await this.userRepository.findOne({
      where: { id: userId },
      relations: ['friends'],
      select: {
        friends: {
          id: true,
          email: true,
          displayName: true,
          avatarUrl: true,
          lastSeen: true,
        },
      },
    });

    if (!user) {
      throw new NotFoundException('User not found');
    }

    return user.friends || [];
  }

  async addFriend(userId: string, friendId: string): Promise<void> {
    if (userId === friendId) {
      throw new BadRequestException('Cannot add yourself as a friend');
    }

    const [user, friend] = await Promise.all([
      this.userRepository.findOne({
        where: { id: userId },
        relations: ['friends'],
      }),
      this.findById(friendId),
    ]);

    if (!user) {
      throw new NotFoundException('User not found');
    }

    // Check if already friends
    const isAlreadyFriend = user.friends?.some(f => f.id === friendId);
    if (isAlreadyFriend) {
      throw new ConflictException('Users are already friends');
    }

    // Add friend relationship (bidirectional)
    user.friends = user.friends || [];
    user.friends.push(friend);
    await this.userRepository.save(user);

    // Add reverse relationship
    const friendEntity = await this.userRepository.findOne({
      where: { id: friendId },
      relations: ['friends'],
    });

    if (friendEntity) {
      friendEntity.friends = friendEntity.friends || [];
      friendEntity.friends.push(user);
      await this.userRepository.save(friendEntity);
    }
  }

  async removeFriend(userId: string, friendId: string): Promise<void> {
    const user = await this.userRepository.findOne({
      where: { id: userId },
      relations: ['friends'],
    });

    if (!user) {
      throw new NotFoundException('User not found');
    }

    // Remove friend relationship (bidirectional)
    user.friends = user.friends?.filter(friend => friend.id !== friendId) || [];
    await this.userRepository.save(user);

    // Remove reverse relationship
    const friendEntity = await this.userRepository.findOne({
      where: { id: friendId },
      relations: ['friends'],
    });

    if (friendEntity) {
      friendEntity.friends = friendEntity.friends?.filter(friend => friend.id !== userId) || [];
      await this.userRepository.save(friendEntity);
    }
  }

  // Search and discovery
  async searchUsers(query: string, currentUserId: string, limit = 20): Promise<User[]> {
    return this.userRepository
      .createQueryBuilder('user')
      .where('user.id != :currentUserId', { currentUserId })
      .andWhere(
        '(user.displayName LIKE :query OR user.email LIKE :query)',
        { query: `%${query}%` }
      )
      .andWhere('user.displayNameVisibility = :visibility', {
        visibility: VisibilityLevel.PUBLIC,
      })
      .select([
        'user.id',
        'user.email',
        'user.displayName',
        'user.avatarUrl',
        'user.bio',
        'user.createdAt',
      ])
      .take(limit)
      .getMany();
  }

  async updateLastSeen(userId: string): Promise<void> {
    await this.userRepository.update(userId, {
      lastSeen: new Date(),
    });
  }

  // Advanced queries
  async findUsersWithMusicPreferences(genres: string[], currentUserId?: string): Promise<User[]> {
    const queryBuilder = this.userRepository
      .createQueryBuilder('user')
      .leftJoin('user.friends', 'friend')
      .where('JSON_EXTRACT(user.musicPreferences, "$.favoriteGenres") IS NOT NULL')
      .andWhere(
        genres.map((_, index) => 
          `JSON_CONTAINS(user.musicPreferences, JSON_QUOTE(:genre${index}), "$.favoriteGenres")`
        ).join(' OR '),
        genres.reduce((params, genre, index) => {
          params[`genre${index}`] = genre;
          return params;
        }, {})
      );

    // Apply privacy filtering for music preferences
    if (currentUserId) {
      queryBuilder
        .andWhere(
          `(user.musicPreferenceVisibility = :publicVisibility 
           OR (user.musicPreferenceVisibility = :friendsVisibility AND friend.id = :currentUserId)
           OR user.id = :currentUserId)`,
          {
            publicVisibility: VisibilityLevel.PUBLIC,
            friendsVisibility: VisibilityLevel.FRIENDS,
            currentUserId: currentUserId
          }
        );
    } else {
      // If no current user, only show public music preferences
      queryBuilder.andWhere('user.musicPreferenceVisibility = :publicVisibility', {
        publicVisibility: VisibilityLevel.PUBLIC
      });
    }

    return queryBuilder
      .select([
        'user.id',
        'user.displayName',
        'user.avatarUrl',
        'user.musicPreferences',
        'user.musicPreferenceVisibility',
      ])
      .getMany();
  }

  async updateMusicPreferences(userId: string, preferences: MusicPreferencesDto): Promise<User> {
    const user = await this.userRepository.findOne({ where: { id: userId } });
    if (!user) throw new NotFoundException('User not found');
    user.musicPreferences = preferences;
    return this.userRepository.save(user);
  }

  async updatePrivacySettings(userId: string, privacySettings: Partial<{
    displayNameVisibility: VisibilityLevel;
    bioVisibility: VisibilityLevel;
    birthDateVisibility: VisibilityLevel;
    locationVisibility: VisibilityLevel;
    musicPreferenceVisibility: VisibilityLevel;
  }>): Promise<User> {
    const user = await this.userRepository.findOne({ where: { id: userId } });
    if (!user) {
      throw new NotFoundException('User not found');
    }

    // Update privacy settings
    Object.assign(user, privacySettings);
    
    return this.userRepository.save(user);
  }

  async getUserStats(userId: string): Promise<{
    friendsCount: number;
    eventsCreated: number;
    eventsParticipated: number;
    playlistsCreated: number;
    playlistsCollaborated: number;
  }> {
    const user = await this.userRepository.findOne({
      where: { id: userId },
      relations: [
        'friends',
        'createdEvents',
        'participatedEvents',
        'createdPlaylists',
        'collaboratedPlaylists',
      ],
    });

    if (!user) {
      throw new NotFoundException('User not found');
    }

    return {
      friendsCount: user.friends?.length || 0,
      eventsCreated: user.createdEvents?.length || 0,
      eventsParticipated: user.participatedEvents?.length || 0,
      playlistsCreated: user.createdPlaylists?.length || 0,
      playlistsCollaborated: user.collaboratedPlaylists?.length || 0,
    };
  }

  // Privacy methods
  async getVisibleUserData(userId: string, viewerId?: string): Promise<Partial<User>> {
    const user = await this.findById(userId);
    
    if (!user) {
      throw new NotFoundException('User not found');
    }

    // If viewing own profile, return all data
    if (viewerId === userId) {
      return user;
    }

    // Check if users are friends
    const isFriend = viewerId ? await this.areUsersFriends(userId, viewerId) : false;
    
    // Build visible data based on privacy settings
    const visibleData: Partial<User> = {
      id: user.id,
      email: viewerId === userId ? user.email : undefined, // Only show email to self
      createdAt: user.createdAt,
      lastSeen: user.lastSeen,
      // Always include privacy settings so UI can show what's visible
      displayNameVisibility: user.displayNameVisibility,
      bioVisibility: user.bioVisibility,
      birthDateVisibility: user.birthDateVisibility,
      locationVisibility: user.locationVisibility,
      musicPreferenceVisibility: user.musicPreferenceVisibility,
    };

    // Apply visibility rules
    if (user.displayNameVisibility === VisibilityLevel.PUBLIC || 
        (user.displayNameVisibility === VisibilityLevel.FRIENDS && isFriend)) {
      visibleData.displayName = user.displayName;
      visibleData.avatarUrl = user.avatarUrl;
    }

    if (user.bioVisibility === VisibilityLevel.PUBLIC || 
        (user.bioVisibility === VisibilityLevel.FRIENDS && isFriend)) {
      visibleData.bio = user.bio;
    }

    if (user.locationVisibility === VisibilityLevel.PUBLIC || 
        (user.locationVisibility === VisibilityLevel.FRIENDS && isFriend)) {
      visibleData.location = user.location;
    }

    if (user.birthDateVisibility === VisibilityLevel.PUBLIC || 
        (user.birthDateVisibility === VisibilityLevel.FRIENDS && isFriend)) {
      visibleData.birthDate = user.birthDate;
    }

    // Apply music preferences visibility rules
    if (user.musicPreferenceVisibility === VisibilityLevel.PUBLIC || 
        (user.musicPreferenceVisibility === VisibilityLevel.FRIENDS && isFriend)) {
      visibleData.musicPreferences = user.musicPreferences;
    }

    return visibleData;
  }

  private async areUsersFriends(userId1: string, userId2: string): Promise<boolean> {
    const user = await this.userRepository.findOne({
      where: { id: userId1 },
      relations: ['friends'],
    });

    return user?.friends?.some(friend => friend.id === userId2) || false;
  }

  // Utility method to filter user arrays based on privacy settings
  async filterUsersWithPrivacy(users: User[], viewerId?: string): Promise<Partial<User>[]> {
    return Promise.all(
      users.map(async (user) => 
        await this.getVisibleUserData(user.id, viewerId)
      )
    );
  }

  // Bulk operations
  async updateMultipleUsers(userIds: string[], updateData: Partial<User>): Promise<void> {
    await this.userRepository.update(userIds, updateData);
  }

  async deleteInactiveUsers(daysSinceLastSeen: number): Promise<number> {
    const cutoffDate = new Date();
    cutoffDate.setDate(cutoffDate.getDate() - daysSinceLastSeen);

    const result = await this.userRepository
      .createQueryBuilder()
      .delete()
      .from(User)
      .where('lastSeen < :cutoffDate', { cutoffDate })
      .andWhere('emailVerified = false')
      .execute();

    return result.affected || 0;
  }
}
