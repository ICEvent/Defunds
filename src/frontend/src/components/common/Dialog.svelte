<script>
	export let isOpen = false;
	export let onClose = () => {};

	const closeDialog = () => {
		onClose();
	};
</script>

{#if isOpen}
	<button class="backdrop" on:click={closeDialog} aria-label="Close dialog">
		<button class="dialog" on:click|stopPropagation>
			<slot></slot>
		</button>
	</button>
{/if}

<style>
	.backdrop {
		position: fixed;
		top: 0;
		left: 0;
		width: 100%;
		height: 100%;
		background: rgba(0, 0, 0, 0.5);
		display: flex;
		align-items: center;
		justify-content: center;
		border: none;
		cursor: pointer;
	}

	.dialog {
		background: white;
		padding: 1rem;
		border-radius: 0.5rem;
		box-shadow: 0 2px 10px rgba(0, 0, 0, 0.1);
		max-width: 500px;
		width: 100%;

		border: none;
		padding: 0;
		margin: 0;
		cursor: pointer;
	}
</style>
