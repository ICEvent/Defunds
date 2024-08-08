<script>
	import ListItem from './Application/ListItem.svelte';
	import { globalStore } from '../../store';
	import { onMount } from 'svelte';
	import { DEFUND_CANISTER_ID, EXPLORER_PRINCIPAL, ICP_LEDGER_CANISTER_ID } from '$lib/constants';
	import {Principal} from '@dfinity/principal';

	let applications = [
		
	];
	let backend = null;

	onMount(async () => {
		const unsubscribe = globalStore.subscribe((store) => {
			backend = store.backend;
		});
		try {
			// let r = await backend.applyGrant({
			// 	amount: 1,
			// 	currency: ICP_LEDGER_CANISTER_ID,
			// 	description: 'Topup Defund treasury and application canister',
			// 	grantType: 'Develop',
			// 	recipient: Principal.fromText(DEFUND_CANISTER_ID),
			// 	reference: 'https://icevent/calendar/105',
			// 	title: 'Topup Canister'
			// });

			// console.log(r);

			const response = await backend.getGrants(0, 0);
			applications = response;
			console.log(applications);
		} catch (error) {
			console.error('Error fetching applications:', error);
		}
		return unsubscribe;
	});
</script>

<div class="w-full md:w-1/2">
	<h3 class="text-2xl font-bold mb-4 text-center">Applications</h3>
	{#each applications as app}
		<ListItem {app} />
	{/each}
</div>
