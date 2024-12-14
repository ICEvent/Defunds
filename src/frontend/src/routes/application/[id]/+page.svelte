<script>
    import { page } from "$app/stores";
    import { onMount } from "svelte";
    import { globalStore } from "../../../store";
    import { parseApplication } from "$lib/utils";

    let application;
    let backend;

    onMount(async () => {
        const unsubscribe = globalStore.subscribe((store) => {
            backend = store.backend;
        });

        if (backend) {
            const grantId = parseInt($page.params.id);
            let result = await backend.getGrant(grantId);
            if (result.length > 0) {
                application = parseApplication(result[0]);
                console.log(application);
            }
        }

        return () => {
            unsubscribe();
        };
    });
    async function voteOnGrant(grantId, voteType) {
        if (backend) {
            const result = await backend.voteOnGrant(grantId, voteType);
            if (result.ok) {
                // Refresh grant data
                let result = await backend.getGrant(grantId);
                if (result) {
                    application = parseApplication(result);
                    console.log(application);
                }
            }
        }
    }
</script>

<div class="max-w-4xl mx-auto p-8">
    {#if application}
        <div class="bg-white shadow-xl rounded-lg overflow-hidden">
            <!-- Header Section -->
            <div class="p-6 border-b border-gray-200">
                <h1 class="text-3xl font-bold text-gray-900">
                    {application.title}
                </h1>
                <div class="flex items-center gap-4 mb-2 mt-2">
                    <span class="status {application.grantStatus.toLowerCase()}">{application.grantStatus}</span>
                    
                    <span class="text-sm text-gray-400">
                        {new Date(Number(application.submitime) / 1_000_000).toLocaleDateString()}
                    </span>
                    <span class="text-sm text-gray-400">
                        created by {application.applicant}
                        </span> 
                  </div>
                
            </div>

            <!-- Main Content -->
            <div class="p-6 space-y-6">
     
                <div class="grid md:grid-cols-2 gap-6">
                    <div class="bg-gray-50 p-4 rounded-lg">
                        <h3 class="text-sm font-medium text-gray-500">
                            Amount Requested
                        </h3>
                        <p class="mt-2 text-2xl font-bold text-green-600">
                            {application.amount}
                            {application.currency}
                        </p>
                    </div>
                    <div class="bg-gray-50 p-4 rounded-lg">
                        <h3 class="text-sm font-medium text-gray-500">
                            Recipient
                        </h3>
                        <p class="mt-2 font-mono text-sm break-all">
                            {application.recipient
                                ? application.recipient.toString()
                                : "Unknown"}
                        </p>
                    </div>
                </div>

                <!-- Description -->
                <div class="bg-gray-50 p-4 rounded-lg">
                    <h3 class="text-sm font-medium text-gray-500 mb-2">
                        Description
                    </h3>
                    <p class="text-gray-700 whitespace-pre-wrap">
                        {application.description}
                    </p>
                </div>

                <!-- Category -->
                <!-- <div class="bg-gray-50 p-4 rounded-lg">
                    <h3 class="text-sm font-medium text-gray-500 mb-2">
                        Category
                    </h3>
                    <p class="text-gray-700">{application.category}</p>
                </div> -->
            </div>
        </div>
        <div class="voting-section mt-8">
            <div class="voting-buttons">
                <button
                    on:click={() =>
                        voteOnGrant(application.grantId, { approve: null })}
                    class="vote-btn approve"
                >
                    <span class="vote-count">120</span>
                    <span class="vote-text">Approve</span>
                </button>
                <button
                    on:click={() =>
                        voteOnGrant(application.grantId, { reject: null })}
                    class="vote-btn reject"
                >
                    <span class="vote-count">45</span>
                    <span class="vote-text">Reject</span>
                </button>
            </div>

            {#if application.votingStatus}
                <div class="voting-stats mb-6">
                    <div class="stat-item">
                        <span class="text-2xl font-bold text-green-600"
                            >{application.votingStatus.approvalVotePower}</span
                        >
                        <span class="text-sm text-gray-500">Approval Power</span
                        >
                    </div>
                    <div class="stat-item">
                        <span class="text-2xl font-bold text-red-600"
                            >{application.votingStatus.rejectVotePower}</span
                        >
                        <span class="text-sm text-gray-500">Reject Power</span>
                    </div>
                </div>

                <div class="votes-list">
                    {#each application.votingStatus.votes as vote}
                        <div class="vote-item">
                            <div class="vote-info">
                                <code class="text-sm text-gray-600"
                                    >{vote.voterId.toString()}</code
                                >
                                <span class="vote-power"
                                    >{vote.votePower} Power</span
                                >
                            </div>
                            <span
                                class="vote-type {Object.keys(
                                    vote.voteType,
                                )[0]}"
                            >
                                {Object.keys(vote.voteType)[0]}
                            </span>
                        </div>
                    {/each}
                </div>
            {/if}
        </div>
    {:else}
        <div class="text-center py-12">
            <div class="animate-pulse text-gray-600">
                Loading application details...
            </div>
        </div>
    {/if}
</div>

<style>
    .status {
        display: inline-block;
        padding: 4px 12px;
        border-radius: 16px;
        font-size: 14px;
        font-weight: 500;
    }

    .status.submitted {
        background: #fef3c7;
        color: #92400e;
    }

    .status.review {
        background: #e0f2fe;
        color: #075985;
    }

    .status.voting {
        background: #f3e8ff;
        color: #6b21a8;
    }

    .status.approved {
        background: #dcfce7;
        color: #166534;
    }

    .status.rejected {
        background: #fee2e2;
        color: #991b1b;
    }

    .status.cancelled {
        background: #f3f4f6;
        color: #374151;
    }

    .status.expired {
        background: #fef2f2;
        color: #7f1d1d;
    }
    .voting-section {
        background: #f8fafc;
        padding: 24px;
        border-radius: 16px;
    }

    .voting-stats {
        display: flex;
        gap: 24px;
        margin-bottom: 24px;
    }

    .stat-item {
        display: flex;
        flex-direction: column;
        align-items: center;
    }

    .voting-section {
        background: #f8fafc;
        padding: 24px;
        border-radius: 16px;
    }

    .voting-buttons {
        display: flex;
        gap: 16px;
    }

    .vote-btn {
        flex: 1;
        display: flex;
        flex-direction: column;
        align-items: center;
        padding: 16px;
        border-radius: 12px;
        border: none;
        transition: all 0.2s;
        cursor: pointer;
    }

    .vote-count {
        font-size: 24px;
        font-weight: 600;
        margin-bottom: 4px;
    }

    .vote-text {
        font-size: 14px;
        font-weight: 500;
    }

    .approve {
        background: #dcfce7;
        color: #166534;
    }

    .approve:hover {
        background: #bbf7d0;
    }

    .reject {
        background: #fee2e2;
        color: #991b1b;
    }

    .reject:hover {
        background: #fecaca;
    }
    .votes-list {
        display: flex;
        flex-direction: column;
        gap: 12px;
    }

    .vote-item {
        display: flex;
        justify-content: space-between;
        align-items: center;
        padding: 12px;
        background: white;
        border-radius: 8px;
    }

    .vote-info {
        display: flex;
        flex-direction: column;
        gap: 4px;
    }

    .vote-power {
        font-size: 14px;
        color: #6b7280;
    }

    .vote-type {
        font-size: 14px;
        font-weight: 500;
        padding: 4px 12px;
        border-radius: 12px;
    }

    .vote-type.approve {
        background: #dcfce7;
        color: #166534;
    }

    .vote-type.reject {
        background: #fee2e2;
        color: #991b1b;
    }
</style>
