<script>
	import Dialog from './common/Dialog.svelte';
	import { AuthClient } from '@dfinity/auth-client';
	import { HttpAgent } from '@dfinity/agent';
	import { onMount } from 'svelte';

	import { globalStore, setAgent } from '../store';
	import { goto } from '$app/navigation';
	import LoginForm from './LoginForm.svelte';
	import { HOST_MAINNET } from '$lib/constants';

	let isAuthed = false;
	let principal = '';
	let showLoginDialog = false;
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
		console.log('principal: ' + identity.getPrincipal().toText());
		setAgent(
			new HttpAgent({
				identity,
				host: HOST_MAINNET
			})
		);
		globalStore.set({ isAuthed: true, principal: identity.getPrincipal().toText() });
	};
	function navigateToProfile() {
		// Instead of toggling the dropdown, navigate to the profile page
		goto('/profile'); // Navigate to the '/profile' route
	}
</script>

<nav class="bg-gray-700 py-4">
	<div class="container mx-auto px-4 flex justify-between items-center">
		<a href="/" class="text-white font-bold flex items-center">
			<img src="/defund_logo.jpg" alt="Defund Logo" class="h-8 mr-2" />
			Defund
		</a>
		{#if isAuthed}
		<div class="flex items-center space-x-4">
			<button
				class="text-white hover:text-gray-300 focus:outline-none"
				on:click={navigateToProfile}
			>
				Profile
			</button>
			<button
				class="bg-blue-500 hover:bg-blue-700 text-white font-bold py-2 px-4 rounded"
				on:click={() => (
					authClient.logout(), globalStore.set({ isAuthed: false, principal: undefined })
				)}
			>
				Logout
			</button>
		</div>
		{:else}
			<button
				class="bg-blue-500 hover:bg-blue-700 text-white font-bold py-2 px-4 rounded"
				on:click={() => (showLoginDialog = true)}
			>
				Login
			</button>
		{/if}
		<Dialog isOpen={showLoginDialog} on:close={() => (showLoginDialog = false)}>
			<LoginForm closeLoginForm={() => (showLoginDialog = false)} />
		</Dialog>
	</div>
</nav>
