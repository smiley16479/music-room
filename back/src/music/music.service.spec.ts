import { Test, TestingModule } from '@nestjs/testing';
import { getRepositoryToken } from '@nestjs/typeorm';
import { Repository } from 'typeorm';
import { CACHE_MANAGER } from '@nestjs/cache-manager';

import { MusicService } from './music.service';
import { DeezerService } from './deezer.service';
import { Track } from 'src/music/entities/track.entity';
import { User } from 'src/user/entities/user.entity';

describe('MusicService', () => {
  let service: MusicService;
  let trackRepository: jest.Mocked<Repository<Track>>;
  let deezerService: jest.Mocked<DeezerService>;

  const mockTrack = {
    id: 'track-123',
    deezerId: 'deezer-123',
    title: 'Test Song',
    artist: 'Test Artist',
    album: 'Test Album',
    duration: 180,
    available: true,
  };

  const mockDeezerTrack = {
    id: 'deezer-123',
    title: 'Test Song',
    duration: 180,
    preview: 'https://preview.deezer.com/123.mp3',
    artist: {
      id: 'artist-123',
      name: 'Test Artist',
    },
    album: {
      id: 'album-123',
      title: 'Test Album',
      cover: 'https://cover.deezer.com/123.jpg',
      cover_small: 'https://cover.deezer.com/123-small.jpg',
      cover_medium: 'https://cover.deezer.com/123-medium.jpg',
      cover_big: 'https://cover.deezer.com/123-big.jpg',
      release_date: '2023-01-01',
    },
    link: 'https://deezer.com/track/123',
  };

  beforeEach(async () => {
    const module: TestingModule = await Test.createTestingModule({
      providers: [
        MusicService,
        {
          provide: getRepositoryToken(Track),
          useValue: {
            findOne: jest.fn(),
            find: jest.fn(),
            create: jest.fn(),
            save: jest.fn(),
            createQueryBuilder: jest.fn(() => ({
              where: jest.fn().mockReturnThis(),
              andWhere: jest.fn().mockReturnThis(),
              orderBy: jest.fn().mockReturnThis(),
              take: jest.fn().mockReturnThis(),
              getMany: jest.fn(),
            })),
          },
        },
        {
          provide: getRepositoryToken(User),
          useValue: {
            findOne: jest.fn(),
          },
        },
        {
          provide: DeezerService,
          useValue: {
            searchTracks: jest.fn(),
            searchAdvanced: jest.fn(),
            getTrack: jest.fn(),
            getTopTracks: jest.fn(),
            getGenres: jest.fn(),
            clearCache: jest.fn(),
          },
        },
      ],
    }).compile();

    service = module.get<MusicService>(MusicService);
    trackRepository = module.get<Repository<Track>>(getRepositoryToken(Track));
    deezerService = module.get<DeezerService>(DeezerService);
  });

  describe('searchTracks', () => {
    it('should search tracks successfully', async () => {
      const searchDto = { query: 'test song', limit: 10 };
      
      deezerService.searchTracks.mockResolvedValue({
        data: [mockDeezerTrack as any],
        total: 1,
      });

      trackRepository.findOne.mockResolvedValue(null);
      trackRepository.create.mockReturnValue(mockTrack as Track);
      trackRepository.save.mockResolvedValue(mockTrack as Track);

      const queryBuilder = {
        where: jest.fn().mockReturnThis(),
        andWhere: jest.fn().mockReturnThis(),
        orderBy: jest.fn().mockReturnThis(),
        take: jest.fn().mockReturnThis(),
        getMany: jest.fn().mockResolvedValue([]),
      };
      trackRepository.createQueryBuilder.mockReturnValue(queryBuilder as any);

      const result = await service.searchTracks(searchDto);

      expect(result.tracks).toHaveLength(1);
      expect(result.source).toBe('deezer');
      expect(result.total).toBe(1);
    });
  });

  describe('getTrackById', () => {
    it('should return track from local database if exists', async () => {
      trackRepository.findOne.mockResolvedValue(mockTrack as Track);

      const result = await service.getTrackById('track-123');

      expect(result).toEqual(mockTrack);
      expect(trackRepository.findOne).toHaveBeenCalledWith({ where: { id: 'track-123' } });
    });

    it('should fetch from Deezer if not in local database', async () => {
      trackRepository.findOne
        .mockResolvedValueOnce(null) // First call (by id)
        .mockResolvedValueOnce(null); // Second call (by deezerId)
      
      deezerService.getTrack.mockResolvedValue(mockDeezerTrack as any);
      trackRepository.create.mockReturnValue(mockTrack as Track);
      trackRepository.save.mockResolvedValue(mockTrack as Track);

      const result = await service.getTrackById('deezer-123');

      expect(result).toEqual(mockTrack);
      expect(deezerService.getTrack).toHaveBeenCalledWith('deezer-123');
      expect(trackRepository.save).toHaveBeenCalled();
    });
  });

  describe('getRecommendationsForUser', () => {
    it('should return recommendations based on user preferences', async () => {
      const user = {
        id: 'user-123',
        musicPreferences: {
          favoriteGenres: ['rock', 'pop'],
          favoriteArtists: ['Test Artist'],
        },
      };

      const userRepository = module.get<Repository<User>>(getRepositoryToken(User));
      userRepository.findOne.mockResolvedValue(user as User);

      jest.spyOn(service, 'searchTracks').mockResolvedValue({
        tracks: [mockTrack as Track],
        total: 1,
        source: 'deezer',
        hasMore: false,
      });

      const result = await service.getRecommendationsForUser('user-123');

      expect(result.recommended).toHaveLength(1);
      expect(result.reason).toBe('Based on your music preferences');
      expect(result.basedOn?.type).toBe('user_preferences');
    });
  });
});