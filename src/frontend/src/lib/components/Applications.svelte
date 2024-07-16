<script>
	import ListItem from "./Application/ListItem.svelte";

	
	let applications = [
		{ id: 1, name: 'Developing grant', description: 'Request 100 ICP for developing grant', status: 'Pending' },
		{ id: 1, name: 'Support Children Food Security', description: 'Request 1000 ICP to support children in poor counties', status: 'Pending' },
	];

</script>

<div class="w-full md:w-1/2">
    <h3 class="text-2xl font-bold mb-4 text-center">Applications</h3>
    {#each applications as app}
        <ListItem {app}/>
    {/each}
</div>