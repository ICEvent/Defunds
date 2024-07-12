<script>
    import { onMount } from 'svelte';
    import { page } from '$app/stores';
  
    let id;
    
    $: id = $page.params.id;
  
    onMount(() => {
      console.log('ID:', id);
      // Fetch details using id
    });
  </script>
  
  <h1>Details for {id}</h1>
  