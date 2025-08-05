import { Injectable } from '@nestjs/common';
import { InjectRepository } from '@nestjs/typeorm';
import { Repository, FindOptionsWhere } from 'typeorm';
import { User, VisibilityLevel } from 'src/user/entities/user.entity';

@Injectable()
export class UserRepository {
  constructor(
    @InjectRepository(User)
    private readonly userRepository: Repository<User>,
  ) {}

  async findById(id: string, relations: string[] = []): Promise<User | null> {
    return this.userRepository.findOne({
      where: { id },
      relations,
    });
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

  async create(userData: Partial<User>): Promise<User> {
    const user = this.userRepository.create(userData);
    return this.userRepository.save(user);
  }

  async update(id: string, updateData: Partial<User>): Promise<User | null> {
    await this.userRepository.update(id, updateData);
    return this.findById(id);
  }

  async delete(id: string): Promise<void> {
    await this.userRepository.delete(id);
  }

  async getFriends(userId: string): Promise<User[]> {
    const user = await this.userRepository.findOne({
      where: { id: userId },
      relations: ['friends'],
    });
    return user?.friends || [];
  }

  async addFriend(userId: string, friendId: string): Promise<void> {
    const user = await this.findById(userId, ['friends']);
    const friend = await this.findById(friendId);
    
    if (user && friend) {
      user.friends = user.friends || [];
      user.friends.push(friend);
      await this.userRepository.save(user);
    }
  }

  async removeFriend(userId: string, friendId: string): Promise<void> {
    const user = await this.findById(userId, ['friends']);
    
    if (user && user.friends) {
      user.friends = user.friends.filter(friend => friend.id !== friendId);
      await this.userRepository.save(user);
    }
  }

  async searchUsers(query: string, currentUserId: string, limit = 20): Promise<User[]> {
    return this.userRepository
      .createQueryBuilder('user')
      .where('user.id != :currentUserId', { currentUserId })
      .andWhere('(user.displayName LIKE :query OR user.email LIKE :query)')
      .andWhere('user.displayNameVisibility = :visibility')
      .setParameters({
        query: `%${query}%`,
        visibility: VisibilityLevel.PUBLIC,
      })
      .take(limit)
      .getMany();
  }

  async updateLastSeen(userId: string): Promise<void> {
    await this.userRepository.update(userId, {
      lastSeen: new Date(),
    });
  }
}