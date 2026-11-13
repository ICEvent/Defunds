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
  assert.match(page, /Amount: \{money\(eventAmount, selectedCurrencyDefinition\)\}/);
  assert.match(page, /selected\.originalAmountCents/);
  assert.match(page, /getLoanCurrencyDefinition\(loan\.id\)/);
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
  assert.match(page, /getRepaymentCents\(full, latest\.outstandingCents, input, currentLoanDecimals\(\)\)/);
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


test('review: lender can re-declare disputed borrowing with a visible recovery action', () => {
  assert.match(page, /canLenderDeclareFunding\(variant\(entry\.status\), variant\(entry\.kind\), isMe\(selected\.lender\)\)/);
  assert.match(page, /data-testid="loan-disputed-funding-recovery"/);
  assert.match(page, /Re-declare funds delivered/);
  assert.match(page, /canRequesterWithdrawEntry\(variant\(entry\.status\), variant\(entry\.kind\)\)/);
});

test('review: date and method are visible before confirming payment on both surfaces', () => {
  assert.match(page, /data-testid="loan-entry-payment-details"/);
  assert.match(page, /formatEntryPaymentDate\(entry\)/);
  assert.match(page, /entry\.method/);
  assert.match(page, /paymentDate: formatEntryPaymentDate\(entry\)/);
  assert.match(page, /paymentMethod: entry\.method\?\.trim\(\) \|\| ''/);
  assert.match(page, /paymentDate=\{confirmation\?\.paymentDate \|\| ''\}/);
  assert.match(page, /paymentMethod=\{confirmation\?\.paymentMethod \|\| ''\}/);
  assert.match(modal, /data-testid="loan-confirmation-payment-details"/);
  assert.match(modal, /Recorded payment date \(UTC\)/);
  assert.match(modal, /Recorded payment method/);
});


test('review: drop stale loan A details and clear old state immediately on selecting B', () => {
  assert.match(page, /refreshVersion/);
  assert.match(page, /isCurrentLoanRefresh\(/);
  assert.match(page, /if \(!isCurrent\(\)\) return; \/\/ A's slow response must not overwrite B/);
  assert.match(page, /selected = loan;[\s\S]*?entries = \[\];[\s\S]*?auditEvents = \[\];[\s\S]*?balance = null;[\s\S]*?detailLoading = true;/);
  assert.match(page, /data-testid="loan-detail-loading"/);
});

test('review: accepted undelivered funding is cancellable only with bilateral approvals', () => {
  assert.match(page, /getFundingCancellationRequests\(requestedLoanId\)/);
  assert.match(page, /data-testid="loan-bilateral-funding-cancellation"/);
  assert.match(page, /requestFundingCancellation\(loanId, entryId\)/);
  assert.match(page, /withdrawFundingCancellationRequest\(loanId, entryId\)/);
  assert.match(page, /Approve cancellation/);
  assert.match(page, /Withdraw cancellation request/);
});

test('review: agreed loan due date is always formatted in UTC', () => {
  assert.match(page, /formatLoanUtcDate\(selected\.dueAt\[0\]\)/);
  assert.doesNotMatch(page, /selected\.dueAt\[0\].*toLocaleDateString/);
});

test('manually managed fiat and crypto assets use immutable loan precision', () => {
  assert.match(page, /data-testid="loan-currency-manager"/);
  assert.match(page, /getMyCurrencies\(\)/);
  assert.match(page, /upsertMyCurrencyWithReference\(/);
  assert.match(page, /deleteMyCurrency\(/);
  assert.match(page, /createPersonalLoanWithReference\(/);
  assert.match(page, /parseAmountMinor\(originalAmount, info\.decimals\)/);
  assert.match(page, /parseAmountMinor\(entryAmount, currentLoanDecimals\(\)\)/);
  assert.match(page, /data-testid="loan-immutable-currency"/);
  assert.match(page, /loanCurrencyDefinitions\[String\(loan\.id\)\]/);
  assert.match(page, /On-chain transfer \(self-reported\)/);
});

test('currency save gives immediate inline feedback instead of only page-top errors', () => {
  assert.match(page, /data-testid="loan-save-currency"/);
  assert.match(page, /on:click=\{saveCustomCurrency\}/);
  assert.match(page, /currencyFormNotice = 'Saving '/);
  assert.match(page, /currencyFormNotice = 'Saved '/);
  assert.match(page, /currencyFormError = \(saved/);
  assert.match(page, /data-testid="loan-currency-save-error"/);
  assert.match(page, /data-testid="loan-currency-save-status"/);
  assert.match(page, /role="alert"/);
  assert.match(page, /aria-live="polite"/);
  assert.match(page, /currencySaving \? 'Saving currency/);
  assert.match(page, /unwrap\(await requestedActor\.upsertMyCurrencyWithReference\(/);
  assert.match(page, /customCurrencies = unwrap\(owned\) \?\? \[\]/);
});

test('new loans and parties show immutable asset network and contract identity', () => {
  assert.match(page, /getMyAssetReferences\(\)/);
  assert.match(page, /getLoanAssetReference\(loan\.id\)/);
  assert.match(page, /assetReference\(/);
  assert.match(page, /data-testid="currency-blockchain-reference-fields"/);
  assert.match(page, /id="custom-network"/);
  assert.match(page, /id="custom-contract"/);
  assert.match(page, /data-testid="loan-immutable-asset-reference"/);
  assert.match(page, /data-testid="loan-proposed-asset-reference"/);
  assert.match(page, /getBuiltinCurrency\(/);
  assert.match(page, /Contract \/ Ledger ID/);
});
