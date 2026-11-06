import assert from 'node:assert/strict';
import { readFileSync } from 'node:fs';
import test from 'node:test';

const page = readFileSync('src/frontend/src/routes/loans/+page.svelte', 'utf8');
const modal = readFileSync('src/frontend/src/lib/components/LoanConfirmationModal.svelte', 'utf8');

test('loan actions open a branded confirmation modal, never the native browser confirm', () => {
  assert.doesNotMatch(page, /window\.confirm\s*\(/);
  assert.match(page, /<LoanConfirmationModal\b/);
  assert.match(page, /on:confirm=\{executeLoanConfirmation\}/);
  assert.match(page, /on:cancel=\{cancelLoanConfirmation\}/);
  assert.match(page, /Confirm funds received/);
  assert.match(page, /Declare funds delivered/);
  assert.match(page, /Confirm repayment/);
  assert.match(page, /Confirm loan closure/);
  assert.match(modal, /role="dialog"/);
  assert.match(modal, /aria-modal="true"/);
  assert.match(modal, /data-testid="loan-confirmation-amount"/);
  assert.match(modal, /event\.key === 'Escape'/);
});

test('audit timeline shows each associated entry amount and the loan currency', () => {
  assert.match(page, /entries\.find\(entry => entry\.id === event\.entryId\[0\]\)/);
  assert.match(page, /loan-audit-amount/);
  assert.match(page, /Amount: \{money\(eventAmount, selectedCurrency\)\}/);
  assert.match(page, /selected\.originalAmountCents/);
  assert.match(page, /getLoanCurrency\(loan\.id\)/);
});

test('loan description appears in loan details and list preview', () => {
  assert.match(page, /data-testid="loan-description"/);
  assert.match(page, /selected\.note \|\| 'No description provided\.'/);
  assert.match(page, /title=\{loan\.note\}/);
});

test('additional borrowing and repayment are exclusive tabs with separate notes', () => {
  assert.match(page, /role="tablist" aria-label="Transaction type"/);
  assert.match(page, /transactionMode === 'borrow'/);
  assert.match(page, /transactionMode === 'repay'/);
  assert.match(page, /\{#if transactionMode === 'borrow'\}/);
  assert.match(page, /bind:value=\{borrowingNote\}/);
  assert.match(page, /bind:value=\{repaymentNote\}/);
  assert.doesNotMatch(page, /bind:value=\{entryNote\}/);
});

test('repay full outstanding requests an up-to-date balance before submission', () => {
  assert.match(page, /id="repay-full" type="checkbox" bind:checked=\{repaymentFull\}/);
  assert.match(page, /data-testid="full-repayment-amount"/);
  assert.match(page, /await actor\.getBalance\(loanId\)/);
  assert.match(page, /getRepaymentCents\(full, latest\.outstandingCents, input\)/);
});

test('audit shows friendly event names and original notes with each entry', () => {
  assert.match(page, /loanEventLabel\(eventKind\)/);
  assert.match(page, /loanEventNote\(eventKind, relatedEntry, selected\)/);
  assert.match(page, /data-testid="loan-audit-note"/);
});

test('new transaction form is shown only to the loan borrower', () => {
  assert.match(
    page,
    /\{#if variant\(selected\.status\) === 'active' && isMe\(selected\.borrower\)\}[\s\S]*?<h3 class="mb-4 font-semibold">New transaction<\/h3>/
  );
  assert.match(
    page,
    /if \(!selected \|\| !isMe\(selected\.borrower\) \|\| transactionMode !== 'borrow'\) return;/
  );
  assert.match(
    page,
    /if \(!selected \|\| !isMe\(selected\.borrower\) \|\| transactionMode !== 'repay'\) return;/
  );
  // Lenders retain their confirmation controls inside shared transaction history.
  assert.match(page, /isMe\(selected\.lender\)/);
  assert.match(page, /Declare funds delivered/);
  assert.match(page, /confirmEntry\(entry\)/);
});
