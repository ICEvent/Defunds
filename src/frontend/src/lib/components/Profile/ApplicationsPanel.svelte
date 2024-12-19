<script>
    import { onMount } from "svelte";
    import { Principal } from "@dfinity/principal";
    import { globalStore } from "$lib/store";
    import { parseApplication } from "$lib/utils/grant.utils";
    import {
        getDecimalsByCurrency,
        getCurrencyObjectByName,
    } from "$lib/utils/currency.utils";
    import { showProgress, hideProgress } from "$lib/stores/progress";
    import { showNotification } from "$lib/stores/notification";

    let isAuthed = false;
    let principal;
    let backend;
    let page = 1;
    onMount(async () => {
        const unsubscribe = globalStore.subscribe((store) => {
            isAuthed = store.isAuthed;
            principal = store.principal;
            backend = store.backend;
        });
        loadApplications();
        return () => {
            unsubscribe();
        };
    });

    let showApplicationModal = false;
    let applications = [];
    let formData = {
        title: "",
        description: "",
        recipient: "",
        amount: 0.01,
        currency: "ICP",
        category: "",
        proofs: [],
    };

    async function loadApplications() {
        if (backend) {
            let rapplications = await backend.getMyGrants();
            applications = rapplications.map(parseApplication);
            console.log(applications);
        }
    }

    async function handleSubmit() {
        const decimals = getDecimalsByCurrency(
            Object.keys(formData.currency)[0],
        );
        const amount = BigInt(
            Math.floor(formData.amount * Math.pow(10, decimals)),
        );

        let grant = {
            title: formData.title,
            description: formData.description,
            recipient: formData.recipient,
            amount: amount,
            currency: getCurrencyObjectByName(formData.currency),
            category: formData.category,
            proofs: formData.proofs,
        };
        console.log(grant);
        showProgress();
        try {
            let result = await backend.applyGrant(grant);
            if (result.ok) {
                showNotification(
                    "Application submitted successfully",
                    "success",
                );
                showApplicationModal = false;

                loadApplications();
            } else {
                showNotification(result.err, "error");
            }
        } catch (error) {
            showNotification(error.message, "error");
        } finally {
            hideProgress();
        }
    }

    async function cancelGrant(grantId) {
        try {
            showProgress();
            const result = await backend.cancelGrant(grantId);
            if (result.ok) {
                let rapplications = await backend.getMyGrants();
                applications = rapplications.map(parseApplication);
                console.log(applications);
            }
        } finally {
            hideProgress();
        }
    }

    async function claimGrant(grantId) {
        if (backend) {
            showProgress();
            try {
                const result = await backend.claimGrant(grantId);
                if (result.ok) {
                    showNotification("Grant claimed successfully!", "success");
                    loadApplications();
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
</script>

<div class="applications-panel">
    <div class="panel-header">
        <h1>Applications</h1>
        <button
            class="bg-blue-600 text-white px-6 py-2 rounded-lg hover:bg-blue-700"
            on:click={() => (showApplicationModal = true)}
        >
            Submit
        </button>
    </div>

    <div class="applications-list">
        {#each applications as application}
            <div class="application-card">
                <h3>{application.title}</h3>
                <p class="status {application.grantStatus.toLowerCase()}">
                    {application.grantStatus}
                </p>
                <p class="status amount">
                    {application.amount}
                    {application.currency}
                </p>

                <p class="status recipient">
                    {application.recipient.slice(0, 6)}... {application.recipient.slice(
                        -6,
                    )}
                </p>
                <p class="description">{application.description}</p>
                <p class="text-gray-500 text-sm">
                    Submitted: {new Date(
                        Number(application.submitime) / 1_000_000,
                    ).toLocaleString()}
                </p>
                {#if application.grantStatus == "submitted"}
                    <div class="card-actions">
                        <button
                            class="cancel-grant-btn"
                            on:click={() => cancelGrant(application.grantId)}
                        >
                            Cancel Grant
                        </button>
                    </div>
                {/if}
                {#if application.grantStatus === "approved"}
                    <div class="card-actions">
                        <button
                            class="claim-grant-btn"
                            on:click={() => claimGrant(application.grantId)}
                        >
                            Claim Grant
                        </button>
                    </div>
                {/if}
            </div>
        {/each}
    </div>

    <style>
        .card-actions {
            margin-top: 16px;
            display: flex;
            justify-content: flex-end;
        }

        .cancel-grant-btn {
            background: #ef4444;
            color: white;
            padding: 8px 16px;
            border-radius: 6px;
            border: none;
            cursor: pointer;
            font-size: 14px;
            font-weight: 500;
        }

        .cancel-grant-btn:hover {
            background: #dc2626;
        }
    </style>
    {#if showApplicationModal}
        <div class="modal-overlay">
            <div class="modal">
                <div class="modal-header">
                    <h2>Create New Application</h2>
                </div>
                <form on:submit|preventDefault={handleSubmit}>
                    <div class="modal-content">
                        <div class="form-group">
                            <label for="title">Title</label>
                            <input
                                type="text"
                                id="title"
                                bind:value={formData.title}
                                required
                            />
                        </div>
                        <div class="form-group">
                            <label for="description">Description</label>
                            <textarea
                                id="description"
                                bind:value={formData.description}
                                required
                            ></textarea>
                        </div>
                        <div class="form-group">
                            <label for="recipient">Recipient Account</label>
                            <input
                                type="text"
                                id="recipient"
                                bind:value={formData.recipient}
                                required
                            />
                        </div>
                        <div class="form-group">
                            <label for="amount">Amount</label>
                            <div class="amount-input-group">
                                <input
                                    type="number"
                                    id="amount"
                                    bind:value={formData.amount}
                                    min="0.000001"
                                    step="0.000001"
                                    required
                                />
                                <select
                                    id="currency"
                                    bind:value={formData.currency}
                                    required
                                >
                                    <option selected value={"ICP"}>ICP</option>
                                    <option value="ckUSDC">ckUSDC</option>
                                </select>
                            </div>
                        </div>

                        <div class="form-group">
                            <label for="category">Category</label>
                            <input
                                type="text"
                                id="category"
                                bind:value={formData.category}
                                required
                            />
                        </div>
                        <!-- <div class="form-group">
                            <label for="proofs">Proofs (URLs)</label>
                            <textarea
                                id="proofs"
                                placeholder="Enter each proof URL on a new line"
                                value={formData.proofs.join("\n")}
                                on:input={(e) => {
                                    formData.proofs = e.target.value
                                        .split("\n")
                                        .filter((url) => url.trim());
                                }}
                                required
                            ></textarea>
                        </div> -->
                    </div>
                    <div class="modal-footer">
                        <button
                            type="button"
                            class="cancel-btn"
                            on:click={() => (showApplicationModal = false)}
                            >Cancel</button
                        >
                        <button type="submit" class="submit-btn">Submit</button>
                    </div>
                </form>
            </div>
        </div>{/if}
</div>

<style>
    .applications-list {
        display: grid;
        gap: 20px;
        padding: 20px;
    }

    .application-card {
        background: white;
        border-radius: 12px;
        padding: 24px;
        box-shadow: 0 2px 4px rgba(0, 0, 0, 0.05);
        border: 1px solid #e5e7eb;
    }

    .application-card h3 {
        font-size: 18px;
        font-weight: 600;
        margin: 0 0 12px 0;
        color: #111827;
    }

    .status {
        display: inline-block;
        padding: 4px 12px;
        border-radius: 16px;
        font-size: 14px;
        font-weight: 500;
        margin-bottom: 16px;
    }

    .amount {
        background: #edec9e;
        color: #15d763;
    }
    .receipant {
        background: #aec2e9;
        color: rgb(16, 17, 16);
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

    .description {
        color: #4b5563;
        margin-bottom: 16px;
        line-height: 1.5;
    }

    .amount {
        font-weight: 500;
        color: #059669;
    }

    .panel-header {
        display: flex;
        justify-content: space-between;
        align-items: center;
        padding: 20px;
        border-bottom: 1px solid #e5e7eb;
    }

    .create-btn {
        background: #5230d8;
        color: white;
        padding: 8px 16px;
        border-radius: 6px;
        font-weight: 500;
        border: none;
        cursor: pointer;
    }

    .create-btn:hover {
        background: #43a047;
    }

    .modal-overlay {
        position: fixed;
        inset: 0;
        background: rgba(0, 0, 0, 0.2);
        display: flex;
        align-items: center;
        justify-content: center;
        z-index: 1000;
        overflow-y: auto;
        padding: 20px;
    }

    .modal {
        background: white;
        width: 720px;
        max-width: 100%;
        border-radius: 16px;
        box-shadow:
            0 20px 25px -5px rgba(0, 0, 0, 0.1),
            0 10px 10px -5px rgba(0, 0, 0, 0.04);
        max-height: 90vh;
        overflow-y: auto;
        margin: auto;
    }

    .modal-header {
        padding: 24px 32px;
        border-bottom: 1px solid #e5e7eb;
    }

    .modal-content {
        padding: 32px;
    }

    .form-group {
        margin-bottom: 24px;
    }

    .form-group:last-child {
        margin-bottom: 0;
    }

    label {
        display: block;
        margin-bottom: 8px;
        font-weight: 500;
        font-size: 15px;
        color: #374151;
    }

    .amount-input-group {
        display: flex;
    }

    .amount-input-group input {
        border-top-right-radius: 0;
        border-bottom-right-radius: 0;
        flex: 1;
    }

    .amount-input-group select {
        border-top-left-radius: 0;
        border-bottom-left-radius: 0;
        border-left: none;
        width: 100px;
    }
    input,
    textarea,
    select {
        width: 100%;
        padding: 12px;
        border: 1px solid #d1d5db;
        border-radius: 8px;
        font-size: 15px;
        background: #fff;
    }
    textarea {
        height: 140px;
        resize: vertical;
    }
    .modal-content {
        padding: 32px;
        width: 100%;
    }

    .modal-footer {
        padding: 24px 32px 32px 32px; /* Increased bottom padding */
        border-top: 1px solid #e5e7eb;
        display: flex;
        justify-content: flex-end;
        gap: 12px;

        width: 100%;
    }
    /* Override the general button styles for modal footer buttons only */
    .modal-footer button {
        all: unset;
        height: 40px;
        padding: 0 24px;
        border-radius: 6px;
        font-size: 15px;
        font-weight: 500;
        min-width: 120px;
        display: inline-flex;
        align-items: center;
        justify-content: center;
        cursor: pointer;
    }

    .modal-footer .submit-btn {
        background: #4caf50;
        color: white;
    }

    .modal-footer .cancel-btn {
        background: #fff;
        border: 1px solid #d1d5db;
    }
    .applicant {
        font-size: 14px;
        color: #6b7280;
        margin-bottom: 12px;
        font-family: monospace;
    }
    .claim-grant-btn {
        background: #22c55e;
        color: white;
        padding: 8px 16px;
        border-radius: 6px;
        border: none;
        cursor: pointer;
        font-size: 14px;
        font-weight: 500;
    }

    .claim-grant-btn:hover {
        background: #16a34a;
    }
</style>
