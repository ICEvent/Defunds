<script>
	import { createEventDispatcher } from 'svelte';

   
	export let cancel = () => {};

    const dispatch = createEventDispatcher();
	let amount = 1;
	let selectedCurrency = 'ICP';
	const supportedCurrencies = ['ICP', 'BTC', 'ETH', 'USDC'];

	const handleSubmit = () => {
		const formData = {
			amount: amount,
			currency: selectedCurrency
		};
		dispatch('submit', formData);
		resetForm();
	};

	const resetForm = () => {
		amount = '';
		selectedCurrency = 'ICP';
	};
</script>

<div>
	
	<form on:submit={handleSubmit}>
        <h2>Make Your Donate</h2>
		<div>
			<label for="amount">Amount(ICP):</label>
			<input type="number" id="amount" bind:value={amount} placeholder="Amount(ICP)" required />
		</div>
		<!-- <div>
			<label for="currency">Currency:</label>
			<select id="currency" bind:value={selectedCurrency}>
				{#each supportedCurrencies as currency}
					<option value={currency}>{currency}</option>
				{/each}
			</select>
		</div> -->
		<div class="button-group">
			<button type="submit" class="primary">Donate</button>
			<button type="button" on:click={cancel} class="secondary">Cancel</button>
		</div>
	</form>
</div>

<style>
	form {
		display: flex;
		flex-direction: column;
		gap: 1rem;
	}

	.button-group {
		display: flex;
		justify-content: center;
		gap: 0.5rem;
	}
    .primary {
		background-color: #4caf50; /* Green */
		color: white;
		padding: 0.5rem 1rem;
		border: none;
		border-radius: 4px;
		cursor: pointer;
	}

	.secondary {
		background-color: #ccc; /* Gray */
		color: black;
		padding: 0.5rem 1rem;
		border: none;
		border-radius: 4px;
		cursor: pointer;
	}
</style>
