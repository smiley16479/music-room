import {
  Injectable,
  NotFoundException,
  BadRequestException,
  ForbiddenException,
  ConflictException,
} from '@nestjs/common';
import { InjectRepository } from '@nestjs/typeorm';
import { Repository, FindOptionsWhere, In } from 'typeorm';

import { 
  Playlist, 
  PlaylistVisibility, 
  PlaylistLicenseType 
} from 'src/playlist/entities/playlist.entity';
import { PlaylistTrack } from 'src/playlist/entities/playlist-track.entity';
import { Track } from 'src/music/entities/track.entity';
import { User } from 'src/user/entities/user.entity';
import { 
  Invitation, 
  InvitationType, 
  InvitationStatus 
} from 'src/invitation/entities/invitation.entity';

import { CreatePlaylistDto } from './dto/create-playlist.dto';
import { UpdatePlaylistDto } from './dto/update-playlist.dto';
import { AddTrackToPlaylistDto } from './dto/add-track.dto';
import { ReorderTracksDto } from './dto/reorder-tracks.dto';
import { PaginationDto } from '../common/dto/pagination.dto';

import { EmailService } from '../email/email.service';
import { PlaylistGateway } from './playlist.gateway';

export interface PlaylistWithStats extends Playlist {
  stats: {
    trackCount: number;
    totalDuration: number;
    collaboratorCount: number;
    isUserCollaborator: boolean;
    isUserOwner: boolean;
  };
}

export interface PlaylistTrackWithDetails extends PlaylistTrack {
  track: Track;
  addedBy: User;
}

export interface CollaborativeOperation {
  type: 'add' | 'remove' | 'reorder' | 'update';
  trackId?: string;
  position?: number;
  userId: string;
  timestamp: Date;
}

@Injectable()
export class PlaylistService {
  constructor(
    @InjectRepository(Playlist)
    private readonly playlistRepository: Repository<Playlist>,
    @InjectRepository(PlaylistTrack)
    private readonly playlistTrackRepository: Repository<PlaylistTrack>,
    @InjectRepository(Track)
    private readonly trackRepository: Repository<Track>,
    @InjectRepository(User)
    private readonly userRepository: Repository<User>,
    @InjectRepository(Invitation)
    private readonly invitationRepository: Repository<Invitation>,
    private readonly emailService: EmailService,
    private readonly playlistGateway: PlaylistGateway,
  ) {}

  // CRUD Operations
  async create(createPlaylistDto: CreatePlaylistDto, creatorId: string): Promise<PlaylistWithStats> {
    const creator = await this.userRepository.findOne({ where: { id: creatorId } });
    if (!creator) {
      throw new NotFoundException('Creator not found');
    }

    const playlist = this.playlistRepository.create({
      ...createPlaylistDto,
      creatorId,
      trackCount: 0,
      totalDuration: 0,
    });

    const savedPlaylist = await this.playlistRepository.save(playlist);

    // Add creator as first collaborator if collaborative
    await this.addCollaborator(savedPlaylist.id, creatorId, creatorId);

    return this.findById(savedPlaylist.id, creatorId);
  }

  async findAll(paginationDto: PaginationDto, userId?: string) {
    const { page, limit, skip } = paginationDto;

    const queryBuilder = this.playlistRepository.createQueryBuilder('playlist')
      .leftJoinAndSelect('playlist.creator', 'creator')
      .leftJoinAndSelect('playlist.collaborators', 'collaborators')
      .where('playlist.visibility = :visibility', { visibility: PlaylistVisibility.PUBLIC })
      .orWhere('playlist.creatorId = :userId', { userId })
      .orWhere('collaborators.id = :userId', { userId })
      .orderBy('playlist.updatedAt', 'DESC')
      .skip(skip)
      .take(limit);

    const [playlists, total] = await queryBuilder.getManyAndCount();

    const playlistsWithStats = await Promise.all(
      playlists.map(playlist => this.addPlaylistStats(playlist, userId)),
    );

    const totalPages = Math.ceil(total / limit);

    return {
      success: true,
      data: playlistsWithStats,
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

  async findById(id: string, userId?: string): Promise<PlaylistWithStats> {
    const playlist = await this.playlistRepository.findOne({
      where: { id },
      relations: ['creator', 'collaborators'],
    });

    if (!playlist) {
      throw new NotFoundException('Playlist not found');
    }

    // Check access permissions
    await this.checkPlaylistAccess(playlist, userId);

    return this.addPlaylistStats(playlist, userId);
  }

  async update(
    id: string, 
    updatePlaylistDto: UpdatePlaylistDto, 
    userId: string
  ): Promise<PlaylistWithStats> {
    const playlist = await this.findById(id, userId);

    // Check if user can edit
    await this.checkEditPermissions(playlist, userId);

    Object.assign(playlist, updatePlaylistDto);
    const updatedPlaylist = await this.playlistRepository.save(playlist);

    // Notify collaborators of changes
    this.playlistGateway.notifyPlaylistUpdated(id, updatedPlaylist, userId);

    return this.addPlaylistStats(updatedPlaylist, userId);
  }

  async remove(id: string, userId: string): Promise<void> {
    const playlist = await this.findById(id, userId);

    // Only creator can delete playlist
    if (playlist.creatorId !== userId) {
      throw new ForbiddenException('Only the creator can delete this playlist');
    }

    await this.playlistRepository.remove(playlist);

    // Notify collaborators
    this.playlistGateway.notifyPlaylistDeleted(id, userId);
  }

  // Track Management
  async addTrack(
    playlistId: string, 
    userId: string, 
    addTrackDto: AddTrackToPlaylistDto
  ): Promise<PlaylistTrackWithDetails> {
    const playlist = await this.findById(playlistId, userId);
    
    // Check edit permissions
    await this.checkEditPermissions(playlist, userId);

    // Get or create track
    let track = await this.trackRepository.findOne({
      where: { deezerId: addTrackDto.deezerId },
    });

    if (!track) {
      track = this.trackRepository.create({
        deezerId: addTrackDto.deezerId,
        title: addTrackDto.title,
        artist: addTrackDto.artist,
        album: addTrackDto.album,
        duration: addTrackDto.duration,
        previewUrl: addTrackDto.previewUrl,
        albumCoverUrl: addTrackDto.albumCoverUrl,
      });
      track = await this.trackRepository.save(track);
    }

    // Check if track already exists in playlist
    const existingTrack = await this.playlistTrackRepository.findOne({
      where: { playlistId, trackId: track.id },
    });

    if (existingTrack) {
      throw new ConflictException('Track already exists in playlist');
    }

    // Determine position
    let position = addTrackDto.position;
    if (!position) {
      const lastTrack = await this.playlistTrackRepository.findOne({
        where: { playlistId },
        order: { position: 'DESC' },
      });
      position = (lastTrack?.position || 0) + 1;
    } else {
      // Shift existing tracks if inserting at specific position
      await this.shiftTracksPosition(playlistId, position, 1);
    }

    // Create playlist track
    const playlistTrack = this.playlistTrackRepository.create({
      playlistId,
      trackId: track.id,
      addedById: userId,
      position,
    });

    const savedPlaylistTrack = await this.playlistTrackRepository.save(playlistTrack);

    // Update playlist stats
    await this.updatePlaylistStats(playlistId);

    // Get complete track details
    const trackWithDetails = await this.playlistTrackRepository.findOne({
      where: { id: savedPlaylistTrack.id },
      relations: ['track', 'addedBy'],
    }) as PlaylistTrackWithDetails;

    // Notify collaborators
    this.playlistGateway.notifyTrackAdded(playlistId, trackWithDetails, userId);

    return trackWithDetails;
  }

  async removeTrack(
    playlistId: string, 
    trackId: string, 
    userId: string
  ): Promise<void> {
    const playlist = await this.findById(playlistId, userId);
    
    // Check edit permissions
    await this.checkEditPermissions(playlist, userId);

    const playlistTrack = await this.playlistTrackRepository.findOne({
      where: { playlistId, trackId },
      relations: ['track', 'addedBy'],
    });

    if (!playlistTrack) {
      throw new NotFoundException('Track not found in playlist');
    }

    const position = playlistTrack.position;

    // Remove track
    await this.playlistTrackRepository.remove(playlistTrack);

    // Shift remaining tracks
    await this.shiftTracksPosition(playlistId, position + 1, -1);

    // Update playlist stats
    await this.updatePlaylistStats(playlistId);

    // Notify collaborators
    this.playlistGateway.notifyTrackRemoved(playlistId, trackId, userId);
  }

  async reorderTracks(
    playlistId: string, 
    userId: string, 
    reorderDto: ReorderTracksDto
  ): Promise<PlaylistTrackWithDetails[]> {
    const playlist = await this.findById(playlistId, userId);
    
    // Check edit permissions
    await this.checkEditPermissions(playlist, userId);

    const { trackIds } = reorderDto;

    // Validate all tracks exist in playlist
    const existingTracks = await this.playlistTrackRepository.find({
      where: { playlistId, trackId: In(trackIds) },
    });

    if (existingTracks.length !== trackIds.length) {
      throw new BadRequestException('Some tracks are not in the playlist');
    }

    // Update positions
    for (let i = 0; i < trackIds.length; i++) {
      await this.playlistTrackRepository.update(
        { playlistId, trackId: trackIds[i] },
        { position: i + 1 },
      );
    }

    // Get updated tracks
    const updatedTracks = await this.getPlaylistTracks(playlistId);

    // Notify collaborators
    this.playlistGateway.notifyTracksReordered(playlistId, trackIds, userId);

    return updatedTracks;
  }

  async getPlaylistTracks(playlistId: string, userId?: string): Promise<PlaylistTrackWithDetails[]> {
    const playlist = await this.findById(playlistId, userId);

    const tracks = await this.playlistTrackRepository.find({
      where: { playlistId },
      relations: ['track', 'addedBy'],
      order: { position: 'ASC' },
    });

    return tracks as PlaylistTrackWithDetails[];
  }

  // Collaborator Management
  async addCollaborator(
    playlistId: string, 
    collaboratorId: string, 
    requesterId: string
  ): Promise<void> {
    const playlist = await this.findById(playlistId, requesterId);

    // Only creator or existing collaborators can add new collaborators
    const canAddCollaborator = playlist.creatorId === requesterId || 
      playlist.collaborators?.some(c => c.id === requesterId);

    if (!canAddCollaborator) {
      throw new ForbiddenException('You cannot add collaborators to this playlist');
    }

    // Check if user is already a collaborator
    const isAlreadyCollaborator = playlist.collaborators?.some(c => c.id === collaboratorId);
    if (isAlreadyCollaborator) {
      throw new ConflictException('User is already a collaborator');
    }

    // Add collaborator
    await this.playlistRepository
      .createQueryBuilder()
      .relation(Playlist, 'collaborators')
      .of(playlistId)
      .add(collaboratorId);

    const collaborator = await this.userRepository.findOne({ 
      where: { id: collaboratorId } 
    });

    // Notify collaborators
    this.playlistGateway.notifyCollaboratorAdded(playlistId, collaborator!, requesterId);
  }

  async removeCollaborator(
    playlistId: string, 
    collaboratorId: string, 
    requesterId: string
  ): Promise<void> {
    const playlist = await this.findById(playlistId, requesterId);

    // Creator can remove anyone, collaborators can only remove themselves
    const canRemove = playlist.creatorId === requesterId || 
      (collaboratorId === requesterId);

    if (!canRemove) {
      throw new ForbiddenException('You cannot remove this collaborator');
    }

    // Cannot remove creator
    if (collaboratorId === playlist.creatorId) {
      throw new BadRequestException('Cannot remove playlist creator');
    }

    // Remove collaborator
    await this.playlistRepository
      .createQueryBuilder()
      .relation(Playlist, 'collaborators')
      .of(playlistId)
      .remove(collaboratorId);

    const collaborator = await this.userRepository.findOne({ 
      where: { id: collaboratorId } 
    });

    // Notify collaborators
    this.playlistGateway.notifyCollaboratorRemoved(playlistId, collaborator!, requesterId);
  }

  async getCollaborators(playlistId: string, userId?: string): Promise<User[]> {
    const playlist = await this.playlistRepository.findOne({
      where: { id: playlistId },
      relations: ['collaborators'],
    });

    if (!playlist) {
      throw new NotFoundException('Playlist not found');
    }

    await this.checkPlaylistAccess(playlist, userId);

    return playlist.collaborators || [];
  }

  // Search and Discovery
  async searchPlaylists(query: string, userId?: string, limit = 20) {
    const queryBuilder = this.playlistRepository.createQueryBuilder('playlist')
      .leftJoinAndSelect('playlist.creator', 'creator')
      .leftJoinAndSelect('playlist.collaborators', 'collaborators')
      .where('playlist.visibility = :visibility', { visibility: PlaylistVisibility.PUBLIC })
      .andWhere('(playlist.name LIKE :query OR playlist.description LIKE :query)')
      .setParameter('query', `%${query}%`)
      .orderBy('playlist.updatedAt', 'DESC')
      .take(limit);

    const playlists = await queryBuilder.getMany();

    const playlistsWithStats = await Promise.all(
      playlists.map(playlist => this.addPlaylistStats(playlist, userId)),
    );

    return {
      success: true,
      data: playlistsWithStats,
      timestamp: new Date().toISOString(),
    };
  }

  async getRecommendedPlaylists(userId: string, limit = 20) {
    // Get user's music preferences
    const user = await this.userRepository.findOne({ where: { id: userId } });
    if (!user || !user.musicPreferences?.favoriteGenres) {
      return this.findAll({ page: 1, limit } as PaginationDto, userId);
    }

    // Find playlists with tracks matching user's preferences
    // This is a simplified version - in production you'd want more sophisticated recommendation logic
    const playlists = await this.playlistRepository.find({
      where: { visibility: PlaylistVisibility.PUBLIC },
      relations: ['creator', 'collaborators'],
      order: { updatedAt: 'DESC' },
      take: limit,
    });

    const playlistsWithStats = await Promise.all(
      playlists.map(playlist => this.addPlaylistStats(playlist, userId)),
    );

    return {
      success: true,
      data: playlistsWithStats,
      timestamp: new Date().toISOString(),
    };
  }

  // Playlist Duplication
  async duplicatePlaylist(
    originalPlaylistId: string, 
    userId: string, 
    newName?: string
  ): Promise<PlaylistWithStats> {
    const originalPlaylist = await this.findById(originalPlaylistId, userId);
    const originalTracks = await this.getPlaylistTracks(originalPlaylistId, userId);

    // Create new playlist
    const duplicatePlaylist = await this.create({
      name: newName || `Copy of ${originalPlaylist.name}`,
      description: originalPlaylist.description,
      visibility: originalPlaylist.visibility,
      licenseType: originalPlaylist.licenseType,
    }, userId);

    // Copy all tracks
    for (const playlistTrack of originalTracks) {
      await this.addExistingTrackToPlaylist(
        duplicatePlaylist.id,
        playlistTrack.track.id,
        userId,
        playlistTrack.position
      );
    }

    return this.findById(duplicatePlaylist.id, userId);
  }

  // Invitation System
  async inviteCollaborators(
    playlistId: string, 
    inviterUserId: string, 
    inviteeEmails: string[]
  ): Promise<void> {
    const playlist = await this.findById(playlistId, inviterUserId);

    // Check if user can invite
    const canInvite = playlist.creatorId === inviterUserId || 
      playlist.collaborators?.some(c => c.id === inviterUserId);

    if (!canInvite) {
      throw new ForbiddenException('You cannot invite collaborators to this playlist');
    }

    const inviter = await this.userRepository.findOne({ where: { id: inviterUserId } });

    for (const email of inviteeEmails) {
      // Check if user exists
      const invitee = await this.userRepository.findOne({ where: { email } });

      if (invitee) {
        // Create invitation record
        const invitation = this.invitationRepository.create({
          inviterId: inviterUserId,
          inviteeId: invitee.id,
          playlistId,
          type: InvitationType.PLAYLIST,
          status: InvitationStatus.PENDING,
          expiresAt: new Date(Date.now() + 7 * 24 * 60 * 60 * 1000), // 7 days
        });

        await this.invitationRepository.save(invitation);
      }

      // Send invitation email
      const playlistUrl = `${process.env.FRONTEND_URL}/playlists/${playlistId}`;
      await this.emailService.sendPlaylistInvitation(
        email,
        playlist.name,
        inviter?.displayName || 'A friend',
        playlistUrl,
      );
    }
  }

  // Export/Import
  async exportPlaylist(playlistId: string, userId: string): Promise<any> {
    const playlist = await this.findById(playlistId, userId);
    const tracks = await this.getPlaylistTracks(playlistId, userId);

    return {
      playlist: {
        name: playlist.name,
        description: playlist.description,
        createdAt: playlist.createdAt,
        updatedAt: playlist.updatedAt,
      },
      tracks: tracks.map(pt => ({
        position: pt.position,
        addedAt: pt.addedAt,
        track: {
          deezerId: pt.track.deezerId,
          title: pt.track.title,
          artist: pt.track.artist,
          album: pt.track.album,
          duration: pt.track.duration,
        },
      })),
    };
  }

  // Helper Methods
  private async addPlaylistStats(
    playlist: Playlist, 
    userId?: string
  ): Promise<PlaylistWithStats> {
    const collaboratorCount = playlist.collaborators?.length || 0;
    const isUserCollaborator = userId ? 
      playlist.collaborators?.some(c => c.id === userId) || false : false;
    const isUserOwner = userId ? playlist.creatorId === userId : false;

    return {
      ...playlist,
      stats: {
        trackCount: playlist.trackCount,
        totalDuration: playlist.totalDuration,
        collaboratorCount,
        isUserCollaborator,
        isUserOwner,
      },
    };
  }

  private async checkPlaylistAccess(playlist: Playlist, userId?: string): Promise<void> {
    if (playlist.visibility === PlaylistVisibility.PUBLIC) {
      return; // Public playlists are accessible to everyone
    }

    if (!userId) {
      throw new ForbiddenException('Authentication required for private playlists');
    }

    // Check if user is creator or collaborator
    const hasAccess = playlist.creatorId === userId || 
      playlist.collaborators?.some(c => c.id === userId);

    if (!hasAccess) {
      // Check for invitation
      const invitation = await this.invitationRepository.findOne({
        where: {
          playlistId: playlist.id,
          inviteeId: userId,
          status: InvitationStatus.ACCEPTED,
        },
      });

      if (!invitation) {
        throw new ForbiddenException('You do not have access to this private playlist');
      }
    }
  }

  private async checkEditPermissions(playlist: Playlist, userId: string): Promise<void> {
    switch (playlist.licenseType) {
      case PlaylistLicenseType.OPEN:
        return; // Everyone can edit public playlists

      case PlaylistLicenseType.INVITED:
        const canEdit = playlist.creatorId === userId || 
          playlist.collaborators?.some(c => c.id === userId);

        if (!canEdit) {
          throw new ForbiddenException('Only invited collaborators can edit this playlist');
        }
        break;
    }
  }

  private async shiftTracksPosition(
    playlistId: string, 
    fromPosition: number, 
    shift: number
  ): Promise<void> {
    if (shift > 0) {
      // Shifting up - update in descending order to avoid constraint violations
      await this.playlistTrackRepository
        .createQueryBuilder()
        .update(PlaylistTrack)
        .set({ position: () => 'position + :shift' })
        .where('playlistId = :playlistId AND position >= :fromPosition')
        .setParameters({ playlistId, fromPosition, shift })
        .execute();
    } else {
      // Shifting down - update in ascending order
      await this.playlistTrackRepository
        .createQueryBuilder()
        .update(PlaylistTrack)
        .set({ position: () => 'position + :shift' })
        .where('playlistId = :playlistId AND position >= :fromPosition')
        .setParameters({ playlistId, fromPosition, shift })
        .execute();
    }
  }

  private async updatePlaylistStats(playlistId: string): Promise<void> {
    const tracks = await this.playlistTrackRepository.find({
      where: { playlistId },
      relations: ['track'],
    });

    const trackCount = tracks.length;
    const totalDuration = tracks.reduce((sum, pt) => sum + (pt.track?.duration || 0), 0);

    await this.playlistRepository.update(playlistId, {
      trackCount,
      totalDuration,
      updatedAt: new Date(),
    });
  }

  // Ajout d'un track existant à une playlist (pour duplication)
  private async addExistingTrackToPlaylist(
    playlistId: string,
    trackId: string,
    userId: string,
    position?: number
  ) {
    // Vérifie que le track existe en base
    const track = await this.trackRepository.findOne({ where: { id: trackId } });
    if (!track) throw new NotFoundException('Track not found');

    // Vérifie qu'il n'est pas déjà dans la playlist
    const existingTrack = await this.playlistTrackRepository.findOne({ where: { playlistId, trackId } });
    if (existingTrack) throw new ConflictException('Track already exists in playlist');

    // Ajoute le track à la playlist
    const playlistTrack = this.playlistTrackRepository.create({
      playlistId,
      trackId,
      addedById: userId,
      position,
    });
    await this.playlistTrackRepository.save(playlistTrack);
  }
}