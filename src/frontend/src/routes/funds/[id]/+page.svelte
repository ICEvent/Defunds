<script>
  import { onMount } from "svelte";
  import { page } from "$app/stores";
  import { goto } from "$app/navigation";
  import { Principal } from "@dfinity/principal";
  import { showNotification } from "$lib/stores/notification";
  import { hideProgress, showProgress } from "$lib/stores/progress";
  import { getCurrencyName, getDecimalsByCurrency } from "$lib/utils/currency.utils";

  let groupId;
  let group = null;
  let proposals = [];
  let backend;
  let principal;
  let isAuthed = false;
  let showAddMember = false;
  let showCreateProposal = false;
  let newMemberName = "";
  let newMemberPrincipal = "";
  let newMemberVotingPower = "1";
  let proposalTitle = "";
  let proposalDescription = "";
  let proposalRecipient = "";
  let proposalAmount = "";
  let busyAction = "";
  let editingPowerFor = "";
  let editingPowerValue = "";

  $: principalText = principal?.toText?.() ?? "";
  $: myMember = group && principalText ? group.members.find((member) => member.principal.toText() === principalText) ?? null : null;
  $: isMember = Boolean(myMember);
  $: isCreator = Boolean(group && principalText && group.creator.toText() === principalText);
  $: myVotingPower = BigInt(myMember?.votingPower ?? 0);
  $: canGovern = myVotingPower > 0n;
  $: currency = group ? getCurrencyName(group.currency) : "";
  $: decimals = group ? getDecimalsByCurrency(group.currency) : 8;
  $: totalVotingPower = group ? (() => {
    const counted = new Set();
    return group.members.reduce((sum, member) => {
      const id = member.principal.toText();
      if (counted.has(id)) return sum;
      counted.add(id);
      return sum + BigInt(member.votingPower ?? 0);
    }, 0n);
  })() : 0n;

  onMount(() => {
    groupId = BigInt($page.params.id);
    let unsubscribe;
    let disposed = false;

    import("$lib/store").then(({ globalStore }) => {
      if (disposed) return;
      unsubscribe = globalStore.subscribe((store) => {
        const actorChanged = backend !== store.backend;
        backend = store.backend;
        principal = store.principal;
        isAuthed = store.isAuthed;
        if (backend && actorChanged) void loadGroupData();
      });
    });

    return () => {
      disposed = true;
      unsubscribe?.();
    };
  });

  async function loadGroupData() {
    showProgress();
    try {
      const [groupResult, proposalResult] = await Promise.all([
        backend.getGroup(groupId),
        backend.getGroupProposals(groupId),
      ]);
      const loadedGroup = Array.isArray(groupResult) && groupResult.length > 0 ? groupResult[0] : null;
      if (!loadedGroup) {
        showNotification("Fund not found.", "error");
        goto("/funds");
        return;
      }
      group = loadedGroup;
      proposals = [...(proposalResult ?? [])].sort((a, b) => a.createdAt === b.createdAt ? 0 : a.createdAt > b.createdAt ? -1 : 1);
    } catch (error) {
      showNotification(`Unable to load fund: ${error?.message ?? error}`, "error");
    } finally {
      hideProgress();
    }
  }

  function formatDate(timestamp) {
    return new Date(Number(timestamp) / 1_000_000).toLocaleString();
  }

  function formatAccount(account) {
    if (!account?.length) return "Unavailable";
    return account.map((byte) => byte.toString(16).padStart(2, "0")).join("");
  }

  function formatTokenAmount(raw, precision = decimals) {
    try {
      const value = BigInt(raw ?? 0);
      const safeDecimals = Math.max(0, Math.min(precision, 30));
      const scale = 10n ** BigInt(safeDecimals);
      const whole = value / scale;
      const fraction = (value % scale).toString().padStart(safeDecimals, "0").slice(0, 8).replace(/0+$/, "");
      return fraction ? `${whole}.${fraction}` : whole.toString();
    } catch {
      return "Unavailable";
    }
  }

  function parseTokenAmount(value, precision = decimals) {
    const text = String(value ?? "").trim();
    if (!/^\d+(\.\d+)?$/.test(text)) throw new Error("Enter a valid positive amount.");
    const [whole, fraction = ""] = text.split(".");
    if (fraction.length > precision) throw new Error(`${currency} supports at most ${precision} decimal places.`);
    const scale = 10n ** BigInt(precision);
    const fractionUnits = BigInt((fraction + "0".repeat(precision)).slice(0, precision) || "0");
    const amount = BigInt(whole) * scale + fractionUnits;
    if (amount <= 0n) throw new Error("Amount must be greater than zero.");
    return amount;
  }

  function statusKey(status) {
    return Object.keys(status ?? {})[0] ?? "unknown";
  }

  function statusLabel(status) {
    const key = statusKey(status);
    if (key === "accepted") return "Approved";
    if (key === "executed") return "Executed";
    if (key === "rejected") return "Rejected";
    if (key === "active") return "Voting";
    return key;
  }

  function statusClass(status) {
    const key = statusKey(status);
    if (key === "accepted") return "border-emerald-200 bg-emerald-50 text-emerald-700";
    if (key === "executed") return "border-violet-200 bg-violet-50 text-violet-700";
    if (key === "rejected") return "border-rose-200 bg-rose-50 text-rose-700";
    return "border-sky-200 bg-sky-50 text-sky-700";
  }

  function hasVoted(proposal) {
    if (!principalText) return false;
    return proposal.yesVotes.some((vote) => vote.toText() === principalText)
      || proposal.noVotes.some((vote) => vote.toText() === principalText);
  }

  function votePowerFor(voters) {
    if (!group) return 0n;
    const voterSet = new Set(voters.map((principalValue) => principalValue.toText()));
    const counted = new Set();
    return group.members.reduce((total, member) => {
      const id = member.principal.toText();
      if (!voterSet.has(id) || counted.has(id)) return total;
      counted.add(id);
      return total + BigInt(member.votingPower ?? 0);
    }, 0n);
  }

  function percent(power) {
    if (totalVotingPower === 0n) return 0;
    return Number((power * 10_000n) / totalVotingPower) / 100;
  }

  async function runAction(name, action, successMessage) {
    if (busyAction) return false;
    busyAction = name;
    try {
      const result = await action();
      if (result && Object.prototype.hasOwnProperty.call(result, "ok")) {
        showNotification(successMessage, "success");
        await loadGroupData();
        return true;
      }
      showNotification(result?.err ?? "Action failed.", "error");
      return false;
    } catch (error) {
      showNotification(error?.message ?? "Action failed.", "error");
      return false;
    } finally {
      busyAction = "";
    }
  }

  async function joinGroup() {
    await runAction("join", () => backend.joinGroup(groupId), "Joined as an observer. The fund owner can grant voting power.");
  }

  async function addMember() {
    if (!isCreator) return;
    const name = newMemberName.trim();
    const principalValue = newMemberPrincipal.trim();
    if (!name || !principalValue) {
      showNotification("Member name and Principal are required.", "error");
      return;
    }
    try {
      const votingPower = BigInt(newMemberVotingPower);
      if (votingPower < 0n) throw new Error("Voting power cannot be negative.");
      const memberPrincipal = Principal.fromText(principalValue);
      const success = await runAction(
        "add-member",
        () => backend.addGroupMember(groupId, name, memberPrincipal, votingPower),
        "Member added.",
      );
      if (success) {
        newMemberName = "";
        newMemberPrincipal = "";
        newMemberVotingPower = "1";
        showAddMember = false;
      }
    } catch (error) {
      showNotification(error?.message ?? "Invalid member details.", "error");
    }
  }

  async function removeMember(member) {
    if (!isCreator || member.principal.toText() === group.creator.toText()) return;
    if (!confirm(`Remove ${member.name || "this member"} from the fund?`)) return;
    await runAction(
      `remove-${member.principal.toText()}`,
      () => backend.removeGroupMember(groupId, member.principal),
      "Member removed.",
    );
  }

  function startPowerEdit(member) {
    editingPowerFor = member.principal.toText();
    editingPowerValue = member.votingPower.toString();
  }

  function cancelPowerEdit() {
    editingPowerFor = "";
    editingPowerValue = "";
  }

  async function saveMemberVotingPower(member) {
    if (!isCreator || member.principal.toText() === group.creator.toText()) return;
    try {
      const votingPower = BigInt(editingPowerValue);
      if (votingPower < 0n) throw new Error("Voting power cannot be negative.");
      const success = await runAction(
        `power-${member.principal.toText()}`,
        () => backend.updateGroupMemberVotingPower(groupId, member.principal, votingPower),
        "Voting power updated.",
      );
      if (success) cancelPowerEdit();
    } catch (error) {
      showNotification(error?.message ?? "Invalid voting power.", "error");
    }
  }

  async function createProposal() {
    if (!canGovern) return;
    const title = proposalTitle.trim();
    const description = proposalDescription.trim();
    const recipient = proposalRecipient.trim();
    if (!title || !description || !recipient) {
      showNotification("Title, description, recipient, and amount are required.", "error");
      return;
    }
    try {
      const recipientPrincipal = Principal.fromText(recipient);
      const amount = parseTokenAmount(proposalAmount);
      const success = await runAction(
        "create-proposal",
        () => backend.createGroupProposal(groupId, title, description, recipientPrincipal, amount),
        "Proposal created.",
      );
      if (success) {
        proposalTitle = "";
        proposalDescription = "";
        proposalRecipient = "";
        proposalAmount = "";
        showCreateProposal = false;
      }
    } catch (error) {
      showNotification(error?.message ?? "Invalid proposal.", "error");
    }
  }

  async function voteOnProposal(proposal, voteYes) {
    if (!canGovern || statusKey(proposal.status) !== "active" || hasVoted(proposal)) return;
    await runAction(
      `vote-${proposal.id}`,
      () => backend.voteOnProposal(groupId, proposal.id, voteYes),
      voteYes ? "Yes vote recorded." : "No vote recorded.",
    );
  }

  async function copyAccount() {
    try {
      await navigator.clipboard.writeText(formatAccount(group.account));
      showNotification("Treasury subaccount copied.", "success");
    } catch {
      showNotification("Unable to copy account.", "error");
    }
  }
</script>

<svelte:head>
  <title>{group ? `${group.name} · Defunds` : "Fund · Defunds"}</title>
</svelte:head>

<div class="mx-auto max-w-7xl px-4 py-8 sm:px-6 lg:px-8">
  <button type="button" on:click={() => goto('/funds')} class="mb-4 text-sm font-semibold text-sky-300 hover:text-sky-200">← All funds</button>

  {#if group}
    <section class="rounded-3xl border border-slate-700/70 bg-slate-950/75 p-6 text-white shadow-finance sm:p-8">
      <div class="flex flex-col gap-6 lg:flex-row lg:items-start lg:justify-between">
        <div class="max-w-3xl">
          <div class="flex flex-wrap items-center gap-2">
            <span class="rounded-lg bg-white/10 px-2.5 py-1 text-xs font-semibold">{currency}</span>
            <span class="rounded-full border border-white/15 px-2.5 py-1 text-xs font-semibold text-slate-200">{group.isPublic ? "Public" : "Private"}</span>
            {#if isAuthed}
              <span class="rounded-full border border-sky-400/30 bg-sky-400/10 px-2.5 py-1 text-xs font-semibold text-sky-200">{isCreator ? "Owner" : canGovern ? "Voting member" : isMember ? "Observer" : "Visitor"}</span>
            {/if}
          </div>
          <h1 class="mt-3 text-3xl font-semibold tracking-tight sm:text-4xl">{group.name}</h1>
          <p class="mt-3 max-w-2xl text-sm leading-6 text-slate-300 sm:text-base">{group.description || "No description provided."}</p>
        </div>
        {#if isAuthed && group.isPublic && !isMember}
          <button type="button" disabled={Boolean(busyAction)} on:click={joinGroup} class="rounded-xl bg-sky-500 px-5 py-2.5 text-sm font-semibold text-white hover:bg-sky-400 disabled:opacity-50">
            {busyAction === "join" ? "Joining…" : "Join as observer"}
          </button>
        {/if}
      </div>

      <div class="mt-7 grid gap-3 sm:grid-cols-2 xl:grid-cols-4">
        <div class="rounded-2xl border border-white/10 bg-white/5 p-4">
          <div class="text-xs uppercase tracking-wide text-slate-400">Recorded balance</div>
          <div class="mt-1 text-2xl font-semibold">{formatTokenAmount(group.balance)} {currency}</div>
          <div class="mt-1 text-xs text-amber-200">Not live-ledger verified</div>
        </div>
        <div class="rounded-2xl border border-white/10 bg-white/5 p-4">
          <div class="text-xs uppercase tracking-wide text-slate-400">Members</div>
          <div class="mt-1 text-2xl font-semibold">{group.members.length}</div>
        </div>
        <div class="rounded-2xl border border-white/10 bg-white/5 p-4">
          <div class="text-xs uppercase tracking-wide text-slate-400">Voting power</div>
          <div class="mt-1 text-2xl font-semibold">{totalVotingPower.toString()}</div>
        </div>
        <div class="rounded-2xl border border-white/10 bg-white/5 p-4">
          <div class="text-xs uppercase tracking-wide text-slate-400">Proposals</div>
          <div class="mt-1 text-2xl font-semibold">{proposals.length}</div>
        </div>
      </div>
    </section>

    <section class="mt-6 rounded-2xl border border-slate-200 bg-white p-5 shadow-sm">
      <div class="flex flex-col gap-4 sm:flex-row sm:items-center sm:justify-between">
        <div>
          <div class="text-xs font-semibold uppercase tracking-wide text-slate-400">Treasury identity</div>
          <h2 class="mt-1 text-lg font-semibold text-slate-950">Fund subaccount</h2>
          <p class="mt-1 text-sm text-slate-500">Use this identifier when inspecting or funding the fund treasury.</p>
        </div>
        <button type="button" on:click={copyAccount} class="w-fit rounded-xl border border-slate-300 px-3 py-2 text-sm font-semibold text-slate-700 hover:bg-slate-50">Copy</button>
      </div>
      <div class="mt-4 break-all rounded-xl bg-slate-950 px-4 py-3 font-mono text-xs text-slate-200">{formatAccount(group.account)}</div>
    </section>

    <section class="mt-6 rounded-2xl border border-slate-200 bg-white p-5 shadow-sm sm:p-6">
      <div class="flex flex-col gap-3 sm:flex-row sm:items-center sm:justify-between">
        <div>
          <h2 class="text-xl font-semibold text-slate-950">Members</h2>
          <p class="mt-1 text-sm text-slate-500">Public visitors may join as observers with zero power. The owner explicitly grants governance power.</p>
        </div>
        {#if isCreator}
          <button type="button" on:click={() => showAddMember = !showAddMember} class="rounded-xl bg-slate-950 px-4 py-2 text-sm font-semibold text-white hover:bg-slate-800">
            {showAddMember ? "Cancel" : "+ Add member"}
          </button>
        {/if}
      </div>

      {#if showAddMember && isCreator}
        <div class="mt-4 grid gap-3 rounded-2xl border border-slate-200 bg-slate-50 p-4 lg:grid-cols-[1fr_2fr_160px_auto]">
          <input bind:value={newMemberName} placeholder="Member name" class="rounded-xl border border-slate-300 bg-white px-3 py-2.5 text-sm text-slate-900 outline-none focus:border-sky-500" />
          <input bind:value={newMemberPrincipal} placeholder="Principal" class="rounded-xl border border-slate-300 bg-white px-3 py-2.5 font-mono text-sm text-slate-900 outline-none focus:border-sky-500" />
          <input bind:value={newMemberVotingPower} inputmode="numeric" placeholder="Voting power" class="rounded-xl border border-slate-300 bg-white px-3 py-2.5 text-sm text-slate-900 outline-none focus:border-sky-500" />
          <button type="button" disabled={Boolean(busyAction)} on:click={addMember} class="rounded-xl bg-sky-600 px-4 py-2.5 text-sm font-semibold text-white hover:bg-sky-500 disabled:opacity-50">Add</button>
        </div>
      {/if}

      <div class="mt-4 divide-y divide-slate-100 rounded-2xl border border-slate-200">
        {#each group.members as member (member.principal.toText())}
          <div class="flex flex-col gap-3 p-4 sm:flex-row sm:items-center sm:justify-between">
            <div class="min-w-0">
              <div class="flex flex-wrap items-center gap-2">
                <span class="font-semibold text-slate-950">{member.name || "Unnamed member"}</span>
                {#if member.principal.toText() === group.creator.toText()}
                  <span class="rounded-full bg-slate-950 px-2 py-0.5 text-[10px] font-semibold uppercase tracking-wide text-white">Owner</span>
                {/if}
              </div>
              <div class="mt-1 break-all font-mono text-xs text-slate-500">{member.principal.toText()}</div>
            </div>
            <div class="flex flex-wrap items-center gap-2">
              {#if BigInt(member.votingPower ?? 0) === 0n}
                <span class="rounded-lg bg-slate-100 px-3 py-1.5 text-sm font-semibold text-slate-600">Observer · no voting power</span>
              {:else}
                <span class="rounded-lg bg-sky-50 px-3 py-1.5 text-sm font-semibold text-sky-700">Power {member.votingPower.toString()}</span>
              {/if}
              {#if isCreator && member.principal.toText() !== group.creator.toText()}
                {#if editingPowerFor === member.principal.toText()}
                  <input bind:value={editingPowerValue} inputmode="numeric" aria-label="Voting power" class="w-24 rounded-lg border border-slate-300 px-2 py-1.5 text-sm text-slate-900" />
                  <button type="button" disabled={Boolean(busyAction)} on:click={() => saveMemberVotingPower(member)} class="text-sm font-semibold text-sky-700 hover:text-sky-900 disabled:opacity-50">Save power</button>
                  <button type="button" disabled={Boolean(busyAction)} on:click={cancelPowerEdit} class="text-sm font-semibold text-slate-500 hover:text-slate-700 disabled:opacity-50">Cancel</button>
                {:else}
                  <button type="button" disabled={Boolean(busyAction)} on:click={() => startPowerEdit(member)} class="text-sm font-semibold text-sky-700 hover:text-sky-900 disabled:opacity-50">Set power</button>
                  <button type="button" disabled={Boolean(busyAction)} on:click={() => removeMember(member)} class="text-sm font-semibold text-rose-600 hover:text-rose-700 disabled:opacity-50">Remove</button>
                {/if}
              {/if}
            </div>
          </div>
        {/each}
      </div>
    </section>

    <section class="mt-6 rounded-2xl border border-slate-200 bg-white p-5 shadow-sm sm:p-6">
      <div class="flex flex-col gap-3 sm:flex-row sm:items-center sm:justify-between">
        <div>
          <h2 class="text-xl font-semibold text-slate-950">Proposals</h2>
          <p class="mt-1 text-sm text-slate-500">A proposal is approved only when Yes voting power exceeds 50% of total fund voting power.</p>
        </div>
        {#if canGovern}
          <button type="button" on:click={() => showCreateProposal = !showCreateProposal} class="rounded-xl bg-sky-600 px-4 py-2 text-sm font-semibold text-white hover:bg-sky-500">
            {showCreateProposal ? "Cancel" : "+ New proposal"}
          </button>
        {/if}
      </div>

      {#if isMember && !canGovern}
        <div class="mt-4 rounded-xl border border-sky-200 bg-sky-50 px-4 py-3 text-sm text-sky-800">
          You joined this public fund as an observer. Observation does not grant governance power; the fund owner must explicitly assign voting power before you can create proposals or vote.
        </div>
      {/if}

      <div class="mt-4 rounded-xl border border-amber-200 bg-amber-50 px-4 py-3 text-sm text-amber-800">
        Approval currently represents a governance decision. The Group Fund code does not yet execute the treasury transfer automatically, so approved proposals should be treated as <strong>execution pending</strong> until an execution receipt exists.
      </div>

      {#if showCreateProposal && canGovern}
        <div class="mt-4 grid gap-4 rounded-2xl border border-slate-200 bg-slate-50 p-4">
          <div class="grid gap-4 lg:grid-cols-2">
            <label class="grid gap-1.5 text-sm font-medium text-slate-700">
              Title
              <input bind:value={proposalTitle} placeholder="What should the fund do?" class="rounded-xl border border-slate-300 bg-white px-3 py-2.5 font-normal text-slate-900 outline-none focus:border-sky-500" />
            </label>
            <label class="grid gap-1.5 text-sm font-medium text-slate-700">
              Amount ({currency})
              <input bind:value={proposalAmount} inputmode="decimal" placeholder="0.00" class="rounded-xl border border-slate-300 bg-white px-3 py-2.5 font-normal text-slate-900 outline-none focus:border-sky-500" />
            </label>
          </div>
          <label class="grid gap-1.5 text-sm font-medium text-slate-700">
            Recipient Principal
            <input bind:value={proposalRecipient} placeholder="aaaaa-aa…" class="rounded-xl border border-slate-300 bg-white px-3 py-2.5 font-mono font-normal text-slate-900 outline-none focus:border-sky-500" />
          </label>
          <label class="grid gap-1.5 text-sm font-medium text-slate-700">
            Rationale
            <textarea bind:value={proposalDescription} rows="4" placeholder="Explain the purpose, expected outcome, and why this amount is appropriate." class="rounded-xl border border-slate-300 bg-white px-3 py-2.5 font-normal text-slate-900 outline-none focus:border-sky-500"></textarea>
          </label>
          <div class="flex justify-end">
            <button type="button" disabled={Boolean(busyAction)} on:click={createProposal} class="rounded-xl bg-slate-950 px-5 py-2.5 text-sm font-semibold text-white hover:bg-slate-800 disabled:opacity-50">
              {busyAction === "create-proposal" ? "Creating…" : "Create proposal"}
            </button>
          </div>
        </div>
      {/if}

      {#if proposals.length === 0}
        <div class="mt-5 rounded-2xl border border-dashed border-slate-300 px-5 py-10 text-center text-sm text-slate-500">No proposals yet.</div>
      {:else}
        <div class="mt-5 grid gap-4">
          {#each proposals as proposal (proposal.id)}
            {@const yesPower = votePowerFor(proposal.yesVotes)}
            {@const noPower = votePowerFor(proposal.noVotes)}
            {@const yesPercent = percent(yesPower)}
            {@const noPercent = percent(noPower)}
            <article class="rounded-2xl border border-slate-200 p-5">
              <div class="flex flex-col gap-3 sm:flex-row sm:items-start sm:justify-between">
                <div class="min-w-0">
                  <div class="text-xs font-semibold uppercase tracking-wide text-slate-400">Proposal #{proposal.id.toString()}</div>
                  <h3 class="mt-1 text-lg font-semibold text-slate-950">{proposal.title}</h3>
                  <p class="mt-2 text-sm leading-6 text-slate-600">{proposal.description}</p>
                </div>
                <span class="w-fit rounded-full border px-2.5 py-1 text-xs font-semibold {statusClass(proposal.status)}">{statusLabel(proposal.status)}</span>
              </div>

              <div class="mt-4 grid gap-3 md:grid-cols-3">
                <div class="rounded-xl bg-slate-50 p-3">
                  <div class="text-[11px] font-semibold uppercase tracking-wide text-slate-400">Amount</div>
                  <div class="mt-1 font-semibold text-slate-900">{formatTokenAmount(proposal.amount)} {currency}</div>
                </div>
                <div class="rounded-xl bg-slate-50 p-3 md:col-span-2">
                  <div class="text-[11px] font-semibold uppercase tracking-wide text-slate-400">Recipient</div>
                  <div class="mt-1 break-all font-mono text-xs text-slate-700">{proposal.recipient.toText()}</div>
                </div>
              </div>

              <div class="mt-4">
                <div class="flex justify-between text-xs text-slate-500">
                  <span>Yes power {yesPower.toString()} · {yesPercent.toFixed(1)}%</span>
                  <span>No power {noPower.toString()} · {noPercent.toFixed(1)}%</span>
                </div>
                <div class="mt-2 flex h-2 overflow-hidden rounded-full bg-slate-100">
                  <div class="bg-emerald-500" style={`width: ${Math.min(100, yesPercent)}%`}></div>
                  <div class="bg-rose-400" style={`width: ${Math.min(100 - Math.min(100, yesPercent), noPercent)}%`}></div>
                </div>
                <div class="mt-2 text-xs text-slate-400">Total voting power: {totalVotingPower.toString()} · Created {formatDate(proposal.createdAt)}</div>
              </div>

              {#if statusKey(proposal.status) === "accepted"}
                <div class="mt-4 rounded-xl border border-emerald-200 bg-emerald-50 px-3 py-2 text-xs text-emerald-800">Approved by governance · treasury execution is still pending.</div>
              {/if}

              {#if canGovern && statusKey(proposal.status) === "active"}
                <div class="mt-4 flex flex-wrap items-center gap-2">
                  {#if hasVoted(proposal)}
                    <span class="rounded-lg bg-slate-100 px-3 py-2 text-sm font-semibold text-slate-600">Vote recorded</span>
                  {:else}
                    <button type="button" disabled={Boolean(busyAction)} on:click={() => voteOnProposal(proposal, true)} class="rounded-xl bg-emerald-600 px-4 py-2 text-sm font-semibold text-white hover:bg-emerald-500 disabled:opacity-50">Vote yes</button>
                    <button type="button" disabled={Boolean(busyAction)} on:click={() => voteOnProposal(proposal, false)} class="rounded-xl border border-rose-300 px-4 py-2 text-sm font-semibold text-rose-700 hover:bg-rose-50 disabled:opacity-50">Vote no</button>
                  {/if}
                </div>
              {/if}
            </article>
          {/each}
        </div>
      {/if}
    </section>
  {:else}
    <section class="rounded-2xl border border-slate-700 bg-slate-900/70 px-6 py-14 text-center text-slate-300">Loading fund…</section>
  {/if}
</div>
