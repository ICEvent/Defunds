<script>
	import Dialog from './common/Dialog.svelte';
	import { globalStore } from '../store';
	import { goto } from '$app/navigation';
	import LoginForm from './LoginForm.svelte';

	let isAuthed = false;
	let principal = '';
	let showLoginDialog = false;

	globalStore.subscribe((value) => {
		isAuthed = value.isAuthed;
		principal = value.principal;
	});

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
			<button
				class="text-white hover:text-gray-300 focus:outline-none"
				on:click={navigateToProfile}
			>
				Profile
			</button>
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
