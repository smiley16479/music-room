import {
  Controller,
  Get,
  Post,
  Body,
  Patch,
  Param,
  Delete,
  Query,
  UseGuards,
  HttpCode,
  HttpStatus,
} from '@nestjs/common';
import { UserService } from './user.service';
import { CreateUserDto } from './dto/create-user.dto';
import { UpdateUserDto } from './dto/update-user.dto';
import { UpdatePasswordDto } from './dto/update-password.dto';
import { PaginationDto } from '../common/dto/pagination.dto';

import { JwtAuthGuard } from 'src/auth/guards/jwt-auth.guard';
import { Public } from '../auth/decorators/public.decorator';
import { CurrentUser } from '../common/decorators/current-user.decorator';
import { RequirePermissions } from '../common/decorators/permissions.decorator';
import { PERMISSIONS } from '../common/constants/permissions';

import { User } from './entities/user.entity';

@Controller('users')
@UseGuards(JwtAuthGuard)
export class UserController {
  constructor(private readonly userService: UserService) {}

  @Post()
  @RequirePermissions(PERMISSIONS.USERS.CREATE)
  async create(@Body() createUserDto: CreateUserDto) {
    const user = await this.userService.create(createUserDto);
    return {
      success: true,
      message: 'User created successfully',
      data: user,
      timestamp: new Date().toISOString(),
    };
  }

  @Get()
  @RequirePermissions(PERMISSIONS.USERS.READ_ALL)
  async findAll(@Query() paginationDto: PaginationDto) {
    return this.userService.findAll(paginationDto);
  }

  @Get('search')
  async searchUsers(
    @Query('q') query: string,
    @Query('limit') limit: string = '20',
    @CurrentUser() user: User,
  ) {
    const users = await this.userService.searchUsers(
      query,
      user.id,
      parseInt(limit, 10),
    );

    return {
      success: true,
      data: users,
      timestamp: new Date().toISOString(),
    };
  }

  @Get('me')
  async getProfile(@CurrentUser() user: User) {
    const fullUser = await this.userService.findById(user.id, [
      'friends',
      'createdEvents',
      'createdPlaylists',
    ]);

    return {
      success: true,
      data: fullUser,
      timestamp: new Date().toISOString(),
    };
  }

  @Get('me/stats')
  async getMyStats(@CurrentUser() user: User) {
    const stats = await this.userService.getUserStats(user.id);
    return {
      success: true,
      data: stats,
      timestamp: new Date().toISOString(),
    };
  }

  @Get('me/friends')
  async getMyFriends(@CurrentUser() user: User) {
    const friends = await this.userService.getFriends(user.id);
    return {
      success: true,
      data: friends,
      timestamp: new Date().toISOString(),
    };
  }

  @Post('me/friends/:friendId')
  @HttpCode(HttpStatus.OK)
  async addFriend(
    @Param('friendId') friendId: string,
    @CurrentUser() user: User,
  ) {
    await this.userService.addFriend(user.id, friendId);
    return {
      success: true,
      message: 'Friend added successfully',
      timestamp: new Date().toISOString(),
    };
  }

  @Delete('me/friends/:friendId')
  async removeFriend(
    @Param('friendId') friendId: string,
    @CurrentUser() user: User,
  ) {
    await this.userService.removeFriend(user.id, friendId);
    return {
      success: true,
      message: 'Friend removed successfully',
      timestamp: new Date().toISOString(),
    };
  }

  @Patch('me/password')
  @HttpCode(HttpStatus.OK)
  async updatePassword(
    @Body() updatePasswordDto: UpdatePasswordDto,
    @CurrentUser() user: User,
  ) {
    await this.userService.updatePassword(user.id, updatePasswordDto);
    return {
      success: true,
      message: 'Password updated successfully',
      timestamp: new Date().toISOString(),
    };
  }

  @Get('music-preferences')
  async findUsersWithMusicPreferences(@Query('genres') genres: string) {
    const genreList = genres ? genres.split(',') : [];
    const users = await this.userService.findUsersWithMusicPreferences(genreList);
    
    return {
      success: true,
      data: users,
      timestamp: new Date().toISOString(),
    };
  }

  @Get(':id')
  async findOne(@Param('id') id: string, @CurrentUser() user: User) {
    const userData = await this.userService.getVisibleUserData(id, user.id);
    return {
      success: true,
      data: userData,
      timestamp: new Date().toISOString(),
    };
  }

  @Patch('me')
  async updateProfile(
    @Body() updateUserDto: UpdateUserDto,
    @CurrentUser() user: User,
  ) {
    const updatedUser = await this.userService.update(user.id, updateUserDto);
    return {
      success: true,
      message: 'Profile updated successfully',
      data: updatedUser,
      timestamp: new Date().toISOString(),
    };
  }

  @Delete('me')
  async deleteAccount(@CurrentUser() user: User) {
    await this.userService.remove(user.id);
    return {
      success: true,
      message: 'Account deleted successfully',
      timestamp: new Date().toISOString(),
    };
  }

  // Admin endpoints
  @Get(':id/stats')
  @RequirePermissions(PERMISSIONS.USERS.READ_ALL)
  async getUserStats(@Param('id') id: string) {
    const stats = await this.userService.getUserStats(id);
    return {
      success: true,
      data: stats,
      timestamp: new Date().toISOString(),
    };
  }

  @Patch(':id')
  @RequirePermissions(PERMISSIONS.USERS.UPDATE)
  async update(@Param('id') id: string, @Body() updateUserDto: UpdateUserDto) {
    const user = await this.userService.update(id, updateUserDto);
    return {
      success: true,
      message: 'User updated successfully',
      data: user,
      timestamp: new Date().toISOString(),
    };
  }

  @Delete(':id')
  @RequirePermissions(PERMISSIONS.USERS.DELETE)
  async remove(@Param('id') id: string) {
    await this.userService.remove(id);
    return {
      success: true,
      message: 'User deleted successfully',
      timestamp: new Date().toISOString(),
    };
  }
}
