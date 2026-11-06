# Defunds Personal Loan — Shared Ledger

**Status:** Draft / implementation in progress  
**Version:** 0.1 — 2026-11-05  
**Scope:** personal, two-party, off-chain CAD loans

## Goal
One Loan, Two Parties, One Shared Ledger. A borrower and lender authenticate with Internet Identity and see the same loan, confirmed borrowings, repayments, and outstanding balance. Either party may initiate an additional borrowing or a repayment; the other party must accept. No custody, bank integration, DAO voting, or token transfers in this MVP.

## Definitions
- A **loan** is one continuing debt relationship between a borrower and a lender, with immutable principals and initial terms.
- An **entry** is an append-only debt-changing transaction: initial borrowing, additional borrowing, repayment, or reversal.
- A **pending** entry is not included in the balance. An entry is reflected in the balance **only once confirmed**.
- Monetary amounts are nonnegative integer **CAD cents**; never floating point.
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
- `Loan`: id, borrower, lender, initial CAD cents, due date, 0% rate, status, creator, timestamps, closure requestor.
- `Entry`: id, loanId, kind, integer cents, proposer, effectiveAt, evidence note/method, confirmation status and timestamps. Reversal contains a reference to the original entry.
- `getMyLoans`, `getLoan`, `getLoanEntries`, and `getBalance` enforce participant permissions.
- Use caller-derived actors, not principals passed as claimed approvers.
- Mutations are idempotent through request IDs; state transitions are validated before any persistent update.
- A small-scale v0.1 may store persistent arrays; plan indexes and pagination before scaling.
- Store mutation events for a full audit trail in a later iteration; preserve the complete entry history now.

## Proposed API
```text
createPersonalLoan(borrower, lender, initialAmountCents, dueAt, note)
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
getMyLoans() / getLoan(loanId) / getLoanEntries(loanId) / getBalance(loanId)
```

## Frontend plan
Add **Loans** with **My Borrowings**, **My Lending**, **Invitations** and **Loan Detail**. Loan Detail displays original amount, total borrowed, total repaid, current outstanding, agreement, complete ledger, and separate pending actions. Both users see the same confirmed debt. Pending/unconfirmed items are clearly separated.

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
