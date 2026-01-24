import { Injectable } from '@nestjs/common';
import { InjectRepository } from '@nestjs/typeorm';
import { Repository } from 'typeorm';
import { EventParticipant, ParticipantRole } from 'src/event/entities/event-participant.entity';
import { Event } from 'src/event/entities/event.entity';

@Injectable()
export class EventParticipantService {
  constructor(
    @InjectRepository(EventParticipant)
    private readonly participantRepository: Repository<EventParticipant>,
  ) {}

  async addParticipant(
    eventId: string,
    userId: string,
    role: ParticipantRole = ParticipantRole.PARTICIPANT,
  ): Promise<EventParticipant> {
    const participant = this.participantRepository.create({
      eventId,
      userId,
      role,
    });
    return this.participantRepository.save(participant);
  }

  async removeParticipant(eventId: string, userId: string): Promise<void> {
    await this.participantRepository.delete({ eventId, userId });
  }

  async updateRole(eventId: string, userId: string, role: ParticipantRole): Promise<void> {
    await this.participantRepository.update({ eventId, userId }, { role });
  }

  async getParticipants(eventId: string): Promise<EventParticipant[]> {
    return this.participantRepository.find({
      where: { eventId },
      relations: ['user'],
    });
  }

  async getParticipantRole(eventId: string, userId: string): Promise<ParticipantRole | null> {
    const participant = await this.participantRepository.findOne({
      where: { eventId, userId },
    });
    return participant?.role || null;
  }

  async isParticipant(eventId: string, userId: string): Promise<boolean> {
    const count = await this.participantRepository.count({
      where: { eventId, userId },
    });
    return count > 0;
  }

  async isCreator(eventId: string, userId: string): Promise<boolean> {
    const participant = await this.participantRepository.findOne({
      where: { eventId, userId },
    });
    return participant?.role === ParticipantRole.CREATOR;
  }

  async isCollaborator(eventId: string, userId: string): Promise<boolean> {
    const participant = await this.participantRepository.findOne({
      where: { eventId, userId },
    });
    return participant?.role === ParticipantRole.COLLABORATOR || participant?.role === ParticipantRole.CREATOR;
  }

  async canEdit(event: Event, userId: string): Promise<boolean> {
    if (event.creatorId === userId) {
      return true;
    }

    const participant = await this.participantRepository.findOne({
      where: { eventId: event.id, userId },
    });

    if (!participant) {
      return false;
    }

    return participant.role === ParticipantRole.CREATOR || 
           participant.role === ParticipantRole.COLLABORATOR;
  }

  async getCollaborators(eventId: string): Promise<EventParticipant[]> {
    return this.participantRepository.find({
      where: { eventId },
      relations: ['user'],
    });
  }

  async getCollaboratorsWithRole(eventId: string): Promise<EventParticipant[]> {
    return this.participantRepository.find({
      where: { eventId },
      relations: ['user'],
    });
  }

  async addCollaborator(eventId: string, userId: string): Promise<EventParticipant> {
    // Check if already exists
    const existing = await this.participantRepository.findOne({
      where: { eventId, userId },
    });

    if (existing) {
      // Update role to collaborator if participant
      if (existing.role === ParticipantRole.PARTICIPANT) {
        existing.role = ParticipantRole.COLLABORATOR;
        return this.participantRepository.save(existing);
      }
      return existing;
    }

    return this.addParticipant(eventId, userId, ParticipantRole.COLLABORATOR);
  }

  async removeCollaborator(eventId: string, userId: string): Promise<void> {
    const participant = await this.participantRepository.findOne({
      where: { eventId, userId },
    });

    if (participant && participant.role === ParticipantRole.COLLABORATOR) {
      // Downgrade to participant instead of removing
      participant.role = ParticipantRole.PARTICIPANT;
      await this.participantRepository.save(participant);
    }
  }

  async getCollaboratorCount(eventId: string): Promise<number> {
    return this.participantRepository.count({
      where: [
        { eventId, role: ParticipantRole.CREATOR },
        { eventId, role: ParticipantRole.COLLABORATOR },
      ],
    });
  }

  async isUserCollaborator(eventId: string, userId: string): Promise<boolean> {
    const participant = await this.participantRepository.findOne({
      where: { eventId, userId },
    });

    return participant ? 
      (participant.role === ParticipantRole.CREATOR || participant.role === ParticipantRole.COLLABORATOR) : 
      false;
  }

  async isUserParticipant(eventId: string, userId: string): Promise<boolean> {
    const participant = await this.participantRepository.findOne({
      where: { eventId, userId },
    });

    return !!participant;
  }
}
