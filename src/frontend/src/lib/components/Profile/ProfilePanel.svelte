<script>
    import { onMount } from 'svelte';
    import { globalStore } from '$lib/store';
    import { ICP_TOKEN_DECIMALS, VOTE_POWER_DECIMALS } from '$lib/constants';

    let principal;
    let icpledger;
    let backend;
    let balance = 0;
    let votingPower = 0;

    onMount(async () => {
        const unsubscribe = globalStore.subscribe((store) => {
            icpledger = store.icpledger;
            principal = store.principal;
            backend = store.backend;
        });

        if (backend && principal) {
            const power = await backend.getVotingPower(principal);
            if (power.length > 0) { 
                votingPower = Number(power[0].totalPower)/VOTE_POWER_DECIMALS;
            }
        }
        if (icpledger) {
            const icpbalance = await icpledger.icrc1_balance_of({
                owner: principal,
                subaccount: [],
            });
            balance = Number(icpbalance) / ICP_TOKEN_DECIMALS;
        };

        return unsubscribe;
    });
</script>

<div class="space-y-6">
    <div class="bg-white rounded-lg p-6 shadow-sm">
        <h2 class="text-xl font-semibold mb-4">Profile Information</h2>
        <div class="space-y-4">
            <div>
                <h3 class="text-sm text-gray-500 mb-1">Principal ID</h3>
                <code class="block bg-gray-50 p-3 rounded text-sm break-all">{principal}</code>
            </div>
            <div class="grid grid-cols-2 gap-4">
                <div class="bg-gray-50 p-4 rounded-lg">
                    <h3 class="text-sm font-medium text-gray-500">Voting Power</h3>
                    <p class="mt-2 text-2xl font-bold text-purple-600">{votingPower}</p>
                </div>
                <div class="bg-gray-50 p-4 rounded-lg">
                    <h3 class="text-sm font-medium text-gray-500">ICP</h3>
                    <p class="mt-2 text-2xl font-bold text-green-600">{balance}</p>
                </div>
                
            </div>
        </div>
    </div>
</div>
