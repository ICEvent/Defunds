# Defunds Personal Loan — currency catalog and cryptocurrency precision

**Status:** PR #12 (Draft), local/off-chain ledger only. No on-chain token transfers.
**Base:** merged Personal Loan PR #11 on `main`.

## Principles

- Each Internet Identity principal can maintain up to **40 custom currencies** by code, symbol, type (`fiat` / `crypto`) and decimal places (`0..18`).
- **Built-ins**: CAD, USD, EUR, GBP, CNY (2 decimals); BTC (8), ETH (18), ICP (8), ckBTC (8), ckETH (18). Built-in definitions are not editable, avoiding mismatched BTC/ETH units.
- A currency definition is snapshotted when a loan is proposed. Both parties see the **same immutable code, kind, symbol and decimals** for that loan, even if the creator later edits/deletes their catalog item.
- The loan's currency cannot be changed. Additional borrowing, repayments, reversals and closure all operate in the loan's single unit. No FX exchange, mixed-asset repayment or automatic spot prices.
- Amounts are stored as exact **nonnegative `Nat` minor units**, and parsed/formatted as `BigInt` in JS. Example: 1 satoshi is 1 minor unit (0.00000001 BTC); 1 wei is 1 minor unit (0.000000000000000001 ETH). No `Number` conversion of financial amounts.
- Legacy field names like `Loan.originalAmountCents`, `Entry.amountCents`, and `Balance.outstandingCents` are preserved for **stable-data and Candid compatibility**. For non-fiat assets they represent integer *minor units*, not literal cents.

## APIs and permissions

```text
getMyCurrencies() : Result<[CurrencyDefinition], Text>
upsertMyCurrency(CurrencyDefinition) : Result<(), Text>
deleteMyCurrency(code : Text) : Result<(), Text>
getLoanCurrencyDefinition(loanId : Nat) : Result<CurrencyDefinition, Text>
createPersonalLoanWithAsset(borrower, lender, amountMinor, definition, dueAt, note, requestId)
```

- Built-in currency metadata is available to anyone through the public UI presets, but user-created catalog records are returned **only** to the authenticated owner.
- `getLoanCurrencyDefinition` enforces exactly the same participant ACL as `getLoanCurrency`; outsiders receive an error.
- Creation requires an exact definition matching a preset, or an exact current definition in the creator's personal catalog. Updating an existing custom code affects only **new proposals**.
- The legacy `createPersonalLoan` (CAD) and `createPersonalLoanWithCurrency` (five fiat currencies, 2 decimals) remain unchanged for existing clients.
- Existing Loan, Entry, Balance and Event types remain stable, with two new **separately persistent** mappings: `loanCurrencyDefinitions` and `userCurrencies`.
- Legacy loans without a snapshot still resolve CAD/2 or their previously persisted fiat currency/2.

## Asset scope and risks

The chosen code and decimals are metadata for an **off-chain, jointly acknowledged debt ledger**, not verified wallet assets. `USDT` and `USDC`, for example, may have different decimals and contract addresses depending on blockchain. The UI intentionally asks users to verify network/contract before adding a custom code; a ticker alone is not enough to uniquely identify an instrument.

- Transfers, custody, digital signatures, exchange rates, oracle prices, proof of settlement, token approval, on-chain transaction verification, and real-time market valuation are **not implemented**.
- `On-chain transfer (self-reported)` is only a human-entered method; it is not blockchain evidence. Do not include private keys, seed phrases or bank secrets in loan notes.
- The original borrower/lender permission and two-party acknowledgement remain required, regardless of fiat vs crypto.

## Browser acceptance (two independent local II accounts)

1. Log in as user A and user B, using different browser profiles and the same isolated local canister. Verify their principals are different.
2. In **My currencies → Manage currencies**, create `SOL` (crypto, 9 decimals, symbol SOL). Check it appears in A's Currency list; B should not see it in *their own* list.
3. In A's New Personal Loan form, select `BTC`, input `0.00000001`, propose. B accepts terms, declares funding as `On-chain transfer (self-reported)`, and A confirms. Both see **BTC ₿0.00000001**. Reject `0.000000001` (9 decimals).
4. Create a separate `ETH` loan for `0.000000000000000001` and verify both accounts see the full amount (1 wei). No scientific notation or rounding.
5. Create a SOL loan for `0.000000001`, then change SOL catalog precision to 6 decimals. The **existing** SOL loan must still display 9 decimals and the exact amount to user B, while a **new** SOL proposal uses 6 decimals.
6. Remove SOL from A's catalog; prior SOL loans must remain visible and retain their currency definition. Only the SOL option for future proposals disappears.
7. On the BTC or ETH loan, request additional borrowing and repayment in the same precision, and check that only mutually confirmed transactions affect the balance. **Repay full outstanding** must use the exact current smallest unit.
8. Verify 2026 fiat loans still show 2 decimal places, the original status transitions and audit events, and the exact same values following canister upgrade.
9. Verify a third identity cannot read either participant's loans or definitions, and cannot read or modify their custom catalog.

## CI gates

- Node unit tests: `node --test test/personal-loan-currency.test.mjs`; existing amount/UI/date tests remain.
- Motoko build + unit fixtures, local 3-principal canister E2E including 1 satoshi and 1 wei, legacy stable upgrade, Svelte compile, frontend build, local II preview.
- **Separate browser E2E with two real II sessions is still needed before merging/deploying.**

### Running locally

Use a new worktree to avoid the previous WSL2 `/instances` 400 state; do not delete historical `.dfx` data:

```bash
cd ~/projects/Defunds     # adjust capitalization to your actual repository
git fetch origin
git worktree add --detach ../defunds-currency-qa origin/feat/personal-loan-currency-catalog-crypto-20261108
cd ../defunds-currency-qa
PERSONAL_LOAN_LOCAL_PORT=4955 bash scripts/personal-loan-local.sh
```

Page: `http://127.0.0.1:5173/loans`. This is local-only, requires the isolated PocketIC and an independent local Internet Identity, not a mainnet wallet or production principals.
