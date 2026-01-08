<script>
	import Dialog from "$lib/components/common/Dialog.svelte";
	import { AuthClient } from "@dfinity/auth-client";
	import { HttpAgent } from "@dfinity/agent";
	import { onMount, onDestroy } from "svelte";

	import { globalStore, setAgent } from "$lib/store";
	import { goto } from "$app/navigation";
	import LoginForm from "$lib/components/LoginForm.svelte";
	import { HOST_MAINNET } from "$lib/constants";

	let isAuthed = false;
	let principal = "";
	let showLoginDialog = false;
	let authClient = null;
	let unsubscribe;

	onMount(async () => {
		unsubscribe = globalStore.subscribe((value) => {
			isAuthed = value.isAuthed;
			principal = value.principal;
		});
		authClient = await AuthClient.create({
			idleOptions: {
				disableIdle: true,
				disableDefaultIdleCallback: true,
			},
		});

		if (await authClient.isAuthenticated()) {
			handleAuthenticated(authClient);
		}
	});

	onDestroy(() => {
		if (unsubscribe) {
			unsubscribe();
		}
	});
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
	};
	const handleLogout = async () => {
		if (authClient) {
			await authClient.logout();
			globalStore.set({
				isAuthed: false,
				principal: undefined,
				agent: null,
			});
			// Optional: Redirect to home page
			goto("/");
		}
	};
	function navigateToProfile() {
		// Instead of toggling the dropdown, navigate to the profile page
		goto("/profile"); // Navigate to the '/profile' route
	}
</script>

<nav class="bg-gray-700 py-4">
   <div class="container mx-auto px-4 flex justify-between items-center">
	   <a
		   href="/"
		   class="text-yellow-500 font-bold flex items-center text-2xl"
	   >
		   <img
			   src="/defund_logo.jpg"
			   alt="Defund Logo"
			   class="h-8 mr-2"
			   style="color: #FFD700;"
		   />
		   Defunds
	   </a>
	   <div class="flex items-center space-x-4">
		   <a href="/funds" class="text-white hover:text-yellow-400 font-semibold">Funds</a>
		   <a href="/governance" class="text-white hover:text-yellow-400 font-semibold">Governance</a>
		   {#if isAuthed}
			   <button
				   class="text-white hover:text-gray-300 focus:outline-none"
				   on:click={navigateToProfile}
			   >
				   Profile
			   </button>
			   <button
				   class="bg-blue-500 hover:bg-blue-700 text-white font-bold py-2 px-4 rounded"
				   on:click={handleLogout}
			   >
				   Logout
			   </button>
		   {:else}
			   <button
				   class="bg-blue-500 hover:bg-blue-700 text-white font-bold py-2 px-4 rounded"
				   on:click={() => (showLoginDialog = true)}
			   >
				   Login
			   </button>
		   {/if}
	   </div>
	   <Dialog
		   isOpen={showLoginDialog}
		   on:close={() => (showLoginDialog = false)}
	   >
		   <LoginForm closeLoginForm={() => (showLoginDialog = false)} />
	   </Dialog>
   </div>
</nav>
