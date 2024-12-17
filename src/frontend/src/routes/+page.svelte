<script>

	import Donations from '$lib/components/Donations.svelte';
	import Applications from '$lib/components/Applications.svelte';
	import TreasureBox from '$lib/components/TreasureBox.svelte';

</script>

<main class="container mx-auto px-4 py-8 bg-gray-100">

	<TreasureBox />
	<div class="grid grid-cols-1 md:grid-cols-2 gap-8 mt-8">
        <section class="w-full">
            <div class="flex justify-between items-center mb-4">
                <h2 class="text-2xl font-bold">Donations</h2>
                
            </div>
            <div class="w-full">
                <Donations />
                <a href="/donations" class="text-blue-500 hover:text-blue-700">More...</a>
            </div>
        </section>

        <section class="w-full">
            <div class="flex justify-between items-center mb-4">
                <h2 class="text-2xl font-bold">Applications</h2>
                
            </div>
            <div class="w-full">
                <Applications />
                <a href="/applications" class="text-blue-500 hover:text-blue-700">More...</a>
            </div>
        </section>
    </div>
</main>


<style>
	@import url('https://fonts.googleapis.com/css2?family=Inter:wght@400;600;700&display=swap');

	:global(body) {
		font-family: 'Inter', sans-serif;
	}

	
</style>
