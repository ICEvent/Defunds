<!-- Group Fund Component - Reusable group fund card -->
<script>
  export let group;
  export let onView = null;
  export let onJoin = null;
  export let showActions = true;

  function formatDate(timestamp) {
    return new Date(Number(timestamp) / 1000000).toLocaleDateString();
  }

  function formatAccount(account) {
    if (!account || account.length === 0) return "N/A";
    return account.slice(0, 8).map(b => b.toString(16).padStart(2, '0')).join('') + "...";
  }
</script>

<div class="group-fund-card">
  <div class="card-header">
    <h3 class="group-name">💰 {group.name}</h3>
    <span class="badge {group.isPublic ? 'badge-public' : 'badge-private'}">
      {group.isPublic ? 'Public' : 'Private'}
    </span>
  </div>
  
  <p class="group-description">{group.description}</p>
  
  <div class="group-stats">
    <div class="stat">
      <span class="stat-label">Members:</span>
      <span class="stat-value">{group.members.length}</span>
    </div>
    <div class="stat">
      <span class="stat-label">Balance:</span>
      <span class="stat-value">{group.balance}</span>
    </div>
    <div class="stat">
      <span class="stat-label">Account:</span>
      <span class="stat-value">{formatAccount(group.account)}</span>
    </div>
    <div class="stat">
      <span class="stat-label">Created:</span>
      <span class="stat-value">{formatDate(group.createdAt)}</span>
    </div>
  </div>

  {#if showActions}
    <div class="card-actions">
      {#if onView}
        <button on:click={() => onView(group.id)} class="btn btn-view">View Details</button>
      {/if}
      {#if onJoin && group.isPublic}
        <button on:click={() => onJoin(group.id)} class="btn btn-join">Join</button>
      {/if}
    </div>
  {/if}
</div>

<style>
  .group-fund-card {
    background: white;
    border: 1px solid #e5e7eb;
    border-radius: 0.5rem;
    padding: 1.5rem;
    transition: box-shadow 0.2s;
  }
  .group-fund-card:hover {
    box-shadow: 0 4px 6px -1px rgba(0, 0, 0, 0.1);
  }
  .card-header {
    display: flex;
    justify-content: space-between;
    align-items: flex-start;
    margin-bottom: 0.75rem;
  }
  .group-name {
    font-size: 1.125rem;
    font-weight: 600;
    color: #111827;
  }
  .badge {
    font-size: 0.75rem;
    padding: 0.25rem 0.5rem;
    border-radius: 0.25rem;
    font-weight: 500;
  }
  .badge-public {
    background-color: #d1fae5;
    color: #065f46;
  }
  .badge-private {
    background-color: #f3f4f6;
    color: #374151;
  }
  .group-description {
    font-size: 0.875rem;
    color: #6b7280;
    margin-bottom: 1rem;
    line-height: 1.5;
  }
  .group-stats {
    display: grid;
    gap: 0.5rem;
    margin-bottom: 1rem;
  }
  .stat {
    font-size: 0.75rem;
    color: #6b7280;
  }
  .stat-label {
    font-weight: 500;
  }
  .stat-value {
    color: #111827;
  }
  .card-actions {
    display: flex;
    gap: 0.5rem;
    margin-top: 1rem;
  }
  .btn {
    padding: 0.5rem 1rem;
    border-radius: 0.375rem;
    font-size: 0.875rem;
    font-weight: 500;
    border: none;
    cursor: pointer;
    transition: background-color 0.2s;
    flex: 1;
  }
  .btn-view {
    background-color: #3b82f6;
    color: white;
  }
  .btn-view:hover {
    background-color: #2563eb;
  }
  .btn-join {
    background-color: #10b981;
    color: white;
  }
  .btn-join:hover {
    background-color: #059669;
  }
</style>
