<script>
	import '../index.scss';
  import '../app.css';
	import Navbar from '$lib/components/Navbar.svelte';
	import Footer from '$lib/components/Footer.svelte';
	import ProgressIndicator from '$lib/components/ProgressIndicator.svelte';
	import Notification from '$lib/components/Notification.svelte';
</script>
<!-- 
<style lang="scss" global>  
  @import "@dfinity/gix-components/dist/styles/global.scss";
</style> -->
	<ProgressIndicator />
	<Navbar />
	<main>
		<Notification />
		<slot />
	</main>
<Footer />
