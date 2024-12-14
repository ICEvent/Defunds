<script>
    import { onMount } from 'svelte';
    import { globalStore } from "$lib/store";
    import { ICP_TOKEN_DECIMALS } from '$lib/constants';

    let donationAmount = 0;
    let donationCurrency = { ICP: null };
    let donations = [];
    let isAuthed = false;
    let principal;
    let backend;

    onMount(async () => {
        const unsubscribe = globalStore.subscribe((store) => {
            isAuthed = store.isAuthed;
            principal = store.principal;
            backend = store.backend;
        });
        if (backend) {
           
        }
        return () => {
            unsubscribe();
        };
    });

    async function handleDonate() {
        if (backend && donationAmount > 0) {
            const result = await backend.donate(
                BigInt(donationAmount * ICP_TOKEN_DECIMALS), 
                donationCurrency,
                "7cd3f003cac9e17e44b28626c1a8e4dd493b9d223556dbe164f1c4da8734b941"
            );
            console.log("Donation result:", result);
            if (result.ok) {
                // Refresh donations list
                loadDonations();
            }
        }
    }

    async function loadDonations() {
        if (backend) {
            donations = await backend.getDonations();
        }
    }

    onMount(() => {
        loadDonations();
    });
</script>


<div class="donation-panel mt-8">
    <!-- Donation Form -->
    <div class="bg-white rounded-lg p-6 shadow-sm mb-6">
        <h3 class="text-lg font-semibold mb-4">Make a Donation</h3>
        <div class="flex gap-4">
            <input 
                type="number" 
                bind:value={donationAmount}
                placeholder="Amount"
                class="flex-1 px-4 py-2 border rounded-lg"
                min="0"
                step="0.01"
            />
            <select 
                bind:value={donationCurrency}
                class="px-4 py-2 border rounded-lg">
                <option value={{ ICP: null }}>ICP</option>
                <option value={{ ckBTC: null }}>ckBTC</option>
            </select>
            <button 
                on:click={handleDonate}
                class="bg-blue-600 text-white px-6 py-2 rounded-lg hover:bg-blue-700">
                Donate
            </button>
        </div>
    </div>

    <!-- Donation List -->
    <div class="bg-white rounded-lg p-6 shadow-sm">
        <h3 class="text-lg font-semibold mb-4">Recent Donations</h3>
        <div class="space-y-4">
            {#each donations as donation}
                <div class="flex justify-between items-center p-4 bg-gray-50 rounded-lg">
                    <div>
                        <code class="text-sm text-gray-600">{donation.donorId.toString()}</code>
                        <p class="text-sm text-gray-500">
                            {new Date(Number(donation.timestamp) / 1_000_000).toLocaleString()}
                        </p>
                    </div>
                    <div class="text-lg font-semibold text-green-600">
                        {Number(donation.amount) / (10 ** 6)} {Object.keys(donation.currency)[0]}
                    </div>
                </div>
            {/each}
        </div>
    </div>
</div>

