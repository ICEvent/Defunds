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
	<main class="min-h-[calc(100vh-136px)] bg-gradient-to-b from-slate-950 via-slate-900 to-slate-950">
		<Notification />
		<slot />
	</main>
<Footer />
