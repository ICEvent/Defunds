<script>
	// You can add any necessary logic or data here

	import Footer from '../../components/Footer.svelte';
	import Navbar from '../../components/Navbar.svelte';
</script>

<div class="spacer"></div>
<main class="mt-30">
	<div class="description-box">
		<h1 class="box-title">About Defund</h1>
		<p>
			Defund is a decentralized charity fund based on the Internet Computer blockchain. Everyone can
			track their donating history and decide where to donate by voting. Voting power is accumulated
			by donation history.
		</p>
	</div>

	<div class="feature-boxes">
		<div class="feature-box">
			<h3 class="box-title">Public</h3>
			<p>tracking funds in/out, audit</p>
		</div>
		<div class="feature-box">
			<h3 class="box-title">Privacy</h3>
			<p>Verifiable Creditials</p>
		</div>
		<div class="feature-box">
			<h3 class="box-title">Group Fund</h3>
			<p>Manage private fund in a group</p>
		</div>
	</div>
</main>

<style>
	.spacer {
		height: 50px; /* Adjust the height as needed */
	}
	.description-box {
		background-color: #f2f2f2;
		padding: 20px;
		text-align: center;
		margin-bottom: 30px;
		width: 70%; /* Set width to 70% of screen width */
		margin-left: auto; /* Center horizontally */
		margin-right: auto; /* Center horizontally */
	}

	.feature-boxes {
		display: flex;
		justify-content: space-around;
	}

	.feature-box {
		background-color: #f2f2f2;
		padding: 20px;
		text-align: center;
		width: 30%;
	}

	.box-title {
		font-size: 1em; /* Adjust font size as needed */
		font-weight: bold;
	}
</style>
