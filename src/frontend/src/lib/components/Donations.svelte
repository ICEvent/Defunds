<script>
	import ListItem from './Donation/ListItem.svelte';
	import { globalStore } from '../../store';
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

<div class="w-full md:w-1/2 mb-8 md:mb-0 md:mr-4">
	<h3 class="text-2xl font-bold mb-4 text-center">Donations</h3>
	{#each donationHistory as donation}
		<ListItem {donation} />
	{/each}
</div>
