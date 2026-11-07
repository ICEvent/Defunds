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


  // Never use the oneblock.page derivation origin while testing from localhost:
  // II only authorizes alternative origins registered by the derivation origin.
  const localLoanTest = import.meta.env.DEV &&
    import.meta.env.VITE_PERSONAL_LOAN_TEST_MODE === 'true';
  let authError = '';
  let windowFeatures = undefined;

  onMount(() => {
    if (window.innerWidth > 768) {
      const width = 500;
      const height = 600;
      const left = window.screenX + (window.innerWidth - width) / 2;
      const top = window.screenY + (window.innerHeight - height) / 2;
      windowFeatures = `left=${left},top=${top},width=${width},height=${height}`;
    }
    const unsubscribe = globalStore.subscribe(value => {
      isAuthed = value.isAuthed;
      principal = value.principal;
    });
    return unsubscribe;
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

  const handleAuthenticated = async (client) => {
    const identity = client.getIdentity();
    const host = localLoanTest
      ? import.meta.env.VITE_PERSONAL_LOAN_HOST
      : HOST_MAINNET;
    if (localLoanTest && !host) {
      authError = 'Local test is missing VITE_PERSONAL_LOAN_HOST';
      return;
    }
    const agent = new HttpAgent({ identity, host });
    if (localLoanTest) await agent.fetchRootKey();
    setAgent(agent);
    globalStore.update(store => ({
      ...store,
      isAuthed: true,
      principal: identity.getPrincipal()
    }));
    closeLoginForm();
  };

  async function handleIILogin() {
    authError = '';
    try {
      authClient = await AuthClient.create({
        idleOptions: {
          disableIdle: true,
          disableDefaultIdleCallback: true
        }
      });
      const provider = localLoanTest
        ? import.meta.env.VITE_PERSONAL_LOAN_IDENTITY_PROVIDER
        : IDENTITY_PROVIDER;
      if (!provider) throw new Error('Local Internet Identity URL is not configured');
      const options = {
        identityProvider: provider,
        windowOpenerFeatures: windowFeatures,
        onSuccess: async () => {
          try { await handleAuthenticated(authClient); }
          catch (error) { authError = error?.message || String(error); }
        },
        onError: error => {
          authError = error?.message || String(error || 'Internet Identity login failed');
        }
      };
      if (!localLoanTest) options.derivationOrigin = DERIVATION_ORIGION;
      await authClient.login(options);
    } catch (error) {
      authError = error?.message || String(error);
    }
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

	{#if authError}<p role="alert" class="mt-4 text-sm text-red-600">{authError}</p>{/if}
	<p class="mt-6 text-sm text-gray-500">
		By continuing, you agree to our Terms of Service
	</p>
</div>
