<svelte:head>
	<title>Devices - Music Room</title>
	<meta name="description" content="Manage your devices and music control permissions" />
</svelte:head>

<script lang="ts">
	import { onMount } from 'svelte';
	import { authService } from '$lib/services/auth';
	import { authStore } from '$lib/stores/auth';
	import { devicesService, type Device, type ControlPermission, type MusicControl } from '$lib/services/devices';
	import { goto } from '$app/navigation';

	let devices: Device[] = [];
	let controlPermissions: ControlPermission[] = [];
	let loading = false;
	let error = '';
	let showAddDeviceModal = false;
	let showGrantControlModal = false;
	let selectedDevice: Device | null = null;
	let musicControls = new Map<string, MusicControl>();
	let dataLoaded = false; // Flag to prevent repeated loading

	// Use the reactive auth store
	$: user = $authStore;

	// Add device form
	let newDevice = {
		name: '',
		type: 'mobile' as const
	};

	// Grant control form
	let grantControlForm = {
		userId: '',
		expiresAt: ''
	};

	// Reactive authentication check and data loading
	$: if (user === null && typeof window !== 'undefined') {
		goto('/auth/login');
	} else if (user && !loading && !dataLoaded) {
		loadData();
	}

	async function loadData() {
		loading = true;
		error = '';
		try {
			[devices, controlPermissions] = await Promise.all([
				devicesService.getDevices(),
				devicesService.getControlPermissions()
			]);

			// Load music control state for each device
			for (const device of devices) {
				try {
					const control = await devicesService.getMusicControl(device.id);
					musicControls.set(device.id, control);
				} catch (err) {
					// Device might not have music control capability
					console.warn(`Could not load music control for device ${device.id}`);
				}
			}
			musicControls = musicControls; // Trigger reactivity
			dataLoaded = true; // Mark data as loaded
		} catch (err) {
			error = 'Failed to load devices and permissions';
			console.error('loadData error:', err);
			dataLoaded = true; // Mark as loaded even on error to prevent infinite retries
		} finally {
			loading = false;
		}
	}

	function addDevice(event: SubmitEvent) {
		event.preventDefault();
		if (!user) return;

		loading = true;
		error = '';
		devicesService.registerDevice(newDevice).then(() => {
			showAddDeviceModal = false;
			// Reset form
			newDevice = {
				name: '',
				type: 'mobile'
			};
			dataLoaded = false; // Trigger reload
		}).catch((err) => {
			error = err instanceof Error ? err.message : 'Failed to add device';
		}).finally(() => {
			loading = false;
		});
	}

	async function removeDevice(deviceId: string) {
		if (!user) return;

		try {
			await devicesService.deleteDevice(deviceId);
			dataLoaded = false; // Trigger reload
		} catch (err) {
			error = err instanceof Error ? err.message : 'Failed to remove device';
		}
	}

	async function toggleDeviceActive(device: Device) {
		if (!user) return;

		try {
			await devicesService.updateDevice(device.id, { isActive: !device.isActive });
			dataLoaded = false; // Trigger reload
		} catch (err) {
			error = err instanceof Error ? err.message : 'Failed to update device';
		}
	}

	function grantControl(event: SubmitEvent) {
		event.preventDefault();
		if (!user || !selectedDevice) return;

		loading = true;
		error = '';
		devicesService.grantControlPermission(
			selectedDevice.id, 
			grantControlForm.userId, 
			grantControlForm.expiresAt || undefined
		).then(() => {
			showGrantControlModal = false;
			selectedDevice = null;
			// Reset form
			grantControlForm = {
				userId: '',
				expiresAt: ''
			};
			dataLoaded = false; // Trigger reload
		}).catch((err) => {
			error = err instanceof Error ? err.message : 'Failed to grant control permission';
		}).finally(() => {
			loading = false;
		});
	}

	async function revokeControl(permission: ControlPermission) {
		if (!user) return;

		try {
			await devicesService.revokeControlPermission(permission.deviceId, permission.grantedTo);
			dataLoaded = false; // Trigger reload
		} catch (err) {
			error = err instanceof Error ? err.message : 'Failed to revoke control permission';
		}
	}

	async function updateMusicControl(deviceId: string, control: Partial<MusicControl>) {
		if (!user) return;

		try {
			await devicesService.updateMusicControl(deviceId, control);
			// Update local state
			const currentControl = musicControls.get(deviceId);
			if (currentControl) {
				musicControls.set(deviceId, { ...currentControl, ...control });
				musicControls = musicControls; // Trigger reactivity
			}
		} catch (err) {
			error = err instanceof Error ? err.message : 'Failed to update music control';
		}
	}

	function formatDate(dateString: string) {
		return new Date(dateString).toLocaleDateString('en-US', {
			year: 'numeric',
			month: 'short',
			day: 'numeric',
			hour: '2-digit',
			minute: '2-digit'
		});
	}

	function getDeviceIcon(type: string) {
		switch (type) {
			case 'mobile':
				return 'M7 4V2C7 1.45 7.45 1 8 1H16C16.55 1 17 1.45 17 2V4H7ZM19 6H5C4.45 6 4 6.45 4 7S4.45 8 5 8H19C19.55 8 20 7.55 20 7S19.55 6 19 6ZM18 10H6C5.45 10 5 10.45 5 11V19C5 20.1 5.9 21 7 21H17C18.1 21 19 20.1 19 19V11C19 10.45 18.55 10 18 10Z';
			case 'desktop':
				return 'M21 2H3C2.45 2 2 2.45 2 3V17C2 17.55 2.45 18 3 18H8L7 21V22H17V21L16 18H21C21.55 18 22 17.55 22 17V3C22 2.45 21.55 2 21 2ZM20 16H4V4H20V16Z';
			case 'speaker':
				return 'M12 2C11.45 2 11 2.45 11 3V21C11 21.55 11.45 22 12 22S13 21.55 13 21V3C13 2.45 12.55 2 12 2ZM8 6C7.45 6 7 6.45 7 7V17C7 17.55 7.45 18 8 18S9 17.55 9 17V7C9 6.45 8.55 6 8 6ZM16 8C15.45 8 15 8.45 15 9V15C15 15.55 15.45 16 16 16S17 15.55 17 15V9C17 8.45 16.55 8 16 8Z';
			default:
				return 'M12 2L13.09 8.26L22 9L13.09 9.74L12 16L10.91 9.74L2 9L10.91 8.26L12 2Z';
		}
	}

	onMount(() => {
		if (!user) {
			goto('/auth/login');
		}
	});
</script>

{#if !user}
<div class="container mx-auto px-4 py-8">
	<div class="text-center py-12">
		<h3 class="text-xl font-semibold text-gray-700 mb-2">Authentication Required</h3>
		<p class="text-gray-500 mb-4">Please log in to manage your devices.</p>
		<a href="/auth/login" class="bg-secondary text-white px-6 py-2 rounded-lg hover:bg-secondary/80 transition-colors">
			Log In
		</a>
	</div>
</div>
{:else}
<div class="container mx-auto px-4 py-8">
	<div class="flex justify-between items-center mb-8">
		<div>
			<h1 class="font-family-main text-4xl font-bold text-gray-800 mb-2">My Devices</h1>
			<p class="text-gray-600">Manage your devices and control permissions</p>
		</div>
		
		<button 
			onclick={() => showAddDeviceModal = true}
			class="bg-secondary text-white px-6 py-3 rounded-lg font-semibold hover:bg-secondary/80 transition-colors"
		>
			Add Device
		</button>
	</div>

	{#if error}
	<div class="bg-red-100 border border-red-400 text-red-700 px-4 py-3 rounded mb-6">
		{error}
	</div>
	{/if}

	{#if loading}
	<div class="flex justify-center items-center py-12">
		<div class="animate-spin rounded-full h-8 w-8 border-b-2 border-secondary"></div>
	</div>
	{:else}
	<div class="grid grid-cols-1 lg:grid-cols-2 gap-8">
		<!-- Devices -->
		<div class="space-y-6">
			<h2 class="text-2xl font-bold text-gray-800">Devices ({devices.length})</h2>
			
			{#if devices.length === 0}
			<div class="bg-white rounded-lg shadow-md p-8 text-center">
				<h3 class="text-lg font-semibold text-gray-700 mb-2">No devices registered</h3>
				<p class="text-gray-500 mb-4">Add your first device to start managing music control.</p>
				<button 
					onclick={() => showAddDeviceModal = true}
					class="bg-secondary text-white px-6 py-2 rounded-lg hover:bg-secondary/80 transition-colors"
				>
					Add Device
				</button>
			</div>
			{:else}
			<div class="space-y-4">
				{#each devices as device}
				<div class="bg-white rounded-lg shadow-md p-6">
					<div class="flex items-start justify-between mb-4">
						<div class="flex items-center space-x-3">
							<div class="w-10 h-10 bg-secondary/20 rounded-lg flex items-center justify-center">
								<svg class="w-6 h-6 text-secondary" viewBox="0 0 24 24" fill="currentColor">
									<path d={getDeviceIcon(device.type)} />
								</svg>
							</div>
							<div>
								<h3 class="font-semibold text-gray-800">{device.name}</h3>
								<p class="text-sm text-gray-500 capitalize">{device.type}</p>
							</div>
						</div>
						
						<div class="flex items-center space-x-2">
							<span class="px-2 py-1 text-xs rounded-full {device.isActive ? 'bg-green-100 text-green-800' : 'bg-gray-100 text-gray-800'}">
								{device.isActive ? 'Active' : 'Inactive'}
							</span>
							
							{#if device.isControlled}
							<span class="px-2 py-1 text-xs rounded-full bg-blue-100 text-blue-800">
								Controlled by {device.controlledByName}
							</span>
							{/if}
						</div>
					</div>
					
					<div class="text-sm text-gray-500 mb-4">
						<p>Connected: {formatDate(device.connectedAt)}</p>
						<p>Last active: {formatDate(device.lastActiveAt)}</p>
					</div>

					<!-- Music Control -->
					{#if musicControls.has(device.id)}
					{@const control = musicControls.get(device.id)}
					<div class="border-t pt-4 mb-4">
						<h4 class="font-medium text-gray-800 mb-3">Music Control</h4>
						
						{#if control?.currentTrack}
						<div class="bg-gray-50 rounded-lg p-3 mb-3">
							<div class="flex items-center space-x-3">
								{#if control.currentTrack.thumbnailUrl}
								<img src={control.currentTrack.thumbnailUrl} alt={control.currentTrack.title} class="w-10 h-10 rounded object-cover" />
								{/if}
								<div class="flex-1">
									<p class="font-medium text-sm">{control.currentTrack.title}</p>
									<p class="text-xs text-gray-600">{control.currentTrack.artist}</p>
								</div>
							</div>
						</div>
						{/if}
						
						<div class="flex items-center space-x-4">
							<button 
								onclick={() => updateMusicControl(device.id, { isPlaying: !control?.isPlaying })}
								class="flex items-center space-x-1 px-3 py-1 bg-secondary text-white rounded hover:bg-secondary/80 transition-colors"
							>
								{#if control?.isPlaying}
								<svg class="w-4 h-4" fill="none" stroke="currentColor" viewBox="0 0 24 24">
									<path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M10 9v6m4-6v6m7-3a9 9 0 11-18 0 9 9 0 0118 0z"></path>
								</svg>
								<span class="text-sm">Pause</span>
								{:else}
								<svg class="w-4 h-4" fill="none" stroke="currentColor" viewBox="0 0 24 24">
									<path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M14.828 14.828a4 4 0 01-5.656 0M9 10h1.5a2.5 2.5 0 010 5H9m0-5H7.5a2.5 2.5 0 000 5H9m-3-5a9 9 0 1118 0 9 9 0 01-18 0z"></path>
								</svg>
								<span class="text-sm">Play</span>
								{/if}
							</button>
							
							<div class="flex items-center space-x-2">
								<span class="text-sm text-gray-600">Volume:</span>
								<input 
									type="range" 
									min="0" 
									max="100" 
									value={control?.volume || 50}
									onchange={(e) => {
										const target = e.target as HTMLInputElement;
										updateMusicControl(device.id, { volume: parseInt(target.value) });
									}}
									class="w-20"
								/>
								<span class="text-sm text-gray-600">{control?.volume || 50}%</span>
							</div>
						</div>
					</div>
					{/if}
					
					<div class="flex space-x-3">
						<button 
							onclick={() => toggleDeviceActive(device)}
							class="flex-1 {device.isActive ? 'border border-gray-300 text-gray-700 hover:bg-gray-50' : 'bg-green-500 text-white hover:bg-green-600'} py-2 px-4 rounded-lg font-medium transition-colors"
						>
							{device.isActive ? 'Deactivate' : 'Activate'}
						</button>
						
						<button 
							onclick={() => { selectedDevice = device; showGrantControlModal = true; }}
							class="flex-1 bg-blue-500 text-white py-2 px-4 rounded-lg font-medium hover:bg-blue-600 transition-colors"
						>
							Grant Control
						</button>
						
						<button 
							onclick={() => removeDevice(device.id)}
							class="border border-red-500 text-red-500 py-2 px-4 rounded-lg font-medium hover:bg-red-50 transition-colors"
						>
							Remove
						</button>
					</div>
				</div>
				{/each}
			</div>
			{/if}
		</div>
		
		<!-- Control Permissions -->
		<div class="space-y-6">
			<h2 class="text-2xl font-bold text-gray-800">Control Permissions ({controlPermissions.length})</h2>
			
			{#if controlPermissions.length === 0}
			<div class="bg-white rounded-lg shadow-md p-8 text-center">
				<h3 class="text-lg font-semibold text-gray-700 mb-2">No control permissions granted</h3>
				<p class="text-gray-500">You haven't granted control permissions to anyone yet.</p>
			</div>
			{:else}
			<div class="space-y-4">
				{#each controlPermissions as permission}
				<div class="bg-white rounded-lg shadow-md p-6">
					<div class="flex items-start justify-between mb-4">
						<div>
							<h3 class="font-semibold text-gray-800">{permission.grantedToName}</h3>
							<p class="text-sm text-gray-600">Device: {permission.deviceName}</p>
						</div>
						
						<span class="px-2 py-1 text-xs rounded-full {permission.isActive ? 'bg-green-100 text-green-800' : 'bg-gray-100 text-gray-800'}">
							{permission.isActive ? 'Active' : 'Inactive'}
						</span>
					</div>
					
					<div class="text-sm text-gray-500 mb-4">
						<p>Granted: {formatDate(permission.grantedAt)}</p>
						{#if permission.expiresAt}
						<p>Expires: {formatDate(permission.expiresAt)}</p>
						{/if}
					</div>
					
					<button 
						onclick={() => revokeControl(permission)}
						class="w-full border border-red-500 text-red-500 py-2 px-4 rounded-lg font-medium hover:bg-red-50 transition-colors"
					>
						Revoke Permission
					</button>
				</div>
				{/each}
			</div>
			{/if}
		</div>
	</div>
	{/if}
</div>

<!-- Add Device Modal -->
{#if showAddDeviceModal}
<div class="fixed inset-0 bg-black bg-opacity-50 flex items-center justify-center z-50 p-4">
	<div class="bg-white rounded-lg max-w-md w-full">
		<div class="p-6">
			<div class="flex justify-between items-center mb-4">
				<h2 class="text-xl font-bold text-gray-800">Add New Device</h2>
				<button 
					onclick={() => showAddDeviceModal = false}
					class="text-gray-400 hover:text-gray-600"
					aria-label="Close modal"
				>
					<svg class="w-6 h-6" fill="none" stroke="currentColor" viewBox="0 0 24 24">
						<path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M6 18L18 6M6 6l12 12"></path>
					</svg>
				</button>
			</div>
			
			<form onsubmit={addDevice} class="space-y-4">
				<div>
					<label for="device-name" class="block text-sm font-medium text-gray-700 mb-1">Device Name</label>
					<input 
						id="device-name"
						type="text" 
						bind:value={newDevice.name}
						required
						class="w-full px-3 py-2 border border-gray-300 rounded-lg focus:outline-none focus:ring-2 focus:ring-secondary"
						placeholder="Enter device name"
					/>
				</div>
				
				<div>
					<label for="device-type" class="block text-sm font-medium text-gray-700 mb-1">Device Type</label>
					<select 
						id="device-type"
						bind:value={newDevice.type}
						class="w-full px-3 py-2 border border-gray-300 rounded-lg focus:outline-none focus:ring-2 focus:ring-secondary"
					>
						<option value="mobile">Mobile Device</option>
						<option value="desktop">Desktop Computer</option>
						<option value="speaker">Speaker/Audio System</option>
						<option value="other">Other</option>
					</select>
				</div>
				
				<div class="flex space-x-3 pt-4">
					<button 
						type="button"
						onclick={() => showAddDeviceModal = false}
						class="flex-1 px-4 py-2 border border-gray-300 text-gray-700 rounded-lg hover:bg-gray-50"
					>
						Cancel
					</button>
					<button 
						type="submit"
						disabled={loading}
						class="flex-1 bg-secondary text-white px-4 py-2 rounded-lg hover:bg-secondary/80 disabled:opacity-50"
					>
						{loading ? 'Adding...' : 'Add Device'}
					</button>
				</div>
			</form>
		</div>
	</div>
</div>
{/if}

<!-- Grant Control Modal -->
{#if showGrantControlModal && selectedDevice}
<div class="fixed inset-0 bg-black bg-opacity-50 flex items-center justify-center z-50 p-4">
	<div class="bg-white rounded-lg max-w-md w-full">
		<div class="p-6">
			<div class="flex justify-between items-center mb-4">
				<h2 class="text-xl font-bold text-gray-800">Grant Control Permission</h2>
				<button 
					onclick={() => showGrantControlModal = false}
					class="text-gray-400 hover:text-gray-600"
					aria-label="Close modal"
				>
					<svg class="w-6 h-6" fill="none" stroke="currentColor" viewBox="0 0 24 24">
						<path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M6 18L18 6M6 6l12 12"></path>
					</svg>
				</button>
			</div>
			
			<div class="mb-4 p-3 bg-gray-50 rounded-lg">
				<p class="text-sm text-gray-600">Device: <span class="font-medium">{selectedDevice.name}</span></p>
			</div>
			
			<form onsubmit={grantControl} class="space-y-4">
				<div>
					<label for="user-id" class="block text-sm font-medium text-gray-700 mb-1">User ID or Email</label>
					<input 
						id="user-id"
						type="text" 
						bind:value={grantControlForm.userId}
						required
						class="w-full px-3 py-2 border border-gray-300 rounded-lg focus:outline-none focus:ring-2 focus:ring-secondary"
						placeholder="Enter user ID or email"
					/>
				</div>
				
				<div>
					<label for="expires-at" class="block text-sm font-medium text-gray-700 mb-1">Expires At (optional)</label>
					<input 
						id="expires-at"
						type="datetime-local" 
						bind:value={grantControlForm.expiresAt}
						class="w-full px-3 py-2 border border-gray-300 rounded-lg focus:outline-none focus:ring-2 focus:ring-secondary"
					/>
					<p class="text-xs text-gray-500 mt-1">Leave empty for permanent access</p>
				</div>
				
				<div class="flex space-x-3 pt-4">
					<button 
						type="button"
						onclick={() => showGrantControlModal = false}
						class="flex-1 px-4 py-2 border border-gray-300 text-gray-700 rounded-lg hover:bg-gray-50"
					>
						Cancel
					</button>
					<button 
						type="submit"
						disabled={loading}
						class="flex-1 bg-secondary text-white px-4 py-2 rounded-lg hover:bg-secondary/80 disabled:opacity-50"
					>
						{loading ? 'Granting...' : 'Grant Permission'}
					</button>
				</div>
			</form>
		</div>
	</div>
</div>
{/if}
{/if}
