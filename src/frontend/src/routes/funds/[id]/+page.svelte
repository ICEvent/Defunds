<script>
  import { onMount } from "svelte";
  import { page } from "$app/stores";
  import { showNotification } from "$lib/stores/notification";
  import { hideProgress, showProgress } from "$lib/stores/progress";
  import { goto } from "$app/navigation";
  import { Principal } from "@dfinity/principal";

  let groupId;
  let group = null;
  let proposals = [];
  let backend;
  let isAuthed = false;
  let principal;
  let isMember = false;
  let isCreator = false;

  // Member management
  let showAddMember = false;
  let newMemberName = "";
  let newMemberPrincipal = "";
  let newMemberVotingPower = 1;

  // Proposal creation
  let showCreateProposal = false;
  let proposalTitle = "";
  let proposalDescription = "";
  let proposalRecipient = "";
  let proposalAmount = 0;

  onMount(async () => {
    groupId = parseInt($page.params.id);
    const { globalStore } = await import('$lib/store');
    globalStore.subscribe(store => {
      backend = store.backend;
      principal = store.principal;
      isAuthed = store.isAuthed;
    });
    if (backend && groupId) {
      await loadGroupData();
    }
  });

  async function loadGroupData() {
    showProgress();
    try {
      const groupResult = await backend.getGroup(groupId);
      if (groupResult) {
        group = groupResult;
        isMember = group.members.some(m => m.principal.toText() === principal?.toText());
        isCreator = group.creator.toText() === principal?.toText();
      } else {
        showNotification("Group not found", "error");
        goto("/funds");
      }

      const proposalsResult = await backend.getGroupProposals(groupId);
      proposals = proposalsResult || [];
    } catch (e) {
      showNotification("Error loading group: " + e.message, "error");
    } finally {
      hideProgress();
    }
  }

  async function addMember() {
    if (!newMemberName || !newMemberPrincipal) {
      showNotification("Please fill in all fields", "error");
      return;
    }

    showProgress();
    try {
      const principalObj = Principal.fromText(newMemberPrincipal);
      const result = await backend.addGroupMember(groupId, newMemberName, principalObj, newMemberVotingPower);
      if (result.ok !== undefined) {
        showNotification("Member added successfully!", "success");
        newMemberName = "";
        newMemberPrincipal = "";
        newMemberVotingPower = 1;
        showAddMember = false;
        await loadGroupData();
      } else {
        showNotification(result.err, "error");
      }
    } catch (e) {
      showNotification("Error adding member: " + e.message, "error");
    } finally {
      hideProgress();
    }
  }

  async function removeMember(memberPrincipal) {
    showProgress();
    try {
      const result = await backend.removeGroupMember(groupId, memberPrincipal);
      if (result.ok !== undefined) {
        showNotification("Member removed!", "success");
        await loadGroupData();
      } else {
        showNotification(result.err, "error");
      }
    } catch (e) {
      showNotification("Error removing member: " + e.message, "error");
    } finally {
      hideProgress();
    }
  }

  async function createProposal() {
    if (!proposalTitle || !proposalDescription || !proposalRecipient || proposalAmount <= 0) {
      showNotification("Please fill in all fields correctly", "error");
      return;
    }

    showProgress();
    try {
      const recipientPrincipal = Principal.fromText(proposalRecipient);
      const result = await backend.createGroupProposal(
        groupId,
        proposalTitle,
        proposalDescription,
        recipientPrincipal,
        proposalAmount
      );
      if (result.ok) {
        showNotification("Proposal created successfully!", "success");
        proposalTitle = "";
        proposalDescription = "";
        proposalRecipient = "";
        proposalAmount = 0;
        showCreateProposal = false;
        await loadGroupData();
      } else {
        showNotification(result.err, "error");
      }
    } catch (e) {
      showNotification("Error creating proposal: " + e.message, "error");
    } finally {
      hideProgress();
    }
  }

  async function voteOnProposal(proposalId, voteYes) {
    showProgress();
    try {
      const result = await backend.voteOnProposal(groupId, proposalId, voteYes);
      if (result.ok !== undefined) {
        showNotification("Vote recorded!", "success");
        await loadGroupData();
      } else {
        showNotification(result.err, "error");
      }
    } catch (e) {
      showNotification("Error voting: " + e.message, "error");
    } finally {
      hideProgress();
    }
  }

  function formatDate(timestamp) {
    return new Date(Number(timestamp) / 1000000).toLocaleString();
  }

  function formatAccount(account) {
    if (!account || account.length === 0) return "N/A";
    return account.map(b => b.toString(16).padStart(2, '0')).join('');
  }

  function getStatusColor(status) {
    const statusKey = Object.keys(status)[0];
    switch(statusKey) {
      case 'active': return 'bg-blue-100 text-blue-800';
      case 'accepted': return 'bg-green-100 text-green-800';
      case 'rejected': return 'bg-red-100 text-red-800';
      case 'executed': return 'bg-purple-100 text-purple-800';
      default: return 'bg-gray-100 text-gray-800';
    }
  }

  function getStatusText(status) {
    return Object.keys(status)[0] || 'unknown';
  }

  function hasVoted(proposal) {
    if (!principal) return false;
    const principalText = principal.toText();
    return proposal.yesVotes.some(v => v.toText() === principalText) ||
           proposal.noVotes.some(v => v.toText() === principalText);
  }
</script>

{#if group}
  <div class="max-w-6xl mx-auto p-8">
    <!-- Group Header -->
    <div class="bg-white rounded-lg shadow-md p-6 mb-6">
      <div class="flex justify-between items-start mb-4">
        <div>
          <h1 class="text-3xl font-bold mb-2">{group.name}</h1>
          <p class="text-gray-600">{group.description}</p>
        </div>
        <span class="text-xs px-3 py-1 rounded {group.isPublic ? 'bg-green-100 text-green-800' : 'bg-gray-100 text-gray-800'}">
          {group.isPublic ? 'Public' : 'Private'}
        </span>
      </div>
      
      <div class="grid grid-cols-2 md:grid-cols-4 gap-4 mt-4">
        <div class="stat-box">
          <div class="text-sm text-gray-500">Balance</div>
          <div class="text-xl font-bold">{group.balance}</div>
        </div>
        <div class="stat-box">
          <div class="text-sm text-gray-500">Members</div>
          <div class="text-xl font-bold">{group.members.length}</div>
        </div>
        <div class="stat-box">
          <div class="text-sm text-gray-500">Proposals</div>
          <div class="text-xl font-bold">{proposals.length}</div>
        </div>
        <div class="stat-box">
          <div class="text-sm text-gray-500">Created</div>
          <div class="text-sm font-semibold">{formatDate(group.createdAt)}</div>
        </div>
      </div>

      <div class="mt-4 p-3 bg-gray-50 rounded">
        <div class="text-xs text-gray-500">Subaccount Address</div>
        <div class="text-xs font-mono break-all">{formatAccount(group.account)}</div>
      </div>
    </div>

    <!-- Members Section -->
    <div class="bg-white rounded-lg shadow-md p-6 mb-6">
      <div class="flex justify-between items-center mb-4">
        <h2 class="text-2xl font-semibold">Members</h2>
        {#if isCreator || isMember}
          <button on:click={() => showAddMember = !showAddMember} class="btn btn-primary btn-sm">
            {showAddMember ? "Cancel" : "Add Member"}
          </button>
        {/if}
      </div>

      {#if showAddMember}
        <div class="bg-gray-50 p-4 rounded mb-4">
          <div class="grid grid-cols-1 md:grid-cols-3 gap-3">
            <input type="text" bind:value={newMemberName} placeholder="Name" class="input" />
            <input type="text" bind:value={newMemberPrincipal} placeholder="Principal" class="input" />
            <input type="number" bind:value={newMemberVotingPower} min="1" placeholder="Voting Power" class="input" />
          </div>
          <button on:click={addMember} class="btn btn-primary btn-sm mt-2">Add</button>
        </div>
      {/if}

      <div class="space-y-2">
        {#each group.members as member}
          <div class="flex items-center justify-between p-3 bg-gray-50 rounded">
            <div class="flex-1">
              <div class="font-semibold">{member.name || "Unnamed"}</div>
              <div class="text-xs text-gray-500">{member.principal.toText()}</div>
            </div>
            <div class="flex items-center gap-3">
              <span class="text-sm px-2 py-1 bg-blue-100 text-blue-800 rounded">
                Voting Power: {member.votingPower}
              </span>
              {#if isCreator && member.principal.toText() !== group.creator.toText()}
                <button on:click={() => removeMember(member.principal)} class="btn btn-sm btn-danger">
                  Remove
                </button>
              {/if}
            </div>
          </div>
        {/each}
      </div>
    </div>

    <!-- Proposals Section -->
    <div class="bg-white rounded-lg shadow-md p-6">
      <div class="flex justify-between items-center mb-4">
        <h2 class="text-2xl font-semibold">Proposals</h2>
        {#if isMember}
          <button on:click={() => showCreateProposal = !showCreateProposal} class="btn btn-primary btn-sm">
            {showCreateProposal ? "Cancel" : "Create Proposal"}
          </button>
        {/if}
      </div>

      {#if showCreateProposal}
        <div class="bg-gray-50 p-4 rounded mb-4">
          <div class="mb-3">
            <label class="block mb-1 text-sm font-medium">Title</label>
            <input type="text" bind:value={proposalTitle} placeholder="Proposal title" class="input" />
          </div>
          <div class="mb-3">
            <label class="block mb-1 text-sm font-medium">Description</label>
            <textarea bind:value={proposalDescription} placeholder="Describe the proposal" class="input" rows="3"></textarea>
          </div>
          <div class="mb-3">
            <label class="block mb-1 text-sm font-medium">Recipient Principal</label>
            <input type="text" bind:value={proposalRecipient} placeholder="Principal address" class="input" />
          </div>
          <div class="mb-3">
            <label class="block mb-1 text-sm font-medium">Amount</label>
            <input type="number" bind:value={proposalAmount} min="0" placeholder="Amount to transfer" class="input" />
          </div>
          <button on:click={createProposal} class="btn btn-primary">Create Proposal</button>
        </div>
      {/if}

      {#if proposals.length === 0}
        <div class="text-center text-gray-500 py-8">No proposals yet</div>
      {:else}
        <div class="space-y-4">
          {#each proposals as proposal}
            <div class="border rounded-lg p-4">
              <div class="flex justify-between items-start mb-2">
                <h3 class="text-lg font-semibold">{proposal.title}</h3>
                <span class="text-xs px-2 py-1 rounded {getStatusColor(proposal.status)}">
                  {getStatusText(proposal.status)}
                </span>
              </div>
              <p class="text-sm text-gray-600 mb-3">{proposal.description}</p>
              <div class="text-sm space-y-1 mb-3">
                <div><span class="font-medium">Recipient:</span> {proposal.recipient.toText()}</div>
                <div><span class="font-medium">Amount:</span> {proposal.amount}</div>
                <div><span class="font-medium">Created:</span> {formatDate(proposal.createdAt)}</div>
              </div>
              <div class="flex items-center justify-between">
                <div class="text-sm">
                  <span class="text-green-600 font-medium">Yes: {proposal.yesVotes.length}</span>
                  <span class="mx-2">|</span>
                  <span class="text-red-600 font-medium">No: {proposal.noVotes.length}</span>
                </div>
                {#if isMember && getStatusText(proposal.status) === 'active' && !hasVoted(proposal)}
                  <div class="flex gap-2">
                    <button on:click={() => voteOnProposal(proposal.id, true)} class="btn btn-sm btn-success">
                      Vote Yes
                    </button>
                    <button on:click={() => voteOnProposal(proposal.id, false)} class="btn btn-sm btn-danger">
                      Vote No
                    </button>
                  </div>
                {/if}
              </div>
            </div>
          {/each}
        </div>
      {/if}
    </div>
  </div>
{:else}
  <div class="max-w-6xl mx-auto p-8 text-center">
    <div class="text-gray-500">Loading group...</div>
  </div>
{/if}

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
  .btn-success {
    background-color: #10b981;
    color: white;
  }
  .btn-success:hover {
    background-color: #059669;
  }
  .btn-danger {
    background-color: #ef4444;
    color: white;
  }
  .btn-danger:hover {
    background-color: #dc2626;
  }
  .btn-sm {
    padding: 0.375rem 0.75rem;
    font-size: 0.875rem;
  }
  .stat-box {
    padding: 0.75rem;
    background-color: #f9fafb;
    border-radius: 0.5rem;
  }
</style>
