import { Test, TestingModule } from '@nestjs/testing';
import { PlaylistTrackService } from './playlist-track.service';

describe('PlaylistTrackService', () => {
  let service: PlaylistTrackService;

  beforeEach(async () => {
    const module: TestingModule = await Test.createTestingModule({
      providers: [PlaylistTrackService],
    }).compile();

    service = module.get<PlaylistTrackService>(PlaylistTrackService);
  });

  it('should be defined', () => {
    expect(service).toBeDefined();
  });
});
