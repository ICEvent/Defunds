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

<nav class="border-b border-slate-800/80 bg-slate-950/95 py-4 backdrop-blur">
   <div class="container mx-auto flex items-center justify-between px-4">
	   <a
		   href="/"
		   class="flex items-center text-2xl font-semibold tracking-tight text-slate-100"
	   >
		   <img
			   src="/defund_logo.jpg"
			   alt="Defund Logo"
			   class="mr-2 h-8 w-8 rounded-md ring-1 ring-sky-400/30"
		   />
		   Defunds
	   </a>
	   <div class="flex items-center space-x-4 text-sm font-medium">
		   <a href="/funds" class="text-slate-300 hover:text-sky-300">Funds</a>
		   <!-- <a href="/ai-agent-fund" class="text-slate-300 hover:text-sky-300">AI Agent</a> -->
		   {#if isAuthed}
			   <button
				   class="text-slate-300 hover:text-sky-300 focus:outline-none"
				   on:click={navigateToProfile}
			   >
				   Profile
			   </button>
			   <button
				   class="rounded-lg border border-slate-700 bg-slate-900 px-4 py-2 text-slate-100 shadow-finance hover:border-sky-500/60 hover:text-sky-200"
				   on:click={handleLogout}
			   >
				   Logout
			   </button>
		   {:else}
			   <button
				   class="rounded-lg bg-sky-600 px-4 py-2 font-semibold text-white shadow-finance hover:bg-sky-500"
				   on:click={() => (showLoginDialog = true)}
			   >
				   Login
			   </button>
		   {/if}
	   </div>
   </div>
</nav>

<Dialog
	isOpen={showLoginDialog}
	on:close={() => (showLoginDialog = false)}
>
	<LoginForm closeLoginForm={() => (showLoginDialog = false)} />
</Dialog>
