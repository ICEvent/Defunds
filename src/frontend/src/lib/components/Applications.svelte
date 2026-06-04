<script>
	import ListItem from '$lib/components/Application/ListItem.svelte';
	import { globalStore } from '$lib/store';
	import { onMount } from 'svelte';

	import { parseApplication } from '$lib/utils/grant.utils';

	let applications = [];
	let page = 0;
	let backend = null;
	let selectedStatus = 'voting';

	const statusOptions = [
		{ value: 'voting', label: 'Voting' },
		{ value: 'review', label: 'Review' },
		{ value: 'submitted', label: 'Submitted' },
		{ value: 'approved', label: 'Approved' },
		{ value: 'rejected', label: 'Rejected' },
		{ value: 'released', label: 'Released' },
		{ value: 'cancelled', label: 'Cancelled' },
		{ value: 'expired', label: 'Expired' },
		{ value: 'all', label: 'All' }
	];
	
	onMount(async () => {
		const unsubscribe = globalStore.subscribe((store) => {
			backend = store.backend;
		});

		try {
			
		if (backend) {
			let rapplications = await backend.getGrants(
				[
					{ submitted: null },
					{ review: null },
					{ voting: null },
					{ approved: null },
					{ rejected: null },
					{ released: null },
					{ cancelled: null },
					{ expired: null }
				],
				BigInt(page)
			);
			applications = rapplications.map(parseApplication);
			console.log(applications);
		}
	
		} catch (error) {
			console.error('Error fetching applications:', error.message);
		}
		return unsubscribe;
	});

	$: filteredApplications = applications.filter(app => {
		if (selectedStatus === 'all') return true;
		return app.grantStatus.toLowerCase() === selectedStatus;
	});
</script>
	<div class="w-full">
		<div class="mb-3 flex flex-wrap gap-2">
			{#each statusOptions as option}
				<button
					type="button"
					on:click={() => (selectedStatus = option.value)}
					class="rounded-full border px-3 py-1 text-xs font-medium transition-colors {selectedStatus === option.value
						? 'border-sky-400 bg-sky-500/20 text-sky-200'
						: 'border-slate-700 bg-slate-900 text-slate-300 hover:border-slate-500'}"
				>
					{option.label}
				</button>
			{/each}
		</div>

		<div class="h-[600px] overflow-y-auto">
			{#if filteredApplications.length === 0}
				<p class="rounded-lg border border-slate-700 bg-slate-900/80 p-4 text-sm text-slate-300">
					No {selectedStatus === 'all' ? '' : selectedStatus + ' '}applications found.
				</p>
			{:else}
				{#each filteredApplications as app}
					<ListItem {app} />
				{/each}
			{/if}
		</div>
	</div>

	<style>
		.overflow-y-auto {
			scrollbar-width: thin;
			scrollbar-color: #cbd5e1 #f1f5f9;
		}

		.overflow-y-auto::-webkit-scrollbar {
			width: 6px;
		}

		.overflow-y-auto::-webkit-scrollbar-track {
			background: #f1f5f9;
			border-radius: 3px;
		}

		.overflow-y-auto::-webkit-scrollbar-thumb {
			background-color: #cbd5e1;
			border-radius: 3px;
		}
	</style>
