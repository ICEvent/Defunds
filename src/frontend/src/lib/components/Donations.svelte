<script>
	import ListItem from '$lib/components/Donation/ListItem.svelte';
	import { globalStore } from '$lib/store';
	import { onMount } from 'svelte';
	import { HttpAgent } from '@dfinity/agent';
	import { Principal } from '@dfinity/principal';
	import * as ICPIndex from '$declarations/icp_index';
	import {
		DEFUND_CANISTER_ID,
		HOST_MAINNET,
		ICP_INDEX_CANISTER_ID,
		ICP_LEDGER_CANISTER_ID
	} from '$lib/constants';

	let donationHistory = [];
	let backend = null;
	let icpledger = null;
	let principal = null;

	onMount(async () => {
        const unsubscribe = globalStore.subscribe((store) => {
            icpledger = store.icpledger;

        });

        if (backend && principal) {
            const power = await backend.getVotingPower(principal);
            if (power.length > 0) { 
                votingPower = Number(power[0].totalPower)/VOTE_POWER_DECIMALS;
            }
        }
        if (icpledger && principal) {
            const icpbalance = await icpledger.icrc1_balance_of({
                owner: principal,
                subaccount: [],
            });
            balance = Number(icpbalance) / ICP_TOKEN_DECIMALS;
        };

        return unsubscribe;
    });
	onMount(async () => {
		let icpindex = ICPIndex.createActor(
			new HttpAgent({
				host: HOST_MAINNET
			}),
			ICP_INDEX_CANISTER_ID,
			{ actorOptions: {} }
		);
		let para = {
			max_results: 100,
			start: [],
			account: { owner: Principal.fromText(DEFUND_CANISTER_ID), subaccount: [] }
		};
		let trans = [];
		icpindex.get_account_transactions(para).then((result) => {
			console.log(result);
			let txs = result['Ok'].transactions;
			for (let i = 0; i < txs.length; i++) {
				let tx = txs[i].transaction;
				let transfer = tx.operation.Transfer;
				if (transfer) {
					trans.push({
						txid: txs[i].id,
						amount: transfer.amount.e8s,
						currency: ICP_LEDGER_CANISTER_ID,
						timestamp: tx.timestamp[0].timestamp_nanos,
						donor: transfer.from
					});
				}
			}
			console.log(trans);
			donationHistory = trans;
		});
		// const unsubscribe = globalStore.subscribe((store) => {
		// 	backend = store.backend;
		// });
		// try {
		// 	const response = await backend.getDonationHistory(0, 10, [], []);
		// 	donationHistory = response;
		// 	console.log(donationHistory);
		// } catch (error) {
		// 	console.error('Error fetching donation history:', error);
		// }
		// return unsubscribe;
	});
</script>
<div class="w-full">
    <div class="h-[600px] overflow-y-auto">
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

