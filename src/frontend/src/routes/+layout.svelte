<script>
	import '../index.scss';
  import '../app.css';
	import Navbar from '$lib/components/Navbar.svelte';
	import Footer from '$lib/components/Footer.svelte';
</script>
<!-- 
<style lang="scss" global>  
  @import "@dfinity/gix-components/dist/styles/global.scss";
</style> -->

<Navbar />
<main>
	<slot />
</main>
<Footer />
