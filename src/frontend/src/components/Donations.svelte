<script>
	import ListItem from './Donation/ListItem.svelte';
	import { globalStore } from '../store';
	import { onMount } from 'svelte';
	let donationHistory = [];
	let backend = null;

	onMount(async () => {
		const unsubscribe = globalStore.subscribe((store) => {
			backend = store.backend;
		});
		try {
			const response = await backend.getDonationHistory(0, 3, [], []);
			donationHistory = response;
		} catch (error) {
			console.error('Error fetching donation history:', error);
		}
		return unsubscribe;
	});
</script>

<div class="w-full md:w-1/2 mb-8 md:mb-0 md:mr-4">
	<h3 class="text-2xl font-bold mb-4 text-center">Donations</h3>
	{#each donationHistory as donation}
		<ListItem {donation} />
	{/each}
</div>
