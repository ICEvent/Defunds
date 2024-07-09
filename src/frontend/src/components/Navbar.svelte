<script>
	import { globalStore } from '../store';

	let isAuthed = false;
	let principal = '';

	globalStore.subscribe((value) => {
		isAuthed = value.isAuthed;
		principal = value.principal;
	});

	let showDropdown = false;

	const verifyConnection = async () => {
		const connected = await window.ic.plug.isConnected();
		if (!connected) await window.ic.plug.requestConnect({ whitelist, host });
	};

	function handleLogin() {
		(async () => {
			// Canister Ids
			const nnsCanisterId = 'qoctq-giaaa-aaaaa-aaaea-cai';

			// Whitelist
			const whitelist = [nnsCanisterId];

			// Host
			const host = 'https://mainnet.dfinity.network';

			// Callback to print sessionData
			const onConnectionUpdate = () => {
				console.log(window.ic.plug.sessionManager.sessionData);
			};

			// Make the request
			try {
				const publicKey = await window.ic.plug.requestConnect({
					whitelist,
					host,
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

	function toggleDropdown() {
		showDropdown = !showDropdown;
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
			<button class="text-white hover:text-gray-300 focus:outline-none" on:click={toggleDropdown}>
				Profile
			</button>
			{#if showDropdown}
				<div class="absolute right-0 mt-8 w-48 bg-white rounded-md shadow-lg z-10">
					<a href="#" class="block px-4 py-2 text-sm text-gray-700 hover:bg-gray-100"> Profile </a>
					<a
						href="#"
						class="block px-4 py-2 text-sm text-gray-700 hover:bg-gray-100"
						on:click={handleDonation}
					>
						Donate
					</a>

					<a href="#" class="block px-4 py-2 text-sm text-gray-700 hover:bg-gray-100"> Logout </a>
				</div>
			{/if}
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
