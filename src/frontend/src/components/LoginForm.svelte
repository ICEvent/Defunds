<script>
	export let closeLoginForm = () => {};

	import { HttpAgent } from '@dfinity/agent';
	import { AuthClient } from '@dfinity/auth-client';
	import { globalStore, setAgent } from '../store';

	import {
		DEFUND_CANISTER_ID,
		DERIVATION_ORIGION,
		HOST_MAINNET,
		IDENTITY_PROVIDER,
		ONE_WEEK_NS
	} from '$lib/constants';
	import { onMount } from 'svelte';

	let isAuthed = false;
	let principal = '';
	let authClient = null;

	globalStore.subscribe((value) => {
		isAuthed = value.isAuthed;
		principal = value.principal;
	});

	onMount(async () => {
		authClient = await AuthClient.create({
			idleOptions: {
				disableIdle: true,
				disableDefaultIdleCallback: true
			}
		});

		if (await authClient.isAuthenticated()) {
			handleAuthenticated(authClient);
		}
	});

	const handleAuthenticated = async (authClient) => {
		const identity = authClient.getIdentity();

		setAgent(
			new HttpAgent({
				identity,
				host: HOST_MAINNET
			})
		);
		
		globalStore.update((store) => {
						return {
							...store,
							isAuthed: true,
							principal: identity.getPrincipal()
						};
					});
		closeLoginForm();
	};
	function handleIILogin() {
		authClient.login({
			// derivationOrigin: DERIVATION_ORIGION,
			identityProvider: IDENTITY_PROVIDER,
			// maxTimeToLive: ONE_WEEK_NS,
			onSuccess: () => {
				handleAuthenticated(authClient);
			}
		});
	}
	function handlePluginLogin() {
		(async () => {
			// Whitelist
			const whitelist = [DEFUND_CANISTER_ID];

			// Callback to print sessionData
			const onConnectionUpdate = () => {
				setAgent(window.ic.plug.agent);
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
				console.log(`The connected user's public key is:`, publicKey);
				let isConnected = await window.ic.plug.isConnected();
				if (isConnected) {
					globalStore.update((store) => {
						return {
							...store,
							isAuthed: true
						};
					});
					closeLoginForm();
				}
			} catch (e) {
				console.log(e);
			}
		})();
	}
	function handleNFIDLogin() {
		async () => {
			// Whitelist
			const whitelist = [DEFUND_CANISTER_ID];
		};
	}
</script>

<div class="flex flex-col items-center justify-center">
	<h2 class="text-2xl font-bold mb-6">Defund Login</h2>
	<div class="flex flex-col space-y-4">
		<button
			class="bg-blue-500 hover:bg-blue-700 text-white font-bold py-2 px-4 rounded"
			on:click={() => handleIILogin('Internet Identity')}
		>
			Internet Identity
		</button>
		<button
			class="bg-blue-500 hover:bg-blue-700 text-white font-bold py-2 px-4 rounded"
			on:click={() => handlePluginLogin('Plugin')}
		>
			Plugin Wallet
		</button>
	</div>
</div>
