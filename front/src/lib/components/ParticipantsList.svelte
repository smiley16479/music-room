<script lang="ts">
	import type { PlaylistParticipant } from '$lib/services/socket';
	import { participantsStore } from '$lib/stores/participants';
	import { authStore } from '$lib/stores/auth';
	import { getAvatarColor, getAvatarLetter } from '$lib/utils/avatar';
	import { goto } from '$app/navigation';

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

	// Navigate to user profile
	function viewUserProfile(participant: PlaylistParticipant) {
		if (participant.userId && participant.userId !== currentUser?.id) {
			goto(`/users/${participant.userId}`);
		}
	}
</script>

<div class="bg-white rounded-lg shadow-md">
	<div class="p-4 bg-[#f8fafc] border-b border-[#e2e8f0]">
		<h2 class="text-lg font-bold text-gray-800">Active Participants ({participants.length})</h2>
	</div>

	<div class="max-h-60 overflow-y-auto">
		{#each participants as participant (participant.socketId)}
			{#if participant.userId !== currentUser?.id}
			<button 
				class="participant-item clickable" 
				class:is-current-user={participant.userId === currentUser?.id}
				onclick={() => viewUserProfile(participant)}
				onkeydown={(e) => {
					if (e.key === 'Enter' || e.key === ' ') {
						e.preventDefault();
						viewUserProfile(participant);
					}
				}}
			>
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
					<svg class="view-profile-icon" width="16" height="16" fill="none" stroke="currentColor" viewBox="0 0 24 24">
						<path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M9 5l7 7-7 7" />
					</svg>
				</div>
			</button>
			{:else}
			<div 
				class="participant-item" 
				class:is-current-user={participant.userId === currentUser?.id}
			>
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
			{/if}
		{/each}
		
		{#if participants.length === 0}
			<div class="empty-state">
				<p>No active participants</p>
			</div>
		{/if}
	</div>
</div>

<style>
	.participant-item {
		display: flex;
		align-items: center;
		padding: 12px;
		transition: background-color 0.2s ease;
		width: 100%;
		border: none;
		background: transparent;
		text-align: left;
		font-family: inherit;
	}

	.participant-item:hover {
		background: #f1f5f9;
	}

	.participant-item.clickable {
		cursor: pointer;
	}

	.participant-item.clickable:hover {
		background: #e2e8f0;
	}

	.participant-item.is-current-user {
		background: #eff6ff;
		border: 1px solid #dbeafe;
	}

	.participant-item.is-current-user:hover {
		background: #eff6ff;
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
		display: flex;
		align-items: center;
		gap: 8px;
	}

	.online-indicator {
		width: 8px;
		height: 8px;
		background: #10b981;
		border-radius: 50%;
		border: 2px solid white;
		box-shadow: 0 0 0 1px #10b981;
	}

	.view-profile-icon {
		color: #94a3b8;
		transition: color 0.2s ease;
	}

	.participant-item.clickable:hover .view-profile-icon {
		color: #64748b;
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
