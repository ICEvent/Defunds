<script>
    import { onMount } from "svelte";
    import { globalStore } from "$lib/store";
    import { Principal } from "@dfinity/principal";
    import { ICP_TOKEN_DECIMALS, DEFUND_CANISTER_ID } from "$lib/constants";
    import {
        getCurrencyObjectByName,
        getDecimalsByCurrency,
    } from "$lib/utils/currency.utils";
    import { showProgress, hideProgress } from "$lib/stores/progress";
    import { showNotification } from "$lib/stores/notification";

    let donationAmount = 0.01;
    let donationCurrency = "ICP";
    let donations = [];
    let isAuthed = false;
    let principal;
    let backend;
    let icpledger;

    onMount(async () => {
        const unsubscribe = globalStore.subscribe((store) => {
            isAuthed = store.isAuthed;
            principal = store.principal;
            backend = store.backend;
            icpledger = store.icpledger;
        });

        return () => {
            unsubscribe();
        };
    });

    async function handleDonate() {
        if (backend && icpledger && donationAmount > 0) {
            showProgress();
            try {
                showProgress();

                let transResult = await icpledger.icrc1_transfer({
                    from_subaccount: [],
                    to: {
                        owner: Principal.fromText(DEFUND_CANISTER_ID),
                        subaccount: [],
                    },
                    amount: BigInt(donationAmount * ICP_TOKEN_DECIMALS),
                    fee: [],
                    memo: [],
                    created_at_time: [],
                });
                if ("Ok" in transResult) {
                    // Success case
                    const blockIndex = transResult.Ok;
                    showNotification(
                        "Transfer successful! Block: " + blockIndex,
                        "success",
                    );

                    // Update donation record
                    const result = await backend.donate(
                        BigInt(donationAmount * ICP_TOKEN_DECIMALS),
                        getCurrencyObjectByName(donationCurrency),
                        blockIndex,
                    );

                    if (result.ok) {
                        // Refresh donations list
                        showNotification("Donation successful!", "success");
                        loadDonations();
                    } else {
                        showNotification("Donation failed!", "error");
                    }

                    // Refresh balances or update UI
                    await loadBalances();
                } else {
                    let errorMessage = "";
                    const error = transResult.Err;

                    if ("InsufficientFunds" in error) {
                        errorMessage = `Insufficient balance: ${error.InsufficientFunds.balance}`;
                    } else if ("BadFee" in error) {
                        errorMessage = `Invalid fee: ${error.BadFee.expected_fee}`;
                    } else if ("TooOld" in error) {
                        errorMessage = "Transaction expired";
                    } else if ("CreatedInFuture" in error) {
                        errorMessage = "Invalid creation time";
                    } else {
                        errorMessage = "Transaction failed";
                    }

                    showNotification(errorMessage, "error");
                }

                hideProgress();
            } finally {
                hideProgress();
            }
        }
    }

    async function loadDonations() {
        if (backend) {
            donations = await backend.getMyDonations();
            console.log("Donations:", donations);
        }
    }

    onMount(() => {
        loadDonations();
    });
</script>

<div class="donation-panel mt-8">
    <!-- Donation Form -->
    <div class="bg-white rounded-lg p-4 sm:p-6 shadow-sm mb-6">
        <h3 class="text-lg sm:text-xl font-semibold mb-4">Make a Donation</h3>

        <div class="flex flex-col sm:flex-row gap-3 sm:gap-4">
            <input
                type="number"
                bind:value={donationAmount}
                placeholder="Amount"
                class="w-full sm:flex-1 px-4 py-2 border rounded-lg text-sm sm:text-base"
                min="0"
                step="0.01"
            />
            <select
                bind:value={donationCurrency}
                class="w-full sm:w-auto px-4 py-2 border rounded-lg text-sm sm:text-base"
            >
                <option selected value="ICP">ICP</option>
                <option value="ckUSDC">ckUSDC</option>
            </select>
            <button
                on:click={handleDonate}
                class="w-full sm:w-auto bg-blue-600 text-white px-6 py-2 rounded-lg hover:bg-blue-700 text-sm sm:text-base transition-colors"
            >
                Donate
            </button>
        </div>
    </div>

    <!-- Donation List -->
    <div class="bg-white rounded-lg p-6 shadow-sm">
        <h3 class="text-lg font-semibold mb-4">Recent Donations</h3>
        <div class="space-y-4">
            {#each donations as donation}
                <div
                    class="flex justify-between items-center p-4 bg-gray-50 rounded-lg"
                >
                    <div>
                        <p class="text-sm text-gray-500">
                            {new Date(
                                Number(donation.timestamp) / 1_000_000,
                            ).toLocaleString()}
                        </p>
                    </div>
                    <div class="text-lg font-semibold text-green-600">
                        {Number(donation.amount) /
                            10 **
                                getDecimalsByCurrency(
                                    Object.keys(donation.currency)[0],
                                )}
                        {Object.keys(donation.currency)[0]}
                    </div>
                </div>
            {/each}
        </div>
    </div>
</div>
