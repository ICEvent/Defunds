<script>
	import { onMount } from 'svelte';
	import { globalStore } from '$lib/store';
	import * as governanceAPI from '$lib/api/governance';
	import GroupManager from '$lib/components/GroupManager.svelte';

	let isAuthed = false;
	let principal = '';
	let governanceActor = null;
	let loading = false;
	let error = null;

	// Selected group
	let selectedGroup = null;
	let selectedGroupId = null;
	let groupInfo = null;

	// System info
	let systemInfo = {
		totalGroups: 0,
		totalMembers: 0,
		totalAssets: 0,
		totalProposals: 0,
		rulesVersion: 0,
	};

	// Proposals
	let proposals = [];
	let currentPage = 1;
	let pageSize = 10;

	// Assets and Rules for the selected group
	let assets = [];
	let rules = [];

	// Create proposal form
	let showCreateProposal = false;
	let proposalForm = {
		assetId: 1,
		amount: 0,
		purpose: '',
		payee: '',
		evidenceHash: '',
		ruleId: 1,
	};

	// Vote modal
	let showVoteModal = false;
	let selectedProposal = null;

	onMount(() => {
		globalStore.subscribe(async (value) => {
			isAuthed = value.isAuthed;
			principal = value.principal?.toText() || '';
			governanceActor = value.governance;

			if (governanceActor) {
				await loadSystemInfo();
			}
		});
	});

	async function handleGroupSelected(event) {
		selectedGroup = event.detail.group;
		selectedGroupId = event.detail.groupId;
		
		if (selectedGroupId) {
			await loadGroupData();
		}
	}

	async function loadSystemInfo() {
		try {
			systemInfo = await governanceAPI.auditSystemInfo(governanceActor);
		} catch (e) {
			console.error('Error loading system info:', e);
		}
	}

	async function loadGroupData() {
		if (!governanceActor || !selectedGroupId) return;
		
		loading = true;
		error = null;
		try {
			// Load group info
			groupInfo = await governanceAPI.auditGroupInfo(governanceActor, selectedGroupId);

			// Load group assets
			assets = await governanceAPI.getGroupAssets(governanceActor, selectedGroupId);

			// Load group rules
			rules = await governanceAPI.getGroupRules(governanceActor, selectedGroupId);

			// Load proposals for this group
			proposals = await governanceAPI.listGroupProposalsAudit(
				governanceActor,
				selectedGroupId,
				currentPage,
				pageSize
			);
		} catch (e) {
			error = e.message;
			console.error('Error loading group data:', e);
		} finally {
			loading = false;
		}
	}

	async function handleCreateProposal() {
		if (!governanceActor || !selectedGroupId) return;

		loading = true;
		try {
			const result = await governanceAPI.createProposal(
				governanceActor,
				selectedGroupId,
				Number(proposalForm.assetId),
				Number(proposalForm.amount),
				proposalForm.purpose,
				proposalForm.payee,
				proposalForm.evidenceHash || null,
				Number(proposalForm.ruleId)
			);

			if ('ok' in result) {
				alert(`Proposal created with ID: ${result.ok}`);
				showCreateProposal = false;
				await loadGroupData();
				// Reset form
				proposalForm = {
					assetId: assets[0]?.assetId || 1,
					amount: 0,
					purpose: '',
					payee: '',
					evidenceHash: '',
					ruleId: rules[0]?.ruleId || 1,
				};
			} else {
				alert(`Error: ${result.err}`);
			}
		} catch (e) {
			alert(`Error creating proposal: ${e.message}`);
		} finally {
			loading = false;
		}
	}

	function openVoteModal(proposal) {
		selectedProposal = proposal;
		showVoteModal = true;
	}

	async function handleVote(approve) {
		if (!governanceActor || !selectedProposal) return;

		loading = true;
		try {
			const result = await governanceAPI.vote(
				governanceActor,
				selectedProposal.proposal.proposalId,
				approve
			);

			if ('ok' in result) {
				alert(`Vote ${approve ? 'approved' : 'rejected'} successfully!`);
				showVoteModal = false;
				await loadGroupData();
			} else {
				alert(`Error: ${result.err}`);
			}
		} catch (e) {
			alert(`Error voting: ${e.message}`);
		} finally {
			loading = false;
		}
	}

	function getStatusClass(status) {
		if ('pending' in status) return 'bg-yellow-100 text-yellow-800';
		if ('approved' in status) return 'bg-green-100 text-green-800';
		if ('rejected' in status) return 'bg-red-100 text-red-800';
		if ('executed' in status) return 'bg-blue-100 text-blue-800';
		return 'bg-gray-100 text-gray-800';
	}

	function getStatusText(status) {
		if ('pending' in status) return 'Pending';
		if ('approved' in status) return 'Approved';
		if ('rejected' in status) return 'Rejected';
		if ('executed' in status) return 'Executed';
		return 'Unknown';
	}

	function formatDate(timestamp) {
		const date = new Date(Number(timestamp) / 1000000); // Convert nanoseconds to milliseconds
		return date.toLocaleDateString() + ' ' + date.toLocaleTimeString();
	}
</script>

<main class="container mx-auto px-4 py-8 bg-gray-50 min-h-screen">
	<h1 class="text-4xl font-bold mb-8 text-center text-blue-600">Unified Group Governance</h1>

	{#if !isAuthed}
		<div class="bg-yellow-100 border-l-4 border-yellow-500 text-yellow-700 p-4 mb-6" role="alert">
			<p class="font-bold">Authentication Required</p>
			<p>Please login to access the governance system.</p>
		</div>
	{:else}
		<!-- System Overview -->
		<section class="bg-white shadow-lg rounded-lg p-6 mb-8">
			<h2 class="text-2xl font-semibold mb-4 text-blue-800 border-b pb-2">System Overview</h2>
			<div class="grid grid-cols-2 md:grid-cols-5 gap-4">
				<div class="bg-indigo-100 p-4 rounded-lg text-center">
					<div class="text-3xl font-bold text-indigo-600">{systemInfo.totalGroups}</div>
					<div class="text-sm text-gray-600">Total Groups</div>
				</div>
				<div class="bg-blue-100 p-4 rounded-lg text-center">
					<div class="text-3xl font-bold text-blue-600">{systemInfo.totalMembers}</div>
					<div class="text-sm text-gray-600">Total Members</div>
				</div>
				<div class="bg-green-100 p-4 rounded-lg text-center">
					<div class="text-3xl font-bold text-green-600">{systemInfo.totalAssets}</div>
					<div class="text-sm text-gray-600">Total Assets</div>
				</div>
				<div class="bg-purple-100 p-4 rounded-lg text-center">
					<div class="text-3xl font-bold text-purple-600">{systemInfo.totalProposals}</div>
					<div class="text-sm text-gray-600">Total Proposals</div>
				</div>
				<div class="bg-yellow-100 p-4 rounded-lg text-center">
					<div class="text-3xl font-bold text-yellow-600">{systemInfo.rulesVersion}</div>
					<div class="text-sm text-gray-600">Rules Version</div>
				</div>
			</div>
		</section>

		<!-- Group Manager -->
		<GroupManager
			{governanceActor}
			on:groupSelected={handleGroupSelected}
		/>

		{#if selectedGroup && selectedGroupId}
			<!-- Group Info -->
			<section class="bg-white shadow-lg rounded-lg p-6 mb-8">
				<div class="flex justify-between items-start mb-4">
					<div>
						<h2 class="text-2xl font-semibold text-blue-800 border-b pb-2">
							{selectedGroup.name} Overview
						</h2>
						<p class="text-gray-600 mt-2">{selectedGroup.description}</p>
						<div class="flex gap-2 mt-3">
							{#if selectedGroup.hasNativeFunds}
								<span class="text-xs bg-green-100 text-green-700 px-2 py-1 rounded font-semibold">
									💰 Native Funds Management
								</span>
							{/if}
							{#if selectedGroup.hasGovernance}
								<span class="text-xs bg-blue-100 text-blue-700 px-2 py-1 rounded font-semibold">
									⚖️ Governance & External Assets
								</span>
							{/if}
						</div>
					</div>
				</div>
				{#if groupInfo && groupInfo[0]}
					<div class="grid grid-cols-2 md:grid-cols-4 gap-4">
						<div class="bg-blue-100 p-3 rounded-lg text-center">
							<div class="text-2xl font-bold text-blue-600">{groupInfo[0]?.totalMembers || 0}</div>
							<div class="text-xs text-gray-600">Members</div>
						</div>
						<div class="bg-green-100 p-3 rounded-lg text-center">
							<div class="text-2xl font-bold text-green-600">{groupInfo[0]?.totalAssets || 0}</div>
							<div class="text-xs text-gray-600">Assets</div>
						</div>
						<div class="bg-purple-100 p-3 rounded-lg text-center">
							<div class="text-2xl font-bold text-purple-600">{groupInfo[0]?.totalProposals || 0}</div>
							<div class="text-xs text-gray-600">Proposals</div>
						</div>
						<div class="bg-yellow-100 p-3 rounded-lg text-center">
							<div class="text-2xl font-bold text-yellow-600">{groupInfo[0]?.totalRules || 0}</div>
							<div class="text-xs text-gray-600">Rules</div>
						</div>
					</div>
				{/if}
			</section>

		<!-- Create Proposal Section -->
		<section class="bg-white shadow-lg rounded-lg p-6 mb-8">
			<div class="flex justify-between items-center mb-4">
				<h2 class="text-2xl font-semibold text-blue-800">Proposals</h2>
				<button
					class="bg-blue-500 hover:bg-blue-700 text-white font-bold py-2 px-4 rounded"
					on:click={() => (showCreateProposal = !showCreateProposal)}
					disabled={assets.length === 0 || rules.length === 0}
				>
					{showCreateProposal ? 'Cancel' : 'Create Proposal'}
				</button>
			</div>

			{#if assets.length === 0 || rules.length === 0}
				<div class="bg-yellow-100 border-l-4 border-yellow-500 text-yellow-700 p-3 mb-4 text-sm">
					<p class="font-bold">Setup Required</p>
					<p>
						This group needs at least one asset and one rule before proposals can be created.
					</p>
				</div>
			{/if}

			{#if showCreateProposal}
				<div class="bg-gray-100 p-6 rounded-lg mb-6">
					<h3 class="text-xl font-semibold mb-4">New Proposal</h3>
					<form on:submit|preventDefault={handleCreateProposal}>
						<div class="grid grid-cols-1 md:grid-cols-2 gap-4 mb-4">
							<div>
								<label class="block text-gray-700 text-sm font-bold mb-2" for="assetId">
									Asset
								</label>
								<select
									id="assetId"
									bind:value={proposalForm.assetId}
									class="shadow appearance-none border rounded w-full py-2 px-3 text-gray-700 leading-tight focus:outline-none focus:shadow-outline"
									required
								>
									{#each assets as asset}
										<option value={asset.assetId}>
											#{asset.assetId} - {asset.description}
										</option>
									{/each}
								</select>
							</div>
							<div>
								<label class="block text-gray-700 text-sm font-bold mb-2" for="amount">
									Amount
								</label>
								<input
									id="amount"
									type="number"
									bind:value={proposalForm.amount}
									class="shadow appearance-none border rounded w-full py-2 px-3 text-gray-700 leading-tight focus:outline-none focus:shadow-outline"
									required
								/>
							</div>
							<div>
								<label class="block text-gray-700 text-sm font-bold mb-2" for="payee">
									Payee
								</label>
								<input
									id="payee"
									type="text"
									bind:value={proposalForm.payee}
									class="shadow appearance-none border rounded w-full py-2 px-3 text-gray-700 leading-tight focus:outline-none focus:shadow-outline"
									required
								/>
							</div>
							<div>
								<label class="block text-gray-700 text-sm font-bold mb-2" for="ruleId">
									Rule
								</label>
								<select
									id="ruleId"
									bind:value={proposalForm.ruleId}
									class="shadow appearance-none border rounded w-full py-2 px-3 text-gray-700 leading-tight focus:outline-none focus:shadow-outline"
									required
								>
									{#each rules as rule}
										<option value={rule.ruleId}>
											#{rule.ruleId} - Threshold: {rule.threshold}, Quorum: {rule.quorum}
										</option>
									{/each}
								</select>
							</div>
						</div>
						<div class="mb-4">
							<label class="block text-gray-700 text-sm font-bold mb-2" for="purpose">
								Purpose
							</label>
							<textarea
								id="purpose"
								bind:value={proposalForm.purpose}
								class="shadow appearance-none border rounded w-full py-2 px-3 text-gray-700 leading-tight focus:outline-none focus:shadow-outline"
								rows="3"
								required
							></textarea>
						</div>
						<div class="mb-4">
							<label class="block text-gray-700 text-sm font-bold mb-2" for="evidenceHash">
								Evidence Hash (Optional)
							</label>
							<input
								id="evidenceHash"
								type="text"
								bind:value={proposalForm.evidenceHash}
								class="shadow appearance-none border rounded w-full py-2 px-3 text-gray-700 leading-tight focus:outline-none focus:shadow-outline"
							/>
						</div>
						<button
							type="submit"
							class="bg-green-500 hover:bg-green-700 text-white font-bold py-2 px-4 rounded"
							disabled={loading}
						>
							{loading ? 'Creating...' : 'Submit Proposal'}
						</button>
					</form>
				</div>
			{/if}

			<!-- Proposals List -->
			{#if loading}
				<div class="text-center py-8">
					<div class="inline-block animate-spin rounded-full h-8 w-8 border-b-2 border-blue-600"></div>
					<p class="mt-2 text-gray-600">Loading proposals...</p>
				</div>
			{:else if error}
				<div class="bg-red-100 border-l-4 border-red-500 text-red-700 p-4" role="alert">
					<p class="font-bold">Error</p>
					<p>{error}</p>
				</div>
			{:else if proposals.length === 0}
				<div class="text-center py-8 text-gray-600">
					<p>No proposals found. Create the first one!</p>
				</div>
			{:else}
				<div class="space-y-4">
					{#each proposals as proposalAudit}
						<div class="border rounded-lg p-4 hover:shadow-md transition-shadow">
							<div class="flex justify-between items-start mb-3">
								<div>
									<h3 class="text-lg font-semibold text-gray-800">
										Proposal #{proposalAudit.proposal.proposalId}
									</h3>
									<p class="text-sm text-gray-600">
										Asset ID: {proposalAudit.proposal.assetId} | Amount: {proposalAudit.proposal.amount}
									</p>
								</div>
								<span
									class="px-3 py-1 rounded-full text-sm font-semibold {getStatusClass(
										proposalAudit.proposal.status
									)}"
								>
									{getStatusText(proposalAudit.proposal.status)}
								</span>
							</div>
							<p class="text-gray-700 mb-2">{proposalAudit.proposal.purpose}</p>
							<div class="text-sm text-gray-600 mb-3">
								<p>Payee: {proposalAudit.proposal.payee}</p>							<p>Group ID: {proposalAudit.proposal.groupId}</p>								<p>Created: {formatDate(proposalAudit.proposal.createdAt)}</p>
								<p>Votes: {proposalAudit.votes.length} | Rule: #{proposalAudit.rule.ruleId}</p>
								<p>Threshold: {proposalAudit.rule.threshold} | Quorum: {proposalAudit.rule.quorum}</p>
							</div>
							{#if 'pending' in proposalAudit.proposal.status}
								<button
									class="bg-blue-500 hover:bg-blue-700 text-white font-bold py-1 px-4 rounded text-sm"
									on:click={() => openVoteModal(proposalAudit)}
								>
									Vote
								</button>
							{/if}
						</div>
					{/each}
				</div>
			{/if}
		</section>
		{:else if selectedGroup && !selectedGroupId}
			<div class="text-center py-8 text-gray-600 bg-white rounded-lg shadow">
				<p class="text-lg font-semibold mb-2">📝 Governance Not Available</p>
				<p class="text-sm">This group only has native fund management.</p>
				<p class="text-sm mt-2">You can still view fund proposals in the Funds section.</p>
			</div>
		{:else if selectedGroupId}
			<div class="text-center py-8 text-gray-600 bg-white rounded-lg shadow">
				<p>Loading group information...</p>
			</div>
		{:else}
			<div class="text-center py-8 text-gray-600 bg-white rounded-lg shadow">
				<p>Please select a group to view governance data.</p>
			</div>
		{/if}
	{/if}
</main>

<!-- Vote Modal -->
{#if showVoteModal && selectedProposal}
	<div class="fixed inset-0 bg-gray-600 bg-opacity-50 overflow-y-auto h-full w-full z-50">
		<div class="relative top-20 mx-auto p-5 border w-96 shadow-lg rounded-md bg-white">
			<div class="mt-3 text-center">
				<h3 class="text-lg leading-6 font-medium text-gray-900">Vote on Proposal</h3>
				<div class="mt-2 px-7 py-3">
					<p class="text-sm text-gray-500 mb-4">
						Proposal #{selectedProposal.proposal.proposalId}
					</p>
					<p class="text-sm text-gray-700 mb-4">{selectedProposal.proposal.purpose}</p>
					<div class="flex justify-center space-x-4">
						<button
							class="bg-green-500 hover:bg-green-700 text-white font-bold py-2 px-6 rounded"
							on:click={() => handleVote(true)}
							disabled={loading}
						>
							Approve
						</button>
						<button
							class="bg-red-500 hover:bg-red-700 text-white font-bold py-2 px-6 rounded"
							on:click={() => handleVote(false)}
							disabled={loading}
						>
							Reject
						</button>
					</div>
				</div>
				<div class="items-center px-4 py-3">
					<button
						class="px-4 py-2 bg-gray-500 text-white text-base font-medium rounded-md w-full shadow-sm hover:bg-gray-600 focus:outline-none focus:ring-2 focus:ring-gray-300"
						on:click={() => (showVoteModal = false)}
					>
						Cancel
					</button>
				</div>
			</div>
		</div>
	</div>
{/if}
