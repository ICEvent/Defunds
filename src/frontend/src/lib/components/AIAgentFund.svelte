<!-- AI Agent Fund Card Component -->
<script>
  export let fund;
  export let onView = null;
  export let onJoin = null;
  export let showActions = true;

  // ICP timestamps are in nanoseconds; JavaScript Date expects milliseconds.
  const NANOS_TO_MILLIS = 1_000_000;

  function formatDate(timestamp) {
    return new Date(Number(timestamp) / NANOS_TO_MILLIS).toLocaleDateString();
  }

  function formatLastRun(lastRunAt) {
    if (!lastRunAt || lastRunAt.length === 0) return "Never";
    return new Date(Number(lastRunAt[0]) / NANOS_TO_MILLIS).toLocaleString();
  }

  function strategyLabel(strategy) {
    const key = Object.keys(strategy)[0];
    switch (key) {
      case "conservative": return "🛡️ Conservative";
      case "balanced":     return "⚖️ Balanced";
      case "aggressive":   return "🚀 Aggressive";
      case "custom":       return "🔧 Custom";
      default:             return key;
    }
  }

  function recommendationBadge(rec) {
    const key = Object.keys(rec)[0];
    switch (key) {
      case "approve": return { label: "Approve", cls: "bg-green-100 text-green-800" };
      case "reject":  return { label: "Reject",  cls: "bg-red-100 text-red-800" };
      case "review":  return { label: "Review",  cls: "bg-yellow-100 text-yellow-800" };
      default:        return { label: key, cls: "bg-gray-100 text-gray-800" };
    }
  }

  $: groupFund = fund.groupFund;
  $: config = fund.agentConfig;
  $: evaluations = fund.evaluations || [];
  $: lastRunAt = fund.lastRunAt;
</script>

<div class="ai-fund-card">
  <div class="card-header">
    <div class="flex items-center gap-2">
      <span class="text-xl">🤖</span>
      <h3 class="fund-name">{groupFund.name}</h3>
    </div>
    <div class="flex flex-col items-end gap-1">
      <span class="badge {groupFund.isPublic ? 'badge-public' : 'badge-private'}">
        {groupFund.isPublic ? "Public" : "Private"}
      </span>
      <span class="badge {config.enabled ? 'badge-active' : 'badge-inactive'}">
        {config.enabled ? "AI Active" : "AI Paused"}
      </span>
    </div>
  </div>

  <p class="fund-description">{groupFund.description}</p>

  <!-- Strategy & Config -->
  <div class="config-row">
    <span class="config-label">Strategy:</span>
    <span class="config-value">{strategyLabel(config.strategy)}</span>
  </div>
  <div class="config-row">
    <span class="config-label">Risk Tolerance:</span>
    <span class="config-value">{config.riskTolerance}/100</span>
  </div>
  <div class="config-row">
    <span class="config-label">Max Allocation:</span>
    <span class="config-value">{config.maxAllocationPct}% per proposal</span>
  </div>
  <div class="config-row">
    <span class="config-label">Auto-Approve Score:</span>
    <span class="config-value">≥ {config.autoApproveThreshold}</span>
  </div>

  <div class="fund-stats">
    <div class="stat">
      <span class="stat-label">Members:</span>
      <span class="stat-value">{groupFund.members.length}</span>
    </div>
    <div class="stat">
      <span class="stat-label">Balance:</span>
      <span class="stat-value">{groupFund.balance}</span>
    </div>
    <div class="stat">
      <span class="stat-label">Evaluations:</span>
      <span class="stat-value">{evaluations.length}</span>
    </div>
    <div class="stat">
      <span class="stat-label">Last AI Run:</span>
      <span class="stat-value">{formatLastRun(lastRunAt)}</span>
    </div>
    <div class="stat">
      <span class="stat-label">Created:</span>
      <span class="stat-value">{formatDate(groupFund.createdAt)}</span>
    </div>
  </div>

  <!-- Recent Evaluations -->
  {#if evaluations.length > 0}
    <div class="evaluations-section">
      <h4 class="eval-header">Recent AI Evaluations</h4>
      {#each evaluations.slice(-3) as ev}
        {@const badge = recommendationBadge(ev.recommendation)}
        <div class="eval-row">
          <span class="eval-proposal">Proposal #{ev.proposalId}</span>
          <span class="eval-score">Score: {ev.score}/100</span>
          <span class="badge {badge.cls}">{badge.label}</span>
        </div>
      {/each}
    </div>
  {/if}

  {#if showActions}
    <div class="card-actions">
      {#if onView}
        <button on:click={() => onView(groupFund.id)} class="btn btn-view">View Details</button>
      {/if}
      {#if onJoin && groupFund.isPublic}
        <button on:click={() => onJoin(groupFund.id)} class="btn btn-join">Join</button>
      {/if}
    </div>
  {/if}
</div>

<style>
  .ai-fund-card {
    background: white;
    border: 1px solid #e5e7eb;
    border-radius: 0.5rem;
    padding: 1.5rem;
    transition: box-shadow 0.2s;
  }
  .ai-fund-card:hover {
    box-shadow: 0 4px 6px -1px rgba(0,0,0,0.1);
  }
  .card-header {
    display: flex;
    justify-content: space-between;
    align-items: flex-start;
    margin-bottom: 0.75rem;
  }
  .fund-name {
    font-size: 1.125rem;
    font-weight: 600;
    color: #111827;
  }
  .fund-description {
    font-size: 0.875rem;
    color: #6b7280;
    margin-bottom: 0.75rem;
    line-height: 1.5;
  }
  .badge {
    font-size: 0.7rem;
    padding: 0.2rem 0.5rem;
    border-radius: 0.25rem;
    font-weight: 500;
  }
  .badge-public   { background:#d1fae5; color:#065f46; }
  .badge-private  { background:#f3f4f6; color:#374151; }
  .badge-active   { background:#dbeafe; color:#1e40af; }
  .badge-inactive { background:#fef3c7; color:#92400e; }
  .config-row {
    display: flex;
    gap: 0.5rem;
    font-size: 0.75rem;
    margin-bottom: 0.25rem;
  }
  .config-label { color:#6b7280; font-weight:500; }
  .config-value { color:#111827; }
  .fund-stats {
    display: grid;
    gap: 0.4rem;
    margin-top: 0.75rem;
    margin-bottom: 0.75rem;
  }
  .stat { font-size: 0.75rem; color: #6b7280; }
  .stat-label { font-weight: 500; }
  .stat-value { color: #111827; }
  .evaluations-section { margin-top: 0.75rem; }
  .eval-header { font-size: 0.8rem; font-weight: 600; color: #374151; margin-bottom: 0.4rem; }
  .eval-row {
    display: flex;
    align-items: center;
    gap: 0.5rem;
    font-size: 0.75rem;
    margin-bottom: 0.25rem;
  }
  .eval-proposal { color: #6b7280; flex: 1; }
  .eval-score { color: #374151; }
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
  .btn-view { background-color: #6d28d9; color: white; }
  .btn-view:hover { background-color: #5b21b6; }
  .btn-join { background-color: #10b981; color: white; }
  .btn-join:hover { background-color: #059669; }
</style>
