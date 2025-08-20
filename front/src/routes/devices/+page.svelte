<svelte:head>
	<title>Device Management - Music Room</title>
	<meta name="description" content="Manage your devices, delegate music control for events, and connect devices to playlists in Music Room" />
</svelte:head>

<script lang="ts">
	import { onMount, onDestroy } from 'svelte';
	import { goto } from '$app/navigation';
	import { authStore } from '$lib/stores/auth';
	import { authService } from '$lib/services/auth';
	import { devicesService as apiDevicesService } from '$lib/services/devices';
	import type { 
		Device, 
		CreateDeviceDto, 
		DelegateControlDto 
	} from '$lib/types/device';
	import { DeviceType, DeviceStatus } from '$lib/types/device';
	import { deviceSocketService } from '$lib/services/device-socket';

	// Rename to avoid any conflicts with socket service
	const devicesService = apiDevicesService;

	// Reactive state using Svelte 5 runes
	let devices = $state<Device[]>([]);
	let filteredDevices = $state<Device[]>([]);
	let loading = $state(false);
	let error = $state('');
	let socketConnected = $state(false);
	
	// Filter and sort states
	let activeTab = $state<'all' | 'mine' | 'delegated'>('all');
	let searchQuery = $state('');
	let sortBy = $state<'name' | 'type' | 'status' | 'lastSeen'>('lastSeen');
	let sortOrder = $state<'asc' | 'desc'>('desc');
	
	// Modal states
	let showAddDeviceModal = $state(false);
	let showDelegateModal = $state(false);
	let showConnectToEventModal = $state(false);
	let selectedDevice = $state<Device | null>(null);
	
	// Form states
	let newDevice = $state<CreateDeviceDto>({
		name: '',
		type: DeviceType.OTHER,
		canBeControlled: false
	});
	
	let delegateForm = $state<DelegateControlDto & { deviceId: string }>({
		deviceId: '',
		userId: '',
		expiresAt: '',
		permissions: {
			canPlay: true,
			canPause: true,
			canSkip: false,
			canChangeVolume: false,
			canChangePlaylist: false
		}
	});

	// Connect to event/playlist form
	let connectForm = $state({
		deviceId: '',
		eventId: '',
		playlistId: '',
		type: 'event' as 'event' | 'playlist'
	});

	// Get user from auth store
	const user = $derived($authStore);

	// Computed values
	const myDevices = $derived(devices.filter(device => device.ownerId === user?.id));
	const delegatedDevices = $derived(devices.filter(device => device.delegatedToId === user?.id));
	const onlineDevicesCount = $derived(devices.filter(device => device.status === DeviceStatus.ONLINE).length);

	// Filter and sort devices
	$effect(() => {
		let filtered = [...devices];

		// Apply search filter
		if (searchQuery.trim()) {
			const query = searchQuery.toLowerCase().trim();
			filtered = filtered.filter(device => 
				device.name.toLowerCase().includes(query) ||
				device.type.toLowerCase().includes(query) ||
				device.owner?.displayName?.toLowerCase().includes(query) ||
				device.delegatedTo?.displayName?.toLowerCase().includes(query)
			);
		}

		// Apply tab filter
		if (activeTab === 'mine' && user) {
			filtered = filtered.filter(device => device.ownerId === user.id);
		} else if (activeTab === 'delegated' && user) {
			filtered = filtered.filter(device => device.delegatedToId === user.id);
		}

		// Apply sorting
		filtered.sort((a, b) => {
			let comparison = 0;
			
			switch (sortBy) {
				case 'name':
					comparison = a.name.localeCompare(b.name);
					break;
				case 'type':
					comparison = a.type.localeCompare(b.type);
					break;
				case 'status':
					const statusOrder = { 'online': 0, 'playing': 1, 'paused': 2, 'offline': 3 };
					comparison = statusOrder[a.status] - statusOrder[b.status];
					break;
				case 'lastSeen':
				default:
					comparison = new Date(a.lastSeen).getTime() - new Date(b.lastSeen).getTime();
					break;
			}
			
			return sortOrder === 'asc' ? comparison : -comparison;
		});

		filteredDevices = filtered;
	});

	// Authentication check
	$effect(() => {
		if (user === null && typeof window !== 'undefined') {
			goto('/auth/login');
		}
	});

	onMount(async () => {
		if (user) {
			await loadDevices();
			await initializeSocket();
		}
	});

	onDestroy(() => {
		deviceSocketService.disconnect();
	});

	async function loadDevices() {
		loading = true;
		error = '';
		try {
			// TypeScript workaround: assert service has the correct methods
			const service = devicesService as any;
			devices = await service.getDevices();
		} catch (err: unknown) {
			const errorMsg = (err as Error).message || 'Failed to load devices';
			error = errorMsg;
		} finally {
			loading = false;
		}
	}

	async function initializeSocket() {
		if (!user || !authService.getAuthToken()) {
			return;
		}

		try {
			await deviceSocketService.connect();
			socketConnected = true;

			// Set up socket listeners
			deviceSocketService.onDeviceConnected((data) => {
				loadDevices(); // Refresh device list
			});

			deviceSocketService.onDeviceDisconnected((data) => {
				loadDevices(); // Refresh device list
			});

			deviceSocketService.onDeviceUpdated((data) => {
				// Update specific device in the list
				const index = devices.findIndex(d => d.id === data.deviceId);
				if (index !== -1) {
					devices[index] = data.device;
					devices = [...devices]; // Trigger reactivity
				}
			});

			deviceSocketService.onDeviceStatusChanged((data) => {
				// Update device status
				const device = devices.find(d => d.id === data.deviceId);
				if (device) {
					device.status = data.status as DeviceStatus;
					device.lastSeen = data.timestamp;
					devices = [...devices]; // Trigger reactivity
				}
			});

			deviceSocketService.onControlDelegated((data) => {
				loadDevices(); // Refresh to show delegation changes
			});

			deviceSocketService.onControlRevoked((data) => {
				loadDevices(); // Refresh to show delegation changes
			});

		deviceSocketService.onError((error) => {
			// Socket error - just set disconnected state
			socketConnected = false;
		});		} catch (err: unknown) {
			socketConnected = false;
		}
	}

	async function createDevice() {
		if (!newDevice.name.trim()) {
			error = 'Device name is required';
			return;
		}

		loading = true;
		error = '';
		
		try {
			// TypeScript workaround: assert service has the correct methods
			const service = devicesService as any;
			const device = await service.createDevice({
				name: newDevice.name.trim(),
				type: newDevice.type,
				canBeControlled: newDevice.canBeControlled
			});
			
			devices = [...devices, device];
			showAddDeviceModal = false;
			
			// Reset form
			newDevice = {
				name: '',
				type: DeviceType.OTHER,
				canBeControlled: false
			};
			
		} catch (err: unknown) {
			error = (err as Error).message || 'Failed to create device';
		} finally {
			loading = false;
		}
	}

	async function deleteDevice(deviceId: string) {
		if (!confirm('Are you sure you want to delete this device?')) {
			return;
		}

		loading = true;
		try {
			await devicesService.deleteDevice(deviceId);
			devices = devices.filter(d => d.id !== deviceId);
		} catch (err: unknown) {
			error = (err as Error).message || 'Failed to delete device';
		} finally {
			loading = false;
		}
	}

	async function delegateControl() {
		if (!delegateForm.userId.trim()) {
			error = 'User ID is required for delegation';
			return;
		}

		loading = true;
		error = '';
		
		try {
			// TypeScript workaround: assert service has the correct methods
			const service = devicesService as any;
			await service.delegateControl(delegateForm.deviceId, {
				userId: delegateForm.userId.trim(),
				expiresAt: delegateForm.expiresAt || undefined,
				permissions: delegateForm.permissions
			});
			
			await loadDevices(); // Refresh to show changes
			showDelegateModal = false;
			
		} catch (err: unknown) {
			error = (err as Error).message || 'Failed to delegate control';
		} finally {
			loading = false;
		}
	}

	async function revokeControl(deviceId: string) {
		if (!confirm('Are you sure you want to revoke control delegation?')) {
			return;
		}

		loading = true;
		try {
			// TypeScript workaround: assert service has the correct methods
			const service = devicesService as any;
			await service.revokeControl(deviceId);
			await loadDevices(); // Refresh to show changes
		} catch (err: unknown) {
			error = (err as Error).message || 'Failed to revoke control';
		} finally {
			loading = false;
		}
	}

	async function connectDevice(deviceId: string) {
		try {
			// TypeScript workaround: assert service has the correct methods
			const service = devicesService as any;
			await service.connectDevice(deviceId);
			// Socket will handle the status update
		} catch (err: unknown) {
			error = (err as Error).message || 'Failed to connect device';
		}
	}

	async function disconnectDevice(deviceId: string) {
		try {
			// TypeScript workaround: assert service has the correct methods
			const service = devicesService as any;
			await service.disconnectDevice(deviceId);
			// Socket will handle the status update
		} catch (err: unknown) {
			error = (err as Error).message || 'Failed to disconnect device';
		}
	}

	function openDelegateModal(device: Device) {
		selectedDevice = device;
		delegateForm = {
			deviceId: device.id,
			userId: '',
			expiresAt: '',
			permissions: {
				canPlay: true,
				canPause: true,
				canSkip: false,
				canChangeVolume: false,
				canChangePlaylist: false
			}
		};
		showDelegateModal = true;
	}

	function openConnectToEventModal(device: Device) {
		selectedDevice = device;
		connectForm = {
			deviceId: device.id,
			eventId: '',
			playlistId: '',
			type: 'event'
		};
		showConnectToEventModal = true;
	}

	async function connectToEventOrPlaylist() {
		// This would connect the device to control music for a specific event or playlist
		// Implementation would depend on your backend API
		loading = true;
		try {
			// Placeholder for API call
			showConnectToEventModal = false;
		} catch (err: unknown) {
			error = (err as Error).message || 'Failed to connect device';
		} finally {
			loading = false;
		}
	}

	function handleTabChange(newTab: 'all' | 'mine' | 'delegated') {
		if (activeTab !== newTab) {
			activeTab = newTab;
		}
	}

	function handleSort(newSortBy: typeof sortBy) {
		if (sortBy === newSortBy) {
			sortOrder = sortOrder === 'asc' ? 'desc' : 'asc';
		} else {
			sortBy = newSortBy;
			sortOrder = 'desc';
		}
	}

	function getSortIcon(column: typeof sortBy) {
		if (sortBy !== column) return '↕';
		return sortOrder === 'asc' ? '↑' : '↓';
	}

	function getDeviceIcon(type: DeviceType): string {
		switch (type) {
			case DeviceType.PHONE:
				return '📱';
			case DeviceType.TABLET:
				return '📟';
			case DeviceType.DESKTOP:
				return '💻';
			case DeviceType.SMART_SPEAKER:
				return '🔊';
			case DeviceType.TV:
				return '📺';
			default:
				return '📱';
		}
	}

	function getStatusColor(status: DeviceStatus): string {
		switch (status) {
			case DeviceStatus.ONLINE:
				return 'text-green-500';
			case DeviceStatus.PLAYING:
				return 'text-blue-500';
			case DeviceStatus.PAUSED:
				return 'text-yellow-500';
			default:
				return 'text-gray-400';
		}
	}

	function getStatusBadgeColor(status: DeviceStatus): string {
		switch (status) {
			case DeviceStatus.ONLINE:
				return 'bg-green-100 text-green-800';
			case DeviceStatus.PLAYING:
				return 'bg-blue-100 text-blue-800';
			case DeviceStatus.PAUSED:
				return 'bg-yellow-100 text-yellow-800';
			default:
				return 'bg-gray-100 text-gray-800';
		}
	}

	function formatLastSeen(timestamp: string): string {
		const date = new Date(timestamp);
		const now = new Date();
		const diffMs = now.getTime() - date.getTime();
		const diffMins = Math.floor(diffMs / 60000);
		
		if (diffMins < 1) return 'Just now';
		if (diffMins < 60) return `${diffMins}m ago`;
		
		const diffHours = Math.floor(diffMins / 60);
		if (diffHours < 24) return `${diffHours}h ago`;
		
		const diffDays = Math.floor(diffHours / 24);
		return `${diffDays}d ago`;
	}
</script>

<div class="container mx-auto px-4 py-8">
	<div class="flex justify-between items-center mb-8">
		<div>
			<h1 class="font-family-main text-4xl font-bold text-gray-800 mb-2">Device Management</h1>
			<p class="text-gray-600">Manage your devices, delegate music control, and connect devices to events and playlists</p>
		</div>

		{#if user}
			<button
				onclick={() => showAddDeviceModal = true}
				class="bg-secondary text-white px-6 py-3 rounded-lg font-semibold hover:bg-secondary/80 transition-colors"
			>
				Add Device
			</button>
		{/if}
	</div>

	<!-- Tab Navigation -->
	<div class="flex space-x-4 mb-6">
		<button
			class="px-4 py-2 rounded-lg font-medium transition-colors {activeTab === 'all'
				? 'bg-secondary text-white'
				: 'bg-gray-200 text-gray-700 hover:bg-gray-300'}"
			onclick={() => handleTabChange('all')}
		>
			All Devices
		</button>
		{#if user}
			<button
				class="px-4 py-2 rounded-lg font-medium transition-colors {activeTab === 'mine'
					? 'bg-secondary text-white'
					: 'bg-gray-200 text-gray-700 hover:bg-gray-300'}"
				onclick={() => handleTabChange('mine')}
			>
				My Devices
			</button>
			<button
				class="px-4 py-2 rounded-lg font-medium transition-colors {activeTab === 'delegated'
					? 'bg-indigo-500 text-white'
					: 'bg-gray-200 text-gray-700 hover:bg-gray-300'}"
				onclick={() => handleTabChange('delegated')}
			>
				🤝 Delegated to Me
			</button>
		{/if}
	</div>

	<!-- Search and Sort Controls -->
	<div class="bg-white rounded-lg shadow-sm border border-gray-200 p-4 mb-6">
		<div class="flex flex-col sm:flex-row gap-4 items-start sm:items-center justify-between">
			<!-- Search -->
			<div class="flex-1 max-w-md">
				<label for="search" class="sr-only">Search devices</label>
				<div class="relative">
					<input
						id="search"
						type="text"
						bind:value={searchQuery}
						placeholder="Search devices, owners..."
						class="w-full pl-10 pr-4 py-2 border border-gray-300 rounded-lg focus:outline-none focus:ring-2 focus:ring-secondary focus:border-transparent"
					/>
					<svg
						class="absolute left-3 top-2.5 h-5 w-5 text-gray-400"
						fill="none"
						stroke="currentColor"
						viewBox="0 0 24 24"
					>
						<path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M21 21l-6-6m2-5a7 7 0 11-14 0 7 7 0 0114 0z"></path>
					</svg>
				</div>
			</div>

			<!-- Sort Controls -->
			<div class="flex items-center space-x-2">
				<span class="text-sm font-medium text-gray-700">Sort by:</span>
				<button
					onclick={() => handleSort('name')}
					class="px-3 py-1 text-sm border border-gray-300 rounded hover:bg-gray-50 {sortBy === 'name' ? 'bg-gray-100' : ''}"
				>
					Name {getSortIcon('name')}
				</button>
				<button
					onclick={() => handleSort('type')}
					class="px-3 py-1 text-sm border border-gray-300 rounded hover:bg-gray-50 {sortBy === 'type' ? 'bg-gray-100' : ''}"
				>
					Type {getSortIcon('type')}
				</button>
				<button
					onclick={() => handleSort('status')}
					class="px-3 py-1 text-sm border border-gray-300 rounded hover:bg-gray-50 {sortBy === 'status' ? 'bg-gray-100' : ''}"
				>
					Status {getSortIcon('status')}
				</button>
				<button
					onclick={() => handleSort('lastSeen')}
					class="px-3 py-1 text-sm border border-gray-300 rounded hover:bg-gray-50 {sortBy === 'lastSeen' ? 'bg-gray-100' : ''}"
				>
					Last Seen {getSortIcon('lastSeen')}
				</button>
			</div>
		</div>

		<!-- Stats -->
		<div class="mt-4 grid grid-cols-1 gap-4 sm:grid-cols-3">
			<div class="bg-gray-50 rounded-lg p-3">
				<div class="flex items-center">
					<div class="text-lg mr-2">📱</div>
					<div>
						<div class="text-sm font-medium text-gray-500">Total Devices</div>
						<div class="text-lg font-semibold text-gray-900">{devices.length}</div>
					</div>
				</div>
			</div>
			<div class="bg-gray-50 rounded-lg p-3">
				<div class="flex items-center">
					<div class="text-lg mr-2">🟢</div>
					<div>
						<div class="text-sm font-medium text-gray-500">Online</div>
						<div class="text-lg font-semibold text-gray-900">{onlineDevicesCount}</div>
					</div>
				</div>
			</div>
			<div class="bg-gray-50 rounded-lg p-3">
				<div class="flex items-center">
					<div class="text-lg mr-2">🤝</div>
					<div>
						<div class="text-sm font-medium text-gray-500">Delegated</div>
						<div class="text-lg font-semibold text-gray-900">{delegatedDevices.length}</div>
					</div>
				</div>
			</div>
		</div>
	</div>

	<!-- Error Display -->
	{#if error}
		<div class="mb-6 bg-red-50 border border-red-200 rounded-lg p-4">
			<div class="flex items-center">
				<div class="text-red-400 text-xl mr-3">⚠️</div>
				<p class="text-red-800">{error}</p>
				<button
					onclick={() => error = ''}
					class="ml-auto text-red-400 hover:text-red-600"
					aria-label="Dismiss error"
				>
					<svg class="w-5 h-5" fill="none" stroke="currentColor" viewBox="0 0 24 24">
						<path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M6 18L18 6M6 6l12 12"></path>
					</svg>
				</button>
			</div>
		</div>
	{/if}

	<!-- Socket Connection Status -->
	{#if user}
		<div class="mb-4 flex items-center space-x-2">
			{#if socketConnected}
				<div class="flex items-center text-green-600 text-sm">
					<div class="w-2 h-2 bg-green-500 rounded-full mr-2"></div>
					<span>Real-time updates connected</span>
				</div>
			{:else}
				<div class="flex items-center text-gray-400 text-sm">
					<div class="w-2 h-2 bg-gray-400 rounded-full mr-2"></div>
					<span>Real-time updates offline</span>
				</div>
			{/if}
		</div>
	{/if}

	<!-- Loading State -->
	{#if loading}
		<div class="text-center py-12">
			<div class="inline-block animate-spin rounded-full h-8 w-8 border-b-2 border-secondary"></div>
			<p class="mt-2 text-gray-600">Loading devices...</p>
		</div>
	{:else if filteredDevices.length === 0}
		<div class="text-center py-12">
			<div class="text-6xl mb-4">📱</div>
			{#if searchQuery.trim()}
				<h3 class="text-lg font-medium text-gray-900 mb-2">No devices found</h3>
				<p class="text-gray-600 mb-6">Try adjusting your search or filters.</p>
			{:else}
				<h3 class="text-lg font-medium text-gray-900 mb-2">No devices found</h3>
				<p class="text-gray-600 mb-6">Get started by adding your first device.</p>
				{#if user}
					<button
						onclick={() => showAddDeviceModal = true}
						class="bg-secondary text-white px-6 py-3 rounded-lg font-semibold hover:bg-secondary/80 transition-colors"
					>
						Add Device
					</button>
				{/if}
			{/if}
		</div>
	{:else}
		<!-- Devices Grid -->
		<div class="grid grid-cols-1 gap-6 sm:grid-cols-2 lg:grid-cols-3">
			{#each filteredDevices as device (device.id)}
				<div class="bg-white rounded-lg shadow-sm border border-gray-200 p-6 hover:shadow-md transition-shadow">
					<!-- Device Header -->
					<div class="flex items-center justify-between mb-4">
						<div class="flex items-center">
							<span class="text-2xl mr-3">{getDeviceIcon(device.type)}</span>
							<div>
								<h3 class="text-lg font-semibold text-gray-900">{device.name}</h3>
								<p class="text-sm text-gray-500 capitalize">{device.type.replace('_', ' ')}</p>
							</div>
						</div>
						<span class="inline-flex items-center px-2.5 py-0.5 rounded-full text-xs font-medium {getStatusBadgeColor(device.status)}">
							{device.status}
						</span>
					</div>

					<!-- Device Details -->
					<div class="space-y-2 mb-4 text-sm">
						<div class="flex justify-between">
							<span class="text-gray-500">Last seen:</span>
							<span class="text-gray-900">{formatLastSeen(device.lastSeen)}</span>
						</div>
						<div class="flex justify-between">
							<span class="text-gray-500">Can be controlled:</span>
							<span class="text-gray-900">{device.canBeControlled ? 'Yes' : 'No'}</span>
						</div>
						{#if device.ownerId !== user?.id}
							<div class="flex justify-between">
								<span class="text-gray-500">Owner:</span>
								<span class="text-gray-900">{device.owner?.displayName || device.owner?.email || 'Unknown'}</span>
							</div>
						{/if}
						{#if device.delegatedToId && device.ownerId === user?.id}
							<div class="flex justify-between">
								<span class="text-gray-500">Delegated to:</span>
								<span class="text-indigo-600">{device.delegatedTo?.displayName || device.delegatedTo?.email}</span>
							</div>
						{/if}
						{#if device.delegationExpiresAt}
							<div class="flex justify-between">
								<span class="text-gray-500">Expires:</span>
								<span class="text-gray-900">{new Date(device.delegationExpiresAt).toLocaleDateString()}</span>
							</div>
						{/if}
					</div>

					<!-- Permissions (for delegated devices) -->
					{#if device.delegationPermissions && device.delegatedToId === user?.id}
						<div class="mb-4">
							<span class="text-sm font-medium text-gray-700">Permissions:</span>
							<div class="mt-1 flex flex-wrap gap-1">
								{#if device.delegationPermissions.canPlay}
									<span class="inline-flex items-center px-2 py-0.5 rounded text-xs font-medium bg-green-100 text-green-800">Play</span>
								{/if}
								{#if device.delegationPermissions.canPause}
									<span class="inline-flex items-center px-2 py-0.5 rounded text-xs font-medium bg-green-100 text-green-800">Pause</span>
								{/if}
								{#if device.delegationPermissions.canSkip}
									<span class="inline-flex items-center px-2 py-0.5 rounded text-xs font-medium bg-green-100 text-green-800">Skip</span>
								{/if}
								{#if device.delegationPermissions.canChangeVolume}
									<span class="inline-flex items-center px-2 py-0.5 rounded text-xs font-medium bg-green-100 text-green-800">Volume</span>
								{/if}
							</div>
						</div>
					{/if}

					<!-- Actions -->
					<div class="flex flex-wrap gap-2">
						{#if device.ownerId === user?.id}
							<!-- Owner actions -->
							{#if device.status === DeviceStatus.OFFLINE}
								<button
									onclick={() => connectDevice(device.id)}
									class="flex-1 bg-green-600 text-white px-3 py-2 rounded-md text-sm font-medium hover:bg-green-700 transition-colors"
								>
									Connect
								</button>
							{:else}
								<button
									onclick={() => disconnectDevice(device.id)}
									class="flex-1 bg-gray-600 text-white px-3 py-2 rounded-md text-sm font-medium hover:bg-gray-700 transition-colors"
								>
									Disconnect
								</button>
							{/if}

							{#if device.status !== DeviceStatus.OFFLINE}
								<button
									onclick={() => openConnectToEventModal(device)}
									class="flex-1 bg-blue-600 text-white px-3 py-2 rounded-md text-sm font-medium hover:bg-blue-700 transition-colors"
								>
									Link to Event
								</button>
							{/if}
							
							{#if device.canBeControlled}
								{#if device.delegatedToId}
									<button
										onclick={() => revokeControl(device.id)}
										class="flex-1 bg-red-600 text-white px-3 py-2 rounded-md text-sm font-medium hover:bg-red-700 transition-colors"
									>
										Revoke Control
									</button>
								{:else}
									<button
										onclick={() => openDelegateModal(device)}
										class="flex-1 bg-secondary text-white px-3 py-2 rounded-md text-sm font-medium hover:bg-secondary/80 transition-colors"
									>
										Delegate Control
									</button>
								{/if}
							{/if}
							
							<button
								onclick={() => deleteDevice(device.id)}
								class="bg-red-600 text-white px-3 py-2 rounded-md text-sm font-medium hover:bg-red-700 transition-colors"
								aria-label="Delete device"
								title="Delete device"
							>
								🗑️
							</button>
						{:else}
							<!-- Delegated device actions -->
							<button
								class="flex-1 bg-secondary text-white px-3 py-2 rounded-md text-sm font-medium hover:bg-secondary/80 transition-colors"
								title="Control this device"
							>
								Control Device
							</button>
						{/if}
					</div>
				</div>
			{/each}
		</div>
	{/if}
</div>

<!-- Add Device Modal -->
{#if showAddDeviceModal}
	<div class="fixed inset-0 bg-black bg-opacity-50 flex items-center justify-center z-50 p-4">
		<div class="bg-white rounded-lg max-w-md w-full">
			<div class="p-6">
				<div class="flex justify-between items-center mb-6">
					<h2 class="text-xl font-bold text-gray-800">Add New Device</h2>
					<button 
						onclick={() => showAddDeviceModal = false}
						class="text-gray-400 hover:text-gray-600 transition-colors"
						aria-label="Close modal"
					>
						<svg class="w-6 h-6" fill="none" stroke="currentColor" viewBox="0 0 24 24">
							<path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M6 18L18 6M6 6l12 12"></path>
						</svg>
					</button>
				</div>
				
				<form onsubmit={(e) => { e.preventDefault(); createDevice(); }} class="space-y-4">
					<div>
						<label for="device-name" class="block text-sm font-medium text-gray-700 mb-2">Device Name *</label>
						<input
							id="device-name"
							type="text"
							bind:value={newDevice.name}
							placeholder="My Phone"
							required
							class="w-full px-3 py-2 border border-gray-300 rounded-md focus:outline-none focus:ring-indigo-500 focus:border-indigo-500"
						/>
					</div>
					
					<div>
						<label for="device-type" class="block text-sm font-medium text-gray-700 mb-2">Device Type</label>
						<select
							id="device-type"
							bind:value={newDevice.type}
							class="w-full px-3 py-2 border border-gray-300 rounded-md focus:outline-none focus:ring-indigo-500 focus:border-indigo-500"
						>
							<option value={DeviceType.PHONE}>Phone</option>
							<option value={DeviceType.TABLET}>Tablet</option>
							<option value={DeviceType.DESKTOP}>Desktop</option>
							<option value={DeviceType.SMART_SPEAKER}>Smart Speaker</option>
							<option value={DeviceType.TV}>TV</option>
							<option value={DeviceType.OTHER}>Other</option>
						</select>
					</div>
					
					<div class="flex items-center">
						<input
							id="can-be-controlled"
							type="checkbox"
							bind:checked={newDevice.canBeControlled}
							class="h-4 w-4 text-indigo-600 focus:ring-indigo-500 border-gray-300 rounded"
						/>
						<label for="can-be-controlled" class="ml-2 block text-sm text-gray-700">
							Allow others to control this device
						</label>
					</div>
					
					<div class="flex justify-end space-x-3 pt-4">
						<button
							type="button"
							onclick={() => showAddDeviceModal = false}
							class="px-4 py-2 text-gray-700 border border-gray-300 rounded-md hover:bg-gray-50 transition-colors"
						>
							Cancel
						</button>
						<button
							type="submit"
							class="px-4 py-2 bg-indigo-600 text-white rounded-md hover:bg-indigo-700 transition-colors"
							disabled={loading}
						>
							{loading ? 'Adding...' : 'Add Device'}
						</button>
					</div>
				</form>
			</div>
		</div>
	</div>
{/if}

<!-- Delegate Control Modal -->
{#if showDelegateModal && selectedDevice}
	<div class="fixed inset-0 bg-black bg-opacity-50 flex items-center justify-center z-50 p-4">
		<div class="bg-white rounded-lg max-w-md w-full">
			<div class="p-6">
				<div class="flex justify-between items-center mb-6">
					<h2 class="text-xl font-bold text-gray-800">Delegate Control</h2>
					<button 
						onclick={() => showDelegateModal = false}
						class="text-gray-400 hover:text-gray-600 transition-colors"
						aria-label="Close modal"
					>
						<svg class="w-6 h-6" fill="none" stroke="currentColor" viewBox="0 0 24 24">
							<path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M6 18L18 6M6 6l12 12"></path>
						</svg>
					</button>
				</div>
				
				<p class="text-gray-600 mb-4">
					Delegate control of <strong>{selectedDevice.name}</strong> to another user.
				</p>
				
				<form onsubmit={(e) => { e.preventDefault(); delegateControl(); }} class="space-y-4">
					<div>
						<label for="user-id" class="block text-sm font-medium text-gray-700 mb-2">User ID or Email *</label>
						<input
							id="user-id"
							type="text"
							bind:value={delegateForm.userId}
							placeholder="user@example.com"
							required
							class="w-full px-3 py-2 border border-gray-300 rounded-md focus:outline-none focus:ring-indigo-500 focus:border-indigo-500"
						/>
					</div>
					
					<div>
						<label for="expires-at" class="block text-sm font-medium text-gray-700 mb-2">Expires At (optional)</label>
						<input
							id="expires-at"
							type="datetime-local"
							bind:value={delegateForm.expiresAt}
							class="w-full px-3 py-2 border border-gray-300 rounded-md focus:outline-none focus:ring-indigo-500 focus:border-indigo-500"
						/>
					</div>
					
					<div>
						<span class="block text-sm font-medium text-gray-700 mb-2">Permissions</span>
						<div class="space-y-2">
							<div class="flex items-center">
								<input
									id="can-play"
									type="checkbox"
									bind:checked={delegateForm.permissions.canPlay}
									class="h-4 w-4 text-indigo-600 focus:ring-indigo-500 border-gray-300 rounded"
								/>
								<label for="can-play" class="ml-2 text-sm text-gray-700">Can play music</label>
							</div>
							<div class="flex items-center">
								<input
									id="can-pause"
									type="checkbox"
									bind:checked={delegateForm.permissions.canPause}
									class="h-4 w-4 text-indigo-600 focus:ring-indigo-500 border-gray-300 rounded"
								/>
								<label for="can-pause" class="ml-2 text-sm text-gray-700">Can pause music</label>
							</div>
							<div class="flex items-center">
								<input
									id="can-skip"
									type="checkbox"
									bind:checked={delegateForm.permissions.canSkip}
									class="h-4 w-4 text-indigo-600 focus:ring-indigo-500 border-gray-300 rounded"
								/>
								<label for="can-skip" class="ml-2 text-sm text-gray-700">Can skip tracks</label>
							</div>
							<div class="flex items-center">
								<input
									id="can-change-volume"
									type="checkbox"
									bind:checked={delegateForm.permissions.canChangeVolume}
									class="h-4 w-4 text-indigo-600 focus:ring-indigo-500 border-gray-300 rounded"
								/>
								<label for="can-change-volume" class="ml-2 text-sm text-gray-700">Can change volume</label>
							</div>
							<div class="flex items-center">
								<input
									id="can-change-playlist"
									type="checkbox"
									bind:checked={delegateForm.permissions.canChangePlaylist}
									class="h-4 w-4 text-indigo-600 focus:ring-indigo-500 border-gray-300 rounded"
								/>
								<label for="can-change-playlist" class="ml-2 text-sm text-gray-700">Can change playlist</label>
							</div>
						</div>
					</div>
					
					<div class="flex justify-end space-x-3 pt-4">
						<button
							type="button"
							onclick={() => showDelegateModal = false}
							class="px-4 py-2 text-gray-700 border border-gray-300 rounded-md hover:bg-gray-50 transition-colors"
						>
							Cancel
						</button>
						<button
							type="submit"
							class="px-4 py-2 bg-indigo-600 text-white rounded-md hover:bg-indigo-700 transition-colors"
							disabled={loading}
						>
							{loading ? 'Delegating...' : 'Delegate Control'}
						</button>
					</div>
				</form>
			</div>
		</div>
	</div>
{/if}

<!-- Connect to Event/Playlist Modal -->
{#if showConnectToEventModal && selectedDevice}
	<div class="fixed inset-0 bg-black bg-opacity-50 flex items-center justify-center z-50 p-4">
		<div class="bg-white rounded-lg max-w-md w-full">
			<div class="p-6">
				<div class="flex justify-between items-center mb-6">
					<h2 class="text-xl font-bold text-gray-800">Connect Device to Event/Playlist</h2>
					<button 
						onclick={() => showConnectToEventModal = false}
						class="text-gray-400 hover:text-gray-600 transition-colors"
						aria-label="Close modal"
					>
						<svg class="w-6 h-6" fill="none" stroke="currentColor" viewBox="0 0 24 24">
							<path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M6 18L18 6M6 6l12 12"></path>
						</svg>
					</button>
				</div>
				
				<p class="text-gray-600 mb-4">
					Connect <strong>{selectedDevice.name}</strong> to control music for an event or playlist.
				</p>
				
				<form onsubmit={(e) => { e.preventDefault(); connectToEventOrPlaylist(); }} class="space-y-4">
					<div>
						<span class="block text-sm font-medium text-gray-700 mb-2">Connect to</span>
						<div class="flex space-x-4">
							<label class="flex items-center">
								<input
									type="radio"
									bind:group={connectForm.type}
									value="event"
									class="h-4 w-4 text-indigo-600 focus:ring-indigo-500 border-gray-300"
								/>
								<span class="ml-2 text-sm text-gray-700">Event</span>
							</label>
							<label class="flex items-center">
								<input
									type="radio"
									bind:group={connectForm.type}
									value="playlist"
									class="h-4 w-4 text-indigo-600 focus:ring-indigo-500 border-gray-300"
								/>
								<span class="ml-2 text-sm text-gray-700">Playlist</span>
							</label>
						</div>
					</div>

					{#if connectForm.type === 'event'}
						<div>
							<label for="event-id" class="block text-sm font-medium text-gray-700 mb-2">Event ID *</label>
							<input
								id="event-id"
								type="text"
								bind:value={connectForm.eventId}
								placeholder="Enter event ID"
								required
								class="w-full px-3 py-2 border border-gray-300 rounded-md focus:outline-none focus:ring-indigo-500 focus:border-indigo-500"
							/>
							<p class="mt-1 text-xs text-gray-500">This device will control music playback for the selected event</p>
						</div>
					{:else}
						<div>
							<label for="playlist-id" class="block text-sm font-medium text-gray-700 mb-2">Playlist ID *</label>
							<input
								id="playlist-id"
								type="text"
								bind:value={connectForm.playlistId}
								placeholder="Enter playlist ID"
								required
								class="w-full px-3 py-2 border border-gray-300 rounded-md focus:outline-none focus:ring-indigo-500 focus:border-indigo-500"
							/>
							<p class="mt-1 text-xs text-gray-500">This device will control music playback for the selected playlist</p>
						</div>
					{/if}
					
					<div class="flex justify-end space-x-3 pt-4">
						<button
							type="button"
							onclick={() => showConnectToEventModal = false}
							class="px-4 py-2 text-gray-700 border border-gray-300 rounded-md hover:bg-gray-50 transition-colors"
						>
							Cancel
						</button>
						<button
							type="submit"
							class="px-4 py-2 bg-blue-600 text-white rounded-md hover:bg-blue-700 transition-colors"
							disabled={loading}
						>
							{loading ? 'Connecting...' : 'Connect Device'}
						</button>
					</div>
				</form>
			</div>
		</div>
	</div>
{/if}
