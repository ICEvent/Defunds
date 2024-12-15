<script>
    	import { globalStore } from '$lib/store';
	import { onMount } from 'svelte';

	import { parseApplication } from '$lib/utils/grant.utils';

    let selectedStatus = '';
    let page = 0;
    let backend = null;
    let applications = [];

    onMount(async () => {
		const unsubscribe = globalStore.subscribe((store) => {
			backend = store.backend;
		});

		try {
			
		if (backend) {
			let rapplications = await backend.getGrants([], BigInt(page));
            console.log(rapplications);
			applications = rapplications.map(parseApplication);
	
		}
	
		} catch (error) {
			console.error('Error fetching applications:', error);
		}
		return unsubscribe;
	});

    async function loadApplications(status) {
        if (!backend) return;
        
        if (status) {
            let statusVariant = { [status]: null };
            applications = await backend.getGrants([statusVariant], BigInt(page));
        } else {
            applications = await backend.getGrants([], BigInt(page));
        }
        applications = applications.map(parseApplication);
    }

    $: {
        if (backend) {
            loadApplications(selectedStatus);
        }
    }
</script>

<div class="max-w-6xl mx-auto p-8">
    <div class="flex justify-between items-center mb-8">
        <h1 class="text-3xl font-bold text-gray-900">Applications</h1>
    </div>

    <!-- Search and Filters -->
    <div class="bg-white p-6 rounded-xl shadow-sm mb-8">
        <div class="grid md:grid-cols-3 gap-6">
            <!-- Search -->
            <div class="col-span-2">
                <input
                    type="text"
                    placeholder="Search by title or applicant..."
                    class="w-full px-4 py-2 border border-gray-300 rounded-lg focus:ring-2 focus:ring-indigo-500 focus:border-indigo-500"
                />
            </div>

            <!-- Status Filter -->
            <select
            bind:value={selectedStatus}
                class="px-4 py-2 border border-gray-300 rounded-lg focus:ring-2 focus:ring-indigo-500 focus:border-indigo-500"
            >
                <option value="">All Status</option>
                <option value="submitted">Submitted</option>
                <option value="review">Review</option>
                <option value="voting">Voting</option>
                <option value="approved">Approved</option>
                <option value="rejected">Rejected</option>
            </select>
        </div>
    </div>

    <!-- Applications List -->
    {#if applications.length === 0}
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
                    d="M9 12h6m-6 4h6m2 5H7a2 2 0 01-2-2V5a2 2 0 012-2h5.586a1 1 0 01.707.293l5.414 5.414a1 1 0 01.293.707V19a2 2 0 01-2 2z"
                />
            </svg>
            <h3 class="text-xl font-semibold text-gray-900 mb-2">
                No Applications Found
            </h3>
        </div>
    {:else}
        <div class="space-y-4">
            {#each applications as application}
                <div
                    class="bg-white p-6 rounded-xl shadow-sm hover:shadow-md transition-shadow"
                >
                    <div class="flex justify-between items-start mb-4">
                        <div>
                            <h3 class="text-xl font-semibold text-gray-900">
                                <a
                                    href="/application/{application.id}"
                                    class="hover:text-indigo-600"
                                >
                                    {application.title}
                                </a>
                            </h3>
                            <p class="text-gray-500 text-sm mt-1">
                                by {application.applicant} • {new Date(
                                    Number(application.submitTime) / 1_000_000,
                                ).toLocaleDateString()}
                            </p>
                        </div>
                        <span
                            class="status-badge {application.grantStatus.toLowerCase()}"
                        >
                            {application.grantStatus}
                        </span>
                    </div>

                    <div class="flex items-center justify-between">
                        <div class="text-gray-700">
                            <span class="font-medium"
                                >{application.amount}
                                {application.currency}</span
                            >
                        </div>
                        {#if application.status === "voting"}
                            <div class="flex items-center space-x-2">
                                <div
                                    class="h-2 w-24 bg-gray-200 rounded-full overflow-hidden"
                                >
                                    <div
                                        class="h-full bg-green-500"
                                        style="width: {application.approvalPercentage}%"
                                    ></div>
                                </div>
                                <span class="text-sm text-gray-600"
                                    >{application.approvalPercentage}%</span
                                >
                            </div>
                        {/if}
                    </div>
                </div>
            {/each}
        </div>
    {/if}
</div>

<style>
    .status-badge {
        padding: 0.25rem 0.75rem;
        border-radius: 9999px;
        font-size: 0.875rem;
        font-weight: 500;
    }

    .status-badge.review {
        background-color: #e0f2fe;
        color: #075985;
    }

    .status-badge.voting {
        background-color: #f3e8ff;
        color: #6b21a8;
    }

    .status-badge.approved {
        background-color: #dcfce7;
        color: #166534;
    }

    .status-badge.rejected {
        background-color: #fee2e2;
        color: #991b1b;
    }
</style>
