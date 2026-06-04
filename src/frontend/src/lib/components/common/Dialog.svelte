<script>
	export let isOpen = false;
	export let onClose = () => {};

	const closeDialog = () => {
		onClose();
	};

	const handleKeydown = (event) => {
		if (event.key === 'Escape') {
			closeDialog();
		}
	};
</script>

{#if isOpen}
	<div class="backdrop-container">
		<div
			class="backdrop"
			role="button"
			tabindex="0"
			aria-label="Close dialog"
			on:click={closeDialog}
			on:keydown={handleKeydown}
		>
			<div
				class="dialog"
				role="dialog"
				aria-modal="true"
				on:click|stopPropagation
			>
				<div class="dialog-content">
					<slot></slot>
				</div>
			</div>
		</div>
	</div>
{/if}

<style>
	.backdrop-container {
		position: fixed;
		top: 0;
		left: 0;
		width: 100%;
		height: 100%;
		z-index: 10000;
	}

	.backdrop {
		position: fixed;
		inset: 0;
		width: 100%;
		min-height: 100dvh;
		background: rgba(0, 0, 0, 0.6);
		display: flex;
		align-items: center;
		justify-content: center;
		border: none;
		padding: 1rem;
		margin: 0;
		cursor: pointer;
		animation: fadeIn 0.2s ease-out;
	}

	.dialog {
		background: white;
		border-radius: 0.75rem;
		box-shadow: 0 4px 20px rgba(0, 0, 0, 0.15);
		max-width: 500px;
		width: 90%;
		max-height: calc(100dvh - 2rem);
		overflow: auto;
		position: relative;
		animation: slideIn 0.3s ease-out;
		border: none;
		padding: 0;
		margin: 0;
	}

	.dialog-content {
		padding: 1.5rem;
	}

	@keyframes fadeIn {
		from { opacity: 0; }
		to { opacity: 1; }
	}

	@keyframes slideIn {
		from { 
			transform: translateY(-20px);
			opacity: 0;
		}
		to { 
			transform: translateY(0);
			opacity: 1;
		}
	}
</style>
