# Defunds Personal Loan — currency catalog and cryptocurrency precision

**Status:** PR #12 (Draft), local/off-chain ledger only. No on-chain token transfers.
**Base:** merged Personal Loan PR #11 on `main`.

## Principles

- Each Internet Identity principal can maintain up to **40 custom currencies** by code, symbol, type (`fiat` / `crypto`) and decimal places (`0..18`). Crypto additionally requires an explicit network and native/ERC-20/ICRC asset standard; ERC-20 requires a contract address and ICRC requires a ledger canister ID.
- **Built-ins**: CAD, USD, EUR, GBP, CNY (2 decimals); BTC (8), ETH (18), ICP (8), ckBTC (8), ckETH (18). Built-in definitions are not editable, avoiding mismatched BTC/ETH units.
- The currency definition **and blockchain asset identity** (network, standard, contract or ledger ID) are snapshotted when a loan is proposed. Both parties see the same immutable terms, even if the creator later edits/deletes their catalog item.
- The loan's currency cannot be changed. Additional borrowing, repayments, reversals and closure all operate in the loan's single unit. No FX exchange, mixed-asset repayment or automatic spot prices.
- Amounts are stored as exact **nonnegative `Nat` minor units**, and parsed/formatted as `BigInt` in JS. Example: 1 satoshi is 1 minor unit (0.00000001 BTC); 1 wei is 1 minor unit (0.000000000000000001 ETH). No `Number` conversion of financial amounts.
- Legacy field names like `Loan.originalAmountCents`, `Entry.amountCents`, and `Balance.outstandingCents` are preserved for **stable-data and Candid compatibility**. For non-fiat assets they represent integer *minor units*, not literal cents.

## APIs and permissions

```text
getMyCurrencies() : Result<[CurrencyDefinition], Text>
getMyAssetReferences() : Result<[(Code, AssetReference)], Text>
upsertMyCurrencyWithReference(CurrencyDefinition, AssetReference) : Result<(), Text>
deleteMyCurrency(code : Text) : Result<(), Text>
getLoanCurrencyDefinition(loanId : Nat) : Result<CurrencyDefinition, Text>
getLoanAssetReference(loanId : Nat) : Result<AssetReference, Text>
createPersonalLoanWithReference(borrower, lender, amountMinor, definition, reference, dueAt, note, requestId)
// original createPersonalLoan, createPersonalLoanWithCurrency,
// createPersonalLoanWithAsset and upsertMyCurrency retained for legacy clients
```

- Built-in currency metadata is available to anyone through the public UI presets, but user-created catalog records are returned **only** to the authenticated owner.
- `getLoanCurrencyDefinition` enforces exactly the same participant ACL as `getLoanCurrency`; outsiders receive an error.
- Creation requires an exact definition matching a preset, or an exact current definition in the creator's personal catalog. Updating an existing custom code affects only **new proposals**.
- The legacy `createPersonalLoan` (CAD) and `createPersonalLoanWithCurrency` (five fiat currencies, 2 decimals) remain unchanged for existing clients.
- Existing Loan, Entry, Balance, Event **and CurrencyDefinition** types remain stable. Currency metadata uses existing `loanCurrencyDefinitions` / `userCurrencies` and two new **separately persistent** mappings: `loanAssetReferences` / `userAssetReferences`. Existing crypto loan snapshots without an explicit identity are flagged as legacy/unverified; never infer a custom contract from ticker.
- Legacy loans without a snapshot still resolve CAD/2 or their previously persisted fiat currency/2.

## Asset scope and risks

The chosen code and decimals are metadata for an **off-chain, jointly acknowledged debt ledger**, not verified wallet assets. **For any future on-chain ICRC integration, query the actual token ledger's `icrc1_decimals` and `icrc1_metadata` at runtime and store the ledger canister ID/network; do not trust a manually entered ticker or static preset to authorize transfers.** DFINITY's ledger documentation explicitly recommends runtime querying because token precision can change. `USDT` and `USDC`, for example, may have different decimals and contract addresses depending on blockchain. The UI intentionally asks users to verify network/contract before adding a custom code; a ticker alone is not enough to uniquely identify an instrument.

- Transfers, custody, digital signatures, exchange rates, oracle prices, proof of settlement, token approval, on-chain transaction verification, and real-time market valuation are **not implemented**.
- `On-chain transfer (self-reported)` is only a human-entered method; it is not blockchain evidence. Do not include private keys, seed phrases or bank secrets in loan notes.
- The original borrower/lender permission and two-party acknowledgement remain required, regardless of fiat vs crypto.

## Browser acceptance (two independent local II accounts)

1. Log in as user A and user B, using different browser profiles and the same isolated local canister. Verify their principals are different.
2. In **My currencies → Manage currencies**, create `SOL` (crypto, 9 decimals, symbol SOL, standard **Native**, network `solana:mainnet`, no contract). Check it appears in A's Currency list; B should not see it in *their own* list or asset references.
3. In A's New Personal Loan form, select `BTC`, input `0.00000001`, propose. B accepts terms, declares funding as `On-chain transfer (self-reported)`, and A confirms. Both see **BTC ₿0.00000001**. Reject `0.000000001` (9 decimals).
4. Create a separate `ETH` loan for `0.000000000000000001` and verify both accounts see the full amount (1 wei). No scientific notation or rounding.
5. Create a SOL loan for `0.000000001`, verify B sees `solana:mainnet` and **Native**, then change SOL catalog precision to 6 decimals. The **existing** SOL loan must still display 9 decimals and the exact amount to user B, while a **new** SOL proposal uses 6 decimals.
6. Remove SOL from A's catalog; prior SOL loans must remain visible and retain their currency definition. Only the SOL option for future proposals disappears.
7. On the BTC or ETH loan, request additional borrowing and repayment in the same precision, and check that only mutually confirmed transactions affect the balance. **Repay full outstanding** must use the exact current smallest unit.
8. Verify 2026 fiat loans still show 2 decimal places, the original status transitions and audit events, and the exact same values following canister upgrade.
9. Verify a third identity cannot read either participant's loans or definitions, and cannot read or modify their custom catalog.

## Blockchain identity rules

| Kind | Network | Asset standard | Identifier |
|---|---|---|---|
| CAD / fiat | none | fiat | none |
| BTC native | `bitcoin:mainnet` | native | no token contract |
| ETH native | `eip155:1` | native | no token contract |
| SOL native | `solana:mainnet` | native | no token contract |
| ERC-20 Ethereum USDC | `eip155:1` | erc20 | `0xA0b86991c6218b36c1d19D4a2e9Eb0cE3606eB48` |
| ICP | `ic:mainnet` | icrc | `ryjl3-tyaaa-aaaaa-aaaba-cai` |
| ckBTC | `ic:mainnet` | icrc | `mxzaz-hqaaa-aaaar-qaada-cai` |
| ckETH | `ic:mainnet` | icrc | `ss2fx-dyaaa-aaaar-qacoq-cai` |

ERC-20 contracts are **42-character Ethereum hexadecimal addresses**, with a required EVM chain identifier. `eip155:1` and `eip155:137` are different networks even with the same token symbol/address. Address format validation does **not** prove the contract exists, is trusted, supports ERC-20, or has the stated decimals. ICRC asset identities use **ledger Principal IDs**, never user wallet addresses. Built-in references are fixed and not editable.

**Custom ticker limitation:** the current personal catalog uses one definition per user/ticker. To maintain different USDT contracts in the same account, create distinct user-defined aliases (for example `USDTETH` and `USDTPOLY`) and record the real network and address for each. A future multi-chain asset catalog can key directly on network + contract instead.

The existing legacy `createPersonalLoanWithAsset` still accepts built-in/native assets. New **custom crypto loan proposals** must use `createPersonalLoanWithReference` with an exact match to a reference saved by `upsertMyCurrencyWithReference`. Legacy crypto loans created before reference support are readable but marked **unverified** if the original snapshot lacks identity. An idempotent replay of the original loan request is safe after editing/removing a catalog entry.

### EVM contract acceptance test

1. Account A adds custom `USDC`, crypto, 6 decimals, standard **ERC-20**, network `eip155:1`, contract `0xA0b86991c6218b36c1d19D4a2e9Eb0cE3606eB48`. Verify the network/address are displayed in My currencies.
2. A creates a USDC loan. Before accepting, B verifies **USDC, Ethereum network and full contract address** under Loan detail. A third identity cannot query that loan's reference.
3. Try saving an ERC-20 without a contract, with a short address, or with an invalid chain ID; the form shows an inline error and nothing is saved.
4. Change A's catalog USDC network to `eip155:137`, keeping an address. Confirm the existing Ethereum USDC loan still shows `eip155:1` and the original contract.
5. Delete the custom USDC catalog item. The existing Loan identity remains immutable across refresh and canister upgrade.

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
