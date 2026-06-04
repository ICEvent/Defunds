<script>
    import { onMount } from 'svelte';

	import Donations from '$lib/components/Donations.svelte';
	import Applications from '$lib/components/Applications.svelte';
	import TreasureBox from '$lib/components/TreasureBox.svelte';
    import { globalStore } from '$lib/store';

    let backend;
    let concilMembers = [];
    let concilLoading = false;
    let concilError = '';
    let concilApiUnavailable = false;

    function isMethodNotFoundError(error) {
        const message = String(error?.message || '').toLowerCase();
        return (
            message.includes('has no query method') ||
            message.includes('method not found') ||
            message.includes('canister has no')
        );
    }

    onMount(() => {
        const unsubscribe = globalStore.subscribe((store) => {
            backend = store.backend;
            if (backend) {
                loadConcilMembers();
            }
        });

        return unsubscribe;
    });

    async function loadConcilMembers() {
        if (!backend || concilApiUnavailable) return;

        concilLoading = true;
        concilError = '';
        try {
            const members = await backend.getConcilMembers();
            concilMembers = (members || []).map((member) => member.toText());
        } catch (error) {
            if (isMethodNotFoundError(error)) {
                concilApiUnavailable = true;
                concilError = 'Council members are not available on the currently deployed backend version. Please deploy the latest backend canister.';
            } else {
                concilError = error?.message || 'Failed to load council members.';
            }
        } finally {
            concilLoading = false;
        }
    }

</script>

<main class="container mx-auto px-4 py-8">

	<TreasureBox />

    <section class="mt-8 w-full rounded-2xl border border-slate-800 bg-slate-900/60 p-5 shadow-finance">
        <div class="mb-3 flex items-center justify-between gap-3">
            <h2 class="text-2xl font-semibold text-slate-100">Council Members</h2>
            <a href="/dao" class="text-sm font-medium text-sky-300 hover:text-sky-200">Manage in DAO</a>
        </div>

        {#if concilLoading}
            <p class="text-sm text-slate-300">Loading council members...</p>
        {:else if concilError}
            <p class="rounded-lg border border-rose-800/60 bg-rose-900/20 px-3 py-2 text-sm text-rose-200">{concilError}</p>
        {:else if concilMembers.length === 0}
            <p class="text-sm text-slate-300">No council members configured yet.</p>
        {:else}
            <div class="grid grid-cols-1 gap-2 md:grid-cols-2">
                {#each concilMembers as member}
                    <div class="rounded-lg border border-slate-700 bg-slate-950/80 px-3 py-2 text-xs font-mono text-slate-200 break-all">
                        {member}
                    </div>
                {/each}
            </div>
        {/if}
    </section>

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
