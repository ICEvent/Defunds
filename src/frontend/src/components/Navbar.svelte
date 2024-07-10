<script>
	import { globalStore } from '../store';
	import { goto } from '$app/navigation';
	import { DEFUND_CANISTER_ID, HOST_MAINNET } from '$lib/constants';

	let isAuthed = false;
	let principal = '';

	globalStore.subscribe((value) => {
		isAuthed = value.isAuthed;
		principal = value.principal;
	});

	const verifyConnection = async () => {
		const connected = await window.ic.plug.isConnected();
		if (!connected) await window.ic.plug.requestConnect({ whitelist, host });
	};
	function navigateToProfile() {
		// Instead of toggling the dropdown, navigate to the profile page
		goto('/profile'); // Navigate to the '/profile' route
	}
	function handleLogin() {
		(async () => {
			// Whitelist
			const whitelist = [DEFUND_CANISTER_ID];

			// Callback to print sessionData
			const onConnectionUpdate = () => {
				console.log(window.ic.plug.sessionManager.sessionData);
			};

			// Make the request
			try {
				const publicKey = await window.ic.plug.requestConnect({
					whitelist,
					HOST_MAINNET,
					onConnectionUpdate,
					timeout: 50000
				});
				console.log(`The connected user's public key is:`, publicKey);
				let isConnected = await window.ic.plug.isConnected();
				if (isConnected) {
					globalStore.set({ isAuthed: true, principal });
				}
			} catch (e) {
				console.log(e);
			}
		})();
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

<nav class="bg-gray-700 py-4">
	<div class="container mx-auto px-4 flex justify-between items-center">
		<a href="/" class="text-white font-bold flex items-center">
			<img src="/defund_logo.jpg" alt="Defund Logo" class="h-8 mr-2" />
			Defund
		</a>
		{#if isAuthed}
			<button
				class="text-white hover:text-gray-300 focus:outline-none"
				on:click={navigateToProfile}
			>
				Profile
			</button>
		{:else}
			<button
				class="bg-blue-500 hover:bg-blue-700 text-white font-bold py-2 px-4 rounded"
				on:click={handleLogin}
			>
				Login
			</button>
		{/if}
	</div>
</nav>
