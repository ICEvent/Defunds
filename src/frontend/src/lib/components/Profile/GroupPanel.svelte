<script>
    import { onMount } from "svelte";
    import { goto } from "$app/navigation";
    import { Principal } from "@dfinity/principal";
    import { globalStore } from "$lib/store";
    import { showNotification } from "$lib/stores/notification";
    import { showProgress, hideProgress } from "$lib/stores/progress";
    import UnifiedGroupManager from "$lib/components/UnifiedGroupManager.svelte";

    let backend;
    let governanceActor;
    let selectedFund = null;
    let selectedBackendFundId = null;
    let selectedGovernanceFundId = null;

    let selectedBackendFund = null;
    let editName = "";
    let editDescription = "";
    let editIsPublic = false;

    let newMemberName = "";
    let newMemberPrincipal = "";
    let newMemberVotingPower = 1;

    onMount(() => {
        const unsubscribe = globalStore.subscribe((store) => {
            backend = store.backend;
            governanceActor = store.governance;
        });

        return unsubscribe;
    });

    function handleFundSelected(event) {
        selectedFund = event.detail.group;
        selectedGovernanceFundId = event.detail.governanceGroupId;
        selectedBackendFundId = event.detail.backendGroupId;
        selectedBackendFund = null;

        if (selectedBackendFundId) {
            loadSelectedBackendFund();
        }
    }

    async function loadSelectedBackendFund() {
        if (!backend || !selectedBackendFundId) return;

        try {
            const result = await backend.getGroup(selectedBackendFundId);
            if (result.length > 0) {
                selectedBackendFund = result[0];
                editName = selectedBackendFund.name;
                editDescription = selectedBackendFund.description;
                editIsPublic = selectedBackendFund.isPublic;
            } else {
                selectedBackendFund = null;
            }
        } catch (error) {
            showNotification(error.message || "Failed to load fund details.", "error");
        }
    }

    async function updateFundMetadata() {
        if (!backend || !selectedBackendFundId) return;

        showProgress();
        try {
            const result = await backend.updateGroup(
                selectedBackendFundId,
                editName,
                editDescription,
                editIsPublic
            );

            if ("ok" in result) {
                showNotification("Fund metadata updated.", "success");
                await loadSelectedBackendFund();
            } else {
                showNotification(result.err || "Failed to update fund metadata.", "error");
            }
        } catch (error) {
            showNotification(error.message || "Failed to update fund metadata.", "error");
        } finally {
            hideProgress();
        }
    }

    async function addMember() {
        if (!backend || !selectedBackendFundId) return;

        showProgress();
        try {
            const principal = Principal.fromText(newMemberPrincipal.trim());
            const result = await backend.addGroupMember(
                selectedBackendFundId,
                newMemberName.trim(),
                principal,
                BigInt(newMemberVotingPower)
            );

            if ("ok" in result) {
                showNotification("Member added.", "success");
                newMemberName = "";
                newMemberPrincipal = "";
                newMemberVotingPower = 1;
                await loadSelectedBackendFund();
            } else {
                showNotification(result.err || "Failed to add member.", "error");
            }
        } catch (error) {
            showNotification(error.message || "Failed to add member.", "error");
        } finally {
            hideProgress();
        }
    }

    async function removeMember(memberPrincipal) {
        if (!backend || !selectedBackendFundId) return;

        showProgress();
        try {
            const result = await backend.removeGroupMember(selectedBackendFundId, memberPrincipal);
            if ("ok" in result) {
                showNotification("Member removed.", "success");
                await loadSelectedBackendFund();
            } else {
                showNotification(result.err || "Failed to remove member.", "error");
            }
        } catch (error) {
            showNotification(error.message || "Failed to remove member.", "error");
        } finally {
            hideProgress();
        }
    }

    async function updateMemberName(memberPrincipal, memberName) {
        if (!backend || !selectedBackendFundId) return;

        showProgress();
        try {
            const result = await backend.updateGroupMemberName(
                selectedBackendFundId,
                memberPrincipal,
                memberName
            );
            if ("ok" in result) {
                showNotification("Member name updated.", "success");
                await loadSelectedBackendFund();
            } else {
                showNotification(result.err || "Failed to update member name.", "error");
            }
        } catch (error) {
            showNotification(error.message || "Failed to update member name.", "error");
        } finally {
            hideProgress();
        }
    }

    async function updateMemberVotingPower(memberPrincipal, votingPower) {
        if (!backend || !selectedBackendFundId) return;

        showProgress();
        try {
            const result = await backend.updateGroupMemberVotingPower(
                selectedBackendFundId,
                memberPrincipal,
                BigInt(votingPower)
            );
            if ("ok" in result) {
                showNotification("Voting power updated.", "success");
                await loadSelectedBackendFund();
            } else {
                showNotification(result.err || "Failed to update voting power.", "error");
            }
        } catch (error) {
            showNotification(error.message || "Failed to update voting power.", "error");
        } finally {
            hideProgress();
        }
    }

    function openTreasury() {
        if (!selectedBackendFundId) return;
        goto(`/funds/${selectedBackendFundId}`);
    }

    function openGovernance(action = null) {
        if (!selectedGovernanceFundId) return;
        const params = new URLSearchParams({ fundId: String(selectedGovernanceFundId) });
        if (action) params.set("open", action);
        goto(`/governance?${params.toString()}`);
    }
</script>

<div class="group-panel mt-8">
    <div class="bg-white rounded-lg p-6 shadow-sm mb-6">
        <h3 class="text-xl font-semibold mb-4">💰 Fund Management</h3>
        <p class="text-sm text-gray-600 mb-4">Create and manage private/public funds. Enable governance per fund when needed.</p>
        <UnifiedGroupManager
            backendActor={backend}
            {governanceActor}
            useMyGroupsApi={true}
            on:groupSelected={handleFundSelected}
        />
    </div>

    <div class="bg-white rounded-lg p-6 shadow-sm">
        <h3 class="text-xl font-semibold mb-4">⚙️ Fund Actions</h3>

        {#if !selectedFund}
            <div class="rounded-lg border border-dashed border-gray-300 bg-gray-50 p-4 text-sm text-gray-600">
                Select a fund above to enable management actions: treasury, governance, assets, policy/rules, and proposals.
            </div>
        {:else}
            <div class="mb-4 rounded-lg border border-gray-200 bg-gray-50 p-4">
                <div class="font-semibold text-gray-900">{selectedFund.name}</div>
                <div class="mt-1 text-sm text-gray-600">{selectedFund.description}</div>
                <div class="mt-2 flex flex-wrap gap-2 text-xs">
                    {#if selectedBackendFundId}
                        <span class="rounded bg-green-100 px-2 py-1 font-semibold text-green-700">💰 Treasury enabled</span>
                    {/if}
                    {#if selectedGovernanceFundId}
                        <span class="rounded bg-blue-100 px-2 py-1 font-semibold text-blue-700">⚖️ Governance enabled</span>
                    {/if}
                </div>
            </div>

            <div class="grid grid-cols-1 md:grid-cols-2 gap-3">
                <button
                    class="rounded-lg bg-slate-900 px-4 py-3 text-left text-white hover:bg-slate-800 disabled:cursor-not-allowed disabled:opacity-50"
                    on:click={openTreasury}
                    disabled={!selectedBackendFundId}
                >
                    <div class="font-semibold">Treasury</div>
                    <div class="text-xs text-slate-300 mt-1">Members, balances, and native fund operations</div>
                </button>

                <button
                    class="rounded-lg bg-blue-600 px-4 py-3 text-left text-white hover:bg-blue-700 disabled:cursor-not-allowed disabled:opacity-50"
                    on:click={() => openGovernance()}
                    disabled={!selectedGovernanceFundId}
                >
                    <div class="font-semibold">Governance</div>
                    <div class="text-xs text-blue-100 mt-1">Open governance dashboard for this fund</div>
                </button>

                <button
                    class="rounded-lg bg-emerald-600 px-4 py-3 text-left text-white hover:bg-emerald-700 disabled:cursor-not-allowed disabled:opacity-50"
                    on:click={() => openGovernance("asset")}
                    disabled={!selectedGovernanceFundId}
                >
                    <div class="font-semibold">Assets</div>
                    <div class="text-xs text-emerald-100 mt-1">Register or update governance assets</div>
                </button>

                <button
                    class="rounded-lg bg-violet-600 px-4 py-3 text-left text-white hover:bg-violet-700 disabled:cursor-not-allowed disabled:opacity-50"
                    on:click={() => openGovernance("rule")}
                    disabled={!selectedGovernanceFundId}
                >
                    <div class="font-semibold">Policy & Rules</div>
                    <div class="text-xs text-violet-100 mt-1">Set threshold, quorum, and timelock policy</div>
                </button>

                <button
                    class="rounded-lg bg-cyan-700 px-4 py-3 text-left text-white hover:bg-cyan-800 disabled:cursor-not-allowed disabled:opacity-50 md:col-span-2"
                    on:click={() => openGovernance("proposal")}
                    disabled={!selectedGovernanceFundId}
                >
                    <div class="font-semibold">Proposals</div>
                    <div class="text-xs text-cyan-100 mt-1">Create and vote on fund governance proposals</div>
                </button>
            </div>

            {#if !selectedGovernanceFundId}
                <p class="mt-3 text-xs text-amber-700 bg-amber-50 border border-amber-200 rounded p-3">
                    This fund currently has no governance module linked. Governance actions become available after governance is enabled for the fund.
                </p>
            {/if}
        {/if}
    </div>

    <div class="bg-white rounded-lg p-6 shadow-sm mt-6">
        <h3 class="text-xl font-semibold mb-4">🛠️ Fund Metadata & Members</h3>

        {#if !selectedFund}
            <div class="rounded-lg border border-dashed border-gray-300 bg-gray-50 p-4 text-sm text-gray-600">
                Select a fund above to update metadata and manage members.
            </div>
        {:else if !selectedBackendFund}
            <div class="rounded-lg border border-amber-200 bg-amber-50 p-4 text-sm text-amber-700">
                This selection has no treasury fund record available for metadata/member updates yet.
            </div>
        {:else}
            <div class="grid grid-cols-1 md:grid-cols-2 gap-4">
                <div class="md:col-span-2">
                    <label for="fund-edit-name" class="block text-sm font-medium text-gray-700 mb-1">Fund Name</label>
                    <input
                        id="fund-edit-name"
                        type="text"
                        bind:value={editName}
                        class="w-full rounded-lg border border-gray-300 px-3 py-2 text-gray-900"
                    />
                </div>
                <div class="md:col-span-2">
                    <label for="fund-edit-description" class="block text-sm font-medium text-gray-700 mb-1">Description</label>
                    <textarea
                        id="fund-edit-description"
                        rows="3"
                        bind:value={editDescription}
                        class="w-full rounded-lg border border-gray-300 px-3 py-2 text-gray-900"
                    ></textarea>
                </div>
                <div class="md:col-span-2 flex items-center gap-2">
                    <input id="fund-edit-public" type="checkbox" bind:checked={editIsPublic} class="rounded border-gray-300" />
                    <label for="fund-edit-public" class="text-sm text-gray-700">Public fund</label>
                </div>
            </div>
            <button
                class="mt-4 rounded-lg bg-blue-600 px-4 py-2 text-sm font-semibold text-white hover:bg-blue-700"
                on:click={updateFundMetadata}
            >
                Save Fund Metadata
            </button>

            <h4 class="text-lg font-semibold mt-8 mb-4">👥 Members</h4>

            <div class="grid grid-cols-1 md:grid-cols-4 gap-3 mb-4">
                <input
                    type="text"
                    bind:value={newMemberName}
                    placeholder="Member name"
                    class="rounded-lg border border-gray-300 px-3 py-2 text-gray-900"
                />
                <input
                    type="text"
                    bind:value={newMemberPrincipal}
                    placeholder="Principal"
                    class="rounded-lg border border-gray-300 px-3 py-2 text-gray-900 md:col-span-2"
                />
                <input
                    type="number"
                    min="1"
                    bind:value={newMemberVotingPower}
                    placeholder="Voting"
                    class="rounded-lg border border-gray-300 px-3 py-2 text-gray-900"
                />
            </div>

            <button
                class="mb-4 rounded-lg bg-emerald-600 px-4 py-2 text-sm font-semibold text-white hover:bg-emerald-700"
                on:click={addMember}
            >
                Add Member
            </button>

            <div class="space-y-3">
                {#if selectedBackendFund.members.length === 0}
                    <p class="rounded-lg bg-gray-50 p-3 text-sm text-gray-600">No members found for this fund.</p>
                {:else}
                    {#each selectedBackendFund.members as member}
                        <div class="rounded-lg border border-gray-200 p-4">
                            <div class="grid grid-cols-1 md:grid-cols-5 gap-3 items-end">
                                <div>
                                    <label class="block text-xs text-gray-600 mb-1">Name</label>
                                    <input
                                        type="text"
                                        value={member.name}
                                        on:change={(e) => updateMemberName(member.principal, e.target.value)}
                                        class="w-full rounded-lg border border-gray-300 px-3 py-2 text-gray-900"
                                    />
                                </div>
                                <div class="md:col-span-2">
                                    <label class="block text-xs text-gray-600 mb-1">Principal</label>
                                    <div class="rounded-lg bg-gray-50 border border-gray-200 px-3 py-2 text-xs break-all text-gray-700">
                                        {member.principal.toText()}
                                    </div>
                                </div>
                                <div>
                                    <label class="block text-xs text-gray-600 mb-1">Voting Power</label>
                                    <input
                                        type="number"
                                        min="1"
                                        value={Number(member.votingPower)}
                                        on:change={(e) => updateMemberVotingPower(member.principal, e.target.value)}
                                        class="w-full rounded-lg border border-gray-300 px-3 py-2 text-gray-900"
                                    />
                                </div>
                                <div>
                                    <button
                                        class="w-full rounded-lg bg-rose-600 px-3 py-2 text-sm font-semibold text-white hover:bg-rose-700"
                                        on:click={() => removeMember(member.principal)}
                                    >
                                        Remove
                                    </button>
                                </div>
                            </div>
                        </div>
                    {/each}
                {/if}
            </div>
        {/if}
    </div>
</div>
