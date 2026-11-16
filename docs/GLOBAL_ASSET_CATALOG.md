# Global asset catalog and optional provider imports

The Assets navigation item opens `/assets`. Fund Portfolio → Manage holdings → Global asset catalog opens the combined global and Fund custom catalog.

Users with Portfolio write access can create Fund custom crypto definitions manually, or optionally look up a CoinGecko coin ID and review each supported network entry before saving. Custom entries are only returned to members who can read that Fund. Canister controllers can maintain public definitions; provider results never automatically become reviewed assets. A custom definition can be copied into the global catalog by a controller after review; existing holdings keep their original identity.

Definitions record asset family, name, symbol, network, standard, contract/mint/ledger, decimals, source, reviewed/enabled status, and revision. Identity is network + contract, or network + native. EVM addresses normalize to lowercase; case-sensitive mint identifiers remain intact. Native coins do not have a contract. Network, contract, standard, grouping and precision are immutable. Edits use revision checks. Global catalog entries and Fund custom entries use separate persistent fields without changing existing Portfolio record layouts.

Supported initial networks: Ethereum, Base, Arbitrum One, ICP, Solana and Bitcoin. Precision is limited to 0–18 by the existing Portfolio model. Other asset categories retain their existing Fund definition workflow. Network-specific balances remain separate even when entries share an asset family.

“Add to Fund” references a catalog token through `catalog:<id>` in the Fund currency configuration. The operation is idempotent and reuses an existing Fund definition when a private and public entry identify the same network token. Conflicting precision is rejected. Existing names/precision are snapshots; metadata edits do not silently rewrite recorded holdings. Imported definitions describe manually recorded holdings. Contract metadata alone never enables ledger transfers, address balance discovery, or proposal execution. Those require separately validated adapters. A disabled catalog entry prevents new catalog imports; existing Fund configuration and history remain independent.

## CoinGecko is optional

The public `/assets` page automatically reads `/coins/list?include_platform=true` without requiring catalog write permissions, then provides local search by name, symbol or contract and 20-row pagination. Fund views can opt in with “Browse CoinGecko assets”. Successful public lists are cached in memory for one hour and concurrent reads share a request. The list is displayed separately from saved definitions; provider failures show an explicit retryable error without blocking saved definitions or custom entry.

“View networks” fetches `/coins/{id}` on request and caches successful detail responses in memory for one hour. Anonymous users can inspect details; only users with existing write permissions can save entries. Imports use `detail_platforms` for per-network contracts and decimal precision. Unsupported networks, missing precision and native placeholders are skipped instead of guessed. Metadata is saved only after user review. No scheduled synchronization or dependency on CoinGecko is required for custom assets or saved definitions.

Public API access can be rate limited or require a Demo API key. Do not place keys in frontend environment variables. Fetch a JSON response outside the browser, then use “Or import coin JSON”:

```sh
# Set COINGECKO_DEMO_API_KEY in your shell environment if needed.
node scripts/fetch-coingecko-asset.mjs usd-coin /tmp/usdc.json
```

API reference: https://docs.coingecko.com/reference/coins-id

## Validation

- `moc --check --package base <base-path> src/backend/main.mo`
- `moc -r --package base <base-path> test/AssetCatalog.test.mo`
- `node --test test/asset-catalog.test.mjs test/portfolio-locations.test.mjs test/portfolio-amount.test.mjs`
- `node test/asset-catalog-browser.test.mjs` with Playwright installed; optionally set `PORTFOLIO_CHROMIUM`.
- `bash test/portfolio-e2e.sh` with dfx 0.30.1 for production permissions, cross-Fund isolation, imports and populated upgrade persistence.

Regenerate backend Candid declarations using the usual dfx build/generate process before deployment. There is no seed list of assumed live contracts.
