<script>
	import ListItem from '$lib/components/Application/ListItem.svelte';
	import { globalStore } from '$lib/store';
	import { onMount } from 'svelte';

	import { parseApplication } from '$lib/utils/grant.utils';

	let applications = [
		
	];
	let backend = null;
	
	onMount(async () => {
		const unsubscribe = globalStore.subscribe((store) => {
			backend = store.backend;
		});

		try {
			
		if (backend) {
			let rapplications = await backend.getAllGrants();
			applications = rapplications.map(parseApplication);
			console.log(applications);
		}
	
		} catch (error) {
			console.error('Error fetching applications:', error);
		}
		return unsubscribe;
	});

	let selectedStatus = 'all';
	
	$: filteredApplications = applications.filter(app => {
		if (selectedStatus === 'all') return true;
		return app.grantStatus.toLowerCase() === selectedStatus;
	});
</script>
	<div class="w-full md:w-1/2">
		<div class="flex justify-between items-center mb-6">
			<h3 class="text-2xl font-bold">Applications</h3>
			<select 
				bind:value={selectedStatus}
				class="border rounded-lg px-4 py-2">
				<option value="all">All Status</option>
				<option value="submitted">Submitted</option>
				<option value="review">Review</option>
				<option value="voting">Voting</option>
				<option value="approved">Approved</option>
				<option value="rejected">Rejected</option>
				<option value="cancelled">Cancelled</option>
				<option value="expired">Expired</option>
			</select>
		</div>

		<div class="h-[600px] overflow-y-auto">
			{#each filteredApplications as app}
				<ListItem {app} />
			{/each}
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
