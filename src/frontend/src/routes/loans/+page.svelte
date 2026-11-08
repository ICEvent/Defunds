<script>
  import { onMount } from 'svelte';
  import { Principal } from '@dfinity/principal';
  import { globalStore } from '$lib/store';
  import { connectPersonalLoan, loanCanisterConfigured } from '$lib/api/personal-loan';
  import { parseLoanCalendarDay, LOAN_DATE_PARSER_VERSION } from '$lib/utils/personal-loan-date';
  import LoanConfirmationModal from '$lib/components/LoanConfirmationModal.svelte';
  import { currencyDefinition, currencyCatalog, getBuiltinCurrency,
    parseAmountMinor, formatAmountMinor } from '$lib/utils/personal-loan-currency.js';
  import {
    loanEventLabel,
    loanEventNote,
    getRepaymentCents,
    formatEntryPaymentDate,
    formatLoanUtcDate,
    canLenderDeclareFunding,
    canRequesterWithdrawEntry,
    isCurrentLoanRefresh
  } from '$lib/utils/personal-loan-display';

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
  let loanCurrencyDefinitions = {};
  let customCurrencies = [];
  let currencyManagerOpen = false;
  let currencyCode = '';
  let currencySymbol = '';
  let currencyDecimals = '8';
  let currencyKind = 'crypto';
  let editingCurrency = false;
  let currencyDeleteCode = '';
  let currencyFormError = '';
  let currencyFormNotice = '';
  let currencySaving = false;
  let selected = null;
  let selectedCurrency = 'CAD';
  let selectedCurrencyDefinition = getBuiltinCurrency('CAD');
  let entries = [];
  let auditEvents = [];
  let fundingCancellationRequests = [];
  let balance = null;
  let detailLoading = false;
  // A pending reply must never render loan A's balance under loan B's header.
  let refreshVersion = 0;
  let view = 'borrowings';

  let ownRole = 'borrower';
  let counterparty = '';
  let originalAmount = '';
  let loanCurrency = 'CAD';
  let dueDate = '';
  let loanNote = '';

  let transactionMode = 'borrow';
  let entryAmount = '';
  let borrowingNote = '';
  let repaymentAmount = '';
  let repaymentFull = false;
  let repaymentNote = '';
  let paymentMethod = 'Interac e-Transfer';
  let paymentDate = '';
  let fundingMethod = 'Interac e-Transfer';
  let fundingDate = '';

  const variant = (value) => Object.keys(value ?? {})[0] ?? '';
  const textId = (value) => value?.toText?.() ?? String(value ?? '');
  const isMe = (value) => Boolean(me && textId(value) === textId(me));

  $: supportedCurrencies = currencyCatalog(customCurrencies);
  $: proposedCurrencyInfo =
    supportedCurrencies.find(c => c.code === loanCurrency) || getBuiltinCurrency('CAD');

  const money = (raw, def = getBuiltinCurrency('CAD')) =>
    formatAmountMinor(raw, typeof def === 'string' ? getBuiltinCurrency(def) || getBuiltinCurrency('CAD') : def);
  const currentLoanDecimals = () => Number(selectedCurrencyDefinition?.decimals ?? 2);

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
      const requestedActor = actor;
      const owned = unwrap(await requestedActor.getMyCurrencies());
      if (actor !== requestedActor) return;
      customCurrencies = owned ?? [];
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
    fundingDate = paymentDate;
    const unsub = globalStore.subscribe((state) => {
      const authed = Boolean(state.isAuthed);
      const changed = authed !== isAuthed || textId(me) !== textId(state.principal);
      isAuthed = authed;
      me = state.principal ?? null;
      if (!authed) {
        refreshVersion += 1;
        actor = null;
        loans = [];
        loanCurrencies = {};
        loanCurrencyDefinitions = {};
        customCurrencies = [];
        selected = null;
        entries = [];
        auditEvents = [];
        fundingCancellationRequests = [];
        balance = null;
        detailLoading = false;
        selectedCurrency = 'CAD';
        selectedCurrencyDefinition = getBuiltinCurrency('CAD');
        currencyManagerOpen = false;
        currencyFormError = '';
        currencyFormNotice = '';
      } else if (changed) {
        actor = null;
        void initialize();
      }
    });
    return () => unsub();
  });

  async function refresh() {
    const requestedActor = actor;
    if (!requestedActor) return;
    const version = ++refreshVersion;
    const requestedLoanId = selected?.id ?? null;
    const isCurrent = () => isCurrentLoanRefresh(
      requestedActor, actor, version, refreshVersion,
      requestedLoanId, selected?.id ?? null
    );

    const next = await requestedActor.getMyLoans();
    const pairs = await Promise.all(next.map(async loan => [
      String(loan.id),
      unwrap(await requestedActor.getLoanCurrencyDefinition(loan.id))
    ]));
    if (!isCurrent()) return; // another loan/identity was selected meanwhile

    loanCurrencyDefinitions = Object.fromEntries(pairs);
    loanCurrencies = Object.fromEntries(pairs.map(([id, def]) => [id, def.code]));
    loans = next;
    if (requestedLoanId == null) return;

    const currentLoan = next.find(l => l.id === requestedLoanId);
    if (!currentLoan) {
      selected = null;
      entries = [];
      auditEvents = [];
      fundingCancellationRequests = [];
      balance = null;
      selectedCurrency = 'CAD';
      selectedCurrencyDefinition = getBuiltinCurrency('CAD');
      detailLoading = false;
      return;
    }

    selected = currentLoan;
    selectedCurrencyDefinition = loanCurrencyDefinitions[String(currentLoan.id)] || getBuiltinCurrency('CAD');
    selectedCurrency = selectedCurrencyDefinition.code;
    const [entryResult, balanceResult, eventResult, cancellationResult] = await Promise.all([
      requestedActor.getLoanEntries(requestedLoanId),
      requestedActor.getBalance(requestedLoanId),
      requestedActor.getLoanEvents(requestedLoanId, 0n, 100n),
      requestedActor.getFundingCancellationRequests(requestedLoanId)
    ]);
    if (!isCurrent()) return; // A's slow response must not overwrite B

    entries = unwrap(entryResult) ?? [];
    balance = unwrap(balanceResult);
    auditEvents = unwrap(eventResult) ?? [];
    fundingCancellationRequests = unwrap(cancellationResult) ?? [];
    detailLoading = false;
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
    ++refreshVersion; // invalidate any already-running detail query
    selected = loan;
    selectedCurrencyDefinition = loanCurrencyDefinitions[String(loan.id)] || getBuiltinCurrency('CAD');
    selectedCurrency = selectedCurrencyDefinition.code;
    entries = [];
    auditEvents = [];
    fundingCancellationRequests = [];
    balance = null;
    detailLoading = true;
    error = '';
    try {
      await refresh();
    } catch (e) {
      if (selected?.id === loan.id) {
        detailLoading = false;
        error = e?.message ?? String(e);
      }
    }
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
      amount: options.amountCents == null ? '' : money(options.amountCents, selectedCurrencyDefinition),
      reference: options.reference || ('Loan #' + String(selected.id)),
      paymentDate: options.paymentDate || '',
      paymentMethod: options.paymentMethod || '',
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
    const note = 'Correction requested for transaction #' + String(entryId);
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

  function editCustomCurrency(def) {
    currencyManagerOpen = true;
    currencyCode = def.code;
    currencySymbol = def.symbol;
    currencyDecimals = String(def.decimals);
    currencyKind = def.kind;
    currencyDeleteCode = '';
    currencyFormError = '';
    currencyFormNotice = '';
    editingCurrency = true;
  }

  function resetCurrencyForm() {
    currencyCode = '';
    currencySymbol = '';
    currencyDecimals = '8';
    currencyKind = 'crypto';
    editingCurrency = false;
    currencyDeleteCode = '';
    currencyFormError = '';
    currencyFormNotice = '';
  }

  async function saveCustomCurrency() {
    currencyFormError = '';
    currencyFormNotice = '';
    if (!actor) {
      currencyFormError = 'Personal Loan is not connected. Please log in again.';
      return;
    }
    if (busy || currencySaving) {
      currencyFormError = 'Another operation is in progress.';
      return;
    }
    let saved = false;
    currencySaving = true;
    try {
      if (currencyDecimals === '' || currencyDecimals == null) {
        throw new Error('Enter decimal places between 0 and 18');
      }
      const def = currencyDefinition({
        code: currencyCode, symbol: currencySymbol,
        decimals: currencyDecimals, kind: currencyKind
      });
      if (getBuiltinCurrency(def.code)) {
        throw new Error('Built-in currencies cannot be edited. Use a unique custom code.');
      }
      const requestedActor = actor;
      currencyFormNotice = 'Saving ' + def.code + '…';
      unwrap(await requestedActor.upsertMyCurrency({ ...def, decimals: BigInt(def.decimals) }));
      saved = true;
      if (actor !== requestedActor) throw new Error('Login changed during saving.');
      currencyFormNotice = 'Saved ' + def.code + '. Refreshing list…';
      const owned = unwrap(await requestedActor.getMyCurrencies());
      if (actor !== requestedActor) throw new Error('Login changed during refresh.');
      customCurrencies = owned ?? [];
      loanCurrency = def.code;
      resetCurrencyForm();
      currencyFormNotice = def.code + ' saved. Existing loan precision is unchanged.';
      notice = 'Currency saved for your account.';
    } catch (e) {
      currencyFormError = (saved
        ? 'Saved successfully but unable to refresh the list: '
        : 'Save failed: ') + (e?.message ?? String(e));
      currencyFormNotice = '';
    } finally {
      currencySaving = false;
    }
  }

  async function removeCustomCurrency(code) {
    currencyFormError = '';
    currencyFormNotice = '';
    if (!actor) {
      currencyFormError = 'Personal Loan is not connected. Please log in again.';
      return;
    }
    if (busy || currencySaving || currencyDeleteCode !== code) return;
    let removed = false;
    currencySaving = true;
    try {
      const requestedActor = actor;
      currencyFormNotice = 'Removing ' + code + '…';
      unwrap(await requestedActor.deleteMyCurrency(code));
      removed = true;
      if (actor !== requestedActor) throw new Error('Login changed during deletion.');
      const owned = unwrap(await requestedActor.getMyCurrencies());
      if (actor !== requestedActor) throw new Error('Login changed during refresh.');
      customCurrencies = owned ?? [];
      if (loanCurrency === code) loanCurrency = 'CAD';
      resetCurrencyForm();
      currencyFormNotice = code + ' removed. Existing loans are unchanged.';
      notice = 'Currency removed from your catalog.';
    } catch (e) {
      currencyFormError = (removed
        ? 'Removed successfully but unable to refresh the list: '
        : 'Remove failed: ') + (e?.message ?? String(e));
      currencyFormNotice = '';
    } finally {
      currencySaving = false;
    }
  }

  function createLoan() {
    return run(() => {
      const other = Principal.fromText(counterparty.trim());
      const borrower = ownRole === 'borrower' ? me : other;
      const lender = ownRole === 'lender' ? me : other;
      const info = currencyDefinition(proposedCurrencyInfo);
      const amount = parseAmountMinor(originalAmount, info.decimals);
      const due = dueDate ? [effectiveDay(dueDate, true)] : [];
      const payload = [textId(borrower), textId(lender), String(amount), info.code, info.symbol, String(info.decimals), info.kind, dueDate, loanNote].join('|');
      return actor.createPersonalLoanWithAsset(
        borrower, lender, amount, { ...info, decimals: BigInt(info.decimals) },
        due, loanNote, stableRequestId('create', payload)
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
    if (!selected || !isMe(selected.borrower) || transactionMode !== 'borrow') return;
    const loanId = selected.id;
    return run(() => {
      const amount = parseAmountMinor(entryAmount, currentLoanDecimals());
      const payload = [String(loanId), String(amount), borrowingNote].join('|');
      return actor.requestAdditionalBorrowing(loanId, amount, borrowingNote, stableRequestId('additional', payload));
    }, () => {
      delete pendingIds.additional;
      entryAmount = '';
      borrowingNote = '';
    });
  }

  function requestRepayment() {
    if (!selected || !isMe(selected.borrower) || transactionMode !== 'repay') return;
    const loanId = selected.id;
    const full = repaymentFull;
    const input = repaymentAmount;
    const date = paymentDate;
    const method = paymentMethod;
    const note = repaymentNote;
    return run(async () => {
      // Confirmed outstanding may have changed since the page last refreshed.
      // Query it again immediately before creating the repayment record.
      const latest = unwrap(await actor.getBalance(loanId));
      const amount = getRepaymentCents(full, latest.outstandingCents, input, currentLoanDecimals());
      const at = effectiveDay(date);
      const payload = [String(loanId), String(amount), date, method, note].join('|');
      return actor.submitRepayment(
        loanId, amount, at, method, note, stableRequestId('repayment', payload)
      );
    }, () => {
      delete pendingIds.repayment;
      repaymentAmount = '';
      repaymentNote = '';
      repaymentFull = false;
    });
  }

  function fundingCancellationAction(entry, existingRequest) {
    if (!selected || entry.status == null) return;
    const loanId = selected.id;
    const entryId = entry.id;
    const approving = Boolean(existingRequest && !isMe(existingRequest.requestedBy));
    const title = approving ? 'Approve funding cancellation' : 'Request funding cancellation';
    const description = approving
      ? 'Both parties agree no funds were delivered. This rejects the accepted borrowing without changing confirmed debt. Initial loan funding cancellation rejects the entire unfunded loan.'
      : 'No funds have been delivered. Ask the other participant to agree to cancel this borrowing. The outstanding balance will not change.';
    confirmLoanAction(title, description,
      () => actor.requestFundingCancellation(loanId, entryId),
      {
        amountCents: entry.amountCents,
        reference: 'Loan #' + String(loanId) + ' · Transaction #' + String(entryId),
        confirmLabel: approving ? 'Approve cancellation' : 'Request cancellation',
        danger: approving
      }
    );
  }

  function retractFundingCancellation(entry) {
    if (!selected) return;
    const loanId = selected.id;
    const entryId = entry.id;
    confirmLoanAction('Withdraw cancellation request',
      'Cancel your pending request to stop this undelivered borrowing. The accepted borrowing remains awaiting delivery.',
      () => actor.withdrawFundingCancellationRequest(loanId, entryId),
      {
        amountCents: entry.amountCents,
        reference: 'Loan #' + String(loanId) + ' · Transaction #' + String(entryId),
        confirmLabel: 'Withdraw request'
      }
    );
  }

  function declareFunding(entry) {
    if (!selected) return;
    const loanId = selected.id;
    const entryId = entry.id;
    const date = fundingDate;
    const method = fundingMethod;
    confirmLoanAction(
      'Declare funds delivered',
      'Only proceed after delivery (bank, cash or crypto). Defunds records your declaration but does not transfer funds, verify blockchain settlements or check transaction hashes.',
      () => actor.declareFunding(loanId, entryId, effectiveDay(date), method),
      {
        amountCents: entry.amountCents,
        reference: 'Loan #' + String(loanId) + ' · Transaction #' + String(entryId),
        paymentDate: date,
        paymentMethod: method,
        confirmLabel: variant(entry.status) === 'disputed' ? 'Re-declare delivered' : 'Declare delivered'
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
      paymentDate: formatEntryPaymentDate(entry),
      paymentMethod: entry.method?.trim() || '',
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
              <div class="mt-1 text-sm text-slate-300">{money(loan.originalAmountCents, loanCurrencyDefinitions[String(loan.id)] || getBuiltinCurrency('CAD'))} agreed</div>
              {#if loan.note}
                <div class="mt-2 truncate text-xs text-slate-400" title={loan.note}>{loan.note}</div>
              {/if}
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
            {#each supportedCurrencies as asset (asset.code)}
              <option value={asset.code}>{asset.code} · {asset.kind} · {Number(asset.decimals)} decimals</option>
            {/each}
          </select>
          <p class="mb-3 text-xs text-slate-400" data-testid="loan-currency-precision">
            {proposedCurrencyInfo.code} uses {Number(proposedCurrencyInfo.decimals)} decimal places.
            This page records debt but never transfers crypto or converts currencies.
          </p>
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

        <section class="rounded-xl border border-slate-700 bg-slate-900 p-4" data-testid="loan-currency-manager">
          <div class="flex items-center justify-between gap-2">
            <h2 class="font-semibold">My currencies</h2>
            <button type="button" class="rounded border border-slate-600 px-3 py-2 text-xs"
              on:click={() => currencyManagerOpen = !currencyManagerOpen}>
              {currencyManagerOpen ? 'Hide manager' : 'Manage currencies'}
            </button>
          </div>
          <p class="mt-2 text-xs text-slate-400">
            Add, edit or remove personal currency definitions. Presets cannot be changed.
            Existing loans retain their original currency, decimals and symbol.
          </p>
          {#if currencyManagerOpen}
            <div class="mt-4 space-y-3">
              <div class="grid grid-cols-2 gap-2">
                <div>
                  <label for="custom-code" class="text-xs text-slate-400">Code</label>
                  <input id="custom-code" type="text" maxlength="12" disabled={editingCurrency}
                    bind:value={currencyCode} placeholder="SOL" class="mt-1 w-full rounded bg-slate-800 p-2 text-sm disabled:opacity-50" />
                </div>
                <div>
                  <label for="custom-symbol" class="text-xs text-slate-400">Symbol (optional)</label>
                  <input id="custom-symbol" type="text" maxlength="12" bind:value={currencySymbol}
                    placeholder="SOL" class="mt-1 w-full rounded bg-slate-800 p-2 text-sm" />
                </div>
                <div>
                  <label for="custom-kind" class="text-xs text-slate-400">Type</label>
                  <select id="custom-kind" bind:value={currencyKind} class="mt-1 w-full rounded bg-slate-800 p-2 text-sm">
                    <option value="fiat">Fiat</option><option value="crypto">Crypto</option>
                  </select>
                </div>
                <div>
                  <label for="custom-decimals" class="text-xs text-slate-400">Decimal places (0–18)</label>
                  <input id="custom-decimals" type="number" min="0" max="18" step="1" bind:value={currencyDecimals}
                    class="mt-1 w-full rounded bg-slate-800 p-2 text-sm" />
                </div>
              </div>
              <p class="text-xs text-amber-200">For tokens, verify contract and network decimals before adding. Codes alone do not identify a chain or contract.</p>
              <div class="flex flex-wrap gap-2">
                <button type="button" data-testid="loan-save-currency"
                  disabled={busy || currencySaving || !currencyCode.trim()} on:click={saveCustomCurrency}
                  class="rounded bg-sky-700 px-3 py-2 text-sm disabled:opacity-50">
                  {currencySaving ? 'Saving currency…' : (editingCurrency ? 'Update currency' : 'Save currency')}
                </button>
                <button type="button" disabled={currencySaving} on:click={resetCurrencyForm}
                  class="rounded border border-slate-600 px-3 py-2 text-sm">Clear</button>
              </div>
              {#if currencyFormError}
                <p role="alert" data-testid="loan-currency-save-error"
                  class="rounded border border-red-700 bg-red-950/40 p-3 text-sm text-red-200">{currencyFormError}</p>
              {/if}
              {#if currencyFormNotice}
                <p role="status" aria-live="polite" data-testid="loan-currency-save-status"
                  class="rounded border border-sky-700 bg-sky-950/40 p-3 text-sm text-sky-100">{currencyFormNotice}</p>
              {/if}
              {#if customCurrencies.length === 0}
                <p class="text-xs text-slate-400">No custom currencies yet. BTC, ETH, ICP, ckBTC and ckETH are already included.</p>
              {/if}
              {#each customCurrencies as custom (custom.code)}
                <div class="flex items-center justify-between gap-2 border-t border-slate-700 pt-3">
                  <div class="min-w-0 text-sm">
                    <span class="font-medium">{custom.code}</span>
                    <span class="text-xs text-slate-400"> · {custom.kind} · {Number(custom.decimals)} decimals</span>
                  </div>
                  <div class="flex gap-2">
                    <button type="button" on:click={() => editCustomCurrency(custom)}
                      class="rounded border border-slate-600 px-2 py-1 text-xs">Edit</button>
                    {#if currencyDeleteCode === custom.code}
                      <button type="button" disabled={busy || currencySaving} on:click={() => removeCustomCurrency(custom.code)}
                        class="rounded border border-red-500 px-2 py-1 text-xs text-red-200">Confirm remove</button>
                      <button type="button" on:click={() => currencyDeleteCode = ''}
                        class="rounded border border-slate-600 px-2 py-1 text-xs">Cancel</button>
                    {:else}
                      <button type="button" on:click={() => currencyDeleteCode = custom.code}
                        class="rounded border border-slate-600 px-2 py-1 text-xs">Remove</button>
                    {/if}
                  </div>
                </div>
              {/each}
            </div>
          {/if}
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
            <div class="mt-4 rounded-lg border border-slate-700 bg-slate-800/60 p-4" data-testid="loan-description">
              <div class="text-xs font-medium uppercase tracking-wide text-slate-400">Loan description</div>
              <p class="mt-2 whitespace-pre-wrap break-words text-sm text-slate-100">
                {selected.note || 'No description provided.'}
              </p>
            </div>
            <div class="mt-4 grid gap-3 sm:grid-cols-2 xl:grid-cols-4">
              <div class="rounded-lg bg-slate-800 p-4" data-testid="agreed-loan-amount">
                <div class="text-xs text-slate-400">Agreed Loan Amount</div>
                <div class="text-lg font-semibold">{money(selected.originalAmountCents, selectedCurrencyDefinition)}</div>
                <div class="mt-1 text-xs text-slate-400">Original agreement; not necessarily funded</div>
              </div>
              <div class="rounded-lg bg-slate-800 p-4" data-testid="loan-total-borrowed">
                <div class="text-xs text-slate-400">Total borrowed (confirmed)</div>
                <div class="text-lg font-semibold">{balance ? money(balance.totalBorrowedCents, selectedCurrencyDefinition) : 'Loading...'}</div>
              </div>
              <div class="rounded-lg bg-slate-800 p-4" data-testid="loan-total-repaid">
                <div class="text-xs text-slate-400">Total repaid (confirmed)</div>
                <div class="text-lg font-semibold">{balance ? money(balance.totalRepaidCents, selectedCurrencyDefinition) : 'Loading...'}</div>
              </div>
              <div class="rounded-lg bg-slate-800 p-4" data-testid="loan-outstanding">
                <div class="text-xs text-slate-400">Outstanding (confirmed debt)</div>
                <div class="text-xl font-semibold">{balance ? money(balance.outstandingCents, selectedCurrencyDefinition) : 'Loading...'}</div>
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
              <div data-testid="loan-immutable-currency">Currency: {selectedCurrency} · {selectedCurrencyDefinition.kind} · {Number(selectedCurrencyDefinition.decimals)} decimals (fixed for this loan; no FX conversion)</div>
              <div class="mt-1">Borrower: {textId(selected.borrower)}</div>
              <div class="mt-1">Lender: {textId(selected.lender)}</div>
              <div class="mt-1">Due date: {selected.dueAt?.length ? formatLoanUtcDate(selected.dueAt[0]) : 'Not set'}</div>
            </div>
            {#if variant(selected.status) === 'proposed' && !isMe(selected.createdBy)}
              <div class="mt-4 flex gap-2">
                <button disabled={busy} class="rounded bg-emerald-700 px-4 py-2" on:click={() => confirmLoanAction(
  'Accept loan terms',
  'You agree to the proposed loan terms. The loan will not count as funded until the lender declares delivery and the borrower confirms receipt.',
  () => actor.acceptLoan(selected.id),
  { amountCents: selected.originalAmountCents, confirmLabel: 'Accept terms' }
)}>Accept terms</button>
                <button disabled={busy} class="rounded bg-slate-700 px-4 py-2" on:click={() => confirmLoanAction(
  'Reject this loan?',
  'The proposed loan will be rejected. No confirmed debt will be created.',
  () => actor.rejectLoan(selected.id),
  { amountCents: selected.originalAmountCents, confirmLabel: 'Reject loan', danger: true }
)}>Reject</button>
              </div>
            {/if}
            {#if variant(selected.status) === 'active' && balance?.outstandingCents === 0n}
              <div class="mt-4">
                <button disabled={busy} class="rounded bg-sky-700 px-4 py-2" on:click={() => confirmLoanAction(
  'Request loan closure',
  'The confirmed balance is zero. The other participant must also approve closure. Closing prevents any further borrowing in this loan.',
  () => actor.requestClosure(selected.id),
  { confirmLabel: 'Request closure' }
)}>Request closure</button>
              </div>
            {/if}
            {#if variant(selected.status) === 'readyToClose' && !isMe(selected.closureRequestedBy?.[0])}
              <div class="mt-4">
                <button disabled={busy} class="rounded bg-emerald-700 px-4 py-2" on:click={() => confirmLoanAction(
  'Confirm loan closure',
  'Confirm that the loan has been fully repaid. Once closed, new borrowing will require a separate loan.',
  () => actor.confirmClosure(selected.id),
  { confirmLabel: 'Close loan' }
)}>Confirm closure</button>
              </div>
            {/if}
          </section>

          {#if variant(selected.status) === 'active' && isMe(selected.borrower)}
            <section class="rounded-xl border border-slate-700 bg-slate-900 p-5">
              <h3 class="mb-4 font-semibold">New transaction</h3>
              <div role="tablist" aria-label="Transaction type"
                class="mb-5 grid grid-cols-2 gap-2 rounded-lg bg-slate-800 p-1">
                <button type="button" role="tab" aria-selected={transactionMode === 'borrow'}
                  aria-controls="loan-transaction-fields"
                  on:click={() => transactionMode = 'borrow'}
                  class={transactionMode === 'borrow'
                    ? 'rounded-md bg-sky-700 px-3 py-3 text-sm font-semibold text-white'
                    : 'rounded-md px-3 py-3 text-sm text-slate-300 hover:bg-slate-700'}>
                  Additional borrowing
                </button>
                <button type="button" role="tab" aria-selected={transactionMode === 'repay'}
                  aria-controls="loan-transaction-fields"
                  on:click={() => transactionMode = 'repay'}
                  class={transactionMode === 'repay'
                    ? 'rounded-md bg-emerald-700 px-3 py-3 text-sm font-semibold text-white'
                    : 'rounded-md px-3 py-3 text-sm text-slate-300 hover:bg-slate-700'}>
                  Repayment
                </button>
              </div>

              <div id="loan-transaction-fields" role="tabpanel">
                {#if transactionMode === 'borrow'}
                  <p class="mb-4 text-xs text-slate-400">
                    Request more money under this loan. The amount is recorded as debt only after both parties confirm funding.
                  </p>
                  <label class="block text-xs text-slate-400" for="extra-amount">Additional borrowing ({selectedCurrency})</label>
                  <input id="extra-amount" bind:value={entryAmount} placeholder="3000.00"
                    class="mt-1 w-full rounded bg-slate-800 p-2" />
                  <label class="mt-3 block text-xs text-slate-400" for="borrowing-note">Borrowing note (optional)</label>
                  <textarea id="borrowing-note" maxlength="500" bind:value={borrowingNote}
                    placeholder="Reason for this additional borrowing" class="mt-1 w-full rounded bg-slate-800 p-2"></textarea>
                  <button disabled={busy || !entryAmount} on:click={requestAdditional}
                    class="mt-3 rounded bg-sky-600 px-4 py-2 text-sm font-semibold hover:bg-sky-500 disabled:opacity-40">
                    Request borrowing
                  </button>
                {:else}
                  <p class="mb-4 text-xs text-slate-400">
                    Record a repayment (bank, cash or crypto). The other participant must confirm it before the debt decreases.
                  </p>
                  <label class="flex cursor-pointer items-center gap-2 rounded-lg border border-slate-700 bg-slate-800/60 p-3 text-sm" for="repay-full">
                    <input id="repay-full" type="checkbox" bind:checked={repaymentFull} class="h-4 w-4 accent-emerald-600" />
                    Repay full outstanding balance
                  </label>
                  {#if repaymentFull}
                    <div class="mt-3 rounded-lg bg-slate-800 p-4" data-testid="full-repayment-amount">
                      <div class="text-xs text-slate-400">Confirmed balance to repay</div>
                      <div class="mt-1 text-xl font-semibold">{balance ? money(balance.outstandingCents, selectedCurrencyDefinition) : 'Loading...'}</div>
                      <p class="mt-1 text-xs text-slate-400">
                        The current confirmed balance will be checked again when submitted. Pending repayments are not yet deducted.
                      </p>
                    </div>
                  {:else}
                    <label class="mt-3 block text-xs text-slate-400" for="repay-amount">Repayment amount ({selectedCurrency})</label>
                    <input id="repay-amount" bind:value={repaymentAmount} placeholder="500.00"
                      class="mt-1 w-full rounded bg-slate-800 p-2" />
                  {/if}
                  <label class="mt-3 block text-xs text-slate-400" for="payment-date">Repayment date</label>
                  <input id="payment-date" type="date" bind:value={paymentDate}
                    class="mt-1 w-full rounded bg-slate-800 p-2" />
                  <label class="mt-3 block text-xs text-slate-400" for="payment-method">Reported repayment method (not verified)</label>
                  <select id="payment-method" bind:value={paymentMethod} class="mt-1 w-full rounded bg-slate-800 p-2">
                    <option>Interac e-Transfer</option><option>Bank Transfer</option><option>Cash</option><option>Cheque</option><option>On-chain transfer (self-reported)</option><option>Other</option>
                  </select>
                  <label class="mt-3 block text-xs text-slate-400" for="repayment-note">Repayment note (optional)</label>
                  <textarea id="repayment-note" maxlength="500" bind:value={repaymentNote}
                    placeholder="e.g. Interac reference or repayment details" class="mt-1 w-full rounded bg-slate-800 p-2"></textarea>
                  <button disabled={busy || !balance || balance.outstandingCents <= 0n || (!repaymentFull && !repaymentAmount)}
                    on:click={requestRepayment}
                    class="mt-3 rounded bg-emerald-700 px-4 py-2 text-sm font-semibold hover:bg-emerald-600 disabled:opacity-40">
                    Record repayment
                  </button>
                {/if}
              </div>
            </section>
          {/if}

          <section class="rounded-xl border border-slate-700 bg-slate-900 p-5">
            <h3 class="mb-3 font-semibold">Shared transaction history</h3>
            <p class="mb-4 text-xs text-slate-400">Only confirmed entries affect the outstanding balance. Check that real-world payments have actually occurred before confirming.</p>
            {#if detailLoading}
              <p class="text-sm text-slate-400" data-testid="loan-detail-loading">Loading selected loan details…</p>
            {:else if entries.length === 0}
              <p class="text-sm text-slate-400">No transaction records yet.</p>
            {/if}
            <div class="space-y-3">
              {#each (detailLoading ? [] : entries) as entry (entry.id)}
                {@const pendingCancellation = fundingCancellationRequests.find(x => x.entryId === entry.id)}
                <div class="rounded-lg border border-slate-700 p-3">
                  <div class="flex flex-wrap justify-between gap-2">
                    <span class="text-sm font-medium">{variant(entry.kind)} · {money(entry.amountCents, selectedCurrencyDefinition)}</span>
                    <span class="text-xs text-sky-300">{variant(entry.status)}</span>
                  </div>
                  <div class="mt-1 text-xs text-slate-400">Recorded by {isMe(entry.proposedBy) ? 'you' : 'the other participant'}{entry.note ? ' · ' + entry.note : ''}</div>
                  {#if formatEntryPaymentDate(entry) || entry.method?.trim()}
                    <div class="mt-2 flex flex-wrap gap-x-5 gap-y-1 text-xs text-slate-300"
                      data-testid="loan-entry-payment-details">
                      {#if formatEntryPaymentDate(entry)}
                        <span>{['initialBorrowing', 'additionalBorrowing'].includes(variant(entry.kind)) ? 'Funding date' : 'Payment date'} (UTC):
                          <strong>{formatEntryPaymentDate(entry)}</strong></span>
                      {/if}
                      {#if entry.method?.trim()}
                        <span>Payment method: <strong>{entry.method}</strong></span>
                      {/if}
                    </div>
                  {/if}
                  {#if variant(entry.status) === 'pendingFunding'
                    && ['initialBorrowing','additionalBorrowing'].includes(variant(entry.kind))}
                    <div class="mt-3 rounded-lg border border-amber-900/60 bg-amber-950/20 p-3"
                      data-testid="loan-bilateral-funding-cancellation">
                      {#if pendingCancellation}
                        <p class="mb-2 text-xs text-amber-200">
                          {isMe(pendingCancellation.requestedBy)
                            ? 'Cancellation requested. Awaiting the other participant’s approval.'
                            : 'The other participant requests cancellation of this undelivered borrowing.'}
                        </p>
                      {:else}
                        <p class="mb-2 text-xs text-slate-400">
                          No money delivered? Both participants can agree to cancel this accepted borrowing.
                        </p>
                      {/if}
                      {#if !pendingCancellation || !isMe(pendingCancellation.requestedBy)}
                        <button disabled={busy} on:click={() => fundingCancellationAction(entry, pendingCancellation)}
                          class="rounded border border-amber-600 px-3 py-2 text-xs text-amber-100 hover:bg-amber-900/40">
                          {pendingCancellation ? 'Approve cancellation' : 'Request cancellation'}
                        </button>
                      {:else}
                        <button disabled={busy} on:click={() => retractFundingCancellation(entry)}
                          class="rounded border border-slate-600 px-3 py-2 text-xs text-slate-200 hover:bg-slate-700">
                          Withdraw cancellation request
                        </button>
                      {/if}
                    </div>
                  {/if}
                  {#if variant(entry.status) === 'confirmed' && variant(selected.status) === 'active' && variant(entry.kind) !== 'reversal'}
                    <button disabled={busy} on:click={() => requestReversal(entry)}
                      class="mt-3 rounded border border-slate-600 px-3 py-2 text-xs hover:border-sky-500">Request correction</button>
                  {/if}
                  {#if isMe(entry.proposedBy) && canRequesterWithdrawEntry(variant(entry.status), variant(entry.kind))}
                    <button disabled={busy} on:click={() => confirmLoanAction(
  'Withdraw pending transaction',
  'Withdraw this unconfirmed request. Confirmed transaction history is not deleted.',
  () => actor.withdrawPendingEntry(selected.id, entry.id),
  { amountCents: entry.amountCents, reference: 'Transaction #' + String(entry.id), confirmLabel: 'Withdraw', danger: true }
)}
                      class="mt-3 rounded bg-slate-700 px-3 py-2 text-xs">Withdraw record</button>
                  {/if}
                  {#if variant(entry.status) === 'pendingTerms' && !isMe(entry.proposedBy)}
                    <div class="mt-3 flex gap-2">
                      <button disabled={busy} class="rounded bg-emerald-700 px-3 py-2 text-xs" on:click={() => confirmLoanAction(
  'Accept additional borrowing',
  'Agree to this additional borrowing amount. The debt increases only after the lender declares delivery and the borrower confirms receipt.',
  () => actor.acceptAdditionalBorrowing(selected.id, entry.id),
  { amountCents: entry.amountCents, reference: 'Transaction #' + String(entry.id), confirmLabel: 'Accept terms' }
)}>Accept terms</button>
                      <button disabled={busy} class="rounded bg-slate-700 px-3 py-2 text-xs" on:click={() => confirmLoanAction(
  'Reject additional borrowing?',
  'The additional borrowing request will be rejected. It will not affect the confirmed debt balance.',
  () => actor.rejectAdditionalBorrowing(selected.id, entry.id),
  { amountCents: entry.amountCents, reference: 'Transaction #' + String(entry.id), confirmLabel: 'Reject', danger: true }
)}>Reject</button>
                    </div>
                  {:else if canLenderDeclareFunding(variant(entry.status), variant(entry.kind), isMe(selected.lender))}
                    <div class="mt-3 space-y-2 rounded-lg border border-slate-700 bg-slate-800/50 p-3">
                      {#if variant(entry.status) === 'disputed'}
                        <p class="text-xs text-amber-200" data-testid="loan-disputed-funding-recovery">
                          Funding was disputed. Review the details above and re-declare delivery for borrower confirmation.
                          This does not by itself increase the confirmed balance.
                        </p>
                      {/if}
                      <label class="block text-xs text-slate-400" for="funding-date-{entry.id}">Funding date</label>
                      <input id="funding-date-{entry.id}" type="date" bind:value={fundingDate}
                        class="w-full rounded bg-slate-800 p-2 text-sm" />
                      <label class="block text-xs text-slate-400" for="funding-method-{entry.id}">Funds delivery method</label>
                      <select id="funding-method-{entry.id}" bind:value={fundingMethod}
                        class="w-full rounded bg-slate-800 p-2 text-sm">
                        <option>Interac e-Transfer</option><option>Bank Transfer</option><option>Cash</option><option>Cheque</option><option>On-chain transfer (self-reported)</option><option>Other</option>
                      </select>
                      <button disabled={busy || !fundingDate} on:click={() => declareFunding(entry)}
                        class="rounded bg-sky-700 px-3 py-2 text-xs disabled:opacity-40">
                        {variant(entry.status) === 'disputed' ? 'Re-declare funds delivered' : 'Declare funds delivered'}
                      </button>
                    </div>
                  {:else if variant(entry.status) === 'pendingConfirmation'}
                    {@const kind = variant(entry.kind)}
                    {@const borrowing = kind === 'initialBorrowing' || kind === 'additionalBorrowing'}
                    {#if (borrowing && isMe(selected.borrower)) || (!borrowing && !isMe(entry.proposedBy))}
                      <div class="mt-3 flex gap-2">
                        <button disabled={busy} on:click={() => confirmEntry(entry)} class="rounded bg-emerald-700 px-3 py-2 text-xs">Confirm</button>
                        <button disabled={busy} on:click={() => confirmLoanAction(
  'Dispute this transaction?',
  'This records a dispute instead of confirming the payment. The shared confirmed balance will not change.',
  () => actor.disputeEntry(selected.id, entry.id),
  { amountCents: entry.amountCents, reference: 'Transaction #' + String(entry.id), confirmLabel: 'Dispute', danger: true }
)} class="rounded bg-slate-700 px-3 py-2 text-xs">Dispute</button>
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
            {#if detailLoading}<p class="text-sm text-slate-400">Loading audit history…</p>{/if}
            {#if auditEvents.length === 0}
              <p class="text-sm text-slate-400">No events yet.</p>
            {/if}
            {#each (detailLoading ? [] : auditEvents) as event (event.id)}
              {@const eventKind = variant(event.kind)}
              {@const relatedEntry = event.entryId.length
                ? entries.find(entry => entry.id === event.entryId[0])
                : null}
              {@const eventAmount = relatedEntry
                ? relatedEntry.amountCents
                : (['loanProposed', 'loanRejected'].includes(eventKind)
                    ? selected.originalAmountCents
                    : null)}
              {@const eventNote = loanEventNote(eventKind, relatedEntry, selected)}
              <div class="flex flex-wrap items-start justify-between gap-3 border-t border-slate-800 py-3 text-xs">
                <div class="min-w-0">
                  <div class="font-medium text-slate-200">
                    {loanEventLabel(eventKind)}
                    {event.entryId.length ? (' · transaction #' + String(event.entryId[0])) : ''}
                  </div>
                  {#if eventAmount != null}
                    <div class="mt-1 text-sm font-semibold text-sky-200" data-testid="loan-audit-amount">
                      Amount: {money(eventAmount, selectedCurrencyDefinition)}
                    </div>
                  {/if}
                  {#if eventNote}
                    <div class="mt-2 whitespace-pre-wrap break-words text-slate-300" data-testid="loan-audit-note">
                      <span class="font-medium text-slate-400">Note:</span> {eventNote}
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
  paymentDate={confirmation?.paymentDate || ''}
  paymentMethod={confirmation?.paymentMethod || ''}
  confirmLabel={confirmation?.confirmLabel || 'Confirm'}
  danger={confirmation?.danger || false}
  pending={busy}
  error={confirmation ? error : ''}
  on:cancel={cancelLoanConfirmation}
  on:confirm={executeLoanConfirmation}
/>
