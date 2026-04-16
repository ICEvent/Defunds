<script>

	import Donations from '$lib/components/Donations.svelte';
	import Applications from '$lib/components/Applications.svelte';
	import TreasureBox from '$lib/components/TreasureBox.svelte';

</script>

<main class="container mx-auto px-4 py-8">

	<TreasureBox />
	<div class="mt-8 grid grid-cols-1 gap-8 md:grid-cols-2">
        <section class="w-full">
            <div class="mb-4 flex items-center justify-between">
                <h2 class="text-2xl font-semibold text-slate-100">Donations</h2>
                
            </div>
            <div class="w-full rounded-2xl border border-slate-800 bg-slate-900/60 p-4 shadow-finance">
                <Donations />
                <a href="/donations" class="text-sm font-medium text-sky-300 hover:text-sky-200">More...</a>
            </div>
        </section>

        <section class="w-full">
            <div class="mb-4 flex items-center justify-between">
                <h2 class="text-2xl font-semibold text-slate-100">Applications</h2>
                
            </div>
            <div class="w-full rounded-2xl border border-slate-800 bg-slate-900/60 p-4 shadow-finance">
                <Applications />
                <a href="/applications" class="text-sm font-medium text-sky-300 hover:text-sky-200">More...</a>
            </div>
        </section>
    </div>
</main>
