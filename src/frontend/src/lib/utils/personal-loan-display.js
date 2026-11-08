import { parseAmountMinor } from './personal-loan-currency.js';

// Loan presentation and amount selection. Never derive repayment amounts
// from proposed/unconfirmed borrowings or from an audit-event count.
export const LOAN_EVENT_LABELS = Object.freeze({
  loanProposed: 'Loan proposed',
  loanAccepted: 'Loan terms accepted',
  loanRejected: 'Loan proposal rejected',
  fundingDeclared: 'Funds delivery declared',
  fundingConfirmed: 'Funds received and confirmed',
  additionalBorrowingRequested: 'Additional borrowing requested',
  additionalBorrowingAccepted: 'Additional borrowing approved',
  additionalBorrowingRejected: 'Additional borrowing declined',
  repaymentSubmitted: 'Repayment recorded',
  repaymentConfirmed: 'Repayment confirmed',
  entryDisputed: 'Transaction disputed',
  entryWithdrawn: 'Pending transaction withdrawn',
  fundingCancellationRequested: 'Undelivered funding cancellation requested',
  fundingCancelled: 'Undelivered borrowing cancelled by both parties',
  reversalRequested: 'Correction requested',
  reversalConfirmed: 'Correction confirmed',
  closureRequested: 'Loan closure requested',
  loanClosed: 'Loan closed'
});

export function loanEventLabel(kind) {
  return LOAN_EVENT_LABELS[kind] ?? String(kind ?? 'Unknown event')
    .replace(/([a-z])([A-Z])/g, '$1 $2')
    .replace(/^./, c => c.toUpperCase());
}

export function loanEventNote(kind, entry, loan) {
  // Original agreement notes describe the initial borrowing; the generic
  // initial-entry placeholder ("Initial borrowing") is not the user's note.
  if (entry) {
    if (entry.kind && Object.hasOwn(entry.kind, 'initialBorrowing')) {
      return loan?.note || entry.note || '';
    }
    return entry.note || '';
  }
  return ['loanProposed', 'loanAccepted', 'loanRejected'].includes(kind)
    ? (loan?.note || '')
    : '';
}

// Original CAD callers keep the two-decimal API for backwards compatibility.
export function parseLoanAmountCents(value) {
  return parseAmountMinor(value, 2);
}

export function getRepaymentCents(fullOutstanding, outstandingCents, enteredAmount, decimals = 2) {
  // Call with a FRESH getBalance() result immediately before submission.
  const balance = BigInt(outstandingCents ?? 0);
  if (balance <= 0n) throw new Error('There is no confirmed outstanding balance to repay');
  const amount = fullOutstanding ? balance : parseAmountMinor(enteredAmount, decimals);
  if (amount > balance) throw new Error('Repayment exceeds the confirmed outstanding balance');
  return amount;
}


// The Motoko optional effectiveAt : ?Int is decoded as [] or [bigint].
// UTC date is intentional: loan forms serialize calendar days as UTC nanos,
// and the displayed date must not shift with the viewer's browser timezone.
export function formatEntryPaymentDate(entry) {
  const nanoseconds = entry?.effectiveAt?.[0];
  if (nanoseconds == null) return '';
  try {
    const milliseconds = Number(BigInt(nanoseconds) / 1_000_000n);
    const date = new Date(milliseconds);
    return Number.isFinite(date.getTime()) ? date.toISOString().slice(0, 10) : '';
  } catch {
    return '';
  }
}

// A disputed delivery can be re-declared by the lender to restart the
// borrower acknowledgement. A disputed repayment/reversal cannot use funding.
export function canLenderDeclareFunding(status, kind, isLender) {
  return Boolean(
    isLender
    && (status === 'pendingFunding' || status === 'disputed')
    && (kind === 'initialBorrowing' || kind === 'additionalBorrowing')
  );
}

// Keep UI withdrawal actions consistent with withdrawPendingEntry in Motoko:
// delivered borrowing cannot be unilaterally withdrawn after a dispute.
export function canRequesterWithdrawEntry(status, kind) {
  return status === 'pendingTerms'
    || ((status === 'disputed' || status === 'pendingConfirmation')
      && (kind === 'repayment' || kind === 'reversal'));
}


// A contractual due date is a UTC calendar day, not a viewer-local instant.
// Due dates are stored at 23:59:59.999 UTC, so toLocaleDateString would
// display tomorrow in positive-offset timezones (e.g. Asia/Shanghai).
export function formatLoanUtcDate(nanoseconds) {
  if (nanoseconds == null) return '';
  try {
    const ms = Number(BigInt(nanoseconds) / 1_000_000n);
    const date = new Date(ms);
    return Number.isFinite(date.getTime()) ? date.toISOString().slice(0, 10) : '';
  } catch {
    return '';
  }
}


// Apply async loan details only if both the selected loan and the actor
// session are the ones captured when the request was issued.
export function isCurrentLoanRefresh(requestedActor, activeActor, requestedVersion, activeVersion, requestedLoanId, activeLoanId) {
  return requestedActor === activeActor
    && requestedVersion === activeVersion
    && requestedLoanId === activeLoanId;
}
