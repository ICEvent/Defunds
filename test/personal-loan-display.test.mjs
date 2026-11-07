import assert from 'node:assert/strict';
import test from 'node:test';
import {
  loanEventLabel, loanEventNote,
  parseLoanAmountCents, getRepaymentCents,
  formatEntryPaymentDate, canLenderDeclareFunding, canRequesterWithdrawEntry
} from '../src/frontend/src/lib/utils/personal-loan-display.js';

test('loan audit names are readable and cover all financial transitions', () => {
  assert.equal(loanEventLabel('loanProposed'), 'Loan proposed');
  assert.equal(loanEventLabel('additionalBorrowingRequested'), 'Additional borrowing requested');
  assert.equal(loanEventLabel('fundingConfirmed'), 'Funds received and confirmed');
  assert.equal(loanEventLabel('repaymentConfirmed'), 'Repayment confirmed');
  assert.equal(loanEventLabel('reversalConfirmed'), 'Correction confirmed');
  assert.equal(loanEventLabel('loanClosed'), 'Loan closed');
});

test('audit notes come from original loan or related transaction, not a placeholder', () => {
  const loan = { note: 'To purchase a new car' };
  const original = { kind: { initialBorrowing: null }, note: 'Initial borrowing' };
  const borrowing = { kind: { additionalBorrowing: null }, note: 'Car repairs' };
  const repayment = { kind: { repayment: null }, note: 'November Interac payment' };
  assert.equal(loanEventNote('loanProposed', null, loan), loan.note);
  assert.equal(loanEventNote('fundingDeclared', original, loan), loan.note);
  assert.equal(loanEventNote('fundingConfirmed', original, loan), loan.note);
  assert.equal(loanEventNote('additionalBorrowingRequested', borrowing, loan), borrowing.note);
  assert.equal(loanEventNote('repaymentSubmitted', repayment, loan), repayment.note);
  assert.equal(loanEventNote('repaymentConfirmed', repayment, loan), repayment.note);
  assert.equal(loanEventNote('loanClosed', null, loan), '');
  assert.equal(loanEventNote('repaymentConfirmed', { kind: { repayment: null }, note: '' }, loan), '');
});

test('integer minor-unit parsing is exact', () => {
  assert.equal(parseLoanAmountCents('3000'), 300000n);
  assert.equal(parseLoanAmountCents(' 123.45 '), 12345n);
  assert.equal(parseLoanAmountCents('0.01'), 1n);
  assert.throws(() => parseLoanAmountCents('0'), /positive/);
  assert.throws(() => parseLoanAmountCents('12.345'), /decimal places/);
  assert.throws(() => parseLoanAmountCents('-3'), /decimal places/);
});

test('full repayment uses exact fresh confirmed outstanding, not typed input', () => {
  assert.equal(getRepaymentCents(true, 850000n, ''), 850000n);
  assert.equal(getRepaymentCents(true, 125001n, '99999999'), 125001n);
  assert.equal(getRepaymentCents(false, 850000n, '300.50'), 30050n);
  assert.equal(getRepaymentCents(false, 850000n, '8500'), 850000n);
  assert.throws(() => getRepaymentCents(false, 850000n, '8500.01'), /exceeds/);
  assert.throws(() => getRepaymentCents(true, 0n, ''), /no confirmed outstanding/);
  assert.throws(() => getRepaymentCents(false, 0n, '10'), /no confirmed outstanding/);
});


test('loan payment date uses persisted Motoko nanoseconds and stays UTC calendar day', () => {
  const date = BigInt(Date.parse('2027-01-01T12:00:00.000Z')) * 1_000_000n;
  const repayment = { effectiveAt: [date], method: 'Interac e-Transfer' };
  assert.equal(formatEntryPaymentDate(repayment), '2027-01-01');
  assert.equal(formatEntryPaymentDate({ effectiveAt: [] }), '');
  assert.equal(formatEntryPaymentDate({ effectiveAt: [0n] }), '1970-01-01');
  assert.equal(formatEntryPaymentDate({ effectiveAt: ['not-a-nanosecond'] }), '');
  assert.equal(formatEntryPaymentDate(null), '');
});

test('lender can redeclare disputed borrowing, but not disputed repayment or reversal', () => {
  for (const kind of ['initialBorrowing', 'additionalBorrowing']) {
    assert.equal(canLenderDeclareFunding('pendingFunding', kind, true), true);
    assert.equal(canLenderDeclareFunding('disputed', kind, true), true);
    assert.equal(canLenderDeclareFunding('pendingConfirmation', kind, true), false);
    assert.equal(canLenderDeclareFunding('confirmed', kind, true), false);
    assert.equal(canLenderDeclareFunding('disputed', kind, false), false);
  }
  assert.equal(canLenderDeclareFunding('disputed', 'repayment', true), false);
  assert.equal(canLenderDeclareFunding('disputed', 'reversal', true), false);
});

test('withdrawal controls match Motoko disputed-funding restrictions', () => {
  assert.equal(canRequesterWithdrawEntry('pendingTerms', 'additionalBorrowing'), true);
  assert.equal(canRequesterWithdrawEntry('pendingConfirmation', 'repayment'), true);
  assert.equal(canRequesterWithdrawEntry('disputed', 'repayment'), true);
  assert.equal(canRequesterWithdrawEntry('disputed', 'reversal'), true);
  assert.equal(canRequesterWithdrawEntry('disputed', 'initialBorrowing'), false);
  assert.equal(canRequesterWithdrawEntry('disputed', 'additionalBorrowing'), false);
  assert.equal(canRequesterWithdrawEntry('confirmed', 'repayment'), false);
});
