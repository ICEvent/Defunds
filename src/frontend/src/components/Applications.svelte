<script>
	import ListItem from "./Application/ListItem.svelte";

	
	let applications = [
		{ id: 1, name: 'Application 1', description: 'Description for Application 1' },
		{ id: 2, name: 'Application 2', description: 'Description for Application 2' }
		// Add more applications as needed
	];

</script>

<div class="w-full md:w-1/2">
    <h3 class="text-2xl font-bold mb-4 text-center">Applications</h3>
    {#each applications as app}
        <ListItem {app}/>
    {/each}
</div>