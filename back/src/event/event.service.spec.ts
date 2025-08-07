import { Test, TestingModule } from '@nestjs/testing';
import { getRepositoryToken } from '@nestjs/typeorm';
import { Repository } from 'typeorm';
import { NotFoundException, ForbiddenException } from '@nestjs/common';

import { EventService } from './event.service';
import { Event, EventStatus, EventVisibility } from 'src/event/entities/event.entity';
import { Vote } from 'src/event/entities/vote.entity';
import { Track } from 'src/music/entities/track.entity';
import { User } from 'src/user/entities/user.entity';
import { Invitation } from 'src/invitation/entities/invitation.entity';
import { EmailService } from 'src/email/email.service';
import { EventGateway } from './event.gateway';

describe('EventService', () => {
  let service: EventService;
  let eventRepository: jest.Mocked<Repository<Event>>;
  let voteRepository: jest.Mocked<Repository<Vote>>;
  let userRepository: jest.Mocked<Repository<User>>;

  const mockEvent = {
    id: '123',
    name: 'Test Event',
    creatorId: 'creator-123',
    status: EventStatus.UPCOMING,
    visibility: EventVisibility.PUBLIC,
    participants: [],
  };

  const mockUser = {
    id: 'user-123',
    email: 'test@example.com',
    displayName: 'Test User',
  };

  beforeEach(async () => {
    const module: TestingModule = await Test.createTestingModule({
      providers: [
        EventService,
        {
          provide: getRepositoryToken(Event),
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
              getManyAndCount: jest.fn(),
              relation: jest.fn().mockReturnThis(),
              of: jest.fn().mockReturnThis(),
              add: jest.fn(),
              remove: jest.fn(),
            })),
          },
        },
        {
          provide: getRepositoryToken(Vote),
          useValue: {
            findOne: jest.fn(),
            count: jest.fn(),
            create: jest.fn(),
            save: jest.fn(),
            delete: jest.fn(),
            remove: jest.fn(),
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
            sendEventInvitation: jest.fn(),
          },
        },
        {
          provide: EventGateway,
          useValue: {
            notifyEventUpdated: jest.fn(),
            notifyParticipantJoined: jest.fn(),
            notifyVoteUpdated: jest.fn(),
          },
        },
      ],
    }).compile();

    service = module.get<EventService>(EventService);
    eventRepository = module.get(getRepositoryToken(Event));
    voteRepository = module.get(getRepositoryToken(Vote));
    userRepository = module.get(getRepositoryToken(User));
  });

  describe('create', () => {
    it('should create an event successfully', async () => {
      const createEventDto = {
        name: 'New Event',
        description: 'Test event',
      };

      userRepository.findOne.mockResolvedValue(mockUser as User);
      eventRepository.create.mockReturnValue(mockEvent as unknown as Event);
      eventRepository.save.mockResolvedValue(mockEvent as unknown as Event);

      // Mock the addParticipant method dependencies
      const mockQueryBuilder = {
        relation: jest.fn().mockReturnThis(),
        of: jest.fn().mockReturnThis(),
        add: jest.fn().mockResolvedValue(undefined),
      };
      eventRepository.createQueryBuilder.mockReturnValue(mockQueryBuilder as any);

      jest.spyOn(service, 'findById').mockResolvedValue(mockEvent as any);

      const result = await service.create(createEventDto, 'creator-123');

      expect(userRepository.findOne).toHaveBeenCalledWith({ where: { id: 'creator-123' } });
      expect(eventRepository.create).toHaveBeenCalled();
      expect(eventRepository.save).toHaveBeenCalled();
      expect(result).toEqual(mockEvent);
    });

    it('should throw NotFoundException if creator not found', async () => {
      userRepository.findOne.mockResolvedValue(null);

      await expect(
        service.create({ name: 'Test' }, 'nonexistent-user')
      ).rejects.toThrow(NotFoundException);
    });
  });

  describe('findById', () => {
    it('should return event with stats', async () => {
      const eventWithRelations = {
        ...mockEvent,
        participants: [mockUser],
        votes: [],
      };

      eventRepository.findOne.mockResolvedValue(eventWithRelations as unknown as Event);

      const result = await service.findById('123', 'user-123');

      expect(eventRepository.findOne).toHaveBeenCalledWith({
        where: { id: '123' },
        relations: ['creator', 'participants', 'currentTrack', 'votes', 'votes.user', 'votes.track'],
      });
      expect(result.stats).toBeDefined();
      expect(result.stats.participantCount).toBe(1);
    });

    it('should throw NotFoundException if event not found', async () => {
      eventRepository.findOne.mockResolvedValue(null);

      await expect(service.findById('nonexistent', 'user-123')).rejects.toThrow(NotFoundException);
    });
  });
});