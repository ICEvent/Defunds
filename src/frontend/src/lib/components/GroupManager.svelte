<script>
	import { createEventDispatcher } from 'svelte';
	import * as governanceAPI from '$lib/api/governance';

	export let governanceActor;

	const dispatch = createEventDispatcher();

	let groups = [];
	let selectedGroup = null;

	// Create group form
	let showCreateForm = false;
	let groupName = '';
	let groupDescription = '';
	let creating = false;
	let error = '';

	$: if (governanceActor) {
		loadGroups();
	}

	async function loadGroups() {
		if (!governanceActor) return;
		try {
			groups = await governanceAPI.listGroups(governanceActor);
		} catch (e) {
			console.error('Error loading groups:', e);
		}
	}

	async function handleCreateGroup() {
		if (!groupName.trim()) {
			error = 'Group name is required';
			return;
		}

		creating = true;
		error = '';

		try {
			const result = await governanceAPI.createGroup(
				governanceActor,
				groupName,
				groupDescription
			);

			if (result.ok !== undefined) {
				// Success
				groupName = '';
				groupDescription = '';
				showCreateForm = false;
				await loadGroups();
				dispatch('groupCreated', { groupId: result.ok });
			} else if (result.err) {
				error = result.err;
			}
		} catch (e) {
			error = e.message || 'Failed to create group';
		} finally {
			creating = false;
		}
	}

	function selectGroup(group) {
		selectedGroup = group;
		dispatch('groupSelected', { group, groupId: group.groupId });
	}
</script>

<div class="group-manager mb-6 bg-white shadow-lg rounded-lg p-6">
	<!-- Create Group Button -->
	<div class="mb-4 flex justify-between items-center">
		<h2 class="text-xl font-semibold text-gray-800">Groups</h2>
		<button
			on:click={() => (showCreateForm = !showCreateForm)}
			class="px-4 py-2 bg-blue-600 text-white rounded-lg hover:bg-blue-700 transition-colors text-sm"
		>
			{showCreateForm ? 'Hide Form' : '+ Create New Group'}
		</button>
	</div>

	<!-- Create Group Form -->
	{#if showCreateForm}
		<div class="mb-6 p-4 bg-gray-50 rounded-lg border border-gray-200">
			<h3 class="text-lg font-semibold mb-3">Create New Group</h3>

			<div class="space-y-3">
				<div>
					<label for="group-name" class="block text-sm font-medium text-gray-700 mb-1"
						>Group Name <span class="text-red-500">*</span></label
					>
					<input
						id="group-name"
						type="text"
						bind:value={groupName}
						placeholder="Enter group name"
						class="w-full px-3 py-2 border border-gray-300 rounded-lg focus:ring-2 focus:ring-blue-500 focus:border-transparent"
					/>
				</div>

				<div>
					<label for="group-desc" class="block text-sm font-medium text-gray-700 mb-1"
						>Description</label
					>
					<textarea
						id="group-desc"
						bind:value={groupDescription}
						placeholder="Enter group description"
						rows="3"
						class="w-full px-3 py-2 border border-gray-300 rounded-lg focus:ring-2 focus:ring-blue-500 focus:border-transparent"
					/>
				</div>

				{#if error}
					<div class="p-3 bg-red-50 border border-red-200 rounded-lg text-red-700 text-sm">
						{error}
					</div>
				{/if}

				<div class="flex gap-2">
					<button
						on:click={handleCreateGroup}
						disabled={creating}
						class="px-4 py-2 bg-green-600 text-white rounded-lg hover:bg-green-700 disabled:bg-gray-400 transition-colors"
					>
						{creating ? 'Creating...' : 'Create Group'}
					</button>
					<button
						on:click={() => {
							showCreateForm = false;
							error = '';
						}}
						class="px-4 py-2 bg-gray-200 text-gray-700 rounded-lg hover:bg-gray-300 transition-colors"
					>
						Cancel
					</button>
				</div>
			</div>
		</div>
	{/if}

	<!-- Groups List -->
	<div class="space-y-2">
		<h3 class="text-base font-semibold mb-3 text-gray-700">
			Your Groups ({groups.length})
		</h3>
		{#if groups.length === 0}
			<p class="text-gray-500 text-sm py-4 text-center">
				No groups yet. Create one to get started!
			</p>
		{:else}
			<div class="grid gap-3">
				{#each groups as group}
					<button
						on:click={() => selectGroup(group)}
						class="w-full text-left p-4 rounded-lg border transition-all {selectedGroup?.groupId ===
						group.groupId
							? 'bg-blue-50 border-blue-500 shadow-md'
							: 'bg-white border-gray-200 hover:border-blue-300 hover:shadow'}"
					>
						<div class="flex justify-between items-start">
							<div class="flex-1">
								<h4 class="font-semibold text-gray-900">{group.name}</h4>
								{#if group.description}
									<p class="text-sm text-gray-600 mt-1">{group.description}</p>
								{/if}
							</div>
							{#if selectedGroup?.groupId === group.groupId}
								<span
									class="ml-3 px-2 py-1 text-xs bg-blue-600 text-white rounded-full font-medium"
									>Selected</span
								>
							{/if}
						</div>
					</button>
				{/each}
			</div>
		{/if}
	</div>
</div>

<style>
	.group-manager {
		max-width: 100%;
	}
</style>
