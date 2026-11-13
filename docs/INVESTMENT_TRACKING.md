# Investment tracking — calculation foundation

Status: calculation module only; not connected to backend persistence or UI.

The current backend portfolio is Fund-scoped and records quantities and manual
valuations. It does not yet provide personal portfolios, wallet holdings or an
investment transaction ledger. Do not infer acquisition cost from a valuation.

`src/frontend/src/lib/portfolio/investment.js` replays confirmed events in supplied
chronological order (ties preserve supplied order). Each invocation represents
one investment, one asset and one settlement currency with fixed atomic units.
All quantities and amounts are BigInt; no floating-point conversion is allowed.
The module does not mutate Portfolio balances and is not an authorization boundary.

Purchases capitalize settlement-currency fees. Sales release pooled weighted
average cost across accounts, rounding down in atomic units; final exit releases
all remaining cost. Income, expenses and transfer fees affect realized profit.
Transfer fees here are paid in settlement currency. Asset-denominated fees,
in-kind rewards, swaps, FX, reversals and imported opening holdings require explicit
future event models; callers must not silently map them to these events.

Identity: total = gross sale proceeds + income + current value - purchase outlay
(including purchase fees) - other expenses. Missing valuation means unknown;
explicit zero means zero value. Valuation must match quantity and must not predate
the latest event. Unknown or partially valued totals must not display as complete.

## Next integration

- Add backend-owned investment IDs, asset/currency references, immutable confirmed
  events, request-id deduplication, revision checks and audit corrections.
- Reuse current Fund Portfolio read/write authorization; derive actor/time server-side.
- Use one atomic operation for holding movements and investment events. Existing
  holdings need an explicit opening cost and allocation; never double-count balances.
- Store valuation history, evidence and proposal/execution references. Approval is
  not execution; pending external executions do not affect balances.
- Add Investments to the Fund Portfolio with create, buy, sell, income, expense,
  transfer and valuation forms, transaction history and per-currency summaries.
- Add personal ownership only with a backend ownership model. No implicit fundId=0.

Validation: `node --test test/investment.test.mjs test/portfolio-amount.test.mjs`.
