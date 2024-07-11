<script>
	import '../../app.css';
	import { AuthClient } from '@dfinity/auth-client';
	import { globalStore } from '../../store.js'; // Import your global store
	import Notifications from 'svelte-notifications';

	import { onMount } from 'svelte';
	import { goto } from '$app/navigation';
	import Navbar from '../../components/Navbar.svelte';
	import MenuItem from '../../components/Profile/MenuItem.svelte';
	//import { ProfileIcon, SettingsIcon, HistoryIcon } from '../../Icons.svelte';
	let activeMenuItem = 'profile';
	let isAuthed = false;
	let principal= undefined;
	let credit = 0;
	let backend = undefined;
	let authClient = null;

	onMount(async () => {
		// Subscribe to the global store to get the isAuthed value
		const unsubscribe = globalStore.subscribe((store) => {
			isAuthed = store.isAuthed;
			principal = store.principal;
			backend = store.backend;
		});

		// Check if the user is not authenticated
		if (!isAuthed) {
			// Redirect the user to the login page
			goto('/');
		}

		authClient = await AuthClient.create({
			idleOptions: {
				disableIdle: true,
				disableDefaultIdleCallback: true
			}
		});

		
		if (principal) {
			backend.getDonorCredit(principal.toText()).then((result) => {
				if (result.length > 0) {
					credit = result[0];
				}
			});
		}
		// Clean up the subscription when the component is unmounted
		return unsubscribe;
	});
</script>

<Notifications>
	<Navbar />
	<div class="container">
		<div class="profile-layout">
			<div class="menu-column">
				<!-- Avatar -->
				<div class="avatar-container">
					<img src="/defund_logo.jpg" alt="Avatar" class="avatar" />
				</div>
				<div>Credit: {credit}</div>
				
				<!-- Menu items go here -->
				<nav>
					<ul>
						<MenuItem bind:active={activeMenuItem} name="profile">Profile</MenuItem>
						<MenuItem bind:active={activeMenuItem} name="settings">Settings</MenuItem>
						<MenuItem bind:active={activeMenuItem} name="history">History</MenuItem>
						<MenuItem bind:active={activeMenuItem} on:click={authClient.logout()} name="logout">Logout</MenuItem>
					</ul>
				</nav>
			</div>

			<div class="content-column">
				<!-- Content based on active menu item -->
				{#if activeMenuItem === 'profile'}
					<h1>Welcome to your profile</h1>
					<div>Principal: {principal}</div>
					<p>This is where you can view and manage your profile information.</p>
				{:else if activeMenuItem === 'settings'}
					<h1>Settings</h1>
					<p>Manage your account settings here.</p>
				{:else if activeMenuItem === 'history'}
					<h1>History</h1>
					<p>View your donation history.</p>
				{/if}
			</div>
		</div>
	</div>
</Notifications>

<style>
	.container {
		max-width: 1200px; /* Adjust the maximum width as needed */
		margin: 0 auto; /* Center the container horizontally */
		padding: 20px; /* Add some padding around the container */
	}
	.profile-layout {
		display: flex;
	}

	.menu-column {
		flex: 0 0 200px; /* Adjust the width as needed */
		background-color: #f0f0f0; /* Optional background color for the menu column */
		padding: 20px;
	}
	.avatar-container {
		text-align: center; /* Center the avatar image horizontally */
		margin: 0 auto 20px; /* Center the avatar container vertically */
		display: flex; /* Use flexbox to center the avatar */
		justify-content: center; /* Center the avatar horizontally */
		align-items: center; /* Center the avatar vertically */
	}

	.avatar {
		width: 100px;
		height: 100px;
		border-radius: 50%;
		object-fit: cover;
	}
	.content-column {
		flex: 1;
		padding: 20px;
	}
</style>
