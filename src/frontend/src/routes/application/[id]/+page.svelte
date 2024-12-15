<script>
    import { page } from "$app/stores";
    import { onMount } from "svelte";
    import { globalStore } from "$lib/store";
    import { parseApplication } from "$lib/utils/grant.utils";
    import { VOTE_POWER_DECIMALS } from "$lib/constants";
    import { showNotification } from "$lib/stores/notification";
    import { hideProgress, showProgress } from "$lib/stores/progress";

    let isAuthed=false;
    let application;
    let backend;
    let grantId;
    $: totalPower = application?.votingStatus
        ? Number(application.votingStatus.approvalVotePower) +
          Number(application.votingStatus.rejectVotePower)
        : 0;

    $: approvePercent =
        totalPower > 0
            ? (Number(application.votingStatus.approvalVotePower) /
                  totalPower) *
              100
            : 0;
    onMount(async () => {
        grantId = parseInt($page.params.id);

        const unsubscribe = globalStore.subscribe((store) => {
            isAuthed = store.isAuthed;
            backend = store.backend;
        });

        if (backend) {
            loadApplication(grantId);
        }

        return () => {
            unsubscribe();
        };
    });

    async function loadApplication(grantId) {
        if (backend) {
            let result = await backend.getGrant(grantId);
            if (result.length > 0) {
                console.log("applicaiton:", result[0])
                application = parseApplication(result[0]);
            }
        }
    }
    async function startVoting(grantId) {
        if (backend) {
            showProgress();
            try {
                const result = await backend.startGrantVoting(grantId);
                if (result.ok) {
                    loadApplication(grantId);
                    showNotification("Voting started!", "success");
                }else{
                    showNotification(result.err, "error");
                }
            }catch (error) {
                showNotification(
                    "Error starting voting: " + error.message,
                    "error",
                );
            } finally {
                hideProgress();
            }
        }
    }

    async function voteOnGrant(grantId, voteType) {
        if (backend) {
            try {
                showProgress();
                const result = await backend.voteOnGrant(grantId, voteType);
    
                if (result.ok) {
                    showNotification("Cast vote successful!", "success");
                    loadApplication(grantId);
                } else {
                    showNotification(result.err, "error");
                }
            } catch (error) {
                showNotification(
                    "Error casting vote: " + error.message,
                    "error",
                );
            }finally {
                hideProgress();
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
                    <span class="status {application.grantStatus.toLowerCase()}"
                        >{application.grantStatus}</span
                    >

                    <span class="text-sm text-gray-400">
                        {new Date(
                            Number(application.submitime) / 1_000_000,
                        ).toLocaleDateString()}
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
                                ? application.recipient
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
                {#if isAuthed && application.grantStatus === "review"}
                    <button
                        on:click={() => startVoting(application.grantId)}
                        class="bg-purple-600 text-white px-4 py-2 rounded-lg hover:bg-purple-700 text-sm font-medium"
                    >
                        Start Voting
                    </button>
                {/if}
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
            {#if isAuthed && application.grantStatus === "voting"}
            <div class="voting-buttons">
                <button
                    on:click={() =>
                        voteOnGrant(application.grantId, { approve: null })}
                    class="vote-btn approve"
                >
                    <span class="vote-text">Approve</span>
                </button>
                <button
                    on:click={() =>
                        voteOnGrant(application.grantId, { reject: null })}
                    class="vote-btn reject"
                >
                    <span class="vote-text">Reject</span>
                </button>
            </div>
            {/if}
            <div class="voting-progress mt-5 mb-6">
                {#if application.votingStatus}
                <div class="flex justify-between items-center mb-4">
                    <h3 class="text-xl font-semibold text-gray-800">Voting Status</h3>
                    <span class="text-base font-medium text-gray-700">
                        Ends: {new Date(Number(application.votingStatus.endTime) / 1_000_000).toLocaleString()}
                    </span>
                </div>
                <div class="flex justify-between text-sm mb-2">
                    <span class="text-green-600 font-medium">
                        {Number(application.votingStatus.approvalVotePower) / VOTE_POWER_DECIMALS} 
                    </span>
                    <span class="text-red-600 font-medium">
                        {Number(application.votingStatus.rejectVotePower) / VOTE_POWER_DECIMALS} 
                    </span>
                </div>
                    <div class="progress-bar">
                        <div
                            class="approve-bar"
                            style="width: {approvePercent}%"
                        ></div>
                    </div>
                    <div class="flex justify-between text-sm mt-2">
                        <span class="text-green-600"
                            >{approvePercent.toFixed(1)}% </span
                        >
                        <span class="text-red-600"
                            >{(100 - approvePercent).toFixed(1)}% </span
                        >
                    </div>
                {/if}
            </div>
            
            {#if application.votingStatus}
                <div class="votes-list mt-4">
                    {#each application.votingStatus.votes.sort((a, b) => Number(b.timestamp) - Number(a.timestamp)) as vote}
                        <div class="vote-item">
                            <div class="vote-info">
                                <code class="text-sm text-gray-600"
                                    >{vote.voterId.toString()}</code
                                >
                                <span class="vote-power"
                                    >{Number(vote.votePower) /
                                        VOTE_POWER_DECIMALS} Power</span
                                >
                                <span class="vote-time text-xs text-gray-400">
                                    {new Date(
                                        Number(vote.timestamp) / 1_000_000,
                                    ).toLocaleString()}
                                </span>
                            </div>
                            <span class="vote-type {vote.voteType}">
                                {vote.voteType}
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
    .progress-bar {
        height: 8px;
        background: #fee2e2;
        border-radius: 4px;
        overflow: hidden;
    }

    .approve-bar {
        height: 100%;
        background: #dcfce7;
        transition: width 0.3s ease;
    }
</style>
