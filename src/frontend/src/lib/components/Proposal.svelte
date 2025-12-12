<!-- Proposal Component - Reusable proposal card -->
<script>
  export let proposal;
  export let isMember = false;
  export let userPrincipal = null;
  export let onVote = null;

  function formatDate(timestamp) {
    return new Date(Number(timestamp) / 1000000).toLocaleString();
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

  function hasVoted() {
    if (!userPrincipal) return false;
    const principalText = userPrincipal.toText();
    return proposal.yesVotes.some(v => v.toText() === principalText) ||
           proposal.noVotes.some(v => v.toText() === principalText);
  }

  $: isActive = getStatusText(proposal.status) === 'active';
  $: canVote = isMember && isActive && !hasVoted();
  $: totalVotes = proposal.yesVotes.length + proposal.noVotes.length;
  $: yesPercentage = totalVotes > 0 ? (proposal.yesVotes.length / totalVotes) * 100 : 0;
</script>

<div class="proposal-card">
  <div class="proposal-header">
    <h3 class="proposal-title">{proposal.title}</h3>
    <span class="status-badge {getStatusColor(proposal.status)}">
      {getStatusText(proposal.status)}
    </span>
  </div>

  <p class="proposal-description">{proposal.description}</p>

  <div class="proposal-details">
    <div class="detail-row">
      <span class="detail-label">Recipient:</span>
      <span class="detail-value font-mono">{proposal.recipient.toText().slice(0, 20)}...</span>
    </div>
    <div class="detail-row">
      <span class="detail-label">Amount:</span>
      <span class="detail-value">{proposal.amount}</span>
    </div>
    <div class="detail-row">
      <span class="detail-label">Created:</span>
      <span class="detail-value">{formatDate(proposal.createdAt)}</span>
    </div>
  </div>

  <div class="voting-section">
    <div class="vote-counts">
      <div class="vote-count yes">
        <span class="vote-icon">✓</span>
        <span class="vote-number">{proposal.yesVotes.length}</span>
        <span class="vote-label">Yes</span>
      </div>
      <div class="vote-count no">
        <span class="vote-icon">✗</span>
        <span class="vote-number">{proposal.noVotes.length}</span>
        <span class="vote-label">No</span>
      </div>
    </div>

    {#if totalVotes > 0}
      <div class="vote-progress">
        <div class="progress-bar">
          <div class="progress-fill" style="width: {yesPercentage}%"></div>
        </div>
        <div class="progress-label">{yesPercentage.toFixed(1)}% approval</div>
      </div>
    {/if}

    {#if canVote && onVote}
      <div class="vote-actions">
        <button on:click={() => onVote(proposal.id, true)} class="btn btn-yes">
          Vote Yes
        </button>
        <button on:click={() => onVote(proposal.id, false)} class="btn btn-no">
          Vote No
        </button>
      </div>
    {/if}
  </div>
</div>

<style>
  .proposal-card {
    background: white;
    border: 1px solid #e5e7eb;
    border-radius: 0.5rem;
    padding: 1.5rem;
  }
  .proposal-header {
    display: flex;
    justify-content: space-between;
    align-items: flex-start;
    margin-bottom: 0.75rem;
  }
  .proposal-title {
    font-size: 1.125rem;
    font-weight: 600;
    color: #111827;
  }
  .status-badge {
    font-size: 0.75rem;
    padding: 0.25rem 0.5rem;
    border-radius: 0.25rem;
    font-weight: 500;
  }
  .bg-blue-100 { background-color: #dbeafe; }
  .text-blue-800 { color: #1e40af; }
  .bg-green-100 { background-color: #d1fae5; }
  .text-green-800 { color: #065f46; }
  .bg-red-100 { background-color: #fee2e2; }
  .text-red-800 { color: #991b1b; }
  .bg-purple-100 { background-color: #e9d5ff; }
  .text-purple-800 { color: #5b21b6; }
  .bg-gray-100 { background-color: #f3f4f6; }
  .text-gray-800 { color: #1f2937; }
  .proposal-description {
    font-size: 0.875rem;
    color: #6b7280;
    margin-bottom: 1rem;
    line-height: 1.5;
  }
  .proposal-details {
    margin-bottom: 1rem;
    padding: 0.75rem;
    background-color: #f9fafb;
    border-radius: 0.375rem;
  }
  .detail-row {
    display: flex;
    justify-content: space-between;
    font-size: 0.875rem;
    margin-bottom: 0.5rem;
  }
  .detail-row:last-child {
    margin-bottom: 0;
  }
  .detail-label {
    font-weight: 500;
    color: #6b7280;
  }
  .detail-value {
    color: #111827;
  }
  .font-mono {
    font-family: monospace;
  }
  .voting-section {
    border-top: 1px solid #e5e7eb;
    padding-top: 1rem;
  }
  .vote-counts {
    display: flex;
    gap: 2rem;
    margin-bottom: 1rem;
  }
  .vote-count {
    display: flex;
    align-items: center;
    gap: 0.5rem;
  }
  .vote-count.yes {
    color: #059669;
  }
  .vote-count.no {
    color: #dc2626;
  }
  .vote-icon {
    font-size: 1.25rem;
    font-weight: bold;
  }
  .vote-number {
    font-size: 1.25rem;
    font-weight: 600;
  }
  .vote-label {
    font-size: 0.875rem;
    font-weight: 500;
  }
  .vote-progress {
    margin-bottom: 1rem;
  }
  .progress-bar {
    width: 100%;
    height: 0.5rem;
    background-color: #fee2e2;
    border-radius: 0.25rem;
    overflow: hidden;
  }
  .progress-fill {
    height: 100%;
    background-color: #10b981;
    transition: width 0.3s ease;
  }
  .progress-label {
    font-size: 0.75rem;
    color: #6b7280;
    margin-top: 0.25rem;
  }
  .vote-actions {
    display: flex;
    gap: 0.75rem;
  }
  .btn {
    flex: 1;
    padding: 0.5rem 1rem;
    border-radius: 0.375rem;
    font-size: 0.875rem;
    font-weight: 500;
    border: none;
    cursor: pointer;
    transition: background-color 0.2s;
  }
  .btn-yes {
    background-color: #10b981;
    color: white;
  }
  .btn-yes:hover {
    background-color: #059669;
  }
  .btn-no {
    background-color: #ef4444;
    color: white;
  }
  .btn-no:hover {
    background-color: #dc2626;
  }
</style>
