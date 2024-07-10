<script>
	import { globalStore } from '../store';

	import { DEFUND_CANISTER_ID, HOST_MAINNET } from '$lib/constants';

	let isAuthed = false;
	let principal = '';

	globalStore.subscribe((value) => {
		isAuthed = value.isAuthed;
		principal = value.principal;
	});

  
	function handleIILogin() {

	}
	function handlePluginLogin() {
		(async () => {
			// Whitelist
			const whitelist = [DEFUND_CANISTER_ID];

			// Callback to print sessionData
			const onConnectionUpdate = () => {
				// console.log("principal:",window.ic.plug.principalId);
				// console.log(window.ic.plug.sessionManager.sessionData);
			};

			// Make the request
			try {
				const publicKey = await window.ic.plug.requestConnect({
					whitelist,
					HOST_MAINNET,
					onConnectionUpdate,
					timeout: 50000
				});
				console.log(`The connected user's public key is:`, publicKey.toString());
				let isConnected = await window.ic.plug.isConnected();
				if (isConnected) {
					globalStore.set({ isAuthed: true });
				}
				
			} catch (e) {
				console.log(e);
			}
		})();
		}
	function handleNFIDLogin() {
			(async () => {
			// Whitelist
			const whitelist = [DEFUND_CANISTER_ID];
			})
		}
  </script>
  
  <div class="flex flex-col items-center justify-center ">
	<h2 class="text-2xl font-bold mb-6">Defund Login</h2>
	<div class="flex flex-col space-y-4">
	  <button
		class="bg-blue-500 hover:bg-blue-700 text-white font-bold py-2 px-4 rounded"
		on:click={() => handleIILogin('Internet Identity')}>
		Internet Identity
	  </button>
	  <button
		class="bg-blue-500 hover:bg-blue-700 text-white font-bold py-2 px-4 rounded"
		on:click={() => handlePluginLogin('Plugin')}>
		Plugin Wallet
	  </button>
	  <button
		class="bg-blue-500 hover:bg-blue-700 text-white font-bold py-2 px-4 rounded"
		on:click={() => handleNFIDLogin('NFID')}>
		NFID
	  </button>
	</div>
  </div>