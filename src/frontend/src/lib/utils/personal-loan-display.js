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

export function parseLoanAmountCents(value) {
  const input = String(value ?? '').trim();
  if (!/^(0|[1-9][0-9]{0,11})(\.[0-9]{1,2})?$/.test(input)) {
    throw new Error('Enter an amount with up to two decimal places');
  }
  const [dollars, fraction = ''] = input.split('.');
  const cents = BigInt(dollars) * 100n + BigInt((fraction + '00').slice(0, 2));
  if (cents <= 0n) throw new Error('Amount must be positive');
  return cents;
}

export function getRepaymentCents(fullOutstanding, outstandingCents, enteredAmount) {
  // Call with a FRESH getBalance() result immediately before submission.
  const balance = BigInt(outstandingCents ?? 0);
  if (balance <= 0n) throw new Error('There is no confirmed outstanding balance to repay');
  const amount = fullOutstanding ? balance : parseLoanAmountCents(enteredAmount);
  if (amount > balance) throw new Error('Repayment exceeds the confirmed outstanding balance');
  return amount;
}
