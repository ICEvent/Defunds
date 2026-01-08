<script>
	import { createEventDispatcher } from 'svelte';
	import * as governanceAPI from '$lib/api/governance';

	export let governanceActor = null;
	export let backendActor = null;
	export let selectedGroupId = null;

	const dispatch = createEventDispatcher();

	let governanceGroups = [];
	let backendGroups = [];
	let unifiedGroups = [];
	let loading = false;
	let error = null;
	let showCreateForm = false;

	// Create group form
	let newGroup = {
		name: '',
		description: '',
		isPublic: true,
		createBackendGroup: true, // Whether to create native fund group
		createGovernanceGroup: true, // Whether to create governance group
	};

	$: if (governanceActor || backendActor) {
		loadAllGroups();
	}

	async function loadAllGroups() {
		if (!governanceActor && !backendActor) return;

		loading = true;
		error = null;
		try {
			// Load governance groups
			if (governanceActor) {
				governanceGroups = await governanceAPI.listGroups(governanceActor);
			}

			// Load backend groups
			if (backendActor) {
				try {
					backendGroups = await backendActor.getAllGroups();
				} catch (e) {
					console.warn('Backend groups not available:', e);
					backendGroups = [];
				}
			}

			// Merge and unify groups
			unifiedGroups = mergeGroups(governanceGroups, backendGroups);

			// Auto-select first group if none selected
			if (!selectedGroupId && unifiedGroups.length > 0) {
				selectGroup(unifiedGroups[0].governanceGroupId || unifiedGroups[0].backendGroupId, unifiedGroups[0].type);
			}
		} catch (e) {
			error = e.message;
			console.error('Error loading groups:', e);
		} finally {
			loading = false;
		}
	}

	function mergeGroups(govGroups, backGroups) {
		let merged = [];

		// Add governance groups
		govGroups.forEach((govGroup) => {
			let backendGroup = null;
			if (govGroup.backendGroupId && govGroup.backendGroupId.length > 0) {
				backendGroup = backGroups.find((bg) => bg.id === govGroup.backendGroupId[0]);
			}

			merged.push({
				type: backendGroup ? 'unified' : 'governance-only',
				governanceGroupId: govGroup.groupId,
				backendGroupId: backendGroup?.id || null,
				name: govGroup.name,
				description: govGroup.description,
				hasNativeFunds: !!backendGroup,
				hasGovernance: true,
				governanceGroup: govGroup,
				backendGroup: backendGroup,
			});
		});

		// Add backend-only groups (not linked to governance)
		backGroups.forEach((backGroup) => {
			const alreadyLinked = govGroups.some(
				(g) => g.backendGroupId && g.backendGroupId.length > 0 && g.backendGroupId[0] === backGroup.id
			);
			if (!alreadyLinked) {
				merged.push({
					type: 'backend-only',
					governanceGroupId: null,
					backendGroupId: backGroup.id,
					name: backGroup.name,
					description: backGroup.description,
					hasNativeFunds: true,
					hasGovernance: false,
					governanceGroup: null,
					backendGroup: backGroup,
				});
			}
		});

		return merged;
	}

	function selectGroup(groupId, type) {
		const group = unifiedGroups.find(
			(g) =>
				(type === 'governance' && g.governanceGroupId === groupId) ||
				(type === 'backend' && g.backendGroupId === groupId) ||
				g.governanceGroupId === groupId ||
				g.backendGroupId === groupId
		);
		if (group) {
			selectedGroupId = group.governanceGroupId || group.backendGroupId;
			dispatch('groupSelected', { 
				group,
				governanceGroupId: group.governanceGroupId,
				backendGroupId: group.backendGroupId
			});
		}
	}

	async function handleCreateGroup() {
		if (!newGroup.name) return;

		loading = true;
		error = null;
		try {
			let backendGroupId = null;
			let governanceGroupId = null;

			// Create backend group if requested
			if (newGroup.createBackendGroup && backendActor) {
				const backendResult = await backendActor.createGroup(
					newGroup.name,
					newGroup.description,
					newGroup.isPublic
				);
				if ('ok' in backendResult) {
					backendGroupId = backendResult.ok.id;
				} else {
					throw new Error(`Backend group creation failed: ${backendResult.err}`);
				}
			}

			// Create governance group if requested
			if (newGroup.createGovernanceGroup && governanceActor) {
				const govResult = await governanceAPI.createGroup(
					governanceActor,
					newGroup.name,
					newGroup.description,
					backendGroupId
				);
				if ('ok' in govResult) {
					governanceGroupId = govResult.ok;
				} else {
					throw new Error(`Governance group creation failed: ${govResult.err}`);
				}
			}

			showCreateForm = false;
			newGroup = {
				name: '',
				description: '',
				isPublic: true,
				createBackendGroup: true,
				createGovernanceGroup: true,
			};
			await loadAllGroups();
			if (governanceGroupId) {
				selectGroup(governanceGroupId, 'governance');
			} else if (backendGroupId) {
				selectGroup(backendGroupId, 'backend');
			}
		} catch (e) {
			error = e.message;
			console.error('Error creating group:', e);
		} finally {
			loading = false;
		}
	}

	async function linkGroups(governanceGroupId, backendGroupId) {
		if (!governanceActor) return;

		loading = true;
		try {
			const result = await governanceActor.linkBackendGroup(governanceGroupId, backendGroupId);
			if ('ok' in result) {
				await loadAllGroups();
			} else {
				error = result.err;
			}
		} catch (e) {
			error = e.message;
		} finally {
			loading = false;
		}
	}

	function getGroupIcon(type) {
		switch (type) {
			case 'unified':
				return '🔗'; // Linked
			case 'governance-only':
				return '⚖️'; // Governance only
			case 'backend-only':
				return '💰'; // Funds only
			default:
				return '📁';
		}
	}
</script>

<div class="unified-group-manager bg-white shadow-md rounded-lg p-4 mb-6">
	<div class="flex justify-between items-center mb-4">
		<div>
			<h3 class="text-lg font-semibold text-gray-800">Group Management</h3>
			<p class="text-xs text-gray-600">Manage both native funds and external assets</p>
		</div>
		<button
			class="text-sm bg-blue-500 hover:bg-blue-700 text-white font-bold py-1 px-3 rounded"
			on:click={() => (showCreateForm = !showCreateForm)}
		>
			{showCreateForm ? 'Cancel' : '+ New Group'}
		</button>
	</div>

	{#if error}
		<div class="bg-red-100 border-l-4 border-red-500 text-red-700 p-2 mb-4 text-sm" role="alert">
			<p>{error}</p>
		</div>
	{/if}

	{#if showCreateForm}
		<div class="bg-gray-50 p-4 rounded-lg mb-4 border">
			<h4 class="text-md font-semibold mb-3">Create New Group</h4>
			<form on:submit|preventDefault={handleCreateGroup}>
				<div class="mb-3">
					<label class="block text-gray-700 text-sm font-bold mb-1" for="groupName">
						Group Name
					</label>
					<input
						id="groupName"
						type="text"
						bind:value={newGroup.name}
						class="shadow appearance-none border rounded w-full py-2 px-3 text-gray-700 text-sm leading-tight focus:outline-none focus:shadow-outline"
						placeholder="e.g., Marketing Team"
						required
					/>
				</div>
				<div class="mb-3">
					<label class="block text-gray-700 text-sm font-bold mb-1" for="groupDescription">
						Description
					</label>
					<textarea
						id="groupDescription"
						bind:value={newGroup.description}
						class="shadow appearance-none border rounded w-full py-2 px-3 text-gray-700 text-sm leading-tight focus:outline-none focus:shadow-outline"
						rows="2"
						placeholder="Brief description of this group's purpose"
						required
					></textarea>
				</div>

				<div class="mb-3 space-y-2">
					<label class="block text-gray-700 text-sm font-bold mb-1">Group Features</label>
					<label class="flex items-center">
						<input
							type="checkbox"
							bind:checked={newGroup.createBackendGroup}
							class="mr-2"
							disabled={!backendActor}
						/>
						<span class="text-sm text-gray-700">
							💰 Native Funds Management {!backendActor ? '(Not available)' : ''}
						</span>
					</label>
					<label class="flex items-center">
						<input
							type="checkbox"
							bind:checked={newGroup.createGovernanceGroup}
							class="mr-2"
							disabled={!governanceActor}
						/>
						<span class="text-sm text-gray-700">
							⚖️ Governance & External Assets {!governanceActor ? '(Not available)' : ''}
						</span>
					</label>
					{#if newGroup.createBackendGroup}
						<label class="flex items-center ml-4">
							<input type="checkbox" bind:checked={newGroup.isPublic} class="mr-2" />
							<span class="text-xs text-gray-600">Make fund group public</span>
						</label>
					{/if}
				</div>

				<button
					type="submit"
					class="w-full bg-green-500 hover:bg-green-700 text-white font-bold py-2 px-4 rounded text-sm"
					disabled={loading}
				>
					{loading ? 'Creating...' : 'Create Group'}
				</button>
			</form>
		</div>
	{/if}

	{#if loading && !showCreateForm}
		<div class="text-center py-4">
			<div class="inline-block animate-spin rounded-full h-6 w-6 border-b-2 border-blue-600"></div>
		</div>
	{:else if unifiedGroups.length === 0}
		<div class="text-center py-4 text-gray-600">
			<p class="text-sm">No groups found. Create your first group!</p>
		</div>
	{:else}
		<div class="space-y-2 max-h-96 overflow-y-auto">
			{#each unifiedGroups as group}
				<button
					class="w-full text-left p-3 rounded-lg border transition-all {selectedGroupId === (group.governanceGroupId || group.backendGroupId)
						? 'border-blue-500 bg-blue-50'
						: 'border-gray-200 hover:border-blue-300 hover:bg-gray-50'}"
					on:click={() => selectGroup(group.governanceGroupId || group.backendGroupId, group.type)}
				>
					<div class="flex justify-between items-start">
						<div class="flex-1">
							<div class="flex items-center gap-2">
								<span class="text-lg">{getGroupIcon(group.type)}</span>
								<h4 class="font-semibold text-gray-800">{group.name}</h4>
							</div>
							<p class="text-xs text-gray-600 mt-1">{group.description}</p>
							<div class="flex gap-2 mt-2">
								{#if group.hasNativeFunds}
									<span class="text-xs bg-green-100 text-green-700 px-2 py-1 rounded">
										💰 Funds
									</span>
								{/if}
								{#if group.hasGovernance}
									<span class="text-xs bg-blue-100 text-blue-700 px-2 py-1 rounded">
										⚖️ Governance
									</span>
								{/if}
							</div>
						</div>
						{#if selectedGroupId === (group.governanceGroupId || group.backendGroupId)}
							<span class="ml-2 text-blue-500">
								<svg class="w-5 h-5" fill="currentColor" viewBox="0 0 20 20">
									<path
										fill-rule="evenodd"
										d="M10 18a8 8 0 100-16 8 8 0 000 16zm3.707-9.293a1 1 0 00-1.414-1.414L9 10.586 7.707 9.293a1 1 0 00-1.414 1.414l2 2a1 1 0 001.414 0l4-4z"
										clip-rule="evenodd"
									/>
								</svg>
							</span>
						{/if}
					</div>
					<div class="text-xs text-gray-500 mt-1">
						{#if group.governanceGroupId}
							Gov ID: {group.governanceGroupId}
						{/if}
						{#if group.backendGroupId}
							{group.governanceGroupId ? ' | ' : ''}Fund ID: {group.backendGroupId}
						{/if}
					</div>
				</button>
			{/each}
		</div>
	{/if}
</div>
