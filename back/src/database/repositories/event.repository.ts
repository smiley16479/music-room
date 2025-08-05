import { Injectable } from '@nestjs/common';
import { InjectRepository } from '@nestjs/typeorm';
import { Repository, FindOptionsWhere } from 'typeorm';
import { Event, EventStatus, EventVisibility } from 'src/event/entities/event.entity';

@Injectable()
export class EventRepository {
  constructor(
    @InjectRepository(Event)
    private readonly eventRepository: Repository<Event>,
  ) {}

  async findById(id: string, relations: string[] = []): Promise<Event | null> {
    return this.eventRepository.findOne({
      where: { id },
      relations,
    });
  }

  async findPublicEvents(limit = 20): Promise<Event[]> {
    return this.eventRepository.find({
      where: {
        visibility: EventVisibility.PUBLIC,
        status: EventStatus.LIVE,
      },
      relations: ['creator', 'participants'],
      order: { createdAt: 'DESC' },
      take: limit,
    });
  }

  async findUserEvents(userId: string): Promise<Event[]> {
    return this.eventRepository.find({
      where: [
        { creatorId: userId },
        { participants: { id: userId } },
      ],
      relations: ['creator', 'participants'],
      order: { createdAt: 'DESC' },
    });
  }

  async findNearbyEvents(
    latitude: number,
    longitude: number,
    radiusKm = 10,
  ): Promise<Event[]> {
    return this.eventRepository
      .createQueryBuilder('event')
      .where('event.visibility = :visibility', { visibility: EventVisibility.PUBLIC })
      .andWhere('event.status = :status', { status: EventStatus.LIVE })
      .andWhere('event.latitude IS NOT NULL AND event.longitude IS NOT NULL')
      .andWhere(
        `(6371 * acos(cos(radians(:lat)) * cos(radians(event.latitude)) * cos(radians(event.longitude) - radians(:lng)) + sin(radians(:lat)) * sin(radians(event.latitude)))) <= :radius`,
        { lat: latitude, lng: longitude, radius: radiusKm },
      )
      .leftJoinAndSelect('event.creator', 'creator')
      .leftJoinAndSelect('event.participants', 'participants')
      .orderBy('event.createdAt', 'DESC')
      .getMany();
  }

  async create(eventData: Partial<Event>): Promise<Event> {
    const event = this.eventRepository.create(eventData);
    return this.eventRepository.save(event);
  }

  async update(id: string, updateData: Partial<Event>): Promise<Event | null> {
    await this.eventRepository.update(id, updateData);
    return this.findById(id);
  }

  async delete(id: string): Promise<void> {
    await this.eventRepository.delete(id);
  }

  async addParticipant(eventId: string, userId: string): Promise<void> {
    await this.eventRepository
      .createQueryBuilder()
      .relation(Event, 'participants')
      .of(eventId)
      .add(userId);
  }

  async removeParticipant(eventId: string, userId: string): Promise<void> {
    await this.eventRepository
      .createQueryBuilder()
      .relation(Event, 'participants')
      .of(eventId)
      .remove(userId);
  }

  async getEventStats(eventId: string): Promise<{
    participantCount: number;
    voteCount: number;
    trackCount: number;
  }> {
    const event = await this.findById(eventId, ['participants', 'votes', 'playlist']);
    
    return {
      participantCount: event?.participants?.length || 0,
      voteCount: event?.votes?.length || 0,
      trackCount: event?.playlist?.length || 0,
    };
  }
}