<script>
	export let name;

	export let active;
</script>

<button
	type="button"
	class="menu-item"
	class:active
	on:click
	on:keydown={(e) => e.key === 'Enter' && e.target.click()}
>
	<span>{name}</span>
</button>

<style>
	.menu-item {
		border-bottom: 1px solid #ddd; /* Add a bottom border for separators */
	}

	.menu-item:last-child {
		border-bottom: none; /* Remove the bottom border for the last item */
	}

	.menu-item.active {
		font-weight: bold;
		background-color: #f0f0f0;
	}
</style>
