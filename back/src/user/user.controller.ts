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
import { ApiTags, ApiOperation, ApiBody, ApiParam, ApiQuery } from '@nestjs/swagger';

@ApiTags('Users')
@Controller('users')
@UseGuards(JwtAuthGuard)
export class UserController {
  constructor(private readonly userService: UserService) {}

  @Post()
  @RequirePermissions(PERMISSIONS.USERS.CREATE)
  @ApiOperation({
    summary: 'Create a new user',
    description: 'Creates a new user (admin only)',
  })
  @ApiBody({ type: CreateUserDto })
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
  @ApiOperation({
    summary: 'Get all users',
    description: 'Returns a paginated list of all users (admin only)',
  })
  @ApiQuery({ type: PaginationDto })
  async findAll(@Query() paginationDto: PaginationDto) {
    return this.userService.findAll(paginationDto);
  }

  @Get('search')
  @ApiOperation({
    summary: 'Search users',
    description: 'Search for users by username, display name, or other criteria',
  })
  @ApiQuery({ 
    name: 'q', 
    type: String, 
    required: true,
    description: 'Search query'
  })
  @ApiQuery({ 
    name: 'limit', 
    type: String, 
    required: false,
    description: 'Maximum number of results to return',
    example: '20'
  })
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
  @ApiOperation({
    summary: 'Get current user profile',
    description: 'Returns the full profile of the currently authenticated user',
  })
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
  @ApiOperation({
    summary: 'Get current user stats',
    description: 'Returns activity statistics for the current user',
  })
  async getMyStats(@CurrentUser() user: User) {
    const stats = await this.userService.getUserStats(user.id);
    return {
      success: true,
      data: stats,
      timestamp: new Date().toISOString(),
    };
  }

  @Get('me/friends')
  @ApiOperation({
    summary: 'Get my friends',
    description: 'Returns a list of the current user\'s friends',
  })
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
  @ApiOperation({
    summary: 'Add friend',
    description: 'Adds another user to the current user\'s friends list',
  })
  @ApiParam({
    name: 'friendId',
    type: String,
    description: 'The ID of the user to add as friend',
    required: true
  })
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
  @ApiOperation({
    summary: 'Remove friend',
    description: 'Removes a user from the current user\'s friends list',
  })
  @ApiParam({
    name: 'friendId',
    type: String,
    description: 'The ID of the user to remove as friend',
    required: true
  })
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
  @ApiOperation({
    summary: 'Update password',
    description: 'Changes the current user\'s password',
  })
  @ApiBody({ type: UpdatePasswordDto })
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
  @ApiOperation({
    summary: 'Find users by music preferences',
    description: 'Search for users who have similar music genre preferences',
  })
  @ApiQuery({ 
    name: 'genres', 
    type: String, 
    description: 'Comma-separated list of music genres to filter by',
    required: false,
    example: 'rock,pop,jazz'
  })
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
  @ApiOperation({
    summary: 'Get user by ID',
    description: 'Returns public information about a specific user',
  })
  @ApiParam({
    name: 'id',
    type: String,
    description: 'The ID of the user to retrieve',
    required: true
  })
  async findOne(@Param('id') id: string, @CurrentUser() user: User) {
    const userData = await this.userService.getVisibleUserData(id, user.id);
    return {
      success: true,
      data: userData,
      timestamp: new Date().toISOString(),
    };
  }

  @Patch('me')
  @ApiOperation({
    summary: 'Update my profile',
    description: 'Updates the current user\'s profile information',
  })
  @ApiBody({ type: UpdateUserDto })
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
  @ApiOperation({
    summary: 'Delete my account',
    description: 'Permanently deletes the current user\'s account and all associated data',
  })
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
  @ApiOperation({
    summary: 'Get user stats (Admin)',
    description: 'Returns detailed statistics for a specific user (admin only)',
  })
  @ApiParam({
    name: 'id',
    type: String,
    description: 'The ID of the user to get stats for',
    required: true
  })
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
  @ApiOperation({
    summary: 'Update user (Admin)',
    description: 'Updates any user\'s information (admin only)',
  })
  @ApiParam({
    name: 'id',
    type: String,
    description: 'The ID of the user to update',
    required: true
  })
  @ApiBody({ type: UpdateUserDto })
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
  @ApiOperation({
    summary: 'Delete user (Admin)',
    description: 'Permanently deletes any user\'s account (admin only)',
  })
  @ApiParam({
    name: 'id',
    type: String,
    description: 'The ID of the user to delete',
    required: true
  })
  async remove(@Param('id') id: string) {
    await this.userService.remove(id);
    return {
      success: true,
      message: 'User deleted successfully',
      timestamp: new Date().toISOString(),
    };
  }
}
