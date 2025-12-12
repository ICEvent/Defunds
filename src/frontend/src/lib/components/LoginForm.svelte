<script>
	export let closeLoginForm = () => {};
	import { onMount } from "svelte";
	import { HttpAgent } from "@dfinity/agent";
	import { AuthClient } from "@dfinity/auth-client";
	import { connectPlug, verifyConnection } from "$lib/utils/plug";
	import { globalStore, setAgent } from "$lib/store";

	import {
		DERIVATION_ORIGION,
		HOST_MAINNET,
		IDENTITY_PROVIDER,
	} from "$lib/constants";

	let isAuthed = false;
	let principal = "";
	let authClient = null;

	let windowFeatures = undefined;

	const isDesktop = window.innerWidth > 768;
	if (isDesktop) {
		const width = 500;
		const height = 600;
		const left = window.screenX + (window.innerWidth - width) / 2;
		const top = window.screenY + (window.innerHeight - height) / 2;
		windowFeatures = `left=${left},top=${top},width=${width},height=${height}`;
	}

	globalStore.subscribe((value) => {
		isAuthed = value.isAuthed;
		principal = value.principal;
	});

	//check plug connection
	// onMount(async () => {
	// 	let connect = await verifyConnection();
	// 	if (connect) {
	// 		setAgent(connect.agent);
	// 		globalStore.update((store) => {
	// 			return {
	// 				...store,
	// 				isAuthed: true,
	// 				principal: connect.principal,
					
	// 			};
	// 		});
	// 		closeLoginForm();
	// 	}
	// });

	async function handlePlugConnect() {
		const result = await connectPlug();
		if (result) {
			setAgent(result.agent);
			globalStore.update((store) => {
				return {
					...store,
					isAuthed: true,
					principal: result.principal,
				};
			});
			closeLoginForm();
		}
	}

	const handleAuthenticated = async (authClient) => {
		const identity = authClient.getIdentity();

		setAgent(
			new HttpAgent({
				identity,
				host: HOST_MAINNET,
			}),
		);

		globalStore.update((store) => {
			return {
				...store,
				isAuthed: true,
				principal: identity.getPrincipal(),
			};
		});
		closeLoginForm();
	};

	async function handleIILogin() {
		authClient = await AuthClient.create({
			idleOptions: {
				disableIdle: true,
				disableDefaultIdleCallback: true,
			},
		});

		authClient.login({
			// derivationOrigin: DERIVATION_ORIGION,
			identityProvider: IDENTITY_PROVIDER,
			windowOpenerFeatures: windowFeatures,
			onSuccess: () => {
				handleAuthenticated(authClient);
			},
		});
	}
</script>

<div class="flex flex-col items-center justify-center p-8 bg-white rounded-lg">
	<h2 class="text-3xl font-bold mb-8 text-gray-800">Welcome to Defunds</h2>

	<div class="flex flex-col space-y-6 w-full max-w-sm">
		<button
			class="flex items-center justify-center space-x-3 bg-gradient-to-r from-blue-500 to-blue-600 hover:from-blue-600 hover:to-blue-700 text-white font-semibold py-3 px-6 rounded-lg transform transition-all duration-200 hover:scale-105 shadow-md"
			on:click={() => handleIILogin("Internet Identity")}
		>
			<img src="/ii_logo.png" alt="Internet Identity" class="w-12 h-6" />
			<span> Internet Identity</span>
		</button>

		<!-- <div class="relative my-6">
			<div class="absolute inset-0 flex items-center">
				<div class="w-full border-t border-gray-300"></div>
			</div>
			<div class="relative flex justify-center text-sm">
				<span class="px-2 bg-white text-gray-500">or</span>
			</div>
		</div>

		<button
			class="flex items-center justify-center space-x-3 bg-gradient-to-r from-blue-500 to-blue-600 hover:from-blue-600 hover:to-blue-700 text-white font-semibold py-3 px-6 rounded-lg transform transition-all duration-200 hover:scale-105 shadow-md"
			on:click={() => handlePlugConnect()}
		>
			<img src="/plug_logo.png" alt="Plug Wallet" class="w-12 h-6" />
			<span> Plug Wallet</span>
		</button> -->
	</div>

	<p class="mt-6 text-sm text-gray-500">
		By continuing, you agree to our Terms of Service
	</p>
</div>
