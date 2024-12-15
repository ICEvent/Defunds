<script>
    import { onMount } from 'svelte';
    import { EXPLORER_ICP_TX,getTokenNameByID } from '$lib/constants';
    
    let donations = [];
</script>

<div class="max-w-6xl mx-auto p-8">
    <div class="flex justify-between items-center mb-8">
        <h1 class="text-3xl font-bold text-gray-900">Donation History</h1>

    </div>

    <!-- Search and Filters -->
    <div class="bg-white p-6 rounded-xl shadow-sm mb-8">
        <div class="grid md:grid-cols-3 gap-6">
            <!-- Search -->
            <div class="col-span-2">
                <input
                    type="text"
                    placeholder="Search by donor or transaction..."
                    class="w-full px-4 py-2 border border-gray-300 rounded-lg focus:ring-2 focus:ring-indigo-500 focus:border-indigo-500"
                />
            </div>

            <!-- Currency Filter -->
            <select
                class="px-4 py-2 border border-gray-300 rounded-lg focus:ring-2 focus:ring-indigo-500 focus:border-indigo-500"
            >
                <option value="">All Currencies</option>
                <option value="ICP">ICP</option>
                <option value="ckBTC">ckBTC</option>
            </select>
        </div>
    </div>

    <!-- Donations List -->
    {#if donations.length === 0}
        <div
            class="flex flex-col items-center justify-center py-16 bg-white rounded-xl shadow-sm"
        >
            <svg
                class="w-16 h-16 text-gray-400 mb-4"
                fill="none"
                stroke="currentColor"
                viewBox="0 0 24 24"
            >
                <path
                    stroke-linecap="round"
                    stroke-linejoin="round"
                    stroke-width="2"
                    d="M12 8c-1.657 0-3 .895-3 2s1.343 2 3 2 3 .895 3 2-1.343 2-3 2m0-8c1.11 0 2.08.402 2.599 1M12 8V7m0 1v8m0 0v1m0-1c-1.11 0-2.08-.402-2.599-1M21 12a9 9 0 11-18 0 9 9 0 0118 0z"
                />
            </svg>
            <h3 class="text-xl font-semibold text-gray-900 mb-2">
                No Donations Yet
            </h3>
            <p class="text-gray-600">Be the first to contribute to this fund</p>
           
        </div>
    {:else}
        <div class="space-y-4">
            {#each donations as donation}
                <div
                    class="bg-white p-6 rounded-xl shadow-sm hover:shadow-md transition-shadow"
                >
                    <div class="flex justify-between items-center">
                        <div>
                            <div class="text-lg font-medium text-gray-900">
                                {Number(donation.amount) / 100000000}
                                {getTokenNameByID(donation.currency)}
                            </div>
                            <div class="text-sm text-gray-500">
                                from {`${donation.donor.slice(0, 5)}...${donation.donor.slice(-5)}`}
                            </div>
                        </div>
                        <div class="text-right">
                            <div class="text-sm text-gray-500">
                                {new Date(
                                    Number(donation.timestamp) / 1_000_000,
                                ).toLocaleString()}
                            </div>
                            <a
                                href={`${EXPLORER_ICP_TX}${donation.txid}`}
                                target="_blank"
                                rel="noopener noreferrer"
                                class="text-sm text-indigo-600 hover:text-indigo-800"
                            >
                                View Transaction
                            </a>
                        </div>
                    </div>
                </div>
            {/each}
        </div>
    {/if}
</div>
