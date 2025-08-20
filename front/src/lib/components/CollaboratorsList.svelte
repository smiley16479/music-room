<script lang="ts">
	import { authStore } from '$lib/stores/auth';
	import { getAvatarColor, getAvatarLetter} from '$lib/utils/avatar';
	import { goto } from '$app/navigation';
	import { playlistsService } from '$lib/services/playlists';

	let { 
		playlist, 
		isOwner, 
		onCollaboratorRemoved = () => {}
	} = $props();

	const currentUser = $derived($authStore);

	// Navigate to user profile
	function viewUserProfile(userId: string) {
		if (userId && userId !== currentUser?.id) {
			goto(`/users/${userId}`);
		}
	}

	function viewOwnerProfile() {
		if (currentUser?.id !== playlist?.creator?.id) {
			goto(`/users/${playlist?.creator?.id}`);
		}
	}

	async function removeCollaborator(userId: string) {
		if (!playlist?.id) return;

		try {
			await playlistsService.removeCollaborator(playlist.id, userId);
			onCollaboratorRemoved?.();
		} catch (err) {
			console.error('Failed to remove collaborator:', err);
		}
	}
</script>

<div class="bg-white rounded-lg shadow-md">
	<div class="p-4 bg-[#f8fafc] border-b border-[#e2e8f0]">
		<h2 class="text-lg font-bold text-gray-800">
			Collaborators ({(playlist.collaborators?.length || 0) + 1})
		</h2>
	</div>

	<div class="max-h-80 overflow-y-auto">
		<!-- Owner -->
		{#if playlist?.creator}
			{#if playlist.creator.id !== currentUser?.id}
				<button 
					class="collaborator-item clickable"
					class:is-current-user={playlist.creator.id === currentUser?.id}
					onclick={() => viewOwnerProfile()}
					onkeydown={(e) => {
						if (e.key === 'Enter' || e.key === ' ') {
							e.preventDefault();
							viewOwnerProfile();
						}
					}}
				>
					<div class="collaborator-avatar">
						{#if playlist.creator.avatarUrl && !playlist.creator.avatarUrl.startsWith('data:image/svg+xml')}
							<img src={playlist.creator.avatarUrl} alt={playlist.creator.displayName} />
						{:else}
							<div 
								class="avatar-fallback"
								style="background-color: {getAvatarColor(playlist.creator.displayName || 'Unknown')}"
							>
								{getAvatarLetter(playlist.creator.displayName || 'Unknown')}
							</div>
						{/if}
					</div>
					
					<div class="collaborator-info">
						<div class="collaborator-name">
							{playlist.creator.displayName || 'Unknown'}
						</div>
						<div class="collaborator-role">
							Owner
						</div>
					</div>
					
					<div class="collaborator-status">
						<svg class="view-profile-icon" width="16" height="16" fill="none" stroke="currentColor" viewBox="0 0 24 24">
							<path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M9 5l7 7-7 7" />
						</svg>
					</div>
				</button>
			{:else}
				<div 
					class="collaborator-item" 
					class:is-current-user={playlist.creator.id === currentUser?.id}
				>
					<div class="collaborator-avatar">
						{#if playlist.creator.avatarUrl && !playlist.creator.avatarUrl.startsWith('data:image/svg+xml')}
							<img src={playlist.creator.avatarUrl} alt={playlist.creator.displayName} />
						{:else}
							<div 
								class="avatar-fallback"
								style="background-color: {getAvatarColor(playlist.creator.displayName || 'Unknown')}"
							>
								{getAvatarLetter(playlist.creator.displayName || 'Unknown')}
							</div>
						{/if}
					</div>
					
					<div class="collaborator-info">
						<div class="collaborator-name">
							{playlist.creator.displayName || 'Unknown'}
							<span class="you-badge">You</span>
						</div>
						<div class="collaborator-role">
							Owner
						</div>
					</div>
				</div>
			{/if}
		{/if}

		<!-- Collaborators -->
		{#each playlist.collaborators || [] as collaborator (collaborator.id)}
			{#if collaborator.id !== currentUser?.id}
				<div class="collaborator-item-wrapper">
					<button 
						class="collaborator-item clickable" 
						class:is-current-user={collaborator.id === currentUser?.id}
						onclick={() => viewUserProfile(collaborator.id)}
						onkeydown={(e) => {
							if (e.key === 'Enter' || e.key === ' ') {
								e.preventDefault();
								viewUserProfile(collaborator.id);
							}
						}}
					>
						<div class="collaborator-avatar">
							{#if collaborator.avatarUrl && !collaborator.avatarUrl.startsWith('data:image/svg+xml')}
								<img src={collaborator.avatarUrl} alt={collaborator.displayName} />
							{:else}
								<div 
									class="avatar-fallback"
									style="background-color: {getAvatarColor(collaborator.displayName || 'Unknown')}"
								>
									{getAvatarLetter(collaborator.displayName || 'Unknown')}
								</div>
							{/if}
						</div>
						
						<div class="collaborator-info">
							<div class="collaborator-name">
								{collaborator.displayName || 'Unknown'}
							</div>
							<div class="collaborator-role">
								Collaborator
							</div>
						</div>
						
						<div class="collaborator-status">
							<svg class="view-profile-icon" width="16" height="16" fill="none" stroke="currentColor" viewBox="0 0 24 24">
								<path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M9 5l7 7-7 7" />
							</svg>
						</div>
					</button>
					
					{#if isOwner}
						<button 
							onclick={() => removeCollaborator(collaborator.id)}
							aria-label="Remove collaborator"
							class="remove-btn-standalone"
							title="Remove collaborator"
						>
							<svg width="16" height="16" fill="none" stroke="currentColor" viewBox="0 0 24 24">
								<path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M6 18L18 6M6 6l12 12"></path>
							</svg>
						</button>
					{/if}
				</div>
			{:else}
				<div 
					class="collaborator-item" 
					class:is-current-user={collaborator.id === currentUser?.id}
				>
					<div class="collaborator-avatar">
						{#if collaborator.avatarUrl && !collaborator.avatarUrl.startsWith('data:image/svg+xml')}
							<img src={collaborator.avatarUrl} alt={collaborator.displayName} />
						{:else}
							<div 
								class="avatar-fallback"
								style="background-color: {getAvatarColor(collaborator.displayName || 'Unknown')}"
							>
								{getAvatarLetter(collaborator.displayName || 'Unknown')}
							</div>
						{/if}
					</div>
					
					<div class="collaborator-info">
						<div class="collaborator-name">
							{collaborator.displayName || 'Unknown'}
							<span class="you-badge">You</span>
						</div>
						<div class="collaborator-role">
							Collaborator
						</div>
					</div>
				</div>
			{/if}
		{/each}
		
		{#if !playlist.collaborators || playlist.collaborators.length === 0}
			<div class="empty-state">
				<p>No collaborators yet</p>
			</div>
		{/if}
	</div>
</div>

<style>
	.collaborator-item-wrapper {
		position: relative;
		display: flex;
		align-items: center;
	}

	.collaborator-item-wrapper .collaborator-item {
		flex: 1;
	}

	.remove-btn-standalone {
		position: absolute;
		right: 12px;
		top: 50%;
		transform: translateY(-50%);
		color: #ef4444;
		background: none;
		border: none;
		padding: 4px;
		border-radius: 4px;
		cursor: pointer;
		transition: background-color 0.2s ease;
		z-index: 10;
	}

	.remove-btn-standalone:hover {
		background: #fef2f2;
	}

	.collaborator-item {
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

	.collaborator-item:hover {
		background: #f1f5f9;
	}

	.collaborator-item.clickable {
		cursor: pointer;
	}

	.collaborator-item.clickable:hover {
		background: #e2e8f0;
	}

	.collaborator-item.is-current-user {
		background: #eff6ff;
		border: 1px solid #dbeafe;
	}

	.collaborator-item.is-current-user:hover {
		background: #eff6ff;
	}

	.collaborator-avatar {
		width: 36px;
		height: 36px;
		border-radius: 50%;
		overflow: hidden;
		margin-right: 12px;
		flex-shrink: 0;
	}

	.collaborator-avatar img {
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

	.collaborator-info {
		flex: 1;
		min-width: 0;
	}

	.collaborator-name {
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

	.collaborator-role {
		font-size: 12px;
		color: #64748b;
		margin-top: 2px;
	}

	.collaborator-status {
		flex-shrink: 0;
		display: flex;
		align-items: center;
		gap: 8px;
	}

	.view-profile-icon {
		color: #94a3b8;
		transition: color 0.2s ease;
	}

	.collaborator-item.clickable:hover .view-profile-icon {
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
