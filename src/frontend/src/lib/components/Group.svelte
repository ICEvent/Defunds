<script>
  import { onMount } from "svelte";
  import { showNotification } from "$lib/stores/notification";
  import { hideProgress, showProgress } from "$lib/stores/progress";
  import { page } from "$app/stores";

  let groupId = null;
  let group = null;
  let members = [];
  let backend;
  let isAuthed = false;
  let principal;

  let groupName = "";
  let groupDescription = "";
  let isPublic = false;

  let newMemberName = "";
  let newMemberPrincipal = "";
  let newMemberVotingPower = 1;

  onMount(async () => {
    // Get groupId from route or props
    groupId = $page.params.id ? parseInt($page.params.id) : null;
    // Subscribe to global store for backend and principal
    const { globalStore } = await import('$lib/store');
    globalStore.subscribe(store => {
      backend = store.backend;
      principal = store.principal;
      isAuthed = store.isAuthed;
    });
    if (backend && groupId !== null) {
      await loadGroup();
    }
  });

  async function loadGroup() {
    showProgress();
    try {
      const result = await backend.getGroup(groupId);
      if (result.ok) {
        group = result.ok;
        groupName = group.name;
        groupDescription = group.description;
        isPublic = group.isPublic;
        members = group.members;
      } else {
        showNotification(result.err, "error");
      }
    } catch (e) {
      showNotification("Error loading group: " + e.message, "error");
    } finally {
      hideProgress();
    }
  }

  async function updateGroup() {
    showProgress();
    try {
      const result = await backend.updateGroup(groupId, groupName, groupDescription, isPublic);
      if (result.ok) {
        showNotification("Group updated!", "success");
        await loadGroup();
      } else {
        showNotification(result.err, "error");
      }
    } catch (e) {
      showNotification("Error updating group: " + e.message, "error");
    } finally {
      hideProgress();
    }
  }

  async function addMember() {
    showProgress();
    try {
      const principalObj = backend.parsePrincipal(newMemberPrincipal);
      const result = await backend.addGroupMember(groupId, newMemberName, principalObj, newMemberVotingPower);
      if (result.ok) {
        showNotification("Member added!", "success");
        newMemberName = "";
        newMemberPrincipal = "";
        newMemberVotingPower = 1;
        await loadGroup();
      } else {
        showNotification(result.err, "error");
      }
    } catch (e) {
      showNotification("Error adding member: " + e.message, "error");
    } finally {
      hideProgress();
    }
  }

  async function removeMember(principal) {
    showProgress();
    try {
      const result = await backend.removeGroupMember(groupId, principal);
      if (result.ok) {
        showNotification("Member removed!", "success");
        await loadGroup();
      } else {
        showNotification(result.err, "error");
      }
    } catch (e) {
      showNotification("Error removing member: " + e.message, "error");
    } finally {
      hideProgress();
    }
  }

  async function updateMemberVotingPower(principal, votingPower) {
    showProgress();
    try {
      const result = await backend.updateGroupMemberVotingPower(groupId, principal, votingPower);
      if (result.ok) {
        showNotification("Voting power updated!", "success");
        await loadGroup();
      } else {
        showNotification(result.err, "error");
      }
    } catch (e) {
      showNotification("Error updating voting power: " + e.message, "error");
    } finally {
      hideProgress();
    }
  }

  async function updateMemberName(principal, name) {
    showProgress();
    try {
      const result = await backend.updateGroupMemberName(groupId, principal, name);
      if (result.ok) {
        showNotification("Member name updated!", "success");
        await loadGroup();
      } else {
        showNotification(result.err, "error");
      }
    } catch (e) {
      showNotification("Error updating member name: " + e.message, "error");
    } finally {
      hideProgress();
    }
  }
</script>

<div class="group-management-section p-6 bg-white rounded shadow">
  <h2 class="text-xl font-bold mb-4">💰 Fund Group Management</h2>
  <div class="mb-6">
    <label class="block mb-2 font-semibold">Group Name</label>
    <input type="text" bind:value={groupName} class="input mb-2" />
    <label class="block mb-2 font-semibold">Description</label>
    <textarea bind:value={groupDescription} class="input mb-2" rows="2"></textarea>
    <label class="flex items-center mb-2">
      <input type="checkbox" bind:checked={isPublic} /> Public
    </label>
    <button on:click={updateGroup} class="btn">Update Group</button>
  </div>

  <h3 class="text-lg font-semibold mb-4">Member Management</h3>
  <div class="mb-4 flex gap-2 items-end">
    <input type="text" bind:value={newMemberName} placeholder="Member Name" class="input" />
    <input type="text" bind:value={newMemberPrincipal} placeholder="Principal" class="input" />
    <input type="number" bind:value={newMemberVotingPower} min="1" class="input w-24" />
    <button on:click={addMember} class="btn">Add Member</button>
  </div>
  <div class="members-list">
    {#each members as member}
      <div class="member-item flex items-center justify-between mb-2 p-2 border rounded">
        <div>
          <span class="font-semibold">{member.name}</span>
          <span class="ml-2 text-xs text-gray-500">{member.principal.toText()}</span>
          <span class="ml-2 text-xs text-blue-600">Voting Power: {member.votingPower}</span>
        </div>
        <div class="flex gap-2">
          <input type="text" value={member.name} on:change={e => updateMemberName(member.principal, e.target.value)} class="input w-24" />
          <input type="number" value={member.votingPower} min="1" on:change={e => updateMemberVotingPower(member.principal, Number(e.target.value))} class="input w-16" />
          <button on:click={() => removeMember(member.principal)} class="btn btn-red">Remove</button>
        </div>
      </div>
    {/each}
  </div>
</div>

<style>
  .group-management-section { max-width: 600px; margin: 2rem auto; }
  .input { width: 100%; padding: 0.5rem; border: 1px solid #ccc; border-radius: 4px; }
  .btn { padding: 0.5rem 1rem; background: #007bff; color: #fff; border: none; border-radius: 4px; cursor: pointer; margin-right: 0.5rem; }
  .btn-red { background: #ef4444; }
  .members-list { margin-top: 1rem; }
  .member-item { background: #f9f9f9; }
</style>
