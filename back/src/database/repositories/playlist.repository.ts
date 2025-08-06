import { Injectable } from '@nestjs/common';
import { InjectRepository } from '@nestjs/typeorm';
import { Repository } from 'typeorm';
import { Playlist, PlaylistVisibility } from 'src/playlist/entities/playlist.entity';
import { PlaylistTrack } from 'src/playlist/entities/playlist-track.entity';

@Injectable()
export class PlaylistRepository {
  constructor(
    @InjectRepository(Playlist)
    private readonly playlistRepository: Repository<Playlist>,
    @InjectRepository(PlaylistTrack)
    private readonly playlistTrackRepository: Repository<PlaylistTrack>,
  ) {}

  async findById(id: string, relations: string[] = []): Promise<Playlist | null> {
    return this.playlistRepository.findOne({
      where: { id },
      relations,
    });
  }

  async findPublicPlaylists(limit = 20): Promise<Playlist[]> {
    return this.playlistRepository.find({
      where: { visibility: PlaylistVisibility.PUBLIC },
      relations: ['creator'],
      order: { updatedAt: 'DESC' },
      take: limit,
    });
  }

  async findUserPlaylists(userId: string): Promise<Playlist[]> {
    return this.playlistRepository.find({
      where: [
        { creatorId: userId },
        { collaborators: { id: userId } },
      ],
      relations: ['creator', 'collaborators'],
      order: { updatedAt: 'DESC' },
    });
  }

  async create(playlistData: Partial<Playlist>): Promise<Playlist> {
    const playlist = this.playlistRepository.create(playlistData);
    return this.playlistRepository.save(playlist);
  }

  async update(id: string, updateData: Partial<Playlist>): Promise<Playlist | null> {
    await this.playlistRepository.update(id, updateData);
    return this.findById(id);
  }

  async delete(id: string): Promise<void> {
    await this.playlistRepository.delete(id);
  }

  async addTrack(
    playlistId: string,
    trackId: string,
    addedById: string,
    position?: number,
  ): Promise<PlaylistTrack> {
    if (position === undefined) {
      const lastTrack = await this.playlistTrackRepository.findOne({
        where: { playlistId },
        order: { position: 'DESC' },
      });
      position = (lastTrack?.position || 0) + 1;
    }

    const playlistTrack = this.playlistTrackRepository.create({
      playlistId,
      trackId,
      addedById,
      position,
    });

    const saved = await this.playlistTrackRepository.save(playlistTrack);
    
    // Update playlist stats
    await this.updatePlaylistStats(playlistId);
    
    return saved;
  }

  async removeTrack(playlistId: string, trackId: string): Promise<void> {
    await this.playlistTrackRepository.delete({
      playlistId,
      trackId,
    });

    // Reorder remaining tracks
    await this.reorderTracks(playlistId);
    
    // Update playlist stats
    await this.updatePlaylistStats(playlistId);
  }

  async reorderTracks(playlistId: string, trackIds?: string[]): Promise<void> {
    if (trackIds) {
      // Reorder based on provided order
      for (let i = 0; i < trackIds.length; i++) {
        await this.playlistTrackRepository.update(
          { playlistId, trackId: trackIds[i] },
          { position: i + 1 },
        );
      }
    } else {
      // Auto-reorder to fill gaps
      const tracks = await this.playlistTrackRepository.find({
        where: { playlistId },
        order: { position: 'ASC' },
      });

      for (let i = 0; i < tracks.length; i++) {
        if (tracks[i].position !== i + 1) {
          await this.playlistTrackRepository.update(
            tracks[i].id,
            { position: i + 1 },
          );
        }
      }
    }
  }

  async getPlaylistTracks(playlistId: string): Promise<PlaylistTrack[]> {
    return this.playlistTrackRepository.find({
      where: { playlistId },
      relations: ['track', 'addedBy'],
      order: { position: 'ASC' },
    });
  }

  async addCollaborator(playlistId: string, userId: string): Promise<void> {
    await this.playlistRepository
      .createQueryBuilder()
      .relation(Playlist, 'collaborators')
      .of(playlistId)
      .add(userId);
  }

  async removeCollaborator(playlistId: string, userId: string): Promise<void> {
    await this.playlistRepository
      .createQueryBuilder()
      .relation(Playlist, 'collaborators')
      .of(playlistId)
      .remove(userId);
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
    });
  }
}