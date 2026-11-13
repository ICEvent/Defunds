# Fund investment tracking

Status: implementation on PR #17; not deployed. Manual analytical journal, using
existing Fund Portfolio permissions, asset definitions, currency configuration and
locations. Personal ownership and automated execution remain future work.

## User flow

Open Funds → select a Fund → Investments (below Asset locations & holdings).
Configure a Fund currency and at least one location first. Create an investment,
select its asset and settlement currency, then record externally confirmed buys,
sales, income, expenses, movements and total holding valuations. Existing assets
are referenced as definitions; their Portfolio quantities are never duplicated.

This journal does not send transfers or mutate Portfolio holdings, treasury
balances, proposals or donation history. Until execution integration is available,
users maintain their Portfolio balances separately. Investment P/L must never be
added to Portfolio asset totals as another asset balance.

## Calculation contract

- One asset and settlement currency per investment, with immutable precision and
  symbol snapshots. Amounts are atomic natural numbers; P/L is signed integer.
- Buy fees enter cost. Sales release pooled weighted average cost across investment
  locations, rounding down in atomic units. Final exit releases all residual cost.
- Income increases realized P/L. Expenses and sale/transfer fees reduce it. All
  fees here are in settlement currency; in-kind fees/rewards and swaps are not supported.
- Internal location movement preserves total quantity and cost. Its fee reduces
  realized P/L. It does not independently change a manually estimated market value.
- Buy/sell invalidate the holding valuation. Income and expenses preserve it.
- Unrealized = current value − remaining cost. Total = realized + unrealized.
- Identity: total = gross sale proceeds + income + current value − purchase outlay
  (including buy fees) − other expenses. Missing estimates remain unknown; explicit
  zero is a valid complete loss. Empty holdings have zero current value.
- The UI shows valuation coverage and per-investment settlement denominations.
  No currency conversion or combined cross-currency total is implied.

## Persistence and APIs

`investment/types.mo` and `investment/lib.mo` implement pure state transitions.
`main.mo` adds a persistent field without changing existing stable records.

- `listFundInvestments(fundId, afterId, limit)`
- `listFundInvestmentHistory(fundId, investmentId, afterEventId, limit)`
- `writeFundInvestment(fundId, requestId, operation)`

Read/write authority reuses Portfolio membership/managers policy. Canonical asset
and currency metadata is validated at creation. New buys/transfers require enabled
Fund destination locations; sells and outgoing transfers can leave disabled ones.
Each confirmed write records server timestamp and caller. Revisions prevent stale
writes. Receipts bind Fund + caller + request ID to exact input; retries return the
original response even after later writes or currency/location changes. No await
occurs during validation/commit. Limits: 100 investments and 2,000 events per Fund;
list/history pages are limited to 100. Valuation history and notes are retained.

## Validation

- `node --test test/investment.test.mjs test/portfolio-amount.test.mjs test/portfolio-locations.test.mjs`
- SDK `moc -r --package base <SDK/base> test/Investments.test.mo`
- Backend WASM/Candid generation, Svelte compilation and frontend production build.
- Stable-type compatibility against current main (not a populated upgrade test).
- `bash test/portfolio-e2e.sh`: real actor permissions, metadata, retry, stale writes,
  cross-Fund isolation, unchanged Portfolio balances and populated upgrade persistence.
- `node test/investment-browser.test.mjs`: actual component with transport fixture;
  create, partial exit, valuation, transfer, income, response-loss retry, history,
  member read-only view, desktop/mobile screenshots and overflow checks.

Canister E2E and browser execution could not start locally because the environment
rejects Unix socket creation. They run in the Portfolio CI workflow; do not label
those checks passed until their results are available.

## Remaining boundaries

Records use current recording time, not a backdated trade date. Audit-preserving
correction/reversal, proposal/execution links, evidence attachments, allocation of
existing positions/opening costs, FX, automatic prices, returns adjusted for cash
flow timing and personal portfolios are not implemented. Verify manual entries
before saving. The first version deliberately exposes no destructive history edit.
