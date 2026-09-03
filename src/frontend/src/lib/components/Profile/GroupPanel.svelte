<script>
  import { onMount } from "svelte";
  import { goto } from "$app/navigation";
  import { globalStore } from "$lib/store";
  import { showNotification } from "$lib/stores/notification";
  import { getCurrencyName, getCurrencyObjectByName, getDecimalsByCurrency } from "$lib/utils/currency.utils";

  let backend;
  let principal;
  let isAuthed = false;
  let funds = [];
  let loading = false;
  let creating = false;
  let showCreate = false;
  let name = "";
  let description = "";
  let isPublic = true;
  let currency = "ICP";
  let customCurrency = "";

  onMount(() => {
    const unsubscribe = globalStore.subscribe((store) => {
      const changed = backend !== store.backend || principal?.toText?.() !== store.principal?.toText?.();
      backend = store.backend;
      principal = store.principal;
      isAuthed = store.isAuthed;
      if (backend && isAuthed && changed) void loadFunds();
    });
    return unsubscribe;
  });

  $: principalText = principal?.toText?.() ?? "";
  $: ownedCount = funds.filter((fund) => fund.creator.toText() === principalText).length;
  $: participatingCount = Math.max(0, funds.length - ownedCount);

  async function loadFunds() {
    if (!backend || !isAuthed) return;
    loading = true;
    try {
      funds = (await backend.getMyGroups()) ?? [];
      funds = [...funds].sort((a, b) => a.createdAt === b.createdAt ? 0 : a.createdAt > b.createdAt ? -1 : 1);
    } catch (error) {
      showNotification(error?.message ?? "Unable to load funds.", "error");
    } finally {
      loading = false;
    }
  }

  function myMember(fund) {
    if (!principalText) return null;
    return fund.members.find((member) => member.principal.toText() === principalText) ?? null;
  }

  function roleLabel(fund) {
    if (fund.creator.toText() === principalText) return "Owner";
    const member = myMember(fund);
    return member && BigInt(member.votingPower ?? 0) > 0n ? "Voting member" : "Observer";
  }

  function isCustomIcrc(currencyVariant) {
    return Boolean(
      currencyVariant &&
      typeof currencyVariant === "object" &&
      Object.prototype.hasOwnProperty.call(currencyVariant, "ICRC")
    );
  }

  function formatTokenAmount(raw, currencyVariant) {
    try {
      const value = BigInt(raw ?? 0);
      if (isCustomIcrc(currencyVariant)) return value.toString();
      const decimals = Math.max(0, Math.min(getDecimalsByCurrency(currencyVariant), 30));
      const scale = 10n ** BigInt(decimals);
      const whole = value / scale;
      const fraction = (value % scale).toString().padStart(decimals, "0").replace(/0+$/, "");
      return fraction ? `${whole}.${fraction}` : whole.toString();
    } catch {
      return "Unavailable";
    }
  }

  async function createFund() {
    if (!backend || creating) return;
    const cleanName = name.trim();
    const cleanDescription = description.trim();
    const selectedCurrency = currency === "ICRC" ? customCurrency.trim() : currency;
    if (!cleanName) {
      showNotification("Fund name is required.", "error");
      return;
    }
    if (!selectedCurrency) {
      showNotification("Enter the ICRC ledger canister or token identifier.", "error");
      return;
    }

    creating = true;
    try {
      const result = await backend.createGroup(
        cleanName,
        cleanDescription,
        isPublic,
        getCurrencyObjectByName(selectedCurrency),
      );
      if (result && Object.prototype.hasOwnProperty.call(result, "ok")) {
        const created = result.ok;
        name = "";
        description = "";
        isPublic = true;
        currency = "ICP";
        customCurrency = "";
        showCreate = false;
        showNotification("Fund created.", "success");
        await loadFunds();
        goto(`/funds/${created.id}`);
      } else {
        showNotification(result?.err ?? "Unable to create fund.", "error");
      }
    } catch (error) {
      showNotification(error?.message ?? "Unable to create fund.", "error");
    } finally {
      creating = false;
    }
  }
</script>

<div class="space-y-5">
  <section class="rounded-2xl border border-slate-200 bg-white p-5 shadow-sm sm:p-6">
    <div class="flex flex-col gap-4 sm:flex-row sm:items-start sm:justify-between">
      <div>
        <p class="text-xs font-semibold uppercase tracking-[0.2em] text-sky-600">My funds</p>
        <h2 class="mt-1 text-2xl font-semibold text-slate-950">Fund management</h2>
        <p class="mt-2 max-w-2xl text-sm leading-6 text-slate-600">
          One fund, one membership model. Create funds here, then manage treasury identity, members, voting power, and proposals from the fund workspace.
        </p>
      </div>
      <button
        type="button"
        on:click={() => showCreate = !showCreate}
        class="w-fit rounded-xl bg-slate-950 px-4 py-2.5 text-sm font-semibold text-white hover:bg-slate-800"
      >
        {showCreate ? "Cancel" : "+ Create fund"}
      </button>
    </div>

    <div class="mt-5 grid gap-3 sm:grid-cols-3">
      <div class="rounded-xl bg-slate-50 p-4">
        <div class="text-xs font-semibold uppercase tracking-wide text-slate-400">Memberships</div>
        <div class="mt-1 text-2xl font-semibold text-slate-950">{funds.length}</div>
      </div>
      <div class="rounded-xl bg-slate-50 p-4">
        <div class="text-xs font-semibold uppercase tracking-wide text-slate-400">Owned</div>
        <div class="mt-1 text-2xl font-semibold text-slate-950">{ownedCount}</div>
      </div>
      <div class="rounded-xl bg-slate-50 p-4">
        <div class="text-xs font-semibold uppercase tracking-wide text-slate-400">Participating</div>
        <div class="mt-1 text-2xl font-semibold text-slate-950">{participatingCount}</div>
      </div>
    </div>
  </section>

  {#if showCreate}
    <section class="rounded-2xl border border-sky-200 bg-sky-50/70 p-5 sm:p-6">
      <div class="flex flex-col gap-1">
        <h3 class="text-lg font-semibold text-slate-950">Create a fund</h3>
        <p class="text-sm text-slate-600">Creating a fund currently requires Defunds voting power. The creator starts with fund voting power 1.</p>
      </div>

      <div class="mt-5 grid gap-4">
        <label class="grid gap-1.5 text-sm font-medium text-slate-700">
          Fund name
          <input bind:value={name} placeholder="Community reserve" class="rounded-xl border border-slate-300 bg-white px-3 py-2.5 font-normal text-slate-900 outline-none focus:border-sky-500" />
        </label>
        <label class="grid gap-1.5 text-sm font-medium text-slate-700">
          Description
          <textarea bind:value={description} rows="3" placeholder="What this fund exists to manage" class="rounded-xl border border-slate-300 bg-white px-3 py-2.5 font-normal text-slate-900 outline-none focus:border-sky-500"></textarea>
        </label>
        <div class="grid gap-4 sm:grid-cols-2">
          <label class="grid gap-1.5 text-sm font-medium text-slate-700">
            Currency
            <select bind:value={currency} class="rounded-xl border border-slate-300 bg-white px-3 py-2.5 font-normal text-slate-900 outline-none focus:border-sky-500">
              <option value="ICP">ICP</option>
              <option value="ckBTC">ckBTC</option>
              <option value="ckETH">ckETH</option>
              <option value="ckUSDC">ckUSDC</option>
              <option value="ICRC">Other ICRC</option>
            </select>
          </label>
          <label class="flex items-center gap-3 rounded-xl border border-slate-200 bg-white px-4 py-3 text-sm font-medium text-slate-700">
            <input type="checkbox" bind:checked={isPublic} class="h-4 w-4 rounded border-slate-300" />
            Publicly discoverable
          </label>
        </div>
        {#if currency === "ICRC"}
          <label class="grid gap-1.5 text-sm font-medium text-slate-700">
            ICRC identifier
            <input bind:value={customCurrency} placeholder="Ledger canister or configured token identifier" class="rounded-xl border border-slate-300 bg-white px-3 py-2.5 font-mono font-normal text-slate-900 outline-none focus:border-sky-500" />
            <span class="text-xs font-normal text-violet-700">Token decimals are not fetched yet; balances and proposal amounts use raw ledger base units.</span>
          </label>
        {/if}
        <div class="flex justify-end">
          <button type="button" disabled={creating} on:click={createFund} class="rounded-xl bg-sky-600 px-5 py-2.5 text-sm font-semibold text-white hover:bg-sky-500 disabled:opacity-50">
            {creating ? "Creating…" : "Create fund"}
          </button>
        </div>
      </div>
    </section>
  {/if}

  <section class="rounded-2xl border border-slate-200 bg-white p-5 shadow-sm sm:p-6">
    <div class="flex flex-col gap-3 sm:flex-row sm:items-center sm:justify-between">
      <div>
        <h3 class="text-lg font-semibold text-slate-950">Your fund memberships</h3>
        <p class="mt-1 text-sm text-slate-500">Observers can inspect a public fund but cannot vote until the owner grants voting power.</p>
      </div>
      <button type="button" on:click={() => goto('/funds')} class="w-fit rounded-xl border border-slate-300 px-3 py-2 text-sm font-semibold text-slate-700 hover:bg-slate-50">Browse public funds</button>
    </div>

    {#if loading}
      <div class="mt-5 rounded-xl bg-slate-50 px-4 py-8 text-center text-sm text-slate-500">Loading funds…</div>
    {:else if funds.length === 0}
      <div class="mt-5 rounded-xl border border-dashed border-slate-300 px-4 py-10 text-center">
        <div class="text-sm font-semibold text-slate-700">No fund memberships yet</div>
        <p class="mt-1 text-sm text-slate-500">Create a fund or join a public fund as an observer.</p>
      </div>
    {:else}
      <div class="mt-5 grid gap-3">
        {#each funds as fund (fund.id)}
          <article class="flex flex-col gap-4 rounded-2xl border border-slate-200 p-4 sm:flex-row sm:items-center sm:justify-between">
            <div class="min-w-0">
              <div class="flex flex-wrap items-center gap-2">
                <h4 class="font-semibold text-slate-950">{fund.name}</h4>
                <span class="rounded-full bg-sky-50 px-2 py-0.5 text-xs font-semibold text-sky-700">{roleLabel(fund)}</span>
                <span class="rounded-full bg-slate-100 px-2 py-0.5 text-xs font-semibold text-slate-600">{getCurrencyName(fund.currency)}</span>
                <span class="rounded-full px-2 py-0.5 text-xs font-semibold {fund.isPublic ? 'bg-emerald-50 text-emerald-700' : 'bg-slate-100 text-slate-600'}">{fund.isPublic ? "Public" : "Private"}</span>
              </div>
              <p class="mt-1 line-clamp-2 text-sm text-slate-500">{fund.description || "No description provided."}</p>
              <div class="mt-2 text-xs text-slate-400">{fund.members.length} members · {isCustomIcrc(fund.currency) ? "recorded base units" : "recorded balance"} {formatTokenAmount(fund.balance, fund.currency)} {isCustomIcrc(fund.currency) ? "base units" : getCurrencyName(fund.currency)}</div>
            </div>
            <button type="button" on:click={() => goto(`/funds/${fund.id}`)} class="shrink-0 rounded-xl bg-slate-950 px-4 py-2.5 text-sm font-semibold text-white hover:bg-slate-800">Open fund</button>
          </article>
        {/each}
      </div>
    {/if}
  </section>

  <section class="rounded-2xl border border-violet-200 bg-violet-50 px-5 py-4 text-sm text-violet-900">
    <strong>Governance registry is separate.</strong> Native Fund membership no longer depends on linking a backend group to a governance group. Use the Governance workspace for registered assets, policy, and external-asset governance.
    <button type="button" on:click={() => goto('/governance')} class="ml-2 font-semibold underline underline-offset-2">Open Governance →</button>
  </section>
</div>
