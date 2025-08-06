import { Test, TestingModule } from '@nestjs/testing';
import { getRepositoryToken } from '@nestjs/typeorm';
import { Repository } from 'typeorm';
import { NotFoundException, ForbiddenException, ConflictException } from '@nestjs/common';

import { InvitationService } from './invitation.service';
import { 
  Invitation, 
  InvitationType, 
  InvitationStatus 
} from 'src/invitation/entities/invitation.entity';
import { User } from 'src/user/entities/user.entity';
import { Event } from 'src/event/entities/event.entity';
import { Playlist } from 'src/playlist/entities/playlist.entity';
import { EmailService } from '../email/email.service';

describe('InvitationService', () => {
  let service: InvitationService;
  let invitationRepository: jest.Mocked<Repository<Invitation>>;
  let userRepository: jest.Mocked<Repository<User>>;
  let eventRepository: jest.Mocked<Repository<Event>>;

  const mockInvitation = {
    id: '123',
    inviterId: 'inviter-123',
    inviteeId: 'invitee-123',
    type: InvitationType.FRIEND,
    status: InvitationStatus.PENDING,
    createdAt: new Date(),
  };

  const mockUser = {
    id: 'user-123',
    email: 'test@example.com',
    displayName: 'Test User',
  };

  const mockEvent = {
    id: 'event-123',
    name: 'Test Event',
    creatorId: 'creator-123',
    participants: [],
  };

  beforeEach(async () => {
    const module: TestingModule = await Test.createTestingModule({
      providers: [
        InvitationService,
        {
          provide: getRepositoryToken(Invitation),
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
              orderBy: jest.fn().mockReturnThis(),
              skip: jest.fn().mockReturnThis(),
              take: jest.fn().mockReturnThis(),
              getManyAndCount: jest.fn(),
              getMany: jest.fn(),
              delete: jest.fn().mockReturnThis(),
              from: jest.fn().mockReturnThis(),
              execute: jest.fn(),
            })),
          },
        },
        {
          provide: getRepositoryToken(User),
          useValue: {
            findOne: jest.fn(),
            createQueryBuilder: jest.fn(),
          },
        },
        {
          provide: getRepositoryToken(Event),
          useValue: {
            findOne: jest.fn(),
            createQueryBuilder: jest.fn(),
          },
        },
        {
          provide: getRepositoryToken(Playlist),
          useValue: {
            findOne: jest.fn(),
            createQueryBuilder: jest.fn(),
          },
        },
        {
          provide: EmailService,
          useValue: {
            sendEventInvitation: jest.fn(),
            sendPlaylistInvitation: jest.fn(),
            sendFriendRequest: jest.fn(),
          },
        },
      ],
    }).compile();

    service = module.get<InvitationService>(InvitationService);
    invitationRepository = module.get<Repository<Invitation>>(getRepositoryToken(Invitation));
    userRepository = module.get<Repository<User>>(getRepositoryToken(User));
    eventRepository = module.get<Repository<Event>>(getRepositoryToken(Event));
  });

  describe('create', () => {
    it('should create a friend invitation successfully', async () => {
      const createInvitationDto = {
        inviteeId: 'invitee-123',
        type: InvitationType.FRIEND,
        message: 'Let\'s be friends!',
      };

      const inviter = { ...mockUser, id: 'inviter-123' };
      const invitee = { ...mockUser, id: 'invitee-123' };

      userRepository.findOne
        .mockResolvedValueOnce(inviter as User) // inviter
        .mockResolvedValueOnce(invitee as User); // invitee

      jest.spyOn(service, 'findExistingInvitation' as any).mockResolvedValue(null);
      invitationRepository.create.mockReturnValue(mockInvitation as Invitation);
      invitationRepository.save.mockResolvedValue(mockInvitation as Invitation);
      jest.spyOn(service, 'findByIdWithDetails').mockResolvedValue(mockInvitation as any);
      jest.spyOn(service, 'sendInvitationEmail' as any).mockResolvedValue(undefined);

      const result = await service.create(createInvitationDto, 'inviter-123');

      expect(userRepository.findOne).toHaveBeenCalledTimes(2);
      expect(invitationRepository.create).toHaveBeenCalled();
      expect(invitationRepository.save).toHaveBeenCalled();
      expect(result).toEqual(mockInvitation);
    });

    it('should throw BadRequestException when inviting yourself', async () => {
      const createInvitationDto = {
        inviteeId: 'same-user',
        type: InvitationType.FRIEND,
      };

      userRepository.findOne.mockResolvedValue(mockUser as User);

      await expect(
        service.create(createInvitationDto, 'same-user')
      ).rejects.toThrow(BadRequestException);
    });

    it('should throw ConflictException for existing pending invitation', async () => {
      const createInvitationDto = {
        inviteeId: 'invitee-123',
        type: InvitationType.FRIEND,
      };

      const inviter = { ...mockUser, id: 'inviter-123' };
      const invitee = { ...mockUser, id: 'invitee-123' };

      userRepository.findOne
        .mockResolvedValueOnce(inviter as User)
        .mockResolvedValueOnce(invitee as User);

      const existingInvitation = {
        ...mockInvitation,
        status: InvitationStatus.PENDING,
      };

      jest.spyOn(service, 'findExistingInvitation' as any).mockResolvedValue(existingInvitation);

      await expect(
        service.create(createInvitationDto, 'inviter-123')
      ).rejects.toThrow(ConflictException);
    });
  });

  describe('respond', () => {
    it('should accept invitation successfully', async () => {
      const invitation = {
        ...mockInvitation,
        inviteeId: 'invitee-123',
        status: InvitationStatus.PENDING,
        expiresAt: new Date(Date.now() + 86400000), // 1 day in future
      };

      jest.spyOn(service, 'findById').mockResolvedValue(invitation as any);
      invitationRepository.save.mockResolvedValue({
        ...invitation,
        status: InvitationStatus.ACCEPTED,
      } as Invitation);

      jest.spyOn(service, 'processAcceptedInvitation' as any).mockResolvedValue(undefined);
      jest.spyOn(service, 'sendResponseNotificationEmail' as any).mockResolvedValue(undefined);
      jest.spyOn(service, 'findByIdWithDetails').mockResolvedValue(invitation as any);

      const result = await service.respond(
        '123', 
        'invitee-123', 
        { status: InvitationStatus.ACCEPTED }
      );

      expect(invitationRepository.save).toHaveBeenCalled();
      expect(service.processAcceptedInvitation).toHaveBeenCalled();
    });

    it('should throw ForbiddenException if not invitee', async () => {
      const invitation = {
        ...mockInvitation,
        inviteeId: 'different-user',
      };

      jest.spyOn(service, 'findById').mockResolvedValue(invitation as any);

      await expect(
        service.respond('123', 'wrong-user', { status: InvitationStatus.ACCEPTED })
      ).rejects.toThrow(ForbiddenException);
    });

    it('should throw BadRequestException if invitation expired', async () => {
      const invitation = {
        ...mockInvitation,
        inviteeId: 'invitee-123',
        status: InvitationStatus.PENDING,
        expiresAt: new Date(Date.now() - 86400000), // 1 day in past
      };

      jest.spyOn(service, 'findById').mockResolvedValue(invitation as any);

      await expect(
        service.respond('123', 'invitee-123', { status: InvitationStatus.ACCEPTED })
      ).rejects.toThrow(BadRequestException);
    });
  });

  describe('validateInvitationPermissions', () => {
    it('should validate event invitation permissions', async () => {
      const event = {
        ...mockEvent,
        creatorId: 'creator-123',
        participants: [{ id: 'participant-123' }],
      };

      eventRepository.findOne.mockResolvedValue(event as Event);

      // Should not throw for creator
      await expect(
        service.validateInvitationPermissions(
          InvitationType.EVENT,
          'creator-123',
          'event-123'
        )
      ).resolves.not.toThrow();

      // Should not throw for participant
      await expect(
        service.validateInvitationPermissions(
          InvitationType.EVENT,
          'participant-123',
          'event-123'
        )
      ).resolves.not.toThrow();
    });

    it('should throw ForbiddenException for unauthorized event invitation', async () => {
      const event = {
        ...mockEvent,
        creatorId: 'creator-123',
        participants: [],
      };

      eventRepository.findOne.mockResolvedValue(event as Event);

      await expect(
        service.validateInvitationPermissions(
          InvitationType.EVENT,
          'unauthorized-user',
          'event-123'
        )
      ).rejects.toThrow(ForbiddenException);
    });
  });

  describe('getInvitationStats', () => {
    it('should return correct invitation statistics', async () => {
      const mockInvitations = [
        { ...mockInvitation, status: InvitationStatus.PENDING, type: InvitationType.FRIEND },
        { ...mockInvitation, status: InvitationStatus.ACCEPTED, type: InvitationType.EVENT },
        { ...mockInvitation, status: InvitationStatus.DECLINED, type: InvitationType.PLAYLIST },
      ];

      const mockQueryBuilder = {
        where: jest.fn().mockReturnThis(),
        andWhere: jest.fn().mockReturnThis(),
        getMany: jest.fn().mockResolvedValue(mockInvitations),
      };

      invitationRepository.createQueryBuilder.mockReturnValue(mockQueryBuilder as any);

      const stats = await service.getInvitationStats('user-123');

      expect(stats.total).toBe(3);
      expect(stats.pending).toBe(1);
      expect(stats.accepted).toBe(1);
      expect(stats.declined).toBe(1);
      expect(stats.byType.friend).toBe(1);
      expect(stats.byType.event).toBe(1);
      expect(stats.byType.playlist).toBe(1);
    });
  });
});
