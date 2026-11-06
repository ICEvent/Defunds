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
