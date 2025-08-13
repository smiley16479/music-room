<script lang="ts">
	import type { PlaylistParticipant } from '$lib/services/socket';
	import { participantsStore } from '$lib/stores/participants';
	import { authStore } from '$lib/stores/auth';
	import { getAvatarColor, getAvatarLetter } from '$lib/utils/avatar';

	let { playlistId }: { playlistId: string } = $props();

	// Get participants for this playlist
	const participants = $derived($participantsStore[playlistId] || []);
	const currentUser = $derived($authStore);

	// Format join time
	function formatJoinTime(joinedAt: string): string {
		const now = new Date();
		const joinTime = new Date(joinedAt);
		const diffInMinutes = Math.floor((now.getTime() - joinTime.getTime()) / (1000 * 60));

		if (diffInMinutes < 1) {
			return 'Just joined';
		} else if (diffInMinutes < 60) {
			return `${diffInMinutes}m ago`;
		} else {
			const diffInHours = Math.floor(diffInMinutes / 60);
			return `${diffInHours}h ago`;
		}
	}

	// Get initials for avatar fallback (keeping for backwards compatibility)
	function getInitials(displayName: string): string {
		return displayName
			.split(' ')
			.map(word => word.charAt(0))
			.join('')
			.toUpperCase()
			.slice(0, 2);
	}
</script>

<div class="participants-panel">
	<div class="participants-header">
		<h3>Active Participants ({participants.length})</h3>
	</div>
	
	<div class="participants-list">
		{#each participants as participant (participant.socketId)}
			<div class="participant-item" class:is-current-user={participant.userId === currentUser?.id}>
				<div class="participant-avatar">
					{#if participant.avatarUrl && !participant.avatarUrl.startsWith('data:image/svg+xml')}
						<img src={participant.avatarUrl} alt={participant.displayName} />
					{:else}
						<div 
							class="avatar-fallback"
							style="background-color: {getAvatarColor(participant.displayName)}"
						>
							{getAvatarLetter(participant.displayName)}
						</div>
					{/if}
				</div>
				
				<div class="participant-info">
					<div class="participant-name">
						{participant.displayName}
						{#if participant.userId === currentUser?.id}
							<span class="you-badge">You</span>
						{/if}
					</div>
					<div class="participant-time">
						{formatJoinTime(participant.joinedAt)}
					</div>
				</div>
				
				<div class="participant-status">
					<div class="online-indicator"></div>
				</div>
			</div>
		{/each}
		
		{#if participants.length === 0}
			<div class="empty-state">
				<p>No active participants</p>
			</div>
		{/if}
	</div>
</div>

<style>
	.participants-panel {
		background: white;
		border-radius: 8px;
		border: 1px solid #e2e8f0;
		overflow: hidden;
	}

	.participants-header {
		padding: 16px;
		background: #f8fafc;
		border-bottom: 1px solid #e2e8f0;
	}

	.participants-header h3 {
		margin: 0;
		font-size: 16px;
		font-weight: 600;
		color: #334155;
	}

	.participants-list {
		padding: 8px;
		max-height: 300px;
		overflow-y: auto;
	}

	.participant-item {
		display: flex;
		align-items: center;
		padding: 12px;
		border-radius: 6px;
		transition: background-color 0.2s ease;
	}

	.participant-item:hover {
		background: #f1f5f9;
	}

	.participant-item.is-current-user {
		background: #eff6ff;
		border: 1px solid #dbeafe;
	}

	.participant-avatar {
		width: 36px;
		height: 36px;
		border-radius: 50%;
		overflow: hidden;
		margin-right: 12px;
		flex-shrink: 0;
	}

	.participant-avatar img {
		width: 100%;
		height: 100%;
		object-fit: cover;
	}

	.avatar-fallback {
		width: 100%;
		height: 100%;
		color: white;
		display: flex;
		align-items: center;
		justify-content: center;
		font-size: 14px;
		font-weight: 600;
	}

	.participant-info {
		flex: 1;
		min-width: 0;
	}

	.participant-name {
		font-size: 14px;
		font-weight: 500;
		color: #334155;
		display: flex;
		align-items: center;
		gap: 8px;
	}

	.you-badge {
		background: #10b981;
		color: white;
		font-size: 11px;
		font-weight: 600;
		padding: 2px 6px;
		border-radius: 4px;
		text-transform: uppercase;
	}

	.participant-time {
		font-size: 12px;
		color: #64748b;
		margin-top: 2px;
	}

	.participant-status {
		flex-shrink: 0;
	}

	.online-indicator {
		width: 8px;
		height: 8px;
		background: #10b981;
		border-radius: 50%;
		border: 2px solid white;
		box-shadow: 0 0 0 1px #10b981;
	}

	.empty-state {
		text-align: center;
		padding: 24px;
		color: #64748b;
	}

	.empty-state p {
		margin: 0;
		font-size: 14px;
	}
</style>
