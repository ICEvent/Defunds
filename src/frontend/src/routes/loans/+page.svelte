<script>
  import { onMount } from 'svelte';
  import { Principal } from '@dfinity/principal';
  import { globalStore } from '$lib/store';
  import { connectPersonalLoan, loanCanisterConfigured } from '$lib/api/personal-loan';
  import { parseLoanCalendarDay, LOAN_DATE_PARSER_VERSION } from '$lib/utils/personal-loan-date';
  import LoanConfirmationModal from '$lib/components/LoanConfirmationModal.svelte';

  let isAuthed = false;
  let me = null;
  let actor = null;
  let connecting = false;
  let busy = false;
  let error = '';
  let notice = '';
  let confirmation = null;
  let loans = [];
  let loanCurrencies = {};
  let selected = null;
  let selectedCurrency = 'CAD';
  let entries = [];
  let auditEvents = [];
  let balance = null;
  let view = 'borrowings';

  let ownRole = 'borrower';
  let counterparty = '';
  let originalAmount = '';
  let loanCurrency = 'CAD';
  let dueDate = '';
  let loanNote = '';

  let entryAmount = '';
  let repaymentAmount = '';
  let paymentMethod = 'Interac e-Transfer';
  let paymentDate = '';
  let entryNote = '';

  const variant = (value) => Object.keys(value ?? {})[0] ?? '';
  const textId = (value) => value?.toText?.() ?? String(value ?? '');
  const isMe = (value) => Boolean(me && textId(value) === textId(me));

  const currencySymbols = { CAD: '$', USD: '$', EUR: '€', GBP: '£', CNY: '¥' };
  const supportedCurrencies = ['CAD', 'USD', 'EUR', 'GBP', 'CNY'];

  function money(raw, currency = 'CAD') {
    const cents = BigInt(raw ?? 0);
    const whole = cents / 100n;
    const fractional = (cents % 100n).toString().padStart(2, '0');
    return currency + ' ' + (currencySymbols[currency] || '') +
      whole.toLocaleString('en-CA') + '.' + fractional;
  }

  function parseCents(value) {
    const input = String(value).trim();
    if (!/^(0|[1-9]\d{0,11})(\.\d{1,2})?$/.test(input)) {
      throw new Error('Enter an amount with up to two decimal places');
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

  // Keep a retry id stable for the exact same submitted payload. A lost
  // network response must never turn a retry into a second debt entry.
  const pendingIds = {};
  function stableRequestId(kind, payload) {
    const previous = pendingIds[kind];
    if (previous && previous.payload === payload) return previous.id;
    const id = crypto.randomUUID();
    pendingIds[kind] = { payload, id };
    return id;
  }
  const requestId = () => crypto.randomUUID();
  const effectiveDay = parseLoanCalendarDay;

  async function initialize() {
    if (!isAuthed || !loanCanisterConfigured || connecting) return;
    connecting = true;
    error = '';
    try {
      actor = await connectPersonalLoan(me);
      if (!actor) throw new Error('Personal Loan session unavailable. Please sign in again.');
      await refresh();
    } catch (e) {
      error = e?.message ?? String(e);
    } finally {
      connecting = false;
    }
  }

  onMount(() => {
    const today = new Date();
    paymentDate = new Date(today.getTime() - today.getTimezoneOffset() * 60_000)
      .toISOString().slice(0, 10);
    const unsub = globalStore.subscribe((state) => {
      const authed = Boolean(state.isAuthed);
      const changed = authed !== isAuthed || textId(me) !== textId(state.principal);
      isAuthed = authed;
      me = state.principal ?? null;
      if (!authed) {
        actor = null;
        loans = [];
        loanCurrencies = {};
        selected = null;
        selectedCurrency = 'CAD';
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
    // Separate stable loan-currency mapping preserves existing CAD loan storage.
    const pairs = await Promise.all(next.map(async loan => [
      String(loan.id),
      unwrap(await actor.getLoanCurrency(loan.id))
    ]));
    loanCurrencies = Object.fromEntries(pairs);
    loans = next;
    if (selected) {
      selected = next.find((l) => l.id === selected.id) ?? null;
      if (selected) {
        selectedCurrency = loanCurrencies[String(selected.id)] || 'CAD';
        const [entryResult, balanceResult, eventResult] = await Promise.all([
          actor.getLoanEntries(selected.id),
          actor.getBalance(selected.id),
          actor.getLoanEvents(selected.id, 0n, 100n)
        ]);
        entries = unwrap(entryResult) ?? [];
        balance = unwrap(balanceResult);
        auditEvents = unwrap(eventResult) ?? [];
      } else {
        entries = [];
        auditEvents = [];
        balance = null;
        selectedCurrency = 'CAD';
      }
    }
  }

  async function refreshNow() {
    if (!actor || busy) return;
    error = '';
    try {
      await refresh();
      notice = 'Loan records refreshed.';
    } catch (e) {
      error = e?.message || String(e);
    }
  }

  async function copyMyPrincipal() {
    if (!me) return;
    try {
      await navigator.clipboard.writeText(textId(me));
      notice = 'Principal copied. Send it only to your intended loan counterparty.';
    } catch (e) {
      error = 'Could not copy the Principal. Select it manually.';
    }
  }

  async function selectLoan(loan) {
    selected = loan;
    selectedCurrency = loanCurrencies[String(loan.id)] || 'CAD';
    error = '';
    await refresh();
  }

  function eventTime(at) {
    return new Date(Number(BigInt(at) / 1_000_000n)).toLocaleString('en-CA');
  }

  // All consequential loan actions use an in-app modal, not the system confirmation dialog.
  function confirmLoanAction(title, description, action, options = {}) {
    if (!selected || busy) return;
    error = '';
    confirmation = {
      title,
      description,
      amount: options.amountCents == null ? '' : money(options.amountCents, selectedCurrency),
      reference: options.reference || ('Loan #' + String(selected.id)),
      confirmLabel: options.confirmLabel || 'Confirm',
      danger: Boolean(options.danger),
      action,
      afterSuccess: options.afterSuccess
    };
  }

  function cancelLoanConfirmation() {
    if (busy) return;
    confirmation = null;
    error = '';
  }

  async function executeLoanConfirmation() {
    const pendingConfirmation = confirmation;
    if (!pendingConfirmation || busy) return;
    const success = await run(pendingConfirmation.action, pendingConfirmation.afterSuccess);
    if (success) confirmation = null;
  }

  function requestReversal(entry) {
    if (!selected) return;
    const loanId = selected.id;
    const entryId = entry.id;
    const note = entryNote || ('Correction for transaction #' + String(entryId));
    const id = stableRequestId('reversal', [String(loanId), String(entryId), note].join('|'));
    confirmLoanAction(
      'Request a transaction correction',
      'This creates a new correction request for the other participant to approve. The original confirmed transaction will remain in the audit history.',
      () => actor.requestReversal(loanId, entryId, note, id),
      {
        amountCents: entry.amountCents,
        reference: 'Loan #' + String(loanId) + ' · Transaction #' + String(entryId),
        confirmLabel: 'Request correction',
        afterSuccess: () => { delete pendingIds.reversal; }
      }
    );
  }

  async function run(work, afterSuccess) {
    if (!actor || busy) return false;
    busy = true;
    error = '';
    notice = '';
    try {
      const result = unwrap(await work());
      await refresh();
      if (afterSuccess) await afterSuccess(result);
      notice = 'Record updated. The other party can review the same loan.';
      return true;
    } catch (e) {
      error = e?.message ?? String(e);
      return false;
    } finally {
      busy = false;
    }
  }

  function createLoan() {
    return run(() => {
      const other = Principal.fromText(counterparty.trim());
      const borrower = ownRole === 'borrower' ? me : other;
      const lender = ownRole === 'lender' ? me : other;
      const amount = parseCents(originalAmount);
      const due = dueDate ? [effectiveDay(dueDate, true)] : [];
      const payload = [textId(borrower), textId(lender), String(amount), loanCurrency, dueDate, loanNote].join('|');
      return actor.createPersonalLoanWithCurrency(
        borrower, lender, amount, loanCurrency, due, loanNote, stableRequestId('create', payload)
      );
    }, async (loanId) => {
      delete pendingIds.create;
      view = ownRole === 'borrower' ? 'borrowings' : 'lending';
      const created = loans.find((l) => l.id === loanId);
      if (created) await selectLoan(created);
      originalAmount = '';
      loanNote = '';
      loanCurrency = 'CAD';
    });
  }

  function requestAdditional() {
    if (!selected) return;
    return run(() => {
      const amount = parseCents(entryAmount);
      const payload = [String(selected.id), String(amount), entryNote].join('|');
      return actor.requestAdditionalBorrowing(selected.id, amount, entryNote, stableRequestId('additional', payload));
    }, () => {
      delete pendingIds.additional;
      entryAmount = '';
    });
  }

  function requestRepayment() {
    if (!selected) return;
    return run(() => {
      const amount = parseCents(repaymentAmount);
      const at = effectiveDay(paymentDate);
      const payload = [String(selected.id), String(amount), paymentDate, paymentMethod, entryNote].join('|');
      return actor.submitRepayment(
        selected.id, amount, at, paymentMethod, entryNote, stableRequestId('repayment', payload)
      );
    }, () => {
      delete pendingIds.repayment;
      repaymentAmount = '';
    });
  }

  function declareFunding(entry) {
    if (!selected) return;
    const loanId = selected.id;
    const entryId = entry.id;
    const date = paymentDate;
    const method = paymentMethod;
    confirmLoanAction(
      'Declare funds delivered',
      'Only proceed after you have actually transferred this amount to the borrower. Defunds records your declaration but does not transfer or verify bank funds.',
      () => actor.declareFunding(loanId, entryId, effectiveDay(date), method),
      {
        amountCents: entry.amountCents,
        reference: 'Loan #' + String(loanId) + ' · Transaction #' + String(entryId) + ' · ' + date,
        confirmLabel: 'Declare delivered'
      }
    );
  }

  function confirmEntry(entry) {
    if (!selected) return;
    const loanId = selected.id;
    const entryId = entry.id;
    const kind = variant(entry.kind);
    const borrowing = kind === 'initialBorrowing' || kind === 'additionalBorrowing';
    let title;
    let description;
    let action;
    if (borrowing) {
      title = 'Confirm funds received';
      description = 'Confirm only after you have actually received the money from the lender. This will increase the confirmed outstanding debt.';
      action = () => actor.confirmFunding(loanId, entryId);
    } else if (kind === 'repayment') {
      title = 'Confirm repayment';
      description = 'Confirm that the repayment was received through the stated off-chain method. The confirmed outstanding debt will decrease.';
      action = () => actor.confirmRepayment(loanId, entryId);
    } else {
      title = 'Confirm transaction correction';
      description = 'Confirm this correction after reviewing the original transaction and its effect on the shared loan balance.';
      action = () => actor.confirmReversal(loanId, entryId);
    }
    confirmLoanAction(title, description, action, {
      amountCents: entry.amountCents,
      reference: 'Loan #' + String(loanId) + ' · Transaction #' + String(entryId),
      confirmLabel: borrowing ? 'Confirm received' : 'Confirm transaction'
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
      One loan, two parties, one shared balance. Currency is fixed per loan; no funds or foreign exchange are transferred by this page.
    </p>
    <p class="mt-2 text-xs text-slate-500" data-testid="loan-ui-build">
      Loan UI build: {import.meta.env.VITE_PERSONAL_LOAN_BUILD || 'unspecified'} · {LOAN_DATE_PARSER_VERSION}
    </p>
  </div>
  {#if isAuthed && me}
    <div class="mb-6 flex flex-wrap items-center justify-between gap-3 rounded-xl border border-slate-700 bg-slate-900 p-3 text-sm">
      <div class="min-w-0 flex-1">
        <div class="mb-1 text-xs text-slate-400">Your authenticated Principal (share with the other participant)</div>
        <code class="break-all text-xs text-sky-200">{textId(me)}</code>
      </div>
      <button on:click={copyMyPrincipal} class="rounded bg-slate-800 px-3 py-2 text-sm hover:bg-slate-700">
        Copy Principal
      </button>
      {#if actor}
        <button disabled={busy || connecting} on:click={refreshNow}
          class="rounded bg-sky-700 px-3 py-2 text-sm hover:bg-sky-600 disabled:opacity-50">
          Refresh
        </button>
      {/if}
    </div>
  {/if}

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
    <div class="rounded-xl border border-slate-700 bg-slate-900 p-5">
      {#if error}
        <p role="alert" class="mb-3 text-red-300">{error}</p>
        <button on:click={initialize} disabled={connecting} class="rounded bg-sky-700 px-4 py-2 text-sm disabled:opacity-50">Retry connection</button>
      {:else}
        Connecting to your Personal Loan ledger…
      {/if}
    </div>
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
                class={view === tab[0] ? 'rounded-md bg-sky-700 px-3 py-2 text-xs hover:bg-slate-700' : 'rounded-md bg-slate-800 px-3 py-2 text-xs hover:bg-slate-700'}>{tab[1]}</button>
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
              <div class="mt-1 text-sm text-slate-300">{money(loan.originalAmountCents, loanCurrencies[String(loan.id)] || 'CAD')} agreed</div>
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
          <label class="mb-2 block text-xs text-slate-400" for="loan-currency">Currency</label>
          <select id="loan-currency" bind:value={loanCurrency}
            class="mb-3 w-full rounded bg-slate-800 p-2">
            {#each supportedCurrencies as code}
              <option value={code}>{code}</option>
            {/each}
          </select>
          <label class="mb-2 block text-xs text-slate-400" for="loan-amount">Initial amount ({loanCurrency})</label>
          <input id="loan-amount" bind:value={originalAmount} placeholder="10000.00" class="mb-3 w-full rounded bg-slate-800 p-2" />
          <label class="mb-2 block text-xs text-slate-400" for="loan-due-date">Due date (optional)</label>
          <input id="loan-due-date" type="date" bind:value={dueDate} class="mb-1 w-full rounded bg-slate-800 p-2" />
          <p class="mb-3 text-xs text-slate-400" data-testid="loan-due-date-bound">
            {#if dueDate}
              Form date value: {dueDate}
            {:else}
              No due date selected
            {/if}
          </p>
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
            <div class="mt-4 grid gap-3 sm:grid-cols-2 xl:grid-cols-4">
              <div class="rounded-lg bg-slate-800 p-4" data-testid="agreed-loan-amount">
                <div class="text-xs text-slate-400">Agreed Loan Amount</div>
                <div class="text-lg font-semibold">{money(selected.originalAmountCents, selectedCurrency)}</div>
                <div class="mt-1 text-xs text-slate-400">Original agreement; not necessarily funded</div>
              </div>
              <div class="rounded-lg bg-slate-800 p-4" data-testid="loan-total-borrowed">
                <div class="text-xs text-slate-400">Total borrowed (confirmed)</div>
                <div class="text-lg font-semibold">{balance ? money(balance.totalBorrowedCents, selectedCurrency) : 'Loading...'}</div>
              </div>
              <div class="rounded-lg bg-slate-800 p-4" data-testid="loan-total-repaid">
                <div class="text-xs text-slate-400">Total repaid (confirmed)</div>
                <div class="text-lg font-semibold">{balance ? money(balance.totalRepaidCents, selectedCurrency) : 'Loading...'}</div>
              </div>
              <div class="rounded-lg bg-slate-800 p-4" data-testid="loan-outstanding">
                <div class="text-xs text-slate-400">Outstanding (confirmed debt)</div>
                <div class="text-xl font-semibold">{balance ? money(balance.outstandingCents, selectedCurrency) : 'Loading...'}</div>
              </div>
            </div>
            {#if ['proposed','fundingPending'].includes(variant(selected.status))}
              <p class="mt-3 rounded-lg border border-sky-900 bg-sky-950/30 p-3 text-sm text-sky-200">
                {#if variant(selected.status) === 'proposed'}
                  Awaiting the other participant to accept the agreement. No borrowing is funded yet.
                {:else}
                  Terms accepted. The lender must declare funds delivered and the borrower must confirm receipt before Outstanding increases.
                {/if}
              </p>
            {/if}
            <div class="mt-4 break-all text-xs text-slate-400">
              <div>Currency: {selectedCurrency} (fixed for this loan; no FX conversion)</div>
              <div class="mt-1">Borrower: {textId(selected.borrower)}</div>
              <div class="mt-1">Lender: {textId(selected.lender)}</div>
              <div class="mt-1">Due date: {selected.dueAt?.length ? new Date(Number(selected.dueAt[0] / 1_000_000n)).toLocaleDateString('en-CA') : 'Not set'}</div>
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
                  <label class="block text-xs text-slate-400" for="extra-amount">Additional borrowing ({selectedCurrency})</label>
                  <input id="extra-amount" bind:value={entryAmount} placeholder="3000.00" class="mt-1 w-full rounded bg-slate-800 p-2" />
                  <button disabled={busy || !entryAmount} on:click={requestAdditional} class="mt-2 rounded bg-sky-600 px-4 py-2 text-sm disabled:opacity-40">Request borrowing</button>
                </div>
                <div>
                  <label class="block text-xs text-slate-400" for="repay-amount">Repayment ({selectedCurrency})</label>
                  <input id="repay-amount" bind:value={repaymentAmount} placeholder="500.00" class="mt-1 w-full rounded bg-slate-800 p-2" />
                  <button disabled={busy || !repaymentAmount} on:click={requestRepayment} class="mt-2 rounded bg-emerald-700 px-4 py-2 text-sm disabled:opacity-40">Record repayment</button>
                </div>
              </div>
              <label class="mt-3 block text-xs text-slate-400" for="payment-date">Repayment / funding date</label>
              <input id="payment-date" type="date" bind:value={paymentDate} class="mt-1 w-full rounded bg-slate-800 p-2" />
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
                    <span class="text-sm font-medium">{variant(entry.kind)} · {money(entry.amountCents, selectedCurrency)}</span>
                    <span class="text-xs text-sky-300">{variant(entry.status)}</span>
                  </div>
                  <div class="mt-1 text-xs text-slate-400">Recorded by {isMe(entry.proposedBy) ? 'you' : 'the other participant'}{entry.note ? ' · ' + entry.note : ''}</div>
                  {#if variant(entry.status) === 'confirmed' && variant(selected.status) === 'active' && variant(entry.kind) !== 'reversal'}
                    <button disabled={busy} on:click={() => requestReversal(entry)}
                      class="mt-3 rounded border border-slate-600 px-3 py-2 text-xs hover:border-sky-500">Request correction</button>
                  {/if}
                  {#if isMe(entry.proposedBy) && (
                    variant(entry.status) === 'pendingTerms' ||
                    variant(entry.status) === 'disputed' ||
                    (variant(entry.status) === 'pendingConfirmation' && ['repayment','reversal'].includes(variant(entry.kind)))
                  )}
                    <button disabled={busy} on:click={() => run(() => actor.withdrawPendingEntry(selected.id, entry.id))}
                      class="mt-3 rounded bg-slate-700 px-3 py-2 text-xs">Withdraw record</button>
                  {/if}
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
          <section class="rounded-xl border border-slate-700 bg-slate-900 p-5">
            <h3 class="mb-3 font-semibold">Audit timeline</h3>
            <p class="mb-3 text-xs text-slate-400">Event history is append-only; latest 100 events shown.</p>
            {#if auditEvents.length === 0}
              <p class="text-sm text-slate-400">No events yet.</p>
            {/if}
            {#each auditEvents as event (event.id)}
              {@const eventKind = variant(event.kind)}
              {@const relatedEntry = event.entryId.length
                ? entries.find(entry => entry.id === event.entryId[0])
                : null}
              {@const eventAmount = relatedEntry
                ? relatedEntry.amountCents
                : (['loanProposed', 'loanRejected'].includes(eventKind)
                    ? selected.originalAmountCents
                    : null)}
              <div class="flex flex-wrap items-start justify-between gap-3 border-t border-slate-800 py-3 text-xs">
                <div class="min-w-0">
                  <div class="font-medium text-slate-200">
                    {eventKind}
                    {event.entryId.length ? (' · transaction #' + String(event.entryId[0])) : ''}
                  </div>
                  {#if eventAmount != null}
                    <div class="mt-1 text-sm font-semibold text-sky-200" data-testid="loan-audit-amount">
                      Amount: {money(eventAmount, selectedCurrency)}
                    </div>
                  {/if}
                  {#if relatedEntry?.kind && variant(relatedEntry.kind) === 'reversal'}
                    <div class="mt-1 text-slate-400">Correction of a previously confirmed transaction</div>
                  {/if}
                </div>
                <span class="whitespace-nowrap text-slate-400">{eventTime(event.at)}</span>
              </div>
            {/each}
          </section>
        {/if}
      </div>
    </div>
  {/if}
</div>
<LoanConfirmationModal
  open={Boolean(confirmation)}
  title={confirmation?.title || ''}
  description={confirmation?.description || ''}
  amount={confirmation?.amount || ''}
  reference={confirmation?.reference || ''}
  confirmLabel={confirmation?.confirmLabel || 'Confirm'}
  danger={confirmation?.danger || false}
  pending={busy}
  error={confirmation ? error : ''}
  on:cancel={cancelLoanConfirmation}
  on:confirm={executeLoanConfirmation}
/>
