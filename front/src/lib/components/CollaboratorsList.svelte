<script lang="ts">
	import { authStore } from "$lib/stores/auth";
	import { getAvatarColor, getAvatarLetter } from "$lib/utils/avatar";
	import { goto } from "$app/navigation";
	import { playlistsService, type Playlist, type Collaborator } from "$lib/services/playlists";
	import type { User } from "$lib/services/auth";

	let { playlist, isOwner, onCollaboratorRemoved = () => {} }: {
		playlist: Playlist;
		isOwner: boolean;
		onCollaboratorRemoved?: () => void;
	} = $props();

	const currentUser = $derived($authStore);

	const collaboratorsWithOwner = $derived.by(() => {
		if (!playlist || !playlist.collaborators) return [];
		return playlist.collaborators;
	});

	const collaboratorCount = $derived.by(() => {
		return collaboratorsWithOwner.length;
	});

	async function removeCollaborator(userId: string) {
		if (!playlist?.id) return;

		try {
			console.log("Removing collaborator with userId:", userId);
			await playlistsService.removeCollaborator(playlist.id, userId);
			onCollaboratorRemoved?.();
		} catch (err) {
			console.error("Failed to remove collaborator:", err);
		}
	}
</script>

<div class="bg-white rounded-lg shadow-md p-6">
	<div class="flex items-center justify-between mb-4">
		<h2 class="text-xl font-bold text-gray-800">Collaborators</h2>
		<span
			class="bg-secondary/10 text-secondary px-2 py-1 rounded-full text-sm font-medium ml-2"
		>
			{collaboratorCount}
		</span>
	</div>

	<div>
		{#each collaboratorsWithOwner as collaborator (collaborator.id)}
			<div class="flex items-center justify-between relative">
				<button
					onclick={() => goto(`/users/${collaborator.id}`)}
					class="flex items-center space-x-3 p-2 rounded-lg hover:bg-gray-50 transition-colors w-full text-left {collaborator.id ===
					currentUser?.id
						? 'bg-gray-100'
						: ''}"
				>
					{#if collaborator.avatarUrl && !collaborator.avatarUrl.startsWith("data:image/svg+xml")}
						<img
							src={collaborator.avatarUrl}
							alt={collaborator.displayName}
							class="w-10 h-10 rounded-full object-cover"
						/>
					{:else}
						<div
							class="w-10 h-10 rounded-full flex items-center justify-center text-white font-semibold text-sm"
							style="background-color: {getAvatarColor(
								collaborator.displayName || 'Unknown',
							)}"
						>
							{getAvatarLetter(
								collaborator.displayName || "Unknown",
							)}
						</div>
					{/if}
					<div class="flex-1 min-w-0">
						<p class="font-medium text-gray-800 truncate">
							{collaborator.displayName}
						</p>
						<div
							class="flex items-center space-x-2 text-xs text-gray-500"
						>
							{collaborator.id === playlist?.creator?.id ? 'Creator' : 'Collaborator'}
						</div>
					</div>
				</button>

				{#if isOwner && collaborator.id !== playlist?.creator?.id}
					<button
						onclick={() => removeCollaborator(collaborator.id)}
						aria-label="Remove collaborator"
						class="p-2 rounded-full hover:bg-red-100 text-red-600 transition-colors absolute right-2"
					>
						<svg
							width="16"
							height="16"
							fill="none"
							stroke="currentColor"
							viewBox="0 0 24 24"
						>
							<path
								stroke-linecap="round"
								stroke-linejoin="round"
								stroke-width="2"
								d="M6 18L18 6M6 6l12 12"
							></path>
						</svg>
					</button>
				{/if}
			</div>
		{/each}
	</div>
</div>