<script>
  import { onMount } from 'svelte';
  import { Principal } from '@dfinity/principal';
  import { globalStore } from '$lib/store';
  import { connectPersonalLoan, loanCanisterConfigured } from '$lib/api/personal-loan';

  let isAuthed = false;
  let me = null;
  let actor = null;
  let connecting = false;
  let busy = false;
  let error = '';
  let notice = '';
  let loans = [];
  let selected = null;
  let entries = [];
  let balance = null;
  let view = 'borrowings';

  let ownRole = 'borrower';
  let counterparty = '';
  let originalAmount = '';
  let loanNote = '';

  let entryAmount = '';
  let repaymentAmount = '';
  let paymentMethod = 'Interac e-Transfer';
  let entryNote = '';

  const variant = (value) => Object.keys(value ?? {})[0] ?? '';
  const textId = (value) => value?.toText?.() ?? String(value ?? '');
  const isMe = (value) => Boolean(me && textId(value) === textId(me));

  function cad(raw) {
    const cents = BigInt(raw ?? 0);
    return 'CAD $' + (cents / 100n).toLocaleString('en-CA') + '.' + (cents % 100n).toString().padStart(2, '0');
  }

  function parseCents(value) {
    const input = String(value).trim();
    if (!/^(0|[1-9]\\d{0,11})(\\.\\d{1,2})?$/.test(input)) {
      throw new Error('Enter a CAD amount with up to two decimal places');
    }
    const [dollars, fraction = ''] = input.split('.');
    const cents = BigInt(dollars) * 100n + BigInt((fraction + '00').slice(0, 2));
    if (cents <= 0n) throw new Error('Amount must be positive');
    return cents;
  }

  function unwrap(value) {
    if (value && 'err' in value) throw new Error(value.err);
    return value?.ok;
  }

  const requestId = () => crypto.randomUUID();
  const nowNanos = () => BigInt(Date.now()) * 1_000_000n;

  async function initialize() {
    if (!isAuthed || !loanCanisterConfigured || connecting) return;
    connecting = true;
    try {
      actor = await connectPersonalLoan();
      if (actor) await refresh();
    } catch (e) {
      error = e?.message ?? String(e);
    } finally {
      connecting = false;
    }
  }

  onMount(() => {
    const unsub = globalStore.subscribe((state) => {
      const authed = Boolean(state.isAuthed);
      const changed = authed !== isAuthed || textId(me) !== textId(state.principal);
      isAuthed = authed;
      me = state.principal ?? null;
      if (!authed) {
        actor = null;
        loans = [];
        selected = null;
      } else if (changed) {
        actor = null;
        void initialize();
      }
    });
    return () => unsub();
  });

  async function refresh() {
    if (!actor) return;
    const next = await actor.getMyLoans();
    loans = next;
    if (selected) {
      selected = next.find((l) => l.id === selected.id) ?? null;
      if (selected) {
        entries = unwrap(await actor.getLoanEntries(selected.id)) ?? [];
        balance = unwrap(await actor.getBalance(selected.id));
      } else {
        entries = [];
        balance = null;
      }
    }
  }

  async function selectLoan(loan) {
    selected = loan;
    error = '';
    await refresh();
  }

  async function run(work) {
    if (!actor || busy) return;
    busy = true;
    error = '';
    notice = '';
    try {
      unwrap(await work());
      await refresh();
      notice = 'Record updated. The other party can review the same loan.';
    } catch (e) {
      error = e?.message ?? String(e);
    } finally {
      busy = false;
    }
  }

  function createLoan() {
    return run(() => {
      const other = Principal.fromText(counterparty.trim());
      const borrower = ownRole === 'borrower' ? me : other;
      const lender = ownRole === 'lender' ? me : other;
      return actor.createPersonalLoan(
        borrower, lender, parseCents(originalAmount), [], loanNote, requestId()
      );
    });
  }

  function requestAdditional() {
    if (!selected) return;
    return run(() => actor.requestAdditionalBorrowing(selected.id, parseCents(entryAmount), entryNote, requestId()));
  }

  function requestRepayment() {
    if (!selected) return;
    return run(() => actor.submitRepayment(
      selected.id, parseCents(repaymentAmount), nowNanos(), paymentMethod, entryNote, requestId()
    ));
  }

  function declareFunding(entry) {
    if (!selected || !window.confirm('Confirm you have actually delivered this amount to the borrower? No bank transfer will be made by Defunds.')) return;
    return run(() => actor.declareFunding(selected.id, entry.id, nowNanos(), paymentMethod));
  }

  function confirmEntry(entry) {
    if (!selected) return;
    const kind = variant(entry.kind);
    const isBorrowing = kind === 'initialBorrowing' || kind === 'additionalBorrowing';
    if (!window.confirm(isBorrowing
      ? 'Have you actually received this money from the lender?'
      : 'Confirm the amount and that the off-chain payment/correction is correct?')) return;
    return run(() => {
      if (isBorrowing) return actor.confirmFunding(selected.id, entry.id);
      if (kind === 'repayment') return actor.confirmRepayment(selected.id, entry.id);
      return actor.confirmReversal(selected.id, entry.id);
    });
  }

  $: visibleLoans = loans.filter((loan) => {
    if (view === 'invitations') return variant(loan.status) === 'proposed' && !isMe(loan.createdBy);
    if (view === 'borrowings') return isMe(loan.borrower);
    return isMe(loan.lender);
  });
</script>

<svelte:head>
  <title>Personal Loans | Defunds</title>
  <meta name="description" content="Private two-party borrowing and repayment ledger" />
</svelte:head>

<div class="container mx-auto max-w-6xl px-4 py-10 text-slate-100">
  <div class="mb-8">
    <div class="text-xs uppercase tracking-[.2em] text-sky-300">Defunds · Personal Ledger</div>
    <h1 class="mt-2 text-3xl font-bold">Personal Loans</h1>
    <p class="mt-2 text-sm text-slate-400">
      One loan, two parties, one shared balance. CAD records only; no funds are transferred by this page.
    </p>
  </div>

  {#if !loanCanisterConfigured}
    <div class="rounded-xl border border-amber-600/40 bg-amber-950/20 p-5 text-amber-100">
      Personal Loan is not connected. Configure VITE_PERSONAL_LOAN_CANISTER_ID after deploying the isolated canister.
      This page does not use the main Defunds Treasury.
    </div>
  {:else if !isAuthed}
    <div class="rounded-xl border border-slate-700 bg-slate-900 p-5">
      Please log in with Internet Identity to view your private loans.
    </div>
  {:else if connecting || !actor}
    <div class="rounded-xl border border-slate-700 bg-slate-900 p-5">Connecting to your Personal Loan ledger…</div>
  {:else}
    {#if error}<div class="mb-5 rounded-lg border border-red-600 p-3 text-red-300" role="alert">{error}</div>{/if}
    {#if notice}<div class="mb-5 rounded-lg border border-emerald-700 p-3 text-emerald-200" role="status">{notice}</div>{/if}

    <div class="grid gap-6 lg:grid-cols-[310px_1fr]">
      <div class="space-y-5">
        <section class="rounded-xl border border-slate-700 bg-slate-900 p-4">
          <h2 class="mb-3 font-semibold">Your loans</h2>
          <div class="mb-3 flex flex-wrap gap-2">
            {#each [['borrowings','Borrowings'],['lending','Lending'],['invitations','Invitations']] as tab}
              <button
                on:click={() => { view = tab[0]; selected = null; }}
                class:!bg-sky-700={view === tab[0]}
                class="rounded-md bg-slate-800 px-3 py-2 text-xs hover:bg-slate-700">{tab[1]}</button>
            {/each}
          </div>
          {#if visibleLoans.length === 0}
            <p class="text-sm text-slate-400">No loans in this view.</p>
          {/if}
          {#each visibleLoans as loan (loan.id)}
            <button
              class="mb-2 w-full rounded-lg border border-slate-700 bg-slate-800 p-3 text-left hover:border-sky-500"
              on:click={() => selectLoan(loan)}>
              <div class="flex justify-between gap-2">
                <span class="font-medium">Loan #{String(loan.id)}</span>
                <span class="text-xs text-sky-300">{variant(loan.status)}</span>
              </div>
              <div class="mt-1 text-sm text-slate-300">{cad(loan.originalAmountCents)} initial</div>
            </button>
          {/each}
        </section>

        <section class="rounded-xl border border-slate-700 bg-slate-900 p-4">
          <h2 class="mb-3 font-semibold">New Personal Loan</h2>
          <label class="mb-2 block text-xs text-slate-400" for="loan-role">Your role</label>
          <select id="loan-role" bind:value={ownRole} class="mb-3 w-full rounded bg-slate-800 p-2">
            <option value="borrower">Borrower</option><option value="lender">Lender</option>
          </select>
          <label class="mb-2 block text-xs text-slate-400" for="loan-other">Counterparty Principal</label>
          <input id="loan-other" bind:value={counterparty} placeholder="Principal" class="mb-3 w-full rounded bg-slate-800 p-2 text-sm" />
          <label class="mb-2 block text-xs text-slate-400" for="loan-amount">Initial amount (CAD)</label>
          <input id="loan-amount" bind:value={originalAmount} placeholder="10000.00" class="mb-3 w-full rounded bg-slate-800 p-2" />
          <textarea aria-label="Loan note" bind:value={loanNote} maxlength="500" placeholder="Description (optional)" class="mb-3 w-full rounded bg-slate-800 p-2"></textarea>
          <button disabled={busy || !counterparty || !originalAmount}
            on:click={createLoan}
            class="w-full rounded bg-sky-600 p-2 font-semibold hover:bg-sky-500 disabled:opacity-40">Propose loan</button>
        </section>
      </div>

      <div class="space-y-5">
        {#if !selected}
          <section class="rounded-xl border border-slate-700 bg-slate-900 p-6 text-slate-400">
            Select a loan to see its shared transaction history, or propose a new loan.
          </section>
        {:else}
          <section class="rounded-xl border border-slate-700 bg-slate-900 p-5">
            <div class="flex flex-wrap items-center justify-between gap-3">
              <h2 class="text-xl font-semibold">Loan #{String(selected.id)}</h2>
              <span class="rounded-full bg-slate-800 px-3 py-1 text-sm">{variant(selected.status)}</span>
            </div>
            <div class="mt-4 grid gap-3 sm:grid-cols-3">
              <div class="rounded-lg bg-slate-800 p-4"><div class="text-xs text-slate-400">Outstanding</div><div class="text-xl font-semibold">{cad(balance?.outstandingCents ?? 0n)}</div></div>
              <div class="rounded-lg bg-slate-800 p-4"><div class="text-xs text-slate-400">Total borrowed</div><div class="text-lg font-semibold">{cad(balance?.totalBorrowedCents ?? 0n)}</div></div>
              <div class="rounded-lg bg-slate-800 p-4"><div class="text-xs text-slate-400">Total repaid</div><div class="text-lg font-semibold">{cad(balance?.totalRepaidCents ?? 0n)}</div></div>
            </div>
            <div class="mt-4 break-all text-xs text-slate-400">
              <div>Borrower: {textId(selected.borrower)}</div>
              <div class="mt-1">Lender: {textId(selected.lender)}</div>
            </div>
            {#if variant(selected.status) === 'proposed' && !isMe(selected.createdBy)}
              <div class="mt-4 flex gap-2">
                <button disabled={busy} class="rounded bg-emerald-700 px-4 py-2" on:click={() => run(() => actor.acceptLoan(selected.id))}>Accept terms</button>
                <button disabled={busy} class="rounded bg-slate-700 px-4 py-2" on:click={() => run(() => actor.rejectLoan(selected.id))}>Reject</button>
              </div>
            {/if}
            {#if variant(selected.status) === 'active' && balance?.outstandingCents === 0n}
              <div class="mt-4">
                <button disabled={busy} class="rounded bg-sky-700 px-4 py-2" on:click={() => run(() => actor.requestClosure(selected.id))}>Request closure</button>
              </div>
            {/if}
            {#if variant(selected.status) === 'readyToClose' && !isMe(selected.closureRequestedBy?.[0])}
              <div class="mt-4">
                <button disabled={busy} class="rounded bg-emerald-700 px-4 py-2" on:click={() => run(() => actor.confirmClosure(selected.id))}>Confirm closure</button>
              </div>
            {/if}
          </section>

          {#if variant(selected.status) === 'active'}
            <section class="rounded-xl border border-slate-700 bg-slate-900 p-5">
              <h3 class="mb-3 font-semibold">New transaction</h3>
              <div class="grid gap-3 md:grid-cols-2">
                <div>
                  <label class="block text-xs text-slate-400" for="extra-amount">Additional borrowing (CAD)</label>
                  <input id="extra-amount" bind:value={entryAmount} placeholder="3000.00" class="mt-1 w-full rounded bg-slate-800 p-2" />
                  <button disabled={busy || !entryAmount} on:click={requestAdditional} class="mt-2 rounded bg-sky-600 px-4 py-2 text-sm disabled:opacity-40">Request borrowing</button>
                </div>
                <div>
                  <label class="block text-xs text-slate-400" for="repay-amount">Repayment (CAD)</label>
                  <input id="repay-amount" bind:value={repaymentAmount} placeholder="500.00" class="mt-1 w-full rounded bg-slate-800 p-2" />
                  <button disabled={busy || !repaymentAmount} on:click={requestRepayment} class="mt-2 rounded bg-emerald-700 px-4 py-2 text-sm disabled:opacity-40">Record repayment</button>
                </div>
              </div>
              <label class="mt-3 block text-xs text-slate-400" for="payment-method">Off-chain payment method</label>
              <select id="payment-method" bind:value={paymentMethod} class="mt-1 w-full rounded bg-slate-800 p-2">
                <option>Interac e-Transfer</option><option>Bank Transfer</option><option>Cash</option><option>Cheque</option><option>Other</option>
              </select>
              <textarea aria-label="Transaction note" maxlength="500" bind:value={entryNote} placeholder="Note (optional)" class="mt-3 w-full rounded bg-slate-800 p-2"></textarea>
            </section>
          {/if}

          <section class="rounded-xl border border-slate-700 bg-slate-900 p-5">
            <h3 class="mb-3 font-semibold">Shared transaction history</h3>
            <p class="mb-4 text-xs text-slate-400">Only confirmed entries affect the outstanding balance. Check that real-world payments have actually occurred before confirming.</p>
            {#if entries.length === 0}<p class="text-sm text-slate-400">No transaction records yet.</p>{/if}
            <div class="space-y-3">
              {#each entries as entry (entry.id)}
                <div class="rounded-lg border border-slate-700 p-3">
                  <div class="flex flex-wrap justify-between gap-2">
                    <span class="text-sm font-medium">{variant(entry.kind)} · {cad(entry.amountCents)}</span>
                    <span class="text-xs text-sky-300">{variant(entry.status)}</span>
                  </div>
                  <div class="mt-1 text-xs text-slate-400">Recorded by {isMe(entry.proposedBy) ? 'you' : 'the other participant'}{entry.note ? ' · ' + entry.note : ''}</div>
                  {#if variant(entry.status) === 'pendingTerms' && !isMe(entry.proposedBy)}
                    <div class="mt-3 flex gap-2">
                      <button disabled={busy} class="rounded bg-emerald-700 px-3 py-2 text-xs" on:click={() => run(() => actor.acceptAdditionalBorrowing(selected.id, entry.id))}>Accept terms</button>
                      <button disabled={busy} class="rounded bg-slate-700 px-3 py-2 text-xs" on:click={() => run(() => actor.rejectAdditionalBorrowing(selected.id, entry.id))}>Reject</button>
                    </div>
                  {:else if variant(entry.status) === 'pendingFunding' && isMe(selected.lender)}
                    <button disabled={busy} on:click={() => declareFunding(entry)} class="mt-3 rounded bg-sky-700 px-3 py-2 text-xs">Declare funds delivered</button>
                  {:else if variant(entry.status) === 'pendingConfirmation'}
                    {@const kind = variant(entry.kind)}
                    {@const borrowing = kind === 'initialBorrowing' || kind === 'additionalBorrowing'}
                    {#if (borrowing && isMe(selected.borrower)) || (!borrowing && !isMe(entry.proposedBy))}
                      <div class="mt-3 flex gap-2">
                        <button disabled={busy} on:click={() => confirmEntry(entry)} class="rounded bg-emerald-700 px-3 py-2 text-xs">Confirm</button>
                        <button disabled={busy} on:click={() => run(() => actor.disputeEntry(selected.id, entry.id))} class="rounded bg-slate-700 px-3 py-2 text-xs">Dispute</button>
                      </div>
                    {/if}
                  {/if}
                </div>
              {/each}
            </div>
          </section>
        {/if}
      </div>
    </div>
  {/if}
</div>
