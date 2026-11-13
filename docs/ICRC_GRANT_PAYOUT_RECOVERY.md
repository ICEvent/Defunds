# ICRC Grant payout recovery (ICRC-1 / ICRC-3)

A non-ICP grant must never submit overlapping `icrc1_transfer` calls. This
implementation writes a durable `#paying(createdAt)` marker **before** the
external ledger await. Normal success or ledger `#Duplicate` records the
receipt and finalizes the Grant. A rejected ledger transfer unlocks the
attempt; an ambiguous throw/upgrade preserves a locked state.

## Operator workflow (controller or council)

1. Call `getIcrcGrantPayoutState(grantId)` with an authorized identity. Record
   the ledger canister, grant, amount, destination, timestamp and unique
   memo `grant:<grantId>` from the original attempt.
2. For `#paid(blockIndex)`, ask the grant applicant to call `claimGrant`
   again; it returns the original receipt and finishes local bookkeeping.
3. For `#paying` or `#reconciliationRequired`, inspect the **canonical**
   ICRC-3 transfer history of the configured ledger. If the payment exists,
   call `reconcileIcrcGrantPayout(grantId, blockIndex)`. This is a guarded
   update, not an unchecked declaration: the canister queries that exact
   ledger (including its archived block callbacks), verifies `1xfer` /
   `xfer`, exact treasury/source owner, recipient owner, amount, memo,
   original timestamp and no spender, and compares the live payout attempt
   state again after all awaits. On success it stores the receipt and
   finishes the Grant transition.
4. A missing block **is not proof of no payment**. If no canonical payment
   can be proved, the canister deliberately refuses to clear the locked
   attempt. Do not reset the lock or resubmit a fresh timestamp. Obtain
   independent evidence, validate the ledger's archives and transaction
   deduplication policy, then follow an audited manual recovery procedure.
5. Never enter an arbitrary `blockIndex` as proof of payment, never try to
   'reinstall to reset' the canister and never clear stable payout state.

`#paying` can survive an upgrade if the ledger request outcome was never
returned. `#reconciliationRequired` is a safety state, not an instruction to
retry. The ICRC-3 ledger method must be supported by the currency's ledger;
unsupported/unavailable ledgers fail closed. Reconciliation by negative proof
(no-payment) remains intentionally unsupported pending a safe protocol.

## Compile and regression

```bash
CACHE="$(dfx cache show)"
"$CACHE/moc" -r --package base "$CACHE/base" test/Icrc3PayoutProof.test.mo
dfx build backend --check
```

Test against an isolated ICRC ledger fixture before release:

- Concurrent applicant requests: exactly one transfer, second returns 'in flight'.
- Successful attempt, duplicate ledger response, timeout and upgraded canister
  must not initiate a second on-chain payment.
- A different recipient, amount, memo, timestamp, sender or `2xfer` block
  must fail positive reconciliation.
- A genuine archived `1xfer` payment should be recoverable.
- An unknown block or inaccessible ledger must retain the lock.
- Existing ICP treasury payout path must remain unchanged.

**Deployment gate:** compare old/new stable types and run a funded mock ledger
before upgrading a mainnet financial canister. This PR has not passed that
deployment gate merely because source files were committed.
