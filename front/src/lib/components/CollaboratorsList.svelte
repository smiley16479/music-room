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

<div class="bg-white rounded-lg shadow-md p-6 w-full lg:max-w-xs">
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
			<div class="group/main relative">
				<button
					onclick={() => goto(`/users/${collaborator.id}`)}
					class="flex pr-4 items-center space-x-3 p-2 rounded-lg hover:bg-gray-50 transition-colors w-full relative text-left {collaborator.id ===
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

				<!-- Remove Collaborator Button -->
				{#if isOwner && collaborator.id !== playlist?.creator?.id}
					<button class="absolute right-0 top-[50%] translate-x-[50%] translate-y-[-50%] hidden group-hover/main:block group/btn" onclick={() => (removeCollaborator(collaborator.id))} aria-label="Promote to admin">
						<svg viewBox="-2.4 -2.4 28.80 28.80" class="w-9 h-9" fill="none" xmlns="http://www.w3.org/2000/svg"><g id="SVGRepo_bgCarrier" stroke-width="0"><path transform="translate(-2.4, -2.4), scale(1.7999999999999998)" fill="#ffffff" class="group-hover/btn:fill-gray-200 transition-colors duration-200" d="M9.166.33a2.25 2.25 0 00-2.332 0l-5.25 3.182A2.25 2.25 0 00.5 5.436v5.128a2.25 2.25 0 001.084 1.924l5.25 3.182a2.25 2.25 0 002.332 0l5.25-3.182a2.25 2.25 0 001.084-1.924V5.436a2.25 2.25 0 00-1.084-1.924L9.166.33z" stroke-width="0"></path></g><g id="SVGRepo_tracerCarrier" stroke-linecap="round" stroke-linejoin="round"></g><g id="SVGRepo_iconCarrier"> <path d="M6.99486 7.00636C6.60433 7.39689 6.60433 8.03005 6.99486 8.42058L10.58 12.0057L6.99486 15.5909C6.60433 15.9814 6.60433 16.6146 6.99486 17.0051C7.38538 17.3956 8.01855 17.3956 8.40907 17.0051L11.9942 13.4199L15.5794 17.0051C15.9699 17.3956 16.6031 17.3956 16.9936 17.0051C17.3841 16.6146 17.3841 15.9814 16.9936 15.5909L13.4084 12.0057L16.9936 8.42059C17.3841 8.03007 17.3841 7.3969 16.9936 7.00638C16.603 6.61585 15.9699 6.61585 15.5794 7.00638L11.9942 10.5915L8.40907 7.00636C8.01855 6.61584 7.38538 6.61584 6.99486 7.00636Z" fill="#e01b24"></path> </g></svg>
					</button>
				{/if}
			</div>
		{/each}
	</div>
</div>