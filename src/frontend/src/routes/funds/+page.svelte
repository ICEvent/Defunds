<script>
  import { onMount } from "svelte";
  import { goto } from "$app/navigation";
  import { showNotification } from "$lib/stores/notification";
  import { hideProgress, showProgress } from "$lib/stores/progress";
  import { getCurrencyName, getDecimalsByCurrency } from "$lib/utils/currency.utils";

  let backend;
  let principal;
  let isAuthed = false;
  let publicGroups = [];
  let myGroups = [];
  let activeTab = "public";
  let search = "";
  let currencyFilter = "all";
  let joiningGroupId = null;
  let loadVersion = 0;

  onMount(() => {
    let unsubscribe;
    let disposed = false;

    import("$lib/store").then(({ globalStore }) => {
      if (disposed) return;
      unsubscribe = globalStore.subscribe((store) => {
        const actorChanged = backend !== store.backend;
        const authChanged = isAuthed !== store.isAuthed || principal?.toText?.() !== store.principal?.toText?.();
        backend = store.backend;
        principal = store.principal;
        isAuthed = store.isAuthed;
        if (backend && (actorChanged || authChanged)) void loadGroups();
      });
    });

    return () => {
      disposed = true;
      unsubscribe?.();
    };
  });

  $: if (!isAuthed && activeTab === "mine") activeTab = "public";
  $: sourceGroups = activeTab === "mine" ? myGroups : publicGroups;
  $: currencies = ["all", ...new Set(sourceGroups.map((group) => getCurrencyName(group.currency)))];
  $: if (!currencies.includes(currencyFilter)) currencyFilter = "all";
  $: visibleGroups = sourceGroups
    .filter((group) => currencyFilter === "all" || getCurrencyName(group.currency) === currencyFilter)
    .filter((group) => {
      const needle = search.trim().toLowerCase();
      if (!needle) return true;
      return `${group.name} ${group.description ?? ""}`.toLowerCase().includes(needle);
    })
    .sort((a, b) => (a.createdAt === b.createdAt ? 0 : a.createdAt > b.createdAt ? -1 : 1));

  async function loadGroups() {
    const version = ++loadVersion;
    showProgress();
    try {
      const [publicResult, myResult] = await Promise.all([
        backend.getPublicGroups(),
        isAuthed ? backend.getMyGroups() : Promise.resolve([]),
      ]);
      if (version !== loadVersion) return;
      publicGroups = publicResult ?? [];
      myGroups = myResult ?? [];
    } catch (error) {
      showNotification(`Unable to load funds: ${error?.message ?? error}`, "error");
    } finally {
      if (version === loadVersion) hideProgress();
    }
  }

  function isMember(group) {
    if (!principal) return false;
    const me = principal.toText();
    return group.members?.some((member) => member.principal.toText() === me) ?? false;
  }

  function isOwner(group) {
    return Boolean(principal && group.creator?.toText?.() === principal.toText());
  }

  function memberRecord(group) {
    if (!principal) return null;
    const me = principal.toText();
    return group.members?.find((member) => member.principal.toText() === me) ?? null;
  }

  function roleLabel(group) {
    if (isOwner(group)) return "Owner";
    const member = memberRecord(group);
    if (!member) return "Visitor";
    return BigInt(member.votingPower ?? 0) > 0n ? "Voting member" : "Observer";
  }

  function formatTokenAmount(raw, currency) {
    try {
      const value = BigInt(raw ?? 0);
      const decimals = Math.max(0, Math.min(getDecimalsByCurrency(currency), 30));
      const scale = 10n ** BigInt(decimals);
      const whole = value / scale;
      const fraction = (value % scale).toString().padStart(decimals, "0").slice(0, 6).replace(/0+$/, "");
      return fraction ? `${whole}.${fraction}` : whole.toString();
    } catch {
      return "Unavailable";
    }
  }

  function shortAccount(account) {
    if (!account?.length) return "Unavailable";
    const hex = account.map((byte) => byte.toString(16).padStart(2, "0")).join("");
    return hex.length > 22 ? `${hex.slice(0, 12)}…${hex.slice(-8)}` : hex;
  }

  async function joinGroup(groupId) {
    if (!backend || !isAuthed || joiningGroupId !== null) return;
    joiningGroupId = groupId;
    try {
      const result = await backend.joinGroup(groupId);
      if (result && Object.prototype.hasOwnProperty.call(result, "ok")) {
        showNotification("Joined as an observer. The fund owner can grant voting power.", "success");
        await loadGroups();
      } else {
        showNotification(result?.err ?? "Unable to join fund.", "error");
      }
    } catch (error) {
      showNotification(error?.message ?? "Unable to join fund.", "error");
    } finally {
      joiningGroupId = null;
    }
  }
</script>

<svelte:head>
  <title>Funds · Defunds</title>
</svelte:head>

<div class="mx-auto max-w-7xl px-4 py-8 sm:px-6 lg:px-8">
  <section class="overflow-hidden rounded-3xl border border-slate-700/70 bg-slate-950/70 p-6 shadow-finance backdrop-blur sm:p-8">
    <div class="flex flex-col gap-5 lg:flex-row lg:items-end lg:justify-between">
      <div class="max-w-3xl">
        <p class="text-xs font-semibold uppercase tracking-[0.24em] text-sky-400">Community capital</p>
        <h1 class="mt-2 text-3xl font-semibold tracking-tight text-white sm:text-4xl">Funds</h1>
        <p class="mt-3 max-w-2xl text-sm leading-6 text-slate-300 sm:text-base">
          Discover transparent member-governed funds, inspect their treasury identity, and participate in allocation decisions. Public funds are open to inspect; governance power is explicitly granted.
        </p>
      </div>
      <div class="rounded-2xl border border-amber-400/20 bg-amber-400/10 px-4 py-3 text-xs leading-5 text-amber-100">
        Balance shown below is the fund's recorded balance field, not a verified live-ledger balance yet.
      </div>
    </div>
  </section>

  <section class="mt-6 rounded-2xl border border-slate-200 bg-white p-4 shadow-sm sm:p-5">
    <div class="flex flex-col gap-4 lg:flex-row lg:items-center lg:justify-between">
      <div class="inline-flex w-fit rounded-xl bg-slate-100 p-1">
        <button
          type="button"
          on:click={() => { activeTab = "public"; currencyFilter = "all"; }}
          class="rounded-lg px-4 py-2 text-sm font-semibold transition {activeTab === 'public' ? 'bg-white text-slate-950 shadow-sm' : 'text-slate-500 hover:text-slate-800'}"
        >
          Public funds <span class="ml-1 text-xs text-slate-400">{publicGroups.length}</span>
        </button>
        {#if isAuthed}
          <button
            type="button"
            on:click={() => { activeTab = "mine"; currencyFilter = "all"; }}
            class="rounded-lg px-4 py-2 text-sm font-semibold transition {activeTab === 'mine' ? 'bg-white text-slate-950 shadow-sm' : 'text-slate-500 hover:text-slate-800'}"
          >
            My funds <span class="ml-1 text-xs text-slate-400">{myGroups.length}</span>
          </button>
        {/if}
      </div>

      <div class="grid gap-3 sm:grid-cols-[minmax(0,1fr)_180px] lg:w-[520px]">
        <label class="sr-only" for="fund-search">Search funds</label>
        <input
          id="fund-search"
          bind:value={search}
          placeholder="Search funds"
          class="w-full rounded-xl border border-slate-300 bg-white px-3 py-2.5 text-sm text-slate-900 outline-none transition focus:border-sky-500 focus:ring-2 focus:ring-sky-100"
        />
        <label class="sr-only" for="currency-filter">Currency</label>
        <select
          id="currency-filter"
          bind:value={currencyFilter}
          class="rounded-xl border border-slate-300 bg-white px-3 py-2.5 text-sm text-slate-800 outline-none focus:border-sky-500"
        >
          {#each currencies as currency}
            <option value={currency}>{currency === "all" ? "All currencies" : currency}</option>
          {/each}
        </select>
      </div>
    </div>
  </section>

  {#if visibleGroups.length === 0}
    <section class="mt-6 rounded-2xl border border-dashed border-slate-600 bg-slate-900/60 px-6 py-14 text-center">
      <div class="text-3xl">◎</div>
      <h2 class="mt-3 text-lg font-semibold text-white">No matching funds</h2>
      <p class="mx-auto mt-2 max-w-md text-sm text-slate-400">
        {activeTab === "mine" ? "You are not currently a member of a matching fund." : "Try another search or currency filter."}
      </p>
      {#if isAuthed && activeTab === "mine"}
        <button type="button" on:click={() => goto('/profile')} class="mt-5 rounded-xl bg-sky-600 px-4 py-2 text-sm font-semibold text-white hover:bg-sky-500">
          Manage funds in Profile
        </button>
      {/if}
    </section>
  {:else}
    <section class="mt-6 grid gap-4 md:grid-cols-2 xl:grid-cols-3">
      {#each visibleGroups as group (group.id)}
        <article class="flex min-h-[300px] flex-col rounded-2xl border border-slate-200 bg-white p-5 shadow-sm transition hover:-translate-y-0.5 hover:shadow-lg">
          <div class="flex items-start justify-between gap-3">
            <div class="min-w-0">
              <div class="flex flex-wrap items-center gap-2">
                <span class="rounded-lg bg-slate-950 px-2 py-1 text-[11px] font-bold uppercase tracking-wide text-white">{getCurrencyName(group.currency)}</span>
                <span class="rounded-full border px-2 py-1 text-[11px] font-semibold {group.isPublic ? 'border-emerald-200 bg-emerald-50 text-emerald-700' : 'border-slate-200 bg-slate-100 text-slate-600'}">
                  {group.isPublic ? "Public" : "Private"}
                </span>
                {#if isAuthed && isMember(group)}
                  <span class="rounded-full border border-sky-200 bg-sky-50 px-2 py-1 text-[11px] font-semibold text-sky-700">{roleLabel(group)}</span>
                {/if}
              </div>
              <h2 class="mt-3 truncate text-xl font-semibold text-slate-950">{group.name}</h2>
            </div>
          </div>

          <p class="mt-2 line-clamp-3 min-h-[60px] text-sm leading-5 text-slate-600">{group.description || "No description provided."}</p>

          <div class="mt-5 grid grid-cols-2 gap-3 text-sm">
            <div class="rounded-xl bg-slate-50 p-3">
              <div class="text-[11px] font-semibold uppercase tracking-wide text-slate-400">Members</div>
              <div class="mt-1 text-lg font-semibold text-slate-900">{group.members?.length ?? 0}</div>
            </div>
            <div class="rounded-xl bg-slate-50 p-3">
              <div class="text-[11px] font-semibold uppercase tracking-wide text-slate-400">Recorded balance</div>
              <div class="mt-1 truncate text-lg font-semibold text-slate-900">{formatTokenAmount(group.balance, group.currency)}</div>
            </div>
          </div>

          <div class="mt-4 rounded-xl border border-slate-200 px-3 py-2">
            <div class="text-[11px] font-semibold uppercase tracking-wide text-slate-400">Treasury subaccount</div>
            <div class="mt-1 font-mono text-xs text-slate-600">{shortAccount(group.account)}</div>
          </div>

          <div class="mt-auto flex gap-2 pt-5">
            <button type="button" on:click={() => goto(`/funds/${group.id}`)} class="flex-1 rounded-xl bg-slate-950 px-4 py-2.5 text-sm font-semibold text-white hover:bg-slate-800">
              View fund
            </button>
            {#if isAuthed && group.isPublic && !isMember(group)}
              <button
                type="button"
                disabled={joiningGroupId !== null}
                on:click={() => joinGroup(group.id)}
                class="rounded-xl border border-sky-300 px-4 py-2.5 text-sm font-semibold text-sky-700 hover:bg-sky-50 disabled:cursor-not-allowed disabled:opacity-50"
              >
                {joiningGroupId === group.id ? "Joining…" : "Join as observer"}
              </button>
            {/if}
          </div>
        </article>
      {/each}
    </section>
  {/if}
</div>
