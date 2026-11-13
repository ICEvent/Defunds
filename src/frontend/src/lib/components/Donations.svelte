<script>
    import ListItem from '$lib/components/Donation/ListItem.svelte';
    import { onMount } from 'svelte';
    import { HttpAgent } from '@dfinity/agent';
    import { Principal } from '@dfinity/principal';
    import * as ICPIndex from '$declarations/icp_index';
    import { DEFUND_CANISTER_ID, HOST_MAINNET, ICP_INDEX_CANISTER_ID, ICP_LEDGER_CANISTER_ID, DEFUND_TREASURY_ACCOUNT } from '$lib/constants';
    import { parseDonationTransactions } from '$lib/utils/donation-history.js';

    let donationHistory = [];
    let loading = true;
    let error = '';

    async function loadDonations() {
        loading = true;
        error = '';
        try {
            const index = ICPIndex.createActor(ICP_INDEX_CANISTER_ID, {
                agent: new HttpAgent({ host: HOST_MAINNET })
            });
            const result = await index.get_account_transactions({
                max_results: 30n,
                start: [],
                account: { owner: Principal.fromText(DEFUND_CANISTER_ID), subaccount: [] }
            });
            donationHistory = parseDonationTransactions(result, DEFUND_TREASURY_ACCOUNT.split('/').pop(), ICP_LEDGER_CANISTER_ID);
        } catch (cause) {
            error = cause?.message || 'Failed to load donations.';
        } finally {
            loading = false;
        }
    }

    onMount(() => { loadDonations(); });
</script>
<div class="w-full">
    <div class="h-[600px] overflow-y-auto">
        {#if loading}
            <p class="text-sm text-slate-300" role="status">Loading donations...</p>
        {:else if error}
            <p class="text-sm text-rose-200" role="alert">{error}</p>
            <button type="button" class="text-sky-300" on:click={loadDonations}>Retry</button>
        {:else if donationHistory.length === 0}
            <p class="text-sm text-slate-300">No incoming donations in the latest 30 treasury transactions.</p>
        {/if}
        {#each donationHistory as donation}
            <ListItem {donation} />
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

