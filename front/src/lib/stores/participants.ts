import { writable } from 'svelte/store';
import type { PlaylistParticipant } from '$lib/services/socket';

interface ParticipantsState {
  [playlistId: string]: PlaylistParticipant[];
}

export const participantsStore = writable<ParticipantsState>({});

export const participantsService = {
  // Set participants for a specific playlist
  setParticipants(playlistId: string, participants: PlaylistParticipant[]) {
    participantsStore.update(state => ({
      ...state,
      [playlistId]: participants
    }));
  },

  // Add a participant to a playlist
  addParticipant(playlistId: string, participant: PlaylistParticipant) {
    participantsStore.update(state => {
      const currentParticipants = state[playlistId] || [];
      
      // Check if participant already exists (by userId)
      const existingIndex = currentParticipants.findIndex(p => p.userId === participant.userId);
      
      if (existingIndex >= 0) {
        // Update existing participant
        const updatedParticipants = [...currentParticipants];
        updatedParticipants[existingIndex] = participant;
        return {
          ...state,
          [playlistId]: updatedParticipants
        };
      } else {
        // Add new participant
        return {
          ...state,
          [playlistId]: [...currentParticipants, participant]
        };
      }
    });
  },

  // Remove a participant from a playlist
  removeParticipant(playlistId: string, userId: string) {
    participantsStore.update(state => {
      const currentParticipants = state[playlistId] || [];
      return {
        ...state,
        [playlistId]: currentParticipants.filter(p => p.userId !== userId)
      };
    });
  },

  // Clear participants for a playlist
  clearParticipants(playlistId: string) {
    participantsStore.update(state => {
      const newState = { ...state };
      delete newState[playlistId];
      return newState;
    });
  },

  // Get participants for a specific playlist
  getParticipants(playlistId: string): PlaylistParticipant[] {
    let participants: PlaylistParticipant[] = [];
    const unsubscribe = participantsStore.subscribe(state => {
      participants = state[playlistId] || [];
    });
    unsubscribe(); // Immediately unsubscribe since we just want the current value
    return participants;
  }
};
