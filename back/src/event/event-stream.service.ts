import { Injectable, Logger, Inject, forwardRef } from '@nestjs/common';
import { InjectRepository } from '@nestjs/typeorm';
import { Repository } from 'typeorm';

import { Event } from './entities/event.entity';
import { PlaylistTrack } from './entities/playlist-track.entity';
import { Track } from 'src/music/entities/track.entity';
import { Vote, VoteType } from './entities/vote.entity';
import { EventGateway } from './event.gateway';

/**
 * Server-side stream state for an event.
 * This runs autonomously — even if no users are connected.
 */
interface StreamState {
  eventId: string;
  /** Current track being played (null = stopped) */
  currentTrackId: string | null;
  /** Current track entity (for duration info) */
  currentTrack: Track | null;
  /** Server-side position in seconds (updated each tick) */
  position: number;
  /** Whether the server-side stream is playing */
  isPlaying: boolean;
  /** Timestamp (Date.now()) of last tick update */
  lastTickAt: number;
  /** Interval handle for the tick timer */
  tickInterval: NodeJS.Timeout | null;
  /** Grace period timer when loading a new track */
  loadingTimeout: NodeJS.Timeout | null;
  /** Whether we're in the "loading" grace period after track change */
  isLoadingTrack: boolean;
  /** Duration of the current track in seconds */
  trackDuration: number;
}

/** Seconds of grace period to let clients load a new track */
const TRACK_LOADING_GRACE_SECONDS = 3;

/** Tick interval in ms */
const TICK_INTERVAL_MS = 250;

/** Broadcast sync interval in ticks (every 1s = 4 ticks at 250ms) */
const SYNC_BROADCAST_TICKS = 4;

@Injectable()
export class EventStreamService {
  private readonly logger = new Logger(EventStreamService.name);

  /** Active stream states keyed by eventId */
  private streams = new Map<string, StreamState>();

  constructor(
    @InjectRepository(Event)
    private readonly eventRepository: Repository<Event>,
    @InjectRepository(PlaylistTrack)
    private readonly playlistTrackRepository: Repository<PlaylistTrack>,
    @InjectRepository(Track)
    private readonly trackRepository: Repository<Track>,
    @InjectRepository(Vote)
    private readonly voteRepository: Repository<Vote>,
    @Inject(forwardRef(() => EventGateway))
    private readonly eventGateway: EventGateway,
  ) {}

  // ============================
  // Public API
  // ============================

  /** Start the server-side stream for an event (called by admin) */
  async startStream(eventId: string, trackId?: string): Promise<void> {
    this.logger.log(`▶️ startStream: eventId=${eventId}, trackId=${trackId}`);

    // If stream already exists, just resume
    if (this.streams.has(eventId)) {
      const stream = this.streams.get(eventId)!;
      if (trackId && trackId !== stream.currentTrackId) {
        await this.changeTrack(eventId, trackId);
      } else {
        this.resumeStream(eventId);
      }
      return;
    }

    // Create new stream
    const state: StreamState = {
      eventId,
      currentTrackId: null,
      currentTrack: null,
      position: 0,
      isPlaying: false,
      lastTickAt: Date.now(),
      tickInterval: null,
      loadingTimeout: null,
      isLoadingTrack: false,
      trackDuration: 0,
    };
    this.streams.set(eventId, state);

    // Load the first track
    const firstTrackId = trackId || await this.getNextTrackId(eventId);
    if (firstTrackId) {
      await this.loadTrackIntoStream(eventId, firstTrackId, true);
    } else {
      this.logger.warn(`No tracks available for event ${eventId}`);
    }
  }

  /** Resume a paused stream */
  resumeStream(eventId: string, fromPosition?: number): void {
    const stream = this.streams.get(eventId);
    if (!stream) return;

    if (fromPosition !== undefined) {
      stream.position = fromPosition;
    }

    if (stream.isPlaying) return; // already playing

    stream.isPlaying = true;
    stream.lastTickAt = Date.now();
    this.startTick(eventId);
    this.persistPlaybackState(eventId);

    this.logger.log(`▶️ Resumed stream for ${eventId} at ${stream.position.toFixed(1)}s`);

    // Broadcast play event
    this.eventGateway.broadcastStreamPlay(eventId, {
      trackId: stream.currentTrackId,
      position: stream.position,
      isPlaying: true,
    });
  }

  /** Pause the stream (admin action) */
  pauseStream(eventId: string): void {
    const stream = this.streams.get(eventId);
    if (!stream || !stream.isPlaying) return;

    // Update position one last time
    this.updatePosition(stream);
    stream.isPlaying = false;
    this.stopTick(eventId);
    this.persistPlaybackState(eventId);

    this.logger.log(`⏸️ Paused stream for ${eventId} at ${stream.position.toFixed(1)}s`);

    this.eventGateway.broadcastStreamPause(eventId, {
      trackId: stream.currentTrackId,
      position: stream.position,
      isPlaying: false,
    });
  }

  /** Seek to a position (admin action) */
  seekStream(eventId: string, seekTime: number): void {
    const stream = this.streams.get(eventId);
    if (!stream) return;

    stream.position = Math.max(0, Math.min(seekTime, stream.trackDuration));
    stream.lastTickAt = Date.now();
    this.persistPlaybackState(eventId);

    this.logger.log(`⏩ Seeked stream for ${eventId} to ${stream.position.toFixed(1)}s`);

    this.eventGateway.broadcastStreamSeek(eventId, {
      trackId: stream.currentTrackId,
      position: stream.position,
      isPlaying: stream.isPlaying,
    });
  }

  /** Skip to next track (admin action) */
  async skipTrack(eventId: string): Promise<void> {
    this.logger.log(`⏭️ Skip track for ${eventId}`);
    await this.advanceToNextTrack(eventId);
  }

  /** Change to a specific track (admin action) */
  async changeTrack(eventId: string, trackId: string): Promise<void> {
    this.logger.log(`🔄 Change track for ${eventId} to ${trackId}`);
    await this.loadTrackIntoStream(eventId, trackId, true);
  }

  /** Stop the stream entirely (admin action) */
  stopStream(eventId: string): void {
    const stream = this.streams.get(eventId);
    if (!stream) return;

    this.stopTick(eventId);
    if (stream.loadingTimeout) {
      clearTimeout(stream.loadingTimeout);
    }
    this.streams.delete(eventId);

    // Persist cleared state
    this.eventRepository.update(eventId, {
      currentTrackId: null as any,
      currentTrackStartedAt: null as any,
      currentPosition: 0,
      isPlaying: false,
      lastPositionUpdate: new Date(),
    }).catch(err => this.logger.error(`Failed to clear DB state: ${err.message}`));

    this.logger.log(`⏹️ Stopped stream for ${eventId}`);

    this.eventGateway.broadcastStreamStop(eventId);
  }

  /** Get current stream state (for sync requests from clients) */
  getStreamState(eventId: string): { trackId: string | null; position: number; isPlaying: boolean; trackDuration: number } {
    const stream = this.streams.get(eventId);
    if (!stream) {
      return { trackId: null, position: 0, isPlaying: false, trackDuration: 0 };
    }

    // Calculate live position
    let position = stream.position;
    if (stream.isPlaying && !stream.isLoadingTrack) {
      const elapsed = (Date.now() - stream.lastTickAt) / 1000;
      position += elapsed;
    }

    return {
      trackId: stream.currentTrackId,
      position: Math.min(position, stream.trackDuration),
      isPlaying: stream.isPlaying,
      trackDuration: stream.trackDuration,
    };
  }

  /** Check if a stream is active for the given event */
  hasActiveStream(eventId: string): boolean {
    return this.streams.has(eventId);
  }

  // ============================
  // Internal: Tick Engine
  // ============================

  private tickCounters = new Map<string, number>();

  private startTick(eventId: string): void {
    const stream = this.streams.get(eventId);
    if (!stream || stream.tickInterval) return;

    this.tickCounters.set(eventId, 0);

    stream.tickInterval = setInterval(() => {
      this.onTick(eventId);
    }, TICK_INTERVAL_MS);
  }

  private stopTick(eventId: string): void {
    const stream = this.streams.get(eventId);
    if (!stream || !stream.tickInterval) return;

    clearInterval(stream.tickInterval);
    stream.tickInterval = null;
    this.tickCounters.delete(eventId);
  }

  private async onTick(eventId: string): Promise<void> {
    const stream = this.streams.get(eventId);
    if (!stream || !stream.isPlaying || stream.isLoadingTrack) return;

    // Update position
    this.updatePosition(stream);

    // Check if track ended
    if (stream.position >= stream.trackDuration && stream.trackDuration > 0) {
      this.logger.log(`🏁 Track ended for event ${eventId}: ${stream.currentTrackId}`);
      await this.advanceToNextTrack(eventId);
      return;
    }

    // Periodic sync broadcast
    const counter = (this.tickCounters.get(eventId) || 0) + 1;
    this.tickCounters.set(eventId, counter);

    if (counter % SYNC_BROADCAST_TICKS === 0) {
      this.eventGateway.broadcastTimeSync(eventId, {
        trackId: stream.currentTrackId,
        position: stream.position,
        isPlaying: stream.isPlaying,
        trackDuration: stream.trackDuration,
      });
    }
  }

  private updatePosition(stream: StreamState): void {
    const now = Date.now();
    const elapsed = (now - stream.lastTickAt) / 1000;
    stream.position += elapsed;
    stream.lastTickAt = now;
  }

  // ============================
  // Internal: Track Management
  // ============================

  /** Load a track into the stream and optionally start playing */
  private async loadTrackIntoStream(eventId: string, trackId: string, autoPlay: boolean): Promise<void> {
    const stream = this.streams.get(eventId);
    if (!stream) return;

    // Pause tick during loading
    const wasPlaying = stream.isPlaying;
    stream.isPlaying = false;
    this.stopTick(eventId);

    // Enter loading state
    stream.isLoadingTrack = true;
    stream.currentTrackId = trackId;
    stream.position = 0;
    stream.lastTickAt = Date.now();

    // Get track info for duration
    const track = await this.trackRepository.findOne({ where: { id: trackId } });
    if (!track) {
      this.logger.error(`Track ${trackId} not found`);
      stream.isLoadingTrack = false;
      return;
    }

    stream.currentTrack = track;
    stream.trackDuration = track.duration || 30; // fallback 30s for previews

    // Persist to DB
    await this.eventRepository.update(eventId, {
      currentTrackId: trackId,
      currentTrackStartedAt: new Date(),
      currentPosition: 0,
      isPlaying: false,
      lastPositionUpdate: new Date(),
    }).catch(err => this.logger.error(`DB update failed: ${err.message}`));

    // Broadcast track change to all clients
    this.eventGateway.broadcastStreamTrackChanged(eventId, {
      trackId,
      position: 0,
      isPlaying: false, // not yet playing, loading grace period
      trackDuration: stream.trackDuration,
    });

    // Grace period for clients to load the track
    if (stream.loadingTimeout) {
      clearTimeout(stream.loadingTimeout);
    }

    stream.loadingTimeout = setTimeout(() => {
      const s = this.streams.get(eventId);
      if (!s) return;

      s.isLoadingTrack = false;
      s.loadingTimeout = null;

      if (autoPlay || wasPlaying) {
        s.isPlaying = true;
        s.lastTickAt = Date.now();
        this.startTick(eventId);
        this.persistPlaybackState(eventId);

        // Broadcast play start
        this.eventGateway.broadcastStreamPlay(eventId, {
          trackId: s.currentTrackId,
          position: 0,
          isPlaying: true,
        });

        this.logger.log(`▶️ Track ${trackId} started playing after loading grace for event ${eventId}`);
      }
    }, TRACK_LOADING_GRACE_SECONDS * 1000);
  }

  /** Advance to the next track in the playlist (removes current track, picks next by votes) */
  private async advanceToNextTrack(eventId: string): Promise<void> {
    const stream = this.streams.get(eventId);
    if (!stream) return;

    // Stop current playback
    stream.isPlaying = false;
    this.stopTick(eventId);

    const currentTrackId = stream.currentTrackId;

    // Notify track ended
    if (currentTrackId) {
      this.eventGateway.broadcastStreamTrackEnded(eventId, currentTrackId);

      // Remove the ended track from the playlist
      try {
        const playlistTrack = await this.playlistTrackRepository.findOne({
          where: { eventId, trackId: currentTrackId },
        });
        if (playlistTrack) {
          // Remove votes for this track
          await this.voteRepository.delete({ eventId, trackId: currentTrackId });

          const removedPosition = playlistTrack.position;
          await this.playlistTrackRepository.remove(playlistTrack);

          // Fix positions
          const remaining = await this.playlistTrackRepository.find({
            where: { eventId },
            order: { position: 'ASC' },
          });
          for (const t of remaining) {
            if (t.position > removedPosition) {
              t.position -= 1;
            }
          }
          if (remaining.length > 0) {
            await this.playlistTrackRepository.save(remaining);
          }

          // Update event counters
          await this.eventRepository.decrement({ id: eventId }, 'trackCount', 1);
          const trackEntity = await this.trackRepository.findOne({ where: { id: currentTrackId } });
          if (trackEntity?.duration) {
            await this.eventRepository.decrement({ id: eventId }, 'totalDuration', trackEntity.duration);
          }

          // Notify track removed
          this.eventGateway.notifyTrackRemoved(eventId, currentTrackId, 'server');
        }
      } catch (err) {
        this.logger.error(`Failed to remove ended track: ${err.message}`);
      }
    }

    // Reorder remaining tracks by votes
    await this.reorderByVotes(eventId);

    // Get next track
    const nextTrackId = await this.getNextTrackId(eventId);
    if (nextTrackId) {
      await this.loadTrackIntoStream(eventId, nextTrackId, true);
    } else {
      // No more tracks
      this.logger.log(`🏁 No more tracks for event ${eventId}, stream ending`);
      stream.currentTrackId = null;
      stream.currentTrack = null;
      stream.position = 0;
      stream.trackDuration = 0;

      await this.eventRepository.update(eventId, {
        currentTrackId: null as any,
        currentTrackStartedAt: null as any,
        currentPosition: 0,
        isPlaying: false,
        lastPositionUpdate: new Date(),
      }).catch(err => this.logger.error(`DB update failed: ${err.message}`));

      this.eventGateway.broadcastStreamStop(eventId);
      this.streams.delete(eventId);
    }
  }

  /** Get the next track to play (first by position, which is ordered by votes) */
  private async getNextTrackId(eventId: string): Promise<string | null> {
    const next = await this.playlistTrackRepository.findOne({
      where: { eventId },
      order: { position: 'ASC' },
      relations: ['track'],
    });
    return next?.trackId || null;
  }

  /** Reorder playlist tracks by vote scores */
  private async reorderByVotes(eventId: string): Promise<void> {
    try {
      const tracks = await this.playlistTrackRepository.find({
        where: { eventId },
        order: { position: 'ASC' },
      });

      if (tracks.length <= 1) return;

      const votes = await this.voteRepository.find({ where: { eventId } });
      const scores = new Map<string, number>();
      for (const v of votes) {
        const current = scores.get(v.trackId) || 0;
        scores.set(v.trackId, current + (v.type === VoteType.UPVOTE ? v.weight : -v.weight));
      }

      tracks.sort((a, b) => {
        const sa = scores.get(a.trackId) || 0;
        const sb = scores.get(b.trackId) || 0;
        if (sa !== sb) return sb - sa;
        return a.position - b.position;
      });

      let changed = false;
      for (let i = 0; i < tracks.length; i++) {
        if (tracks[i].position !== i + 1) {
          tracks[i].position = i + 1;
          changed = true;
        }
      }

      if (changed) {
        await this.playlistTrackRepository.save(tracks);
        const newOrder = tracks.map(t => t.id);
        this.eventGateway.notifyQueueReordered(eventId, newOrder, scores);
      }
    } catch (err) {
      this.logger.error(`Reorder by votes failed: ${err.message}`);
    }
  }

  /** Persist current playback state to DB */
  private async persistPlaybackState(eventId: string): Promise<void> {
    const stream = this.streams.get(eventId);
    if (!stream) return;

    try {
      await this.eventRepository.update(eventId, {
        isPlaying: stream.isPlaying,
        currentPosition: stream.position,
        lastPositionUpdate: new Date(),
      });
    } catch (err) {
      this.logger.error(`Failed to persist playback state: ${err.message}`);
    }
  }

  /** Clean up all streams (called on module destroy) */
  onModuleDestroy(): void {
    for (const [eventId, stream] of this.streams) {
      if (stream.tickInterval) clearInterval(stream.tickInterval);
      if (stream.loadingTimeout) clearTimeout(stream.loadingTimeout);
    }
    this.streams.clear();
  }
}
