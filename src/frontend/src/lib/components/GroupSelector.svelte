<script>
	import { createEventDispatcher } from 'svelte';
	import * as governanceAPI from '$lib/api/governance';

	export let governanceActor = null;
	export let selectedGroupId = null;
	export let showCreateForm = false;

	const dispatch = createEventDispatcher();

	let groups = [];
	let loading = false;
	let error = null;

	// Create group form
	let newGroup = {
		name: '',
		description: ''
	};

	$: if (governanceActor) {
		loadGroups();
	}

	async function loadGroups() {
		if (!governanceActor) return;
		
		loading = true;
		error = null;
		try {
			groups = await governanceAPI.listGroups(governanceActor);
			
			// Auto-select first group if none selected
			if (!selectedGroupId && groups.length > 0) {
				selectGroup(groups[0].groupId);
			}
		} catch (e) {
			error = e.message;
			console.error('Error loading groups:', e);
		} finally {
			loading = false;
		}
	}

	function selectGroup(groupId) {
		selectedGroupId = groupId;
		dispatch('groupSelected', { groupId });
	}

	async function handleCreateGroup() {
		if (!governanceActor || !newGroup.name) return;

		loading = true;
		error = null;
		try {
			const result = await governanceAPI.createGroup(
				governanceActor,
				newGroup.name,
				newGroup.description
			);

			if ('ok' in result) {
				showCreateForm = false;
				newGroup = { name: '', description: '' };
				await loadGroups();
				selectGroup(result.ok);
			} else {
				error = result.err;
			}
		} catch (e) {
			error = e.message;
			console.error('Error creating group:', e);
		} finally {
			loading = false;
		}
	}

	function getSelectedGroup() {
		return groups.find(g => g.groupId === selectedGroupId);
	}
</script>

<div class="group-selector bg-white shadow-md rounded-lg p-4 mb-6">
	<div class="flex justify-between items-center mb-4">
		<h3 class="text-lg font-semibold text-gray-800">Select Group</h3>
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
	{:else if groups.length === 0}
		<div class="text-center py-4 text-gray-600">
			<p class="text-sm">No groups found. Create your first group!</p>
		</div>
	{:else}
		<div class="space-y-2">
			{#each groups as group}
				<button
					class="w-full text-left p-3 rounded-lg border transition-all {selectedGroupId === group.groupId
						? 'border-blue-500 bg-blue-50'
						: 'border-gray-200 hover:border-blue-300 hover:bg-gray-50'}"
					on:click={() => selectGroup(group.groupId)}
				>
					<div class="flex justify-between items-start">
						<div class="flex-1">
							<h4 class="font-semibold text-gray-800">{group.name}</h4>
							<p class="text-xs text-gray-600 mt-1">{group.description}</p>
						</div>
						{#if selectedGroupId === group.groupId}
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
						ID: {group.groupId}
					</div>
				</button>
			{/each}
		</div>
	{/if}
</div>

<style>
	.group-selector {
		max-height: 400px;
		overflow-y: auto;
	}
</style>
