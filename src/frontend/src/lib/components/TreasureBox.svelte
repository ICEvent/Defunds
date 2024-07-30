<script>
	import '../../app.css';
	
	import { onMount } from 'svelte';
	import { getNotificationsContext } from 'svelte-notifications';

	import { getAgent } from '$lib/utils/agent.utils';
	import { createActor } from '$lib/utils/actor.utils';
	import { HttpAgent } from "@dfinity/agent";
	import { Principal } from "@dfinity/principal";
	import * as ICPLedger from "$declarations/icrc1_ledger_canister";

	import { DEFUND_CANISTER_ID, DEFUND_TREASURY_ACCOUNT,HOST_MAINNET, getTokenNameByID, ICP_LEDGER_CANISTER_ID, ICP_TOKEN_DECIMALS } from '$lib/constants';
	import DonationForm from './Donation/DonationForm.svelte';
	import Dialog from './common/Dialog.svelte';

	import { globalStore } from '../../store'; // Import your global store

	let icpledger = undefined;
	let backend	= undefined;

	let isAuthed = false;
	let showDonationForm = false;
	let showApplicationForm = false;

	const { addNotification } = getNotificationsContext();

	globalStore.subscribe((value) => {
		icpledger = value.icpledger;
		isAuthed = value.isAuthed;
		backend = value.backend;
	});

	let totalDonations = 0;
	onMount(async () => {
		try {
			icpledger = ICPLedger.createActor(new HttpAgent({
        host: HOST_MAINNET
    }), ICP_LEDGER_CANISTER_ID, { actorOptions: {} });
			let balance = await icpledger.icrc1_balance_of({
				owner: Principal.fromText(DEFUND_CANISTER_ID),
				subaccount: []
			});
			totalDonations = Number(balance) / ICP_TOKEN_DECIMALS;
		} catch (error) {
			console.error('Error fetching user balance:', error);
		}
	});

	function handleDonation() {
		if (!isAuthed) {
			addNotification({
				text: 'Please login to donate',
				type: 'error',
				position: 'top-right'
			});
		} else {
			showDonationForm = true;
		}
	}
	function handleApplication() {
		if (!isAuthed) {
			addNotification({
				text: 'Please login to apply',
				type: 'error',
				position: 'top-right'
			});
		} else {
			showApplicationForm = true;
		}
	}

	function submitDonation(event) {
		// Call the backend function to process the donation
		// with the provided amount and currency
		const {amount, currency} = event.detail;
		const params = {
			to: DEFUND_CANISTER_ID,
			amount: amount * ICP_TOKEN_DECIMALS,
			memo: 'donate fund'
		};
		console.log(params);
		// window.ic.plug
		// 	.requestTransfer(params)
		// 	.then((result) => {
		// 		if (result.ok) {
		// 			// Handle successful donation
		// 			console.log(`Donated ${donationAmount} ${selectedCurrency} successfully!`);
					backend.donate(amount,ICP_LEDGER_CANISTER_ID,{txid:""}
						).then((result) => {
						if (result.ok) {
							// Handle successful donation
							console.log(`Donated ${amount} ${currency} successfully!`);
							addNotification({
								text: `Donated ${amount} ${currency} successfully!`,
								type:'success',
								position: 'top-right'
							});
							showDonationForm = false;
						} else {
							// Handle donation error
							console.error(`Error donating: ${result.err}`);
							addNotification({
								text: `Error donating: ${result.err}`,
								type: 'error',
								position: 'top-right'
							});
						}
					})
			// 	} else {
			// 		// Handle donation error
			// 		console.error(`Error donating: ${result.err}`);
			// 	}
			// })
			// .catch((error) => {
			// 	console.error('Error donating:', error);
			// })
			// .finally(() => {
			// 	showDonationForm = false;
			// 	donationAmount = '';
			// });
	}
</script>

<div class="treasure-box-container bg-green-200 py-8">
	<header class="mb-8 text-center">
		<h1 class="text-4xl font-bold text-indigo-600 mb-8">Know Your Donation</h1>
		<div class="relative inline-block mb-4">
			<div class="treasure-box bg-yellow-500 rounded-md p-4 shadow-md">
				<a href={DEFUND_TREASURY_ACCOUNT} target="_blank" rel="noopener noreferrer" class="text-lg text-white font-bold hover:underline">
					{totalDonations} {getTokenNameByID(ICP_LEDGER_CANISTER_ID)}
				</a>
			</div>
			<div class="treasure-lid bg-yellow-600 rounded-t-md absolute top-0 left-0 w-full h-2"></div>
		</div>
		<!-- <div class="flex justify-center space-x-4">
			<button
				class="bg-indigo-600 hover:bg-indigo-700 text-white font-bold py-1.5 px-3 rounded-md text-sm"
				on:click={handleDonation}
			>
				Donate
			</button>
			<button
				class="bg-indigo-600 hover:bg-indigo-700 text-white font-bold py-1.5 px-3 rounded-md text-sm"
				on:click={handleApplication}
			>
				Apply
			</button>
		</div> -->
		<Dialog isOpen={showDonationForm} on:close={() => (showDonationForm = false)}>
			<DonationForm on:submit={submitDonation} cancel={() => (showDonationForm = false)} />
		</Dialog>
	</header>
</div>

<style>
	.treasure-box {
		position: relative;
		z-index: 1;
	}

	.treasure-lid {
		z-index: 2;
	}

	.treasure-box-container {
		background-color: #d9f7be; /* Light green color */
	}
</style>
