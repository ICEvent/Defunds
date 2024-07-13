<script>
	// Import necessary components and functions

	import Footer from '../../components/Footer.svelte';
	import Navbar from '../../components/Navbar.svelte';
</script>


<main class="container mx-auto px-4 py-8 bg-gray-50 min-h-screen">
	<h1 class="text-4xl font-bold mb-8 text-center text-blue-600">Defund DAO</h1>
	<section class="bg-white shadow-lg rounded-lg p-6 mt-12">
		<h2 class="text-2xl font-semibold mb-4 text-blue-800 border-b pb-2">Fund Principals</h2>
		<div class="bg-gray-100 p-4 rounded-lg">
			<h3 class="text-xl mb-2 font-medium text-gray-700">Education</h3>
			<h3 class="text-xl mb-2 font-medium text-gray-700">Development</h3>
		</div>
		<div class="mt-4">
			<h3 class="text-xl mb-2 font-medium text-gray-700">Fund Principal History</h3>
			<!-- Add a chart or table showing fund principal history -->
		</div>
	</section>

	<section class="mb-12 bg-white shadow-lg rounded-lg p-6">
		<h2 class="text-2xl font-semibold mb-4 text-blue-800 border-b pb-2">Council</h2>
		<div class="bg-gray-100 p-4 rounded-lg mb-4">
			<h3 class="text-xl mb-2 font-medium text-gray-700">Current Council Members</h3>
			<!-- List council members -->
		</div>
		<div>
			<h3 class="text-xl mb-2 font-medium text-gray-700">Council Proposals</h3>
			<!-- List active council proposals or add a button to create new proposals -->
			<button class="bg-blue-500 text-white px-4 py-2 rounded hover:bg-blue-600 transition-colors">
				Create Proposal
			</button>
		</div>
	</section>

	<section class="bg-white shadow-lg rounded-lg p-6">
		<h2 class="text-2xl font-semibold mb-4 text-blue-800 border-b pb-2">Community</h2>
		<div class="bg-gray-100 p-4 rounded-lg mb-4">
			<h3 class="text-xl mb-2 font-medium text-gray-700">Community Proposals</h3>
			<!-- List active community proposals or add a button to create new proposals -->
			<button
				class="bg-green-500 text-white px-4 py-2 rounded hover:bg-green-600 transition-colors"
			>
				Submit Proposal
			</button>
		</div>
		<div>
			<h3 class="text-xl mb-2 font-medium text-gray-700">Your Voting Power</h3>
			<!-- Display user's voting power based on donation history -->
			<div class="text-2xl font-bold text-blue-600">
				<!-- Insert voting power here -->
			</div>
		</div>
	</section>
</main>

<style>
	/* Any additional custom styles can be added here */
</style>
