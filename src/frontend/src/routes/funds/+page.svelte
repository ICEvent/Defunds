<script>
  import { onMount } from "svelte";
  import { showNotification } from "$lib/stores/notification";
  import { hideProgress, showProgress } from "$lib/stores/progress";
  import { goto } from "$app/navigation";

  let publicGroups = [];
  let myGroups = [];
  let backend;
  let isAuthed = false;
  let principal;

  // Create group form
  let showCreateForm = false;
  let groupName = "";
  let groupDescription = "";
  let isPublic = true;

  onMount(async () => {
    const { globalStore } = await import('$lib/store');
    globalStore.subscribe(store => {
      backend = store.backend;
      principal = store.principal;
      isAuthed = store.isAuthed;
    });
    if (backend) {
      await loadGroups();
    }
  });

  async function loadGroups() {
    showProgress();
    try {
      const publicResult = await backend.getPublicGroups();
      publicGroups = publicResult || [];

      if (isAuthed) {
        const myResult = await backend.getMyGroups();
        myGroups = myResult || [];
      }
    } catch (e) {
      showNotification("Error loading groups: " + e.message, "error");
    } finally {
      hideProgress();
    }
  }

  async function createGroup() {
    if (!groupName || !groupDescription) {
      showNotification("Please fill in all fields", "error");
      return;
    }
    
    showProgress();
    try {
      const result = await backend.createGroup(groupName, groupDescription, isPublic);
      if (result.ok) {
        showNotification("Group created successfully!", "success");
        groupName = "";
        groupDescription = "";
        showCreateForm = false;
        await loadGroups();
      } else {
        showNotification(result.err, "error");
      }
    } catch (e) {
      showNotification("Error creating group: " + e.message, "error");
    } finally {
      hideProgress();
    }
  }

  async function joinGroup(groupId) {
    showProgress();
    try {
      const result = await backend.joinGroup(groupId);
      if (result.ok) {
        showNotification("Joined group successfully!", "success");
        await loadGroups();
      } else {
        showNotification(result.err, "error");
      }
    } catch (e) {
      showNotification("Error joining group: " + e.message, "error");
    } finally {
      hideProgress();
    }
  }

  function viewGroup(groupId) {
    goto(`/funds/${groupId}`);
  }

  function formatDate(timestamp) {
    return new Date(Number(timestamp) / 1000000).toLocaleDateString();
  }

  function formatAccount(account) {
    if (!account || account.length === 0) return "N/A";
    return account.slice(0, 8).map(b => b.toString(16).padStart(2, '0')).join('') + "...";
  }

</script>

<div class="max-w-6xl mx-auto p-8">
  <div class="flex justify-between items-center mb-6">
    <h1 class="text-3xl font-bold">Group Funds</h1>
    {#if isAuthed}
      <button on:click={() => showCreateForm = !showCreateForm} class="btn btn-primary">
        {showCreateForm ? "Cancel" : "Create Group"}
      </button>
    {/if}
  </div>

  {#if showCreateForm}
    <div class="create-form bg-white rounded-lg shadow-md p-6 mb-6">
      <h2 class="text-xl font-semibold mb-4">Create New Group</h2>
      <div class="mb-4">
        <label class="block mb-2 font-medium">Group Name</label>
        <input type="text" bind:value={groupName} class="input" placeholder="Enter group name" />
      </div>
      <div class="mb-4">
        <label class="block mb-2 font-medium">Description</label>
        <textarea bind:value={groupDescription} class="input" rows="3" placeholder="Describe your group's purpose"></textarea>
      </div>
      <div class="mb-4">
        <label class="flex items-center">
          <input type="checkbox" bind:checked={isPublic} class="mr-2" />
          <span>Public (anyone can join)</span>
        </label>
      </div>
      <div class="flex gap-2">
        <button on:click={createGroup} class="btn btn-primary">Create</button>
        <button on:click={() => showCreateForm = false} class="btn btn-secondary">Cancel</button>
      </div>
    </div>
  {/if}

  {#if isAuthed && myGroups.length > 0}
    <section class="mb-8">
      <h2 class="text-2xl font-semibold mb-4">My Groups</h2>
      <div class="grid grid-cols-1 md:grid-cols-2 lg:grid-cols-3 gap-4">
        {#each myGroups as group}
          <div class="group-card bg-white rounded-lg shadow-md p-6 hover:shadow-lg transition-shadow cursor-pointer" on:click={() => viewGroup(group.id)}>
            <div class="flex items-start justify-between mb-2">
              <h3 class="text-lg font-semibold">{group.name}</h3>
              <span class="text-xs px-2 py-1 rounded {group.isPublic ? 'bg-green-100 text-green-800' : 'bg-gray-100 text-gray-800'}">
                {group.isPublic ? 'Public' : 'Private'}
              </span>
            </div>
            <p class="text-sm text-gray-600 mb-3">{group.description}</p>
            <div class="text-xs text-gray-500 space-y-1">
              <div>Members: {group.members.length}</div>
              <div>Balance: {group.balance}</div>
              <div>Account: {formatAccount(group.account)}</div>
              <div>Created: {formatDate(group.createdAt)}</div>
            </div>
          </div>
        {/each}
      </div>
    </section>
  {/if}

  <section>
    <h2 class="text-2xl font-semibold mb-4">Public Groups</h2>
    {#if publicGroups.length === 0}
      <div class="text-gray-500 text-center py-8">No public groups available</div>
    {:else}
      <div class="grid grid-cols-1 md:grid-cols-2 lg:grid-cols-3 gap-4">
        {#each publicGroups as group}
          <div class="group-card bg-white rounded-lg shadow-md p-6 hover:shadow-lg transition-shadow">
            <div class="flex items-start justify-between mb-2">
              <h3 class="text-lg font-semibold">{group.name}</h3>
              <span class="text-xs px-2 py-1 rounded bg-green-100 text-green-800">Public</span>
            </div>
            <p class="text-sm text-gray-600 mb-3">{group.description}</p>
            <div class="text-xs text-gray-500 space-y-1 mb-4">
              <div>Members: {group.members.length}</div>
              <div>Balance: {group.balance}</div>
              <div>Account: {formatAccount(group.account)}</div>
              <div>Created: {formatDate(group.createdAt)}</div>
            </div>
            <div class="flex gap-2">
              <button on:click={() => viewGroup(group.id)} class="btn btn-sm btn-primary flex-1">View</button>
              {#if isAuthed}
                <button on:click={(e) => {e.stopPropagation(); joinGroup(group.id)}} class="btn btn-sm btn-secondary flex-1">Join</button>
              {/if}
            </div>
          </div>
        {/each}
      </div>
    {/if}
  </section>
</div>

<style>
  .input {
    width: 100%;
    padding: 0.5rem;
    border: 1px solid #d1d5db;
    border-radius: 0.375rem;
    font-size: 0.875rem;
  }
  .input:focus {
    outline: none;
    border-color: #3b82f6;
    ring: 2px;
    ring-color: #3b82f6;
  }
  .btn {
    padding: 0.5rem 1rem;
    border-radius: 0.375rem;
    font-weight: 500;
    cursor: pointer;
    transition: all 0.2s;
    border: none;
  }
  .btn-primary {
    background-color: #3b82f6;
    color: white;
  }
  .btn-primary:hover {
    background-color: #2563eb;
  }
  .btn-secondary {
    background-color: #6b7280;
    color: white;
  }
  .btn-secondary:hover {
    background-color: #4b5563;
  }
  .btn-sm {
    padding: 0.375rem 0.75rem;
    font-size: 0.875rem;
  }
  .group-card {
    border: 1px solid #e5e7eb;
  }
</style>
