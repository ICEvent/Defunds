<script>
	import '../app.css';
	import Notifications from 'svelte-notifications';

	import Donations from '$lib/components/Donations.svelte';
	import Applications from '$lib/components/Applications.svelte';
	import TreasureBox from '$lib/components/TreasureBox.svelte';

	export let data;
</script>
<Notifications>

<main class="container mx-auto px-4 py-8 bg-gray-100">

	<TreasureBox totalDonations={data.totalDonations} />
	<div class="flex flex-col md:flex-row mt-8">
		<Donations donationHistory={data.donationHistory}/>
		<Applications/>
	</div>
</main>

</Notifications>
<style>
	@import url('https://fonts.googleapis.com/css2?family=Inter:wght@400;600;700&display=swap');

	:global(body) {
		font-family: 'Inter', sans-serif;
	}

	
</style>
