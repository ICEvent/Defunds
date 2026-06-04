<script>
	import { onMount } from 'svelte';
	import { Principal } from '@dfinity/principal';
	import { globalStore } from '$lib/store';
	import * as governanceAPI from '$lib/api/governance';

	let isAuthed = false;
	let principal = '';
	let governanceActor = null;
	let backendActor = null;
	let loading = false;
	let error = '';
	let councilLoading = false;
	let councilError = '';
	let councilSuccess = '';
	let councilMembers = [];
	let newCouncilMember = '';
	let councilApiUnavailable = false;

	function isMethodNotFoundError(error) {
		const message = String(error?.message || '').toLowerCase();
		return (
			message.includes('has no query method') ||
			message.includes('has no update method') ||
			message.includes('method not found') ||
			message.includes('canister has no')
		);
	}

	let systemInfo = {
		totalGroups: 0,
		totalMembers: 0,
		totalAssets: 0,
		totalProposals: 0,
		rulesVersion: 0,
	};

	let groups = [];
	let governanceGroups = [];
	let nativeGroups = [];

	onMount(() => {
		const unsubscribe = globalStore.subscribe(async (store) => {
			isAuthed = store.isAuthed;
			principal = store.principal?.toText?.() || '';
			governanceActor = store.governance;
			backendActor = store.backend;

			if (governanceActor) {
				await loadDashboard();
			}

			if (backendActor) {
				await loadCouncilMembers();
			}
		});

		return unsubscribe;
	});

	async function loadDashboard() {
		if (!governanceActor) return;

		loading = true;
		error = '';
		try {
			const [system, loadedGroups] = await Promise.all([
				governanceAPI.auditSystemInfo(governanceActor),
				governanceAPI.listGroups(governanceActor),
			]);

			systemInfo = system;
			groups = loadedGroups || [];
		} catch (err) {
			error = err?.message || 'Failed to load DAO data.';
		} finally {
			loading = false;
		}
	}

	async function loadCouncilMembers() {
		if (!backendActor || councilApiUnavailable) return;

		councilLoading = true;
		councilError = '';
		try {
			const members = await backendActor.getConcilMembers();
			councilMembers = (members || []).map((member) => member.toText());
		} catch (err) {
			if (isMethodNotFoundError(err)) {
				councilApiUnavailable = true;
				councilError = 'Council management is not available on the currently deployed backend version. Please deploy the latest backend canister.';
			} else {
				councilError = err?.message || 'Failed to load council members.';
			}
		} finally {
			councilLoading = false;
		}
	}

	async function addCouncilMember() {
		if (!backendActor || councilApiUnavailable) return;

		const candidate = newCouncilMember.trim();
		if (!candidate) {
			councilError = 'Council member principal is required.';
			return;
		}

		councilLoading = true;
		councilError = '';
		councilSuccess = '';
		try {
			const principalValue = Principal.fromText(candidate);
			const result = await backendActor.addConcilMember(principalValue);
			if ('ok' in result) {
				councilSuccess = 'Council member added.';
				newCouncilMember = '';
				await loadCouncilMembers();
			} else {
				councilError = result.err || 'Failed to add council member.';
			}
		} catch (err) {
			if (isMethodNotFoundError(err)) {
				councilApiUnavailable = true;
				councilError = 'Council management is not available on the currently deployed backend version. Please deploy the latest backend canister.';
			} else {
				councilError = err?.message || 'Failed to add council member.';
			}
		} finally {
			councilLoading = false;
		}
	}

	async function removeCouncilMember(memberText) {
		if (!backendActor || councilApiUnavailable) return;

		councilLoading = true;
		councilError = '';
		councilSuccess = '';
		try {
			const principalValue = Principal.fromText(memberText);
			const result = await backendActor.removeConcilMember(principalValue);
			if ('ok' in result) {
				councilSuccess = 'Council member removed.';
				await loadCouncilMembers();
			} else {
				councilError = result.err || 'Failed to remove council member.';
			}
		} catch (err) {
			if (isMethodNotFoundError(err)) {
				councilApiUnavailable = true;
				councilError = 'Council management is not available on the currently deployed backend version. Please deploy the latest backend canister.';
			} else {
				councilError = err?.message || 'Failed to remove council member.';
			}
		} finally {
			councilLoading = false;
		}
	}

	function groupId(group) {
		return group?.groupId ?? group?.id ?? null;
	}

	function memberCount(group) {
		if (typeof group?.memberCount === 'number') return group.memberCount;
		if (Array.isArray(group?.members)) return group.members.length;
		return 0;
	}

	function formatBalance(value) {
		if (value === null || value === undefined || value === '') return '0';
		return String(value);
	}

	$: governanceGroups = groups.filter((group) => group?.hasGovernance);
	$: nativeGroups = groups.filter((group) => group?.hasNativeFunds);
</script>

<main class="min-h-screen bg-slate-50">
	<section class="border-b border-slate-200 bg-gradient-to-br from-slate-950 via-slate-900 to-slate-800 text-white">
		<div class="container mx-auto px-4 py-16 lg:py-20">
			<div class="grid gap-10 lg:grid-cols-[1.3fr_0.7fr] lg:items-center">
				<div>
					<p class="mb-4 inline-flex rounded-full border border-sky-400/30 bg-sky-400/10 px-4 py-1 text-sm font-medium text-sky-200">
						DAO governance dashboard
					</p>
					<h1 class="max-w-3xl text-4xl font-bold tracking-tight sm:text-5xl">
						Coordinate treasury decisions, group voting, and fund operations in one place.
					</h1>
					<p class="mt-6 max-w-2xl text-lg leading-8 text-slate-300">
						The Defund DAO brings together public governance, group-level treasury controls, and transparent proposal workflows. Use this page to see the live state of the system and jump into the governance section when you are ready to act.
					</p>
					<div class="mt-8 flex flex-wrap gap-3">
						<a href="/governance" class="rounded-xl bg-sky-500 px-5 py-3 font-semibold text-white shadow-lg shadow-sky-500/20 transition hover:bg-sky-400">
							Open governance
						</a>
						<a href="/funds" class="rounded-xl border border-slate-700 bg-white/5 px-5 py-3 font-semibold text-slate-100 transition hover:border-slate-500 hover:bg-white/10">
							Explore funds
						</a>
					</div>
				</div>

				<div class="rounded-3xl border border-white/10 bg-white/5 p-6 shadow-2xl backdrop-blur">
					<div class="mb-6 flex items-center justify-between">
						<div>
							<p class="text-sm uppercase tracking-[0.2em] text-slate-400">Live status</p>
							<h2 class="mt-1 text-xl font-semibold">DAO snapshot</h2>
						</div>
						<div class="rounded-full bg-emerald-400/15 px-3 py-1 text-sm font-medium text-emerald-300">
							{governanceActor ? 'Connected' : 'Disconnected'}
						</div>
					</div>

					{#if error}
						<div class="mb-4 rounded-2xl border border-rose-500/20 bg-rose-500/10 p-4 text-sm text-rose-200">
							{error}
						</div>
					{/if}

					<div class="grid grid-cols-2 gap-4">
						<div class="rounded-2xl border border-white/10 bg-slate-950/40 p-4">
							<div class="text-sm text-slate-400">Funds</div>
							<div class="mt-2 text-3xl font-bold text-white">{systemInfo.totalGroups ?? groups.length}</div>
						</div>
						<div class="rounded-2xl border border-white/10 bg-slate-950/40 p-4">
							<div class="text-sm text-slate-400">Members</div>
							<div class="mt-2 text-3xl font-bold text-white">{systemInfo.totalMembers}</div>
						</div>
						<div class="rounded-2xl border border-white/10 bg-slate-950/40 p-4">
							<div class="text-sm text-slate-400">Assets</div>
							<div class="mt-2 text-3xl font-bold text-white">{systemInfo.totalAssets}</div>
						</div>
						<div class="rounded-2xl border border-white/10 bg-slate-950/40 p-4">
							<div class="text-sm text-slate-400">Proposals</div>
							<div class="mt-2 text-3xl font-bold text-white">{systemInfo.totalProposals}</div>
						</div>
					</div>
					<p class="mt-4 text-sm text-slate-400">
						{#if principal}
							Signed in as {principal}
						{:else}
							Sign in to create funds and vote on proposals.
						{/if}
					</p>
				</div>
			</div>
		</div>
	</section>

	<section class="container mx-auto px-4 py-12">
		<div class="rounded-3xl border border-slate-200 bg-white p-6 shadow-sm">
			<div class="mb-6 flex flex-wrap items-center justify-between gap-3">
				<div>
					<p class="text-sm font-semibold uppercase tracking-[0.2em] text-violet-600">Council members</p>
					<h2 class="mt-2 text-2xl font-bold tracking-tight text-slate-900">Manage council access</h2>
				</div>
				{#if councilLoading}
					<span class="text-sm font-medium text-slate-500">Updating...</span>
				{/if}
			</div>

			<div class="mb-4 grid gap-3 md:grid-cols-[1fr_auto]">
				<input
					type="text"
					bind:value={newCouncilMember}
					placeholder="Principal to add as council member"
					class="w-full rounded-xl border border-slate-300 px-4 py-3 text-slate-900 focus:border-violet-500 focus:outline-none"
				/>
				<button
					on:click={addCouncilMember}
					disabled={councilLoading || !isAuthed || councilApiUnavailable}
					class="rounded-xl bg-violet-600 px-5 py-3 font-semibold text-white transition hover:bg-violet-500 disabled:cursor-not-allowed disabled:bg-slate-300"
				>
					Add member
				</button>
			</div>

			{#if councilError}
				<div class="mb-4 rounded-xl border border-rose-200 bg-rose-50 px-4 py-3 text-sm text-rose-700">
					{councilError}
				</div>
			{/if}

			{#if councilSuccess}
				<div class="mb-4 rounded-xl border border-emerald-200 bg-emerald-50 px-4 py-3 text-sm text-emerald-700">
					{councilSuccess}
				</div>
			{/if}

			{#if !isAuthed}
				<div class="rounded-xl border border-amber-200 bg-amber-50 px-4 py-3 text-sm text-amber-700">
					Sign in to manage council members.
				</div>
			{/if}

			<div class="space-y-2">
				<div class="text-sm font-semibold text-slate-700">Current members ({councilMembers.length})</div>
				{#if councilMembers.length === 0}
					<p class="rounded-xl bg-slate-50 px-4 py-3 text-sm text-slate-500">No council members configured yet.</p>
				{:else}
					{#each councilMembers as member}
						<div class="flex flex-wrap items-center justify-between gap-3 rounded-xl border border-slate-200 px-4 py-3">
							<div class="font-mono text-sm text-slate-700 break-all">{member}</div>
							<button
								on:click={() => removeCouncilMember(member)}
								disabled={councilLoading || !isAuthed || councilApiUnavailable}
								class="rounded-lg bg-rose-600 px-3 py-2 text-xs font-semibold text-white transition hover:bg-rose-500 disabled:cursor-not-allowed disabled:bg-slate-300"
							>
								Remove
							</button>
						</div>
					{/each}
				{/if}
			</div>
		</div>
	</section>

	<section class="container mx-auto px-4 py-16">
		<div class="mb-8 flex items-end justify-between gap-4">
			<div>
				<p class="text-sm font-semibold uppercase tracking-[0.2em] text-sky-600">DAO structure</p>
				<h2 class="mt-2 text-3xl font-bold tracking-tight text-slate-900">How the system is organized</h2>
			</div>
			{#if loading}
				<div class="text-sm font-medium text-slate-500">Loading live data...</div>
			{/if}
		</div>

		<div class="grid gap-6 lg:grid-cols-3">
			<div class="rounded-3xl border border-slate-200 bg-white p-6 shadow-sm transition hover:-translate-y-1 hover:shadow-lg">
				<div class="text-sm font-semibold uppercase tracking-[0.2em] text-sky-600">Treasury</div>
				<h3 class="mt-3 text-2xl font-semibold text-slate-900">Funds and balances</h3>
				<p class="mt-3 leading-7 text-slate-600">
					Native funds and group balances are managed transparently so contributors can understand how resources are held and used.
				</p>
				<div class="mt-5 grid gap-3 text-sm text-slate-700">
					<div class="rounded-2xl bg-slate-50 px-4 py-3">Native funds: {nativeGroups.length}</div>
					<div class="rounded-2xl bg-slate-50 px-4 py-3">Total assets tracked: {systemInfo.totalAssets}</div>
				</div>
			</div>

			<div class="rounded-3xl border border-slate-200 bg-white p-6 shadow-sm transition hover:-translate-y-1 hover:shadow-lg">
				<div class="text-sm font-semibold uppercase tracking-[0.2em] text-violet-600">Council</div>
				<h3 class="mt-3 text-2xl font-semibold text-slate-900">Policy and approvals</h3>
				<p class="mt-3 leading-7 text-slate-600">
					Governance-enabled groups use rules and proposal flows to coordinate approvals, voting thresholds, and execution.
				</p>
				<div class="mt-5 grid gap-3 text-sm text-slate-700">
					<div class="rounded-2xl bg-slate-50 px-4 py-3">Governance-enabled funds: {governanceGroups.length}</div>
					<div class="rounded-2xl bg-slate-50 px-4 py-3">Rules version: {systemInfo.rulesVersion}</div>
				</div>
			</div>

			<div class="rounded-3xl border border-slate-200 bg-white p-6 shadow-sm transition hover:-translate-y-1 hover:shadow-lg">
				<div class="text-sm font-semibold uppercase tracking-[0.2em] text-emerald-600">Community</div>
				<h3 class="mt-3 text-2xl font-semibold text-slate-900">Participation and voting</h3>
				<p class="mt-3 leading-7 text-slate-600">
					The DAO is designed so contributors can follow proposals, inspect outcomes, and understand how voting power is distributed.
				</p>
				<div class="mt-5 grid gap-3 text-sm text-slate-700">
					<div class="rounded-2xl bg-slate-50 px-4 py-3">Members counted: {systemInfo.totalMembers}</div>
					<div class="rounded-2xl bg-slate-50 px-4 py-3">Proposals tracked: {systemInfo.totalProposals}</div>
				</div>
			</div>
		</div>
	</section>

	<section class="container mx-auto px-4 pb-16">
		<div class="mb-6 flex items-end justify-between gap-4">
			<div>
				<p class="text-sm font-semibold uppercase tracking-[0.2em] text-sky-600">Funds</p>
				<h2 class="mt-2 text-3xl font-bold tracking-tight text-slate-900">Governance-enabled funds</h2>
			</div>
			<a href="/governance" class="text-sm font-semibold text-sky-700 hover:text-sky-600">Open full governance view</a>
		</div>

		{#if governanceActor && groups.length === 0}
			<div class="rounded-3xl border border-dashed border-slate-300 bg-white p-8 text-center text-slate-500">
				No funds have been created yet. Create one in the governance section to start coordinating decisions.
			</div>
		{:else}
			<div class="grid gap-6 md:grid-cols-2 xl:grid-cols-3">
				{#each groups as group}
					<div class="rounded-3xl border border-slate-200 bg-white p-6 shadow-sm transition hover:-translate-y-1 hover:shadow-lg">
						<div class="flex items-start justify-between gap-4">
							<div>
								<p class="text-sm font-semibold uppercase tracking-[0.2em] text-slate-500">Fund {groupId(group)}</p>
								<h3 class="mt-2 text-xl font-semibold text-slate-900">{group.name}</h3>
							</div>
							<div class="rounded-full bg-sky-50 px-3 py-1 text-xs font-semibold text-sky-700">
								{group?.isPublic ? 'Public' : 'Private'}
							</div>
						</div>

						{#if group.description}
							<p class="mt-3 leading-7 text-slate-600">{group.description}</p>
						{/if}

						<div class="mt-5 grid grid-cols-2 gap-3 text-sm text-slate-700">
							<div class="rounded-2xl bg-slate-50 px-4 py-3">
								<div class="text-xs uppercase tracking-[0.2em] text-slate-500">Members</div>
								<div class="mt-1 text-lg font-semibold text-slate-900">{memberCount(group)}</div>
							</div>
							<div class="rounded-2xl bg-slate-50 px-4 py-3">
								<div class="text-xs uppercase tracking-[0.2em] text-slate-500">Balance</div>
								<div class="mt-1 text-lg font-semibold text-slate-900">{formatBalance(group.balance)}</div>
							</div>
						</div>

						<div class="mt-5 flex flex-wrap gap-2">
							{#if group?.hasNativeFunds}
								<span class="rounded-full bg-emerald-50 px-3 py-1 text-xs font-semibold text-emerald-700">Native funds</span>
							{/if}
							{#if group?.hasGovernance}
								<span class="rounded-full bg-violet-50 px-3 py-1 text-xs font-semibold text-violet-700">Governance enabled</span>
							{/if}
						</div>
					</div>
				{/each}
			</div>
		{/if}
	</section>
</main>