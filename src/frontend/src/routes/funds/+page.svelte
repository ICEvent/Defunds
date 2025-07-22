<script>
  import { onMount } from "svelte";
  let publicGroupFunds = [];
  let backend;

  onMount(async () => {
    // Assume globalStore provides backend
    const { globalStore } = await import('$lib/store');
    globalStore.subscribe(store => {
      backend = store.backend;
    });
    if (backend) {
      // Fetch all public group funds from backend
      const result = await backend.getPublicGroupFunds();
      if (result.ok) {
        publicGroupFunds = result.ok;
      }
    }
  });
</script>

<div class="max-w-3xl mx-auto p-8">
  <h1 class="text-2xl font-bold mb-6">Public Group Funds</h1>
  {#if publicGroupFunds.length === 0}
    <div class="text-gray-500">No public group funds found.</div>
  {:else}
    <ul class="space-y-4">
      {#each publicGroupFunds as fund}
        <li class="p-4 bg-white rounded shadow">
          <div class="font-semibold text-lg">{fund.name}</div>
          <div class="text-sm text-gray-600">Members: {fund.members.join(", ")}</div>
          <div class="text-sm text-gray-600">Funds: {fund.amount}</div>
        </li>
      {/each}
    </ul>
  {/if}
</div>

<style>
  .max-w-3xl { max-width: 768px; }
</style>
