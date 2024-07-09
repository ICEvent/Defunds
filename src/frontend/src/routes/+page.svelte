<script>
	import '../app.css';
	import Notifications from 'svelte-notifications';

	import Donations from '../components/Donations.svelte';
	import Applications from '../components/Applications.svelte';
	import TreasureBox from '../components/TreasureBox.svelte';
	import Navbar from '../components/Navbar.svelte';
	import Footer from '../components/Footer.svelte';
	
</script>
<Notifications>
<Navbar />
<main class="container mx-auto px-4 py-8 bg-gray-100">

	<TreasureBox />
	<div class="flex flex-col md:flex-row mt-8">
		<Donations />
		<Applications/>
	</div>
</main>
<Footer />
</Notifications>
<style>
	@import url('https://fonts.googleapis.com/css2?family=Inter:wght@400;600;700&display=swap');

	:global(body) {
		font-family: 'Inter', sans-serif;
	}

	
</style>
