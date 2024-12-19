<script>
    import { page } from "$app/stores";
    import { onMount } from "svelte";
    import { globalStore } from "$lib/store";
    import { parseApplication } from "$lib/utils/grant.utils";
    import { VOTE_POWER_DECIMALS } from "$lib/constants";
    import { showNotification } from "$lib/stores/notification";
    import { hideProgress, showProgress } from "$lib/stores/progress";

    let isAuthed = false;
    let principal;
    let application;
    let backend;
    let grantId;
    let commentContent = "";
    let comments = [];
    let activeTab = application?.votingStatus ? 'voting' : 'comments';

    $: {
        if (application) {
            activeTab = application.votingStatus ? 'voting' : 'comments';
        }
    }
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
            principal = store.principal;
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
                console.log("applicaiton:", result[0]);
                application = parseApplication(result[0]);
                comments = application.comments;
                console.log("comments:", comments);
            }
        }
    }

    async function startReview(grantId) {
        if (backend) {
            showProgress();
            try {
                const result = await backend.startReview(grantId);
                if (result.ok) {
                    loadApplication(grantId);
                    showNotification("Review started!", "success");
                } else {
                    showNotification(result.err, "error");
                }
            } catch (error) {
                showNotification(
                    "Error starting review: " + error.message,
                    "error",
                );
            } finally {
                hideProgress();
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
                } else {
                    showNotification(result.err, "error");
                }
            } catch (error) {
                showNotification(
                    "Error starting voting: " + error.message,
                    "error",
                );
            } finally {
                hideProgress();
            }
        }
    }
    async function rejectGrant(grantId) {
        if (backend) {
            try {
                showProgress();
                const result = await backend.rejectGrant(grantId);

                if (result.ok) {
                    showNotification("Reject grant successful!", "success");
                    loadApplication(grantId);
                } else {
                    showNotification(result.err, "error");
                }
            } catch (error) {
                showNotification(
                    "Error reject grant: " + error.message,
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
            } finally {
                hideProgress();
            }
        }
    }

    async function claimGrant(grantId) {
        if (backend) {
            showProgress();
            try {
                const result = await backend.claimGrant(grantId);
                if (result.ok) {
                    showNotification("Grant claimed successfully!", "success");
                    loadApplication(grantId);
                } else {
                    showNotification(result.err, "error");
                }
            } catch (error) {
                showNotification(
                    "Error claiming grant: " + error.message,
                    "error",
                );
            } finally {
                hideProgress();
            }
        }
    }

    async function addComment(grantId) {
        if (backend && commentContent.trim() !== "") {
            showProgress();
            try {
                const result = await backend.addGrantComment(
                    grantId,
                    commentContent,
                );
                if (result.ok) {
                    showNotification("Comment added!", "success");
                    commentContent = "";
                    loadApplication(grantId);
                } else {
                    showNotification(result.err, "error");
                }
            } catch (error) {
                showNotification(
                    "Error adding comment: " + error.message,
                    "error",
                );
            } finally {
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

                {#if isAuthed && application.grantStatus === "submitted"}
                    <button
                        on:click={() => startReview(application.grantId)}
                        class="bg-purple-600 text-white px-4 py-2 rounded-lg hover:bg-purple-700 text-sm font-medium"
                    >
                        Start Review
                    </button>
                {/if}
                {#if isAuthed && application.grantStatus === "review"}
                    <button
                        on:click={() => startVoting(application.grantId)}
                        class="bg-purple-600 text-white px-4 py-2 rounded-lg hover:bg-purple-700 text-sm font-medium"
                    >
                        Start Voting
                    </button>
                {/if}
                {#if isAuthed && (application.grantStatus === "submitted" || application.grantStatus === "review")}
                    <button
                        on:click={() => rejectGrant(application.grantId)}
                        class="bg-purple-600 text-white px-4 py-2 rounded-lg hover:bg-purple-700 text-sm font-medium"
                    >
                        Reject Grant
                    </button>
                {/if}
                {#if application.grantStatus === "approved"}
                    <div class="mt-6">
                        <button
                            class="bg-green-600 text-white px-6 py-2 rounded-lg hover:bg-green-700 transition-colors"
                            on:click={() => claimGrant(application.grantId)}
                        >
                            Claim
                        </button>
                    </div>
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
        <div class="mt-8">
            {#if application.votingStatus}
                <div class="tabs">
                    <button 
                        class="tab-button {activeTab === 'voting' ? 'active' : ''}" 
                        on:click={() => activeTab = 'voting'}
                    >
                        Voting Status
                    </button>
                    <button 
                        class="tab-button {activeTab === 'comments' ? 'active' : ''}" 
                        on:click={() => activeTab = 'comments'}
                    >
                        Comments
                    </button>
                </div>
            {/if}

            <div class="tab-content">
                {#if activeTab === 'voting' && application.votingStatus}
                    <div class="voting-section">
                        {#if isAuthed && application.grantStatus === "voting" && Number(application.votingStatus.endTime) > Date.now() * 1_000_000}
                            {#if application.votingStatus?.votes.some((vote) => vote.voterId.toString() === principal.toString())}
                                <div
                                    class="text-yellow-700 bg-blue-50 text-blue-700 p-4 rounded-lg mb-4"
                                >
                                    You have already cast your vote on this application
                                </div>
                            {:else}
                                <div class="voting-buttons">
                                    <button
                                        on:click={() =>
                                            voteOnGrant(application.grantId, {
                                                approve: null,
                                            })}
                                        class="vote-btn approve"
                                    >
                                        <span class="vote-text">Approve</span>
                                    </button>
                                    <button
                                        on:click={() =>
                                            voteOnGrant(application.grantId, {
                                                reject: null,
                                            })}
                                        class="vote-btn reject"
                                    >
                                        <span class="vote-text">Reject</span>
                                    </button>
                                </div>
                            {/if}
                        {/if}
                        <div class="voting-progress mt-5 mb-6">
                            {#if application.votingStatus}
                                <div class="flex justify-between items-center mb-4">
                                    <h3 class="text-xl font-semibold text-gray-800">
                                        Voting Status
                                    </h3>
                                    {#if Number(application.votingStatus.endTime) < Date.now() * 1_000_000}
                                        <div
                                            class="bg-red-50 border-l-4 border-red-400 p-4 rounded-lg mb-4"
                                        >
                                            <div class="flex">
                                                <div class="flex-shrink-0">
                                                    <svg
                                                        class="h-5 w-5 text-red-400"
                                                        viewBox="0 0 20 20"
                                                        fill="currentColor"
                                                    >
                                                        <path
                                                            fill-rule="evenodd"
                                                            d="M10 18a8 8 0 100-16 8 8 0 000 16zM8.707 7.293a1 1 0 00-1.414 1.414L8.586 10l-1.293 1.293a1 1 0 101.414 1.414L10 11.414l1.293 1.293a1 1 0 001.414-1.414L11.414 10l1.293-1.293a1 1 0 00-1.414-1.414L10 8.586 8.707 7.293z"
                                                            clip-rule="evenodd"
                                                        />
                                                    </svg>
                                                </div>
                                                <div class="ml-3">
                                                    <p class="text-red-700 font-medium">
                                                        Voting period has ended
                                                    </p>
                                                </div>
                                            </div>
                                        </div>
                                    {:else}
                                        <!-- Show remaining voting time -->
                                        {#if application.votingStatus}
                                            {@const timeLeft =
                                                Number(application.votingStatus.endTime) /
                                                    1_000_000 -
                                                Date.now()}
                                            {@const daysLeft = Math.floor(
                                                timeLeft / (1000 * 60 * 60 * 24),
                                            )}
                                            {@const hoursLeft = Math.floor(
                                                (timeLeft % (1000 * 60 * 60 * 24)) /
                                                    (1000 * 60 * 60),
                                            )}
                                            <div class="text-gray-600 font-medium">
                                                Ends in: {daysLeft} days {hoursLeft} hours
                                            </div>
                                        {/if}
                                    {/if}
                                </div>
                                <div class="flex justify-between text-sm mb-2">
                                    <span class="text-green-600 font-medium">
                                        {Number(
                                            application.votingStatus.approvalVotePower,
                                        ) / VOTE_POWER_DECIMALS}
                                    </span>
                                    <span class="text-red-600 font-medium">
                                        {Number(application.votingStatus.rejectVotePower) /
                                            VOTE_POWER_DECIMALS}
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
                                        >{approvePercent.toFixed(1)}%
                                    </span>
                                    <span class="text-red-600"
                                        >{(100 - approvePercent).toFixed(1)}%
                                    </span>
                                </div>
                            {/if}
                        </div>

                        {#if application.votingStatus && application.votingStatus.votes.length > 0}
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
                    <div class="comments-section">
                        
                        <div class="comments-list">
                            {#each comments as comment}
                                <div class="comment">
                                    <p class="comment-author">
                                        <code>{comment.authorId}</code>
                                        <span class="comment-timestamp">
                                            {new Date(
                                                Number(comment.timestamp) / 1_000_000,
                                            ).toLocaleString()}
                                        </span>
                                    </p>
                                    <p class="comment-content">{comment.content}</p>
                                </div>
                            {/each}
                        </div>
                        {#if isAuthed}
                            <div class="add-comment mt-4">
                                <textarea
                                    bind:value={commentContent}
                                    placeholder="Add a comment..."
                                    class="comment-textarea"
                                ></textarea>
                                <button
                                    on:click={() => addComment(grantId)}
                                    class="comment-submit-button">Comment</button
                                >
                            </div>
                        {/if}
                    </div>
                {/if}
            </div>
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
    .comments-section {
        margin-top: 2rem;
        padding: 1rem;
        background-color: #f9f9f9;
        border-radius: 8px;
    }
    .comments-list {
        margin-bottom: 1rem;
    }
    .comment {
        padding: 0.5rem;
        border-bottom: 1px solid #ddd;
        margin-bottom: 0.5rem;
    }
    .comment-author code {
        font-size: 0.875rem; /* Makes it extra small */
        color: #666;
        max-width: 150px; /* Reduced from previous width */
        overflow: hidden;
        text-overflow: ellipsis;
        display: inline-block;
        white-space: nowrap;
    }

    .comment-timestamp {
        font-size: 0.875rem;
        color: #666;
        margin-left: 0.5rem;
    }
    .comment-content {
        margin-left: 1rem;
    }
    .add-comment {
        display: flex;
        flex-direction: column;
    }
    .comment-textarea {
        width: 100%;
        height: 100px;
        margin-bottom: 0.5rem;
        padding: 0.5rem;
        border: 1px solid #ccc;
        border-radius: 4px;
    }
    .comment-submit-button {
        align-self: flex-end;
        padding: 0.5rem 1rem;
        background-color: #007bff;
        color: white;
        border: none;
        border-radius: 4px;
        cursor: pointer;
    }
    .comment-submit-button:hover {
        background-color: #0056b3;
    }
    .tabs {
    display: flex;
    gap: 1px;
    background: #e5e7eb;
    padding: 2px;
    border-radius: 8px;
    margin-bottom: 16px;
}

.tab-button {
    flex: 1;
    padding: 8px 16px;
    background: #f8fafc;
    border: none;
    cursor: pointer;
    font-weight: 500;
    color: #64748b;
    transition: all 0.2s;
}

.tab-button:first-child {
    border-radius: 6px 0 0 6px;
}

.tab-button:last-child {
    border-radius: 0 6px 6px 0;
}

.tab-button.active {
    background: #fff;
    color: #0f172a;
}

.tab-content {
    background: #fff;
    border-radius: 8px;
}

</style>
