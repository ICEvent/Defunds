<script>
    import { onMount } from "svelte";
    import { globalStore } from "$lib/store";
    import { showProgress, hideProgress } from "$lib/stores/progress";
    import { showNotification } from "$lib/stores/notification";
    import GroupManagement from "$lib/components/Group/Group.svelte";

let groups = [];
let groupName = "";
let groupDescription = "";
let isPublic = false;
let backend;

let showGroupModal = false;
let selectedGroupId = null;

    onMount(async () => {
        const unsubscribe = globalStore.subscribe((store) => {
            backend = store.backend;
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
                    showNotification("Group created successfully!", "success");
                    groupName = "";
                    groupDescription = "";
                    isPublic = false;
                    loadGroups();
                } else {
                    showNotification(result.err || "Failed to create group.", "error");
                }
            } catch (error) {
                showNotification(error.message || "Failed to create group.", "error");
            } finally {
                hideProgress();
            }
        }else {
            showNotification("Backend or group name is not available.", "error");
        }
    }
</script>

<div class="group-panel mt-8">
    <div class="bg-white rounded-lg p-6 shadow-sm mb-6">
        <h3 class="text-xl font-semibold mb-4">Create New Group</h3>
        <div class="space-y-4">
            <input
                type="text"
                bind:value={groupName}
                placeholder="Group Name"
                class="w-full px-4 py-2 border rounded-lg"
            />
            <textarea
                bind:value={groupDescription}
                placeholder="Group Description"
                class="w-full px-4 py-2 border rounded-lg"
                rows="3"
            ></textarea>
            <div class="flex items-center space-x-2">
                <input
                    type="checkbox"
                    id="isPublic"
                    bind:checked={isPublic}
                    class="rounded border-gray-300"
                />
                <label for="isPublic" class="text-gray-700">Make this group public</label>
            </div>
            <button
                on:click={createGroup}
                class="w-full bg-blue-600 text-white px-6 py-2 rounded-lg hover:bg-blue-700 transition-colors"
            >
                Create Group
            </button>
        </div>
    </div>

    <div class="bg-white rounded-lg p-6 shadow-sm">
        <h3 class="text-xl font-semibold mb-4">My Groups</h3>
        <div class="space-y-4">
            {#each groups as group}
                <div class="p-4 bg-gray-50 rounded-lg">
                    <h4 class="text-lg font-semibold">{group.name}</h4>
                    <p class="text-gray-600 mt-2">{group.description}</p>
                    <div class="flex justify-between items-center mt-4">
                        <span class="text-sm text-gray-500">
                            Members: {group.memberCount}
                        </span>
                        <button
                            class="px-4 py-2 bg-blue-500 text-white rounded-lg hover:bg-blue-600 transition-colors"
                            on:click={() => { selectedGroupId = group.id; showGroupModal = true; }}
                        >
                            Manage
                        </button>
                    </div>
                </div>
            {/each}
        </div>
    </div>
    {#if showGroupModal}
        <div class="fixed inset-0 bg-black bg-opacity-40 flex items-center justify-center z-50">
            <div class="bg-white rounded-lg shadow-lg p-6 max-w-2xl w-full relative">
                <button class="absolute top-2 right-2 text-gray-500 hover:text-gray-700" on:click={() => { showGroupModal = false; selectedGroupId = null; }}>&times;</button>
                <GroupManagement groupId={selectedGroupId} />
            </div>
        </div>
    {/if}
</div>
