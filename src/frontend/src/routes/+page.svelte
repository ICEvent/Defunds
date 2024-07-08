<script>
	import '../index.scss';
	import { backend } from '$lib/canisters';

	let totalDonations = 0; // Replace with the actual total donations count
	let applications = [
		{ id: 1, name: 'Application 1', description: 'Description for Application 1' },
		{ id: 2, name: 'Application 2', description: 'Description for Application 2' }
		// Add more applications as needed
	];
	let donationHistory = [
		{ id: 1, amount: 100, date: '2023-05-01' },
		{ id: 2, amount: 200, date: '2023-04-15' }
		// Add more donation history entries as needed
	];
</script>

<main>
	<header>
		<h1>Know your donation</h1>
		<p>Treasury: {totalDonations}</p>
	</header>

	<div class="content">
    <div class="donation-history">
			<h2>Donation History</h2>
			{#each donationHistory as donation}
				<div class="history-item">
					<p>Amount: {donation.amount}</p>
					<p>Date: {donation.date}</p>
				</div>
			{/each}
		</div>
    <div class="applications">
			<h2>Applications</h2>
			{#each applications as app}
				<div class="card">
					<h3>{app.name}</h3>
					<p>{app.description}</p>
					<button>Vote</button>
				</div>
			{/each}
		</div>



	</div>
</main>

<style>
	header {
		text-align: center;
		margin-bottom: 2rem;
	}

	.content {
		display: flex;
		justify-content: space-between;
	}

	.applications {
		width: 48%;
	}

	.donation-history {
		width: 48%;
	}

	.card {
		border: 1px solid #ccc;
		padding: 1rem;
		margin-bottom: 1rem;
	}

	.history-item {
		border: 1px solid #ccc;
		padding: 1rem;
		margin-bottom: 1rem;
	}
</style>
