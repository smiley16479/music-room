import { Test, TestingModule } from '@nestjs/testing';
import { PlaylistTrackController } from './playlist-track.controller';
import { PlaylistTrackService } from './playlist-track.service';

describe('PlaylistTrackController', () => {
  let controller: PlaylistTrackController;

  beforeEach(async () => {
    const module: TestingModule = await Test.createTestingModule({
      controllers: [PlaylistTrackController],
      providers: [PlaylistTrackService],
    }).compile();

    controller = module.get<PlaylistTrackController>(PlaylistTrackController);
  });

  it('should be defined', () => {
    expect(controller).toBeDefined();
  });
});
