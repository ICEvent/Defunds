<script>
  import { onMount } from "svelte";
  import { showNotification } from "$lib/stores/notification";
  import { hideProgress, showProgress } from "$lib/stores/progress";
  import { goto } from "$app/navigation";
  import AIAgentFund from "$lib/components/AIAgentFund.svelte";

  let publicFunds = [];
  let myFunds = [];
  let backend;
  let isAuthed = false;
  let principal;

  let showCreateForm = false;

  // Create form state
  let newFund = {
    name: "",
    description: "",
    isPublic: true,
    strategy: "balanced",
    riskTolerance: 50,
    maxAllocationPct: 20,
    autoApproveThreshold: 70,
  };

  const strategyOptions = [
    { value: "conservative", label: "🛡️ Conservative – Low risk, stable returns" },
    { value: "balanced",     label: "⚖️ Balanced – Moderate risk/reward" },
    { value: "aggressive",   label: "🚀 Aggressive – High risk, high reward" },
    { value: "custom",       label: "🔧 Custom – User-defined parameters" },
  ];

  onMount(async () => {
    const { globalStore } = await import("$lib/store");
    globalStore.subscribe((store) => {
      backend = store.backend;
      principal = store.principal;
      isAuthed = store.isAuthed;
    });
    await loadFunds();
  });

  async function loadFunds() {
    showProgress();
    try {
      const publicResult = await backend.getPublicAIAgentFunds();
      publicFunds = publicResult || [];
    } catch (e) {
      showNotification("Error loading public AI Agent Funds: " + e.message, "error");
    }

    if (isAuthed) {
      try {
        const myResult = await backend.getMyAIAgentFunds();
        myFunds = myResult || [];
      } catch (e) {
        showNotification("Error loading your AI Agent Funds: " + e.message, "error");
      }
    }

    hideProgress();
  }

  function strategyVariant(str) {
    switch (str) {
      case "conservative": return { conservative: null };
      case "balanced":     return { balanced: null };
      case "aggressive":   return { aggressive: null };
      case "custom":       return { custom: null };
      default:             return { balanced: null };
    }
  }

  async function createFund() {
    if (!newFund.name.trim()) {
      showNotification("Fund name is required", "error");
      return;
    }
    if (newFund.riskTolerance < 1 || newFund.riskTolerance > 100) {
      showNotification("Risk tolerance must be between 1 and 100", "error");
      return;
    }
    if (newFund.maxAllocationPct < 1 || newFund.maxAllocationPct > 100) {
      showNotification("Max allocation must be between 1 and 100", "error");
      return;
    }
    if (newFund.autoApproveThreshold > 100) {
      showNotification("Auto-approve threshold must be between 0 and 100", "error");
      return;
    }

    showProgress();
    try {
      const result = await backend.createAIAgentFund(
        newFund.name.trim(),
        newFund.description.trim(),
        newFund.isPublic,
        strategyVariant(newFund.strategy),
        newFund.riskTolerance,
        newFund.maxAllocationPct,
        newFund.autoApproveThreshold,
      );
      if (result.ok) {
        showNotification("AI Agent Fund created successfully!", "success");
        newFund = {
          name: "",
          description: "",
          isPublic: true,
          strategy: "balanced",
          riskTolerance: 50,
          maxAllocationPct: 20,
          autoApproveThreshold: 70,
        };
        showCreateForm = false;
        await loadFunds();
      } else {
        showNotification(result.err, "error");
      }
    } catch (e) {
      showNotification("Error creating AI Agent Fund: " + e.message, "error");
    } finally {
      hideProgress();
    }
  }

  async function runEvaluation(groupId) {
    showProgress();
    try {
      const result = await backend.runAIEvaluation(groupId);
      if (result.ok) {
        const count = result.ok.length;
        showNotification(
          `AI evaluation complete: ${count} proposal${count !== 1 ? "s" : ""} evaluated`,
          "success"
        );
        await loadFunds();
      } else {
        showNotification(result.err, "error");
      }
    } catch (e) {
      showNotification("Error running AI evaluation: " + e.message, "error");
    } finally {
      hideProgress();
    }
  }

  function viewFund(groupId) {
    goto(`/funds/${groupId}`);
  }
</script>

<div class="max-w-6xl mx-auto p-8">
  <!-- Header -->
  <div class="flex justify-between items-center mb-6">
    <div>
      <h1 class="text-3xl font-bold flex items-center gap-2">
        <span>🤖</span> AI Agent Funds
      </h1>
      <p class="text-sm text-gray-600 mt-1">
        Funds managed by an autonomous AI agent that evaluates proposals and recommends allocations
      </p>
    </div>
    {#if isAuthed}
      <button on:click={() => (showCreateForm = !showCreateForm)} class="btn btn-primary">
        {showCreateForm ? "Cancel" : "Create AI Agent Fund"}
      </button>
    {/if}
  </div>

  <!-- Create Fund Form -->
  {#if showCreateForm}
    <div class="bg-white rounded-lg shadow-md p-6 mb-6 border-l-4 border-purple-500">
      <h2 class="text-xl font-semibold mb-4">New AI Agent Fund</h2>
      <div class="grid grid-cols-1 md:grid-cols-2 gap-4">
        <div>
          <label class="block text-sm font-medium mb-1">Fund Name *</label>
          <input type="text" bind:value={newFund.name} placeholder="e.g. DeFi Yield Fund" class="input" />
        </div>
        <div>
          <label class="block text-sm font-medium mb-1">Visibility</label>
          <select bind:value={newFund.isPublic} class="input">
            <option value={true}>Public</option>
            <option value={false}>Private</option>
          </select>
        </div>
        <div class="md:col-span-2">
          <label class="block text-sm font-medium mb-1">Description</label>
          <textarea bind:value={newFund.description} placeholder="Describe the fund's purpose" class="input" rows="3"></textarea>
        </div>
        <div>
          <label class="block text-sm font-medium mb-1">AI Strategy</label>
          <select bind:value={newFund.strategy} class="input">
            {#each strategyOptions as opt}
              <option value={opt.value}>{opt.label}</option>
            {/each}
          </select>
        </div>
        <div>
          <label class="block text-sm font-medium mb-1">Risk Tolerance (1–100)</label>
          <input type="number" bind:value={newFund.riskTolerance} min="1" max="100" class="input" />
          <p class="text-xs text-gray-500 mt-1">Higher = more risk accepted by the AI agent</p>
        </div>
        <div>
          <label class="block text-sm font-medium mb-1">Max Allocation per Proposal (%)</label>
          <input type="number" bind:value={newFund.maxAllocationPct} min="1" max="100" class="input" />
          <p class="text-xs text-gray-500 mt-1">Maximum % of fund balance for a single proposal</p>
        </div>
        <div>
          <label class="block text-sm font-medium mb-1">Auto-Approve Score Threshold (0–100)</label>
          <input type="number" bind:value={newFund.autoApproveThreshold} min="0" max="100" class="input" />
          <p class="text-xs text-gray-500 mt-1">Proposals scoring at or above this are recommended for approval</p>
        </div>
      </div>
      <div class="mt-4 flex gap-3">
        <button on:click={createFund} class="btn btn-primary">Create Fund</button>
        <button on:click={() => (showCreateForm = false)} class="btn btn-secondary">Cancel</button>
      </div>
    </div>
  {/if}

  <!-- My AI Agent Funds -->
  {#if isAuthed && myFunds.length > 0}
    <section class="mb-8">
      <h2 class="text-2xl font-semibold mb-4">My AI Agent Funds</h2>
      <div class="grid grid-cols-1 md:grid-cols-2 lg:grid-cols-3 gap-4">
        {#each myFunds as fund}
          <div class="relative">
            <AIAgentFund
              {fund}
              onView={viewFund}
              showActions={true}
            />
            <div class="mt-2 flex gap-2">
              <button
                on:click={() => runEvaluation(fund.groupFund.id)}
                class="btn btn-ai w-full"
                disabled={!fund.agentConfig.enabled}
              >
                ▶ Run AI Evaluation
              </button>
            </div>
          </div>
        {/each}
      </div>
    </section>
  {/if}

  <!-- Public AI Agent Funds -->
  <section>
    <h2 class="text-2xl font-semibold mb-4">Public AI Agent Funds</h2>
    {#if publicFunds.length === 0}
      <div class="text-gray-500 text-center py-10 bg-white rounded-lg shadow-sm border">
        <span class="text-4xl block mb-2">🤖</span>
        No public AI Agent Funds yet. Be the first to create one!
      </div>
    {:else}
      <div class="grid grid-cols-1 md:grid-cols-2 lg:grid-cols-3 gap-4">
        {#each publicFunds as fund}
          <AIAgentFund
            {fund}
            onView={viewFund}
            showActions={true}
          />
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
    border-color: #7c3aed;
  }
  .btn {
    padding: 0.5rem 1rem;
    border-radius: 0.375rem;
    font-weight: 500;
    cursor: pointer;
    transition: all 0.2s;
    border: none;
    font-size: 0.875rem;
  }
  .btn:disabled {
    opacity: 0.5;
    cursor: not-allowed;
  }
  .btn-primary {
    background-color: #7c3aed;
    color: white;
  }
  .btn-primary:hover:not(:disabled) {
    background-color: #6d28d9;
  }
  .btn-secondary {
    background-color: #6b7280;
    color: white;
  }
  .btn-secondary:hover {
    background-color: #4b5563;
  }
  .btn-ai {
    background-color: #0ea5e9;
    color: white;
  }
  .btn-ai:hover:not(:disabled) {
    background-color: #0284c7;
  }
</style>
