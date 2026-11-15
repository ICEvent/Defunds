<script>
  import {globalStore} from '$lib/store';
  import GlobalAssetCatalog from '$lib/components/GlobalAssetCatalog.svelte';
</script>
<svelte:head><title>Global asset catalog · Defunds</title></svelte:head>
<div class="mx-auto max-w-6xl px-4 py-8"><GlobalAssetCatalog backend={$globalStore.backend}/></div>
