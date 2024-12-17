<script>
	import "../../app.css";

	import { onMount } from "svelte";

	import { Principal } from "@dfinity/principal";

	import {
		DEFUND_CANISTER_ID,
		DEFUND_TREASURY_ACCOUNT,
		getTokenNameByID,
		ICP_LEDGER_CANISTER_ID,
		ICP_TOKEN_DECIMALS,
		VOTE_POWER_DECIMALS,
	} from "$lib/constants";
	import DonationForm from "$lib/components/Donation/DonationForm.svelte";
	import Dialog from "$lib/components/common/Dialog.svelte";

	import { globalStore } from "$lib/store"; // Import your global store

	let icpledger = undefined;
	let backend = undefined;

	let isAuthed = false;
	let showDonationForm = false;
	let showApplicationForm = false;
	let totalVotingPower = 0;

	globalStore.subscribe((value) => {
		icpledger = value.icpledger;
		isAuthed = value.isAuthed;
		backend = value.backend;
	});

	let totalDonations = 0;
	onMount(async () => {
		try {
			if (icpledger) {
				let balance = await icpledger.icrc1_balance_of({
					owner: Principal.fromText(DEFUND_CANISTER_ID),
					subaccount: [],
				});
				totalDonations = Number(balance) / ICP_TOKEN_DECIMALS;
			}
			if(backend) {
				totalVotingPower = await backend.getTotalVotingPower();
			}
			// icpledger = ICPLedger.createActor(
			// 	new HttpAgent({
			// 		host: HOST_MAINNET,
			// 	}),
			// 	ICP_LEDGER_CANISTER_ID,
			// 	{ actorOptions: {} },
			// );
		} catch (error) {
			console.error("Error fetching user balance:", error);
		}
	});

	
</script>

<div class="treasure-box-container bg-green-200 py-8">
	<header class="mb-8 text-center">
		<h1 class="text-4xl font-bold text-indigo-600 mb-8">
			Your Fund, You Decide
		</h1>
		<div class="mb-8">
			All Time Total Voting Power: {Number(totalVotingPower)/VOTE_POWER_DECIMALS}
			
		</div>
		<div class="relative inline-block">
			<div class="treasure-box bg-yellow-500 rounded-md p-4 shadow-md">
				<a
					href={DEFUND_TREASURY_ACCOUNT}
					target="_blank"
					rel="noopener noreferrer"
					class="text-lg text-white font-bold hover:underline"
				>
					{totalDonations}
					{getTokenNameByID(ICP_LEDGER_CANISTER_ID)}
				</a>
			</div>
		</div>
		
	</header>
</div>

<style>
	.treasure-box {
		position: relative;
		z-index: 1;
	}

	.treasure-box-container {
		background-color: #d9f7be; /* Light green color */
	}
</style>
