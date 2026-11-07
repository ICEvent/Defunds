# Defunds Personal Loan — Shared Ledger

**Status:** Draft / implementation in progress  
**Version:** 0.1 — 2026-11-05  
**Scope:** personal, two-party, off-chain loans with immutable per-loan currency (CAD, USD, EUR, GBP, CNY)

## Goal
One Loan, Two Parties, One Shared Ledger. A borrower and lender authenticate with Internet Identity and see the same loan, confirmed borrowings, repayments, and outstanding balance. Either party may initiate an additional borrowing or a repayment; the other party must accept. No custody, bank integration, DAO voting, or token transfers in this MVP.

## Definitions
- A **loan** is one continuing debt relationship between a borrower and a lender, with immutable principals and initial terms.
- An **entry** is an append-only debt-changing transaction: initial borrowing, additional borrowing, repayment, or reversal.
- A **pending** entry is not included in the balance. An entry is reflected in the balance **only once confirmed**. The loan's **Agreed Loan Amount** is stored immediately at proposal creation and displayed separately from **Confirmed Borrowed**, **Total Repaid** and **Outstanding**.
- Monetary amounts use nonnegative integer **minor units** (two decimal places for CAD, USD, EUR, GBP and CNY), never floating point. Each loan has one immutable currency; additional borrowing, repayments and reversals must use that same currency without automatic FX conversion.
- Borrowing is not considered funded when terms are accepted. The lender declares funds delivered, and the borrower separately acknowledges receipt.
- The first version is **interest-free (0 bps)**. Interest schedules, amendments, and multilateral loans are explicitly deferred.

## Roles and authorization
- `borrower` and `lender` are distinct, nonanonymous principals.
- Either principal may propose a loan and view its private information. The counterpart accepts or rejects the invitation.
- A borrower or lender may propose additional borrowing. The counterpart must accept its terms; thereafter the lender declares delivery and the borrower confirms actual receipt.
- Either party may record an off-chain repayment; **only the other party** may confirm or dispute it.
- No participant may mutate a confirmed entry or confirm their own entry. A mistaken confirmed entry requires a new reversal request accepted by the counterpart.
- Only participants may query a loan, its entries, and its balance. A caller may list only loans in which they participate.
- Do not expose public enumeration, public financial history, or sensitive payment attachments. IC canisters are not a substitute for encryption or access control at storage and controller level.

## Lifecycle
```text
Loan: proposed --accept--> fundingPending --funds delivered & acknowledged--> active
      \--reject--> rejected
active --balance reaches zero--> readyToClose --other participant confirms closure--> closed

Initial borrowing entry: pendingFunding --lender declares transfer--> pendingConfirmation
                         --borrower acknowledges receipt--> confirmed
Additional borrowing: pendingTerms --other participant accepts--> pendingFunding
                      --lender declares transfer--> pendingConfirmation
                      --borrower acknowledges receipt--> confirmed
Repayment: pendingConfirmation --other participant confirms--> confirmed
                               \--disputes--> disputed
Reversal: pendingConfirmation --other participant confirms--> confirmed
```

A dispute does not silently change a confirmed balance. Loans with pending entries cannot be closed. Closing requires zero outstanding principal and distinct approvals. Additional borrowing after closing requires a new loan.

## Balance
```text
principal_outstanding =
    sum(confirmed initial/additional borrowings)
  - sum(confirmed repayments)
  + net confirmed reversals
```
Prevent repayments exceeding outstanding and prevent reversals that would make the balance negative, **re-evaluated at confirmation**. Exactly one reversal may be confirmed against a confirmed original transaction. All amounts must be positive.

Example: borrow $10,000; repay $1,000; repay $1,500; borrow $3,000; repay $2,000 => **$8,500 outstanding**.

## Core canister model
Keep Personal Loan in a separate `personal_loan` Motoko canister to avoid modifying Defunds' deployed Grant/Treasury stable state.
- `Loan`: id, borrower, lender, original principal in minor units, due date, 0% rate, status, creator, timestamps, closure requestor. Currency is held in a separate stable `(LoanId, Currency)` mapping so old v0.1 CAD loan records remain upgrade-compatible; missing mapping defaults to CAD.
- `Entry`: id, loanId, kind, integer cents, proposer, effectiveAt, evidence note/method, confirmation status and timestamps. Reversal contains a reference to the original entry.
- `getMyLoans`, `getLoan`, `getLoanEntries`, and `getBalance` enforce participant permissions.
- Use caller-derived actors, not principals passed as claimed approvers.
- Mutations are idempotent through request IDs; state transitions are validated before any persistent update.
- A small-scale v0.1 may store persistent arrays; plan indexes and pagination before scaling.
- Store immutable `LoanEvent` records for all important transitions; every event is readable only by the borrower and lender. Pagination caps audit queries at 100 events.

## Proposed API
```text
createPersonalLoan(borrower, lender, initialAmountCents, dueAt, note)  // legacy CAD\ncreatePersonalLoanWithCurrency(borrower, lender, initialAmountMinor, currency, dueAt, note, requestId)\ngetLoanCurrency(loanId)
acceptLoan(loanId) / rejectLoan(loanId)
requestAdditionalBorrowing(loanId, amountCents, note)
acceptAdditionalBorrowing(loanId, entryId)
declareFunding(loanId, entryId, effectiveAt, method)
confirmFunding(loanId, entryId)
submitRepayment(loanId, amountCents, effectiveAt, method, note)
confirmRepayment(loanId, entryId) / disputeEntry(loanId, entryId)
requestReversal(loanId, originalEntryId, note)
confirmReversal(loanId, entryId)
requestClosure(loanId) / confirmClosure(loanId)
getMyLoans() / getLoan(loanId) / getLoanEntries(loanId) / getBalance(loanId)\ngetLoanEvents(loanId, offset, limit) / withdrawPendingEntry(loanId, entryId)
```

## Frontend plan
Add **Loans** with **My Borrowings**, **My Lending**, **Invitations** and **Loan Detail**. Loan Detail displays an explicit **Agreed Loan Amount** alongside confirmed borrowed/repaid/outstanding balances, immutable currency, agreement, complete ledger, and separate pending actions. An accessible in-app confirmation modal replaces native browser confirms for approvals, funding, repayment, dispute, reversal and closure; the Audit Timeline displays the currency-denominated amount associated with each financial event. Both users see the same confirmed debt. Pending/unconfirmed items are clearly separated.

## Safety and limitations
- An account balance is a **jointly confirmed record**, not proof of money transfer or a legally enforceable contract.
- Off-chain transfers require human verification; screenshots and notes are not automatically trusted.
- On-chain metadata and controller access have privacy constraints. Do not collect sensitive bank numbers or documents in plaintext.
- Interest-bearing lending, consumer-credit compliance, real-funds treasury actions, dispute arbitration, encrypted documents, notifications, and transaction-attached ICRC receipts are outside the initial slice.
- Never deploy an untested financial canister to mainnet.

## Implementation gates
1. Core types, persistence, identity/permission checks, confirm-only ledger and simple unit tests.
2. Mutual acceptance, additional-borrowing delivery confirmation, repayment/dispute/reversal, closure, replay protections.
3. UI and authenticated dual-identity E2E tests.
4. Local dfx compile, state upgrade/migration tests and security review before any deployment.

## Development and local verification
The UI and Motoko backend are committed on the feature branch, **not deployed**.

1. Install the project's dfx/Motoko toolchain, then run `dfx build personal_loan --check`.
2. Run the pure balance fixture:
   ```bash
   CACHE="$(dfx cache show)"
   "$CACHE/moc" -r --package base "$CACHE/base" test/PersonalLoanLedger.test.mo
   ```
3. Create and deploy the canister **only on an isolated local replica**:
   ```bash
   dfx start --clean --background
   dfx deploy personal_loan
   dfx generate personal_loan
   ```
4. Configure the frontend with `VITE_PERSONAL_LOAN_CANISTER_ID=<local canister ID>` and
   `VITE_PERSONAL_LOAN_HOST=http://127.0.0.1:4943`; rebuild the frontend.
   Do not point a local ID at the production replica or reuse the Defunds Treasury ID.
5. With two authenticated identities, test invitations, initial delivery, additional
   borrowing, partial repayments, duplicate client request IDs, declined/disputed
   entries, reversal, closing, and outsiders' denied queries.
6. Test a stable canister upgrade and paginated read performance before production.

**Unverified in this branch:** compiler/build, Svelte integration and dual-identity E2E.
Neither a successful GitHub commit nor this design document establishes those gates.

## Verification record

- CI run [42155309083](https://github.com/ICEvent/Defunds/actions/runs/42155309083): Motoko build and ledger fixtures **passed**. The three-identity E2E **passed**, including the CAD 10,000 + CAD 3,000 case, partial repayments, duplicate requests, outsider denial, reversal guards and mutual closure.
- CI run [42155545233](https://github.com/ICEvent/Defunds/actions/runs/42155545233): Motoko and three-identity E2E **passed**, including a local canister upgrade and balance persistence check.
- The earlier full Vite build blocker involving `icp_index` Candid declarations was fixed in this PR. Later CI validates the full frontend build, the local PocketIC/II preview and the three-identity financial Canister E2E.
- No mainnet deployment has been performed. Keep the PR draft until the frontend integration and complete regression gates pass.

## UI and currencies review (2026-11-06)

- New loan: choose one of CAD, USD, EUR, GBP, CNY before proposing. Currency is immutable after creation; previously created v0.1 loans remain CAD. Amounts are stored as integer cents/minor units (no floating point or FX).
- **Agreed Loan Amount** comes directly from the original proposed principal. Immediately after proposal it can be non-zero while confirmed outstanding is still zero: that is intentional, since funds have not yet been acknowledged.
- **Audit Timeline** shows the event name, transaction reference, associated amount and currency for borrowing/repayment/reversal events. Multiple events may reference the **same** transaction; the audit view must never be summed as if each event were a separate payment.
- Approval, funding delivery, repayment confirmation, dispute, correction and closure use the app's modal with descriptive copy and amount rather than browser-native `confirm()`. Errors remain in the modal; cancellation has no ledger effect.
- CI adds a regression guard for native-confirm removal and currency-aware audit amounts; actual browser interaction with two local Internet Identity users is still required for manual UX acceptance.
