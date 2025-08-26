import { Test, TestingModule } from '@nestjs/testing';
import { getRepositoryToken } from '@nestjs/typeorm';
import { Repository } from 'typeorm';
import { NotFoundException, ForbiddenException, ConflictException } from '@nestjs/common';

import { PlaylistService } from './playlist.service';
import { Playlist, PlaylistVisibility } from 'src/playlist/entities/playlist.entity';
import { PlaylistTrack } from 'src/playlist/entities/playlist-track.entity';
import { Track } from 'src/music/entities/track.entity';
import { User } from 'src/user/entities/user.entity';
import { Invitation } from 'src/invitation/entities/invitation.entity';
import { EmailService } from 'src/email/email.service';
import { PlaylistGateway } from './playlist.gateway';

describe('PlaylistService', () => {
  let service: PlaylistService;
  let playlistRepository: jest.Mocked<Repository<Playlist>>;
  let playlistTrackRepository: jest.Mocked<Repository<PlaylistTrack>>;

  const mockPlaylist = {
    id: '123',
    name: 'Test Playlist',
    creatorId: 'creator-123',
    visibility: PlaylistVisibility.PUBLIC,
    collaborators: [],
    trackCount: 0,
    totalDuration: 0,
  };

  const mockUser = {
    id: 'user-123',
    email: 'test@example.com',
    displayName: 'Test User',
  };

  const mockTrack = {
    id: 'track-123',
    title: 'Test Song',
    artist: 'Test Artist',
    duration: 180,
  };

  beforeEach(async () => {
    const module: TestingModule = await Test.createTestingModule({
      providers: [
        PlaylistService,
        {
          provide: getRepositoryToken(Playlist),
          useValue: {
            findOne: jest.fn(),
            find: jest.fn(),
            findAndCount: jest.fn(),
            create: jest.fn(),
            save: jest.fn(),
            update: jest.fn(),
            remove: jest.fn(),
            createQueryBuilder: jest.fn(() => ({
              leftJoinAndSelect: jest.fn().mockReturnThis(),
              where: jest.fn().mockReturnThis(),
              andWhere: jest.fn().mockReturnThis(),
              orWhere: jest.fn().mockReturnThis(),
              orderBy: jest.fn().mockReturnThis(),
              skip: jest.fn().mockReturnThis(),
              take: jest.fn().mockReturnThis(),
              setParameter: jest.fn().mockReturnThis(),
              getManyAndCount: jest.fn(),
              getMany: jest.fn(),
              relation: jest.fn().mockReturnThis(),
              of: jest.fn().mockReturnThis(),
              add: jest.fn(),
              remove: jest.fn(),
            })),
          },
        },
        {
          provide: getRepositoryToken(PlaylistTrack),
          useValue: {
            findOne: jest.fn(),
            find: jest.fn(),
            create: jest.fn(),
            save: jest.fn(),
            remove: jest.fn(),
            update: jest.fn(),
            createQueryBuilder: jest.fn(),
          },
        },
        {
          provide: getRepositoryToken(Track),
          useValue: {
            findOne: jest.fn(),
          },
        },
        {
          provide: getRepositoryToken(User),
          useValue: {
            findOne: jest.fn(),
          },
        },
        {
          provide: getRepositoryToken(Invitation),
          useValue: {
            findOne: jest.fn(),
            create: jest.fn(),
            save: jest.fn(),
          },
        },
        {
          provide: EmailService,
          useValue: {
            sendPlaylistInvitation: jest.fn(),
          },
        },
        {
          provide: PlaylistGateway,
          useValue: {
            notifyPlaylistUpdated: jest.fn(),
            notifyTrackAdded: jest.fn(),
            notifyCollaboratorAdded: jest.fn(),
          },
        },
      ],
    }).compile();

    service = module.get<PlaylistService>(PlaylistService);
    playlistRepository = module.get(getRepositoryToken(Playlist));
    playlistTrackRepository = module.get(getRepositoryToken(PlaylistTrack));
  });

  describe('create', () => {
    it('should create a playlist successfully', async () => {
      const createPlaylistDto = {
        name: 'New Playlist',
        description: 'Test playlist',
      };

      const userRepository = module.get(getRepositoryToken(User));
      userRepository.findOne.mockResolvedValue(mockUser as User);
      playlistRepository.create.mockReturnValue(mockPlaylist as unknown as Playlist);
      playlistRepository.save.mockResolvedValue(mockPlaylist as unknown as Playlist);

      // Mock the addCollaborator dependencies
      const mockQueryBuilder = {
        relation: jest.fn().mockReturnThis(),
        of: jest.fn().mockReturnThis(),
        add: jest.fn().mockResolvedValue(undefined),
      };
      playlistRepository.createQueryBuilder.mockReturnValue(mockQueryBuilder as any);

      jest.spyOn(service, 'findById').mockResolvedValue(mockPlaylist as any);

      const result = await service.create(createPlaylistDto, 'creator-123');

      expect(userRepository.findOne).toHaveBeenCalledWith({ where: { id: 'creator-123' } });
      expect(playlistRepository.create).toHaveBeenCalled();
      expect(playlistRepository.save).toHaveBeenCalled();
      expect(result).toEqual(mockPlaylist);
    });

    it('should throw NotFoundException if creator not found', async () => {
      const userRepository = module.get(getRepositoryToken(User));
      userRepository.findOne.mockResolvedValue(null);

      await expect(
        service.create({ name: 'Test' }, 'nonexistent-user')
      ).rejects.toThrow(NotFoundException);
    });
  });

  describe('addTrack', () => {
    it('should add track to playlist successfully', async () => {
      const trackRepository = module.get(getRepositoryToken(Track));
      
      jest.spyOn(service, 'findById').mockResolvedValue(mockPlaylist as any);
      jest.spyOn(service, 'checkEditPermissions' as any).mockResolvedValue(undefined);
      trackRepository.findOne.mockResolvedValue(mockTrack as Track);
      playlistTrackRepository.findOne
        .mockResolvedValueOnce(null) // No existing track
        .mockResolvedValueOnce({ position: 0 }) // Last track for position
        .mockResolvedValueOnce({ // Final result with relations
          id: 'pt-123',
          trackId: 'track-123',
          position: 1,
          track: mockTrack,
          addedBy: mockUser,
        } as any);
      
      playlistTrackRepository.create.mockReturnValue({ id: 'pt-123' } as any);
      playlistTrackRepository.save.mockResolvedValue({ id: 'pt-123' } as any);

      const result = await service.addTrack('123', 'user-123', { trackId: 'track-123' });

      expect(trackRepository.findOne).toHaveBeenCalledWith({ where: { id: 'track-123' } });
      expect(playlistTrackRepository.save).toHaveBeenCalled();
    });

    it('should throw ConflictException if track already exists', async () => {
      jest.spyOn(service, 'findById').mockResolvedValue(mockPlaylist as any);
      jest.spyOn(service, 'checkEditPermissions' as any).mockResolvedValue(undefined);
      
      const trackRepository = module.get(getRepositoryToken(Track));
      trackRepository.findOne.mockResolvedValue(mockTrack as Track);
      playlistTrackRepository.findOne.mockResolvedValue({ id: 'existing' } as any);

      await expect(
        service.addTrack('123', 'user-123', { trackId: 'track-123' })
      ).rejects.toThrow(ConflictException);
    });
  });
});