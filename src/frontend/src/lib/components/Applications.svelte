<script>
	import ListItem from '$lib/components/Application/ListItem.svelte';
	import { globalStore } from '$lib/store';
	import { onMount } from 'svelte';

	import { parseApplication } from '$lib/utils/grant.utils';

	let applications = [];
	let page = 0;
	let backend = null;
	
	onMount(async () => {
		const unsubscribe = globalStore.subscribe((store) => {
			backend = store.backend;
		});

		try {
			
		if (backend) {
			let rapplications = await backend.getGrants([{submitted:null},{review:null},{voting:null}], BigInt(page));
			applications = rapplications.map(parseApplication);
			console.log(applications);
		}
	
		} catch (error) {
			console.error('Error fetching applications:', error.message);
		}
		return unsubscribe;
	});

	let selectedStatus = 'all';
	
	$: filteredApplications = applications.filter(app => {
		if (selectedStatus === 'all') return true;
		return app.grantStatus.toLowerCase() === selectedStatus;
	});
</script>
	<div class="w-full">
		

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
