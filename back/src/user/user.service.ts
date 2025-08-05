import { Injectable } from '@nestjs/common';
import { CreateUserDto } from './dto/create-user.dto';
import { UpdateUserDto } from './dto/update-user.dto';
import { MailService } from '../mail/mail.service';

@Injectable()
export class UserService {
  constructor(private readonly mailService: MailService) {}

  async create(createUserDto: CreateUserDto) {
    // Your existing user creation logic here
    
    // Send welcome email to the new user
    await this.mailService.sendWelcomeEmail(
      createUserDto.email,
      createUserDto.displayName || 'User'
    );
    
    return 'This action adds a new user';
  }

  findAll() {
    return `This action returns all user`;
  }

  findOne(id: number) {
    return `This action returns a #${id} user`;
  }

  async update(id: number, updateUserDto: UpdateUserDto) {
    // Your existing user update logic here
    
    return `This action updates a #${id} user`;
  }

  remove(id: number) {
    return `This action removes a #${id} user`;
  }
}
