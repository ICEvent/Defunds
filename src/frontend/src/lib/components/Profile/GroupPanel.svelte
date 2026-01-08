<script>
    import { onMount } from "svelte";
    import { globalStore } from "$lib/store";
    import { showProgress, hideProgress } from "$lib/stores/progress";
    import { showNotification } from "$lib/stores/notification";
    import GroupManagement from "$lib/components/Group/Group.svelte";

let groups = [];
let backend;
let governanceActor;

let showGroupModal = false;
let selectedGroupId = null;
let showCreateForm = false;
let groupName = '';
let groupDescription = '';
let isPublic = false;

    onMount(async () => {
        const unsubscribe = globalStore.subscribe((store) => {
            backend = store.backend;
            governanceActor = store.governance;
        });
        loadGroups();
        return () => unsubscribe();
    });

    async function loadGroups() {
        if (backend) {
            groups = await backend.getMyGroups();
        }
    }

    async function createGroup() {
        if (backend && groupName) {
            showProgress();
            try {
                const result = await backend.createGroup(groupName, groupDescription, isPublic);
                if (result.ok) {
                    showNotification("Fund group created successfully!", "success");
                    groupName = "";
                    groupDescription = "";
                    isPublic = false;
                    showCreateForm = false;
                    loadGroups();
                } else {
                    showNotification(result.err || "Failed to create group.", "error");
                }
            } catch (error) {
                showNotification(error.message || "Failed to create group.", "error");
            } finally {
                hideProgress();
            }
        } else {
            showNotification("Backend or group name is not available.", "error");
        }
    }
</script>

<div class="group-panel mt-8">
    <div class="bg-white rounded-lg p-6 shadow-sm mb-6">
        <div class="flex justify-between items-center mb-4">
            <div>
                <h3 class="text-xl font-semibold">💰 Backend Fund Groups</h3>
                <p class="text-sm text-gray-600 mt-1">Manage native ICP/ICRC token funds</p>
            </div>
            <button
                on:click={() => showCreateForm = !showCreateForm}
                class="bg-blue-600 text-white px-4 py-2 rounded-lg hover:bg-blue-700 transition-colors text-sm"
            >
                {showCreateForm ? 'Hide' : '+ Create Fund Group'}
            </button>
        </div>

        {#if showCreateForm}
            <div class="bg-gray-50 p-4 rounded-lg border border-gray-200 mb-4">
                <h4 class="text-lg font-semibold mb-3">Create Backend Fund Group</h4>
                <div class="space-y-3">
                    <div>
                        <label for="fund-name" class="block text-sm font-medium text-gray-700 mb-1">
                            Group Name <span class="text-red-500">*</span>
                        </label>
                        <input
                            id="fund-name"
                            type="text"
                            bind:value={groupName}
                            placeholder="Enter fund group name"
                            class="w-full px-3 py-2 border border-gray-300 rounded-lg focus:ring-2 focus:ring-blue-500"
                        />
                    </div>
                    <div>
                        <label for="fund-desc" class="block text-sm font-medium text-gray-700 mb-1">
                            Description
                        </label>
                        <textarea
                            id="fund-desc"
                            bind:value={groupDescription}
                            placeholder="Enter description"
                            rows="3"
                            class="w-full px-3 py-2 border border-gray-300 rounded-lg focus:ring-2 focus:ring-blue-500"
                        />
                    </div>
                    <div class="flex items-center">
                        <input
                            id="fund-public"
                            type="checkbox"
                            bind:checked={isPublic}
                            class="rounded border-gray-300 mr-2"
                        />
                        <label for="fund-public" class="text-sm text-gray-700">Make this group public</label>
                    </div>
                    <div class="flex gap-2">
                        <button
                            on:click={createGroup}
                            class="px-4 py-2 bg-green-600 text-white rounded-lg hover:bg-green-700 transition-colors"
                        >
                            Create Fund Group
                        </button>
                        <button
                            on:click={() => showCreateForm = false}
                            class="px-4 py-2 bg-gray-200 text-gray-700 rounded-lg hover:bg-gray-300 transition-colors"
                        >
                            Cancel
                        </button>
                    </div>
                </div>
            </div>
        {/if}

        <div class="bg-blue-50 border border-blue-200 rounded-lg p-3 text-sm text-blue-800">
            <p><strong>Note:</strong> Backend fund groups manage native ICP/ICRC tokens directly.</p>
            <p class="mt-1">For governance and voting on external assets, use the <a href="/governance" class="underline font-semibold">Governance</a> section.</p>
        </div>
    </div>

    <div class="bg-white rounded-lg p-6 shadow-sm">
        <h3 class="text-xl font-semibold mb-4">My Fund Groups ({groups.length})</h3>
        <div class="space-y-4">
            {#if groups.length === 0}
                <p class="text-gray-500 text-center py-8">No fund groups yet. Create one to get started!</p>
            {:else}
                {#each groups as group}
                    <div class="p-4 bg-gray-50 rounded-lg border border-gray-200 hover:border-blue-300 transition-colors">
                        <div class="flex items-start justify-between">
                            <div class="flex-1">
                                <h4 class="text-lg font-semibold">💰 {group.name}</h4>
                                <p class="text-gray-600 mt-1 text-sm">{group.description}</p>
                                <div class="flex gap-4 mt-3 text-sm text-gray-600">
                                    <span>Members: {group.memberCount}</span>
                                    <span>Balance: {group.balance}</span>
                                    <span class="px-2 py-0.5 bg-gray-200 rounded text-xs">
                                        {group.isPublic ? 'Public' : 'Private'}
                                    </span>
                                </div>
                            </div>
                            <button
                                class="ml-4 px-4 py-2 bg-blue-500 text-white rounded-lg hover:bg-blue-600 transition-colors text-sm"
                                on:click={() => { selectedGroupId = group.id; showGroupModal = true; }}
                            >
                                Manage
                            </button>
                        </div>
                    </div>
                {/each}
            {/if}
        </div>
    </div>
    {#if showGroupModal}
        <div class="fixed inset-0 bg-black bg-opacity-40 flex items-center justify-center z-50">
            <div class="bg-white rounded-lg shadow-lg p-6 max-w-2xl w-full relative">
                <button class="absolute top-2 right-2 text-gray-500 hover:text-gray-700 text-2xl" on:click={() => { showGroupModal = false; selectedGroupId = null; }}>&times;</button>
                <GroupManagement groupId={selectedGroupId} />
            </div>
        </div>
    {/if}
</div>
