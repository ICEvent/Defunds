<script>
	import '../../app.css';
	import { AuthClient } from '@dfinity/auth-client';
	import { globalStore } from '../../store.js'; // Import your global store
	import Notifications from 'svelte-notifications';

	import { onMount } from 'svelte';
	import { goto } from '$app/navigation';

	import MenuItem from '$lib/components/Profile/MenuItem.svelte';
	import ApplicationsPanel from '$lib/components/Profile/ApplicationsPanel.svelte';
	//import { ProfileIcon, SettingsIcon, HistoryIcon } from '../../Icons.svelte';
	let activeMenuItem = 'profile';
	let isAuthed = false;
	let principal = undefined;
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
	function changeActiveMenu(menuName) {
		activeMenuItem = menuName;
		// You can add additional logic here if needed
	}
</script>

<Notifications>
	<div class="container">
		<div class="profile-layout">
			<div class="menu-column">
				<!-- Avatar -->
				<div class="avatar-container">
					<img src="/defund_logo.jpg" alt="Avatar" class="avatar" />
				</div>
				<div class="credit-display">
					Available Credit: {credit} ICP
				</div>
					<!-- Menu items go here -->
					<nav>
						<ul>
							<MenuItem
								on:click={() => changeActiveMenu('profile')}
								active={activeMenuItem === 'profile'}
								name="Profile" />
							<MenuItem
								on:click={() => changeActiveMenu('donations')}
								active={activeMenuItem === 'donations'}
								name="Donations" />
							<MenuItem
								on:click={() => changeActiveMenu('applications')}
								active={activeMenuItem === 'applications'}
								name="Applications" />
						</ul>
					</nav>
					
			</div>
			<div class="content-column">
				<!-- Content based on active menu item -->
				{#if activeMenuItem === 'profile'}
					<h1>Welcome to your profile</h1>
					<div class="principal-display">
						Principal ID: {principal}
					</div>
				{:else if activeMenuItem === 'donations'}
					<h1>Settings</h1>
					<p>Manage your account settings here.</p>
				{:else if activeMenuItem === 'applications'}
				<ApplicationsPanel />
				{/if}
			</div>
		</div>
	</div>
</Notifications>
	<style>
		.container {
			max-width: 1200px;
			margin: 0 auto;
			padding: 40px 20px;
			min-height: 100vh;
			background-color: #fafafa;
		}

		.profile-layout {
			display: flex;
			gap: 40px;
			background-color: white;
			border-radius: 12px;
			box-shadow: 0 2px 8px rgba(0, 0, 0, 0.08);
		}

		.menu-column {
			flex: 0 0 280px;
			background-color: white;
			padding: 32px 24px;
			border-right: 1px solid #eaeaea;
			min-height: 600px;
		}

		.avatar-container {
			text-align: center;
			margin: 0 auto 32px;
			display: flex;
			flex-direction: column;
			gap: 16px;
			align-items: center;
		}

		.avatar {
			width: 120px;
			height: 120px;
			border-radius: 50%;
			object-fit: cover;
			border: 4px solid #ffffff;
			box-shadow: 0 2px 12px rgba(0, 0, 0, 0.1);
			transition: transform 0.2s ease;
		}

		.avatar:hover {
			transform: scale(1.05);
		}

		.content-column {
			flex: 1;
			padding: 32px;
			background-color: white;
		}

		.credit-display {
			background-color: #f8f9fa;
			padding: 12px 16px;
			border-radius: 8px;
			font-weight: 600;
			color: #2d3748;
			margin-bottom: 24px;
			text-align: center;
		}

		h1 {
			color: #1a202c;
			font-size: 24px;
			margin-bottom: 24px;
			font-weight: 600;
		}

		.principal-display {
			background-color: #f8f9fa;
			padding: 16px;
			border-radius: 8px;
			word-break: break-all;
			font-family: monospace;
			font-size: 14px;
		}

		nav {
			margin-top: 24px;
		}

		nav ul {
			list-style: none;
			padding: 0;
			margin: 0;
			display: flex;
			flex-direction: column;
			gap: 8px;
		}

		:global(nav .menu-item) {
			padding: 12px 16px;
			border-radius: 8px;
			transition: all 0.2s ease;
			cursor: pointer;
			font-weight: 500;
		}

		:global(nav .menu-item:hover) {
			background-color: #f3f4f6;
		}

		:global(nav .menu-item.active) {
			background-color: #e5e7eb;
			color: #1a202c;
		}
	</style>
