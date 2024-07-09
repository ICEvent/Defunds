<script>
	import '../app.css';

    import { createActor } from '../../../declarations/icrc';

	import { Principal } from '@dfinity/principal';

	let totalDonations = 0;
    let icrc = createActor("ryjl3-tyaaa-aaaaa-aaaba-cai");

	async function  fetchBalance(){
		const result = await icrc.icrc1_icrc1_feebalance_of({"owner":Principal.fromText('zrbbd-7qzdb-xp7r4-v3du3-sulj4-7fwm2-3v3hr-vitzv-4nnsy-mzeab-aae'),"subaccount":[]});
        console.log("balance:  ",result);
	}
    

	function handleDonation() {
		(async () => {
			const params = {
				to: 'be2us-64aaa-aaaaa-qaabq-cai',
				strAmount: '0.01',
				token: 'qoctq-giaaa-aaaaa-aaaea-cai'
			};
			const result = await window.ic.plug.requestTransferToken(params);
			console.log(result);
		})();
	}
</script>

<div class="treasure-box-container bg-green-200 py-8">
	<header class="mb-8 text-center">
		<h1 class="text-4xl font-bold text-indigo-600 mb-2">Know Your Donation</h1>
		<div class="relative inline-block mb-4">
			<div class="treasure-box bg-yellow-500 rounded-md p-4 shadow-md">
				<p class="text-lg text-white font-bold">Treasury : {totalDonations} ICP</p>
				<button on:click={fetchBalance}>fetch</button>
			</div>
			<div class="treasure-lid bg-yellow-600 rounded-t-md absolute top-0 left-0 w-full h-2"></div>
		</div>
		<div class="flex justify-center space-x-4">
			<button
				class="bg-indigo-600 hover:bg-indigo-700 text-white font-bold py-1.5 px-3 rounded-md text-sm"
				on:click={handleDonation}
			>
				Donate
			</button>
			<button
				class="bg-indigo-600 hover:bg-indigo-700 text-white font-bold py-1.5 px-3 rounded-md text-sm"
			>
				Apply
			</button>
		</div>
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
