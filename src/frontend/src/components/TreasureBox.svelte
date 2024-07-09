<script>
	import '../app.css';
    let totalDonations = 10000;
</script>

<div class="treasure-box-container bg-green-200 py-8">
    <header class="mb-8 text-center">
        <h1 class="text-4xl font-bold text-indigo-600 mb-2">Know Your Donation</h1>
        <div class="relative inline-block mb-4">
            <div class="treasure-box bg-yellow-500 rounded-md p-4 shadow-md">
                <p class="text-lg text-white font-bold">Treasury : {totalDonations} ICP</p>
            </div>
            <div class="treasure-lid bg-yellow-600 rounded-t-md absolute top-0 left-0 w-full h-2"></div>
        </div>
        <div class="flex justify-center space-x-4">
            <button
                class="bg-indigo-600 hover:bg-indigo-700 text-white font-bold py-1.5 px-3 rounded-md text-sm"
            >
                Donate
            </button>
            <button
                class="bg-indigo-600 hover:bg-indigo-700 text-white font-bold py-1.5 px-3 rounded-md text-sm"
            >
                Apply
            </button>
        </div>
    </header>
</div>

<style>
	.treasure-box {
		position: relative;
		z-index: 1;
	}

	.treasure-lid {
		z-index: 2;
	}

	.treasure-box-container {
		background-color: #d9f7be; /* Light green color */
	}
</style>
