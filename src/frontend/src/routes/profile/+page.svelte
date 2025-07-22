<script>
	import "../../app.css";
	import { AuthClient } from "@dfinity/auth-client";
	import { globalStore } from "$lib/store.js"; // Import your global store

	import { onMount } from "svelte";
	import { goto } from "$app/navigation";

	import MenuItem from "$lib/components/Profile/MenuItem.svelte";

	import { FaMoneyBillWave } from "svelte-icons/fa";

	import ProfilePanel from "$lib/components/Profile/ProfilePanel.svelte";
	import ApplicationsPanel from "$lib/components/Profile/ApplicationsPanel.svelte";
	import DonationPanel from "$lib/components/Profile/DonationPanel.svelte";
	import GroupsPanel from "$lib/components/Profile/GroupPanel.svelte";

	//import { ProfileIcon, SettingsIcon, HistoryIcon } from '../../Icons.svelte';
	let activeMenuItem = "profile";
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
			goto("/");
		}

		authClient = await AuthClient.create({
			idleOptions: {
				disableIdle: true,
				disableDefaultIdleCallback: true,
			},
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

<div class="container max-w-7xl mx-auto px-4 sm:px-6 lg:px-8 py-8">
	<div
		class="profile-layout flex flex-col lg:flex-row gap-6 bg-white rounded-xl shadow-lg"
	>
		<!-- Menu Column -->
		<div class="menu-column w-full lg:w-80 p-6 lg:border-r border-gray-200">
			<!-- Avatar -->
			<div class="avatar-container">
				<img
					src="/defund_logo.jpg"
					alt="Avatar"
					class="w-24 sm:w-32 h-24 sm:h-32 rounded-full object-cover border-4 border-white shadow-lg transition-transform hover:scale-105"
				/>
			</div>

			<!-- Navigation -->
			<nav class="mt-8">
				<ul class="space-y-2">
					<MenuItem
						on:click={() => changeActiveMenu("profile")}
						active={activeMenuItem === "profile"}
						name="Profile"
					/>
					<MenuItem
						on:click={() => changeActiveMenu("donations")}
						active={activeMenuItem === "donations"}
						name="Donations"
					/>
					<MenuItem
						on:click={() => changeActiveMenu("applications")}
						active={activeMenuItem === "applications"}
						name="Applications"
					/>
					<MenuItem
						on:click={() => changeActiveMenu("groups")}
						active={activeMenuItem === "groups"}
						name="Group Funds"
					/>
				</ul>
			</nav>
		</div>

		<!-- Content Column -->
		<div class="content-column flex-1 p-4 sm:p-6 lg:p-8">
			{#if activeMenuItem === "profile"}
				<ProfilePanel />
			{:else if activeMenuItem === "donations"}
				<DonationPanel />
			{:else if activeMenuItem === "applications"}
				<ApplicationsPanel />
			{:else if activeMenuItem === "groups"}
				<GroupsPanel />
			{/if}
		</div>
	</div>
</div>

<style>
	:global(nav .menu-item) {
		@apply px-4 py-3 rounded-lg transition-all duration-200 cursor-pointer font-medium;
	}

	:global(nav .menu-item:hover) {
		@apply bg-gray-100;
	}

	:global(nav .menu-item.active) {
		@apply bg-gray-200 text-gray-900;
	}
</style>
