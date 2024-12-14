<script>
    import { onMount } from "svelte";
    import { Principal } from "@dfinity/principal";
    import { globalStore } from "../../../store";
    import { parseApplication } from "../../../utils";

    let isAuthed;
    let principal;
    let backend;
    let page = 1;
    onMount(async () => {
        const unsubscribe = globalStore.subscribe((store) => {
            isAuthed = store.isAuthed;
            principal = store.principal;
            backend = store.backend;
        });
        if (backend) {
            let rapplications = await backend.getMyGrants();
            applications = rapplications.map(parseApplication);
            console.log(applications);
        }
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
        amount: 0,
        currency: { ICP: null },
        category: "",
        proofs: [],
    };

    async function handleSubmit() {
        let grant = {
            title: formData.title,
            description: formData.description,
            recipient: Principal.fromText(formData.recipient),
            amount: BigInt(formData.amount * 10 ** 6),
            currency: formData.currency,
            category: formData.category,
            proofs: formData.proofs,
        };

        let result = await backend.applyGrant(grant);

        if (result.ok) {
            // applications.push(grant);
        } else {
            console.error(result.error);
        }
        showApplicationModal = false;
        formData = {
            title: "",
            description: "",
            recipient: "",
            amount: 0,
            currency: "ICP",
            category: "",
            proofs: [],
        };
    }

    async function cancelGrant(grantId) {
        const result = await backend.cancelGrant(grantId);
        if (result.ok) {
            let rapplications = await backend.getMyGrants();
            applications = rapplications.map(parseApplication);
            console.log(applications);
        }
    }
</script>

<div class="applications-panel">
    <div class="panel-header">
        <h1>Applications</h1>
        <button
            class="create-btn"
            on:click={() => (showApplicationModal = true)}
        >
            Apply for Grant
        </button>
    </div>

    <div class="applications-list">
        {#each applications as application}
            <div class="application-card">
                <h3>{application.title}</h3>
                <p class="status {application.grantStatus.toLowerCase()}">
                    {application.grantStatus}
                </p>
                <p class="applicant">
                    Applicant: {application.recipient.toString()}
                </p>
                <p class="description">{application.description}</p>
                <div class="amount">
                    Requested: {application.amount}
                    {application.currencyText}
                </div>
                {#if application.grantStatus !== "cancelled"}
                    <div class="card-actions">
                        <button
                            class="cancel-grant-btn"
                            on:click={() => cancelGrant(application.grantId)}
                        >
                            Cancel Grant
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
                            <label for="recipient">Recipient Principal ID</label
                            >
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
                                    min="0"
                                    step="0.01"
                                    required
                                />
                                <select
                                    id="currency"
                                    bind:value={formData.currency}
                                    required
                                >
                                    <option value={{ ICP: null }}>ICP</option>
                                    <option value={{ ckBTC: null }}
                                        >ckBTC</option
                                    >
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
        background: #4caf50;
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
</style>
