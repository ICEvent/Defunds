# Location network and read-only chain snapshots

## Scope and asset-definition ownership

Asset definitions are implemented in the separate conversation:
https://chatgpt.com/g/g-p-693451325bf48191a2c57a452c76af3f-defunds/c/6af9b5f0-b108-83e8-8466-f5412cbf77c1

This change owns only location identity and read-only address observations. It does not create a second registry, automatically create definitions/holdings, or infer Fund ownership from a whole-wallet balance. That conversation's exact implementation contract was not accessible during this work. No binding to an unverified interface is implemented.

Snapshots retain `reference: {network, standard, address}` in the shape already used by the repository's asset-reference code. `address` there means the asset's contract (empty for a native coin), not the holder's location address. Native coin identity is network + native; EVM token identity is network + contract, with an NFT instance ID when present. Tickers are display metadata, never identity. A future adapter can resolve these to the authoritative asset-definition ID after that interface is available. No automatic symbol matching.

## Location identity and compatibility

- New blockchain locations use `Kind.chainAccount {network; address}`. Network is a separate required field; EVM identifiers use canonical `eip155:<chainId>`.
- The same address on different networks creates distinct locations. EVM addresses are lowercased for deduplication on every EVM chain, not just supported discovery chains.
- Existing `Kind.blockchain Text` and IC `Kind.wallet` records remain unchanged, including receipts and history. Old mixed strings are not parsed heuristically.
- `setLocationNetwork` requires the existing portfolio write permission, Fund-scoped location lookup, expected revision and a unique network/address. Locations already bound to holdings cannot be reassigned to another chain/address; create a new location and record the relevant movements instead.
- IC wallet rows show Internet Computer (`ic:mainnet`); automatic ICP asset enumeration is not part of this adapter. Other networks can be saved for manual tracking.

## Click-only discovery

Supported initial networks: Ethereum, Base, Optimism via their public Blockscout v2 API. The browser requests `/api/v2/addresses/{address}` and paginated `/tokens`, fetching indexed native/ ERC-20 / NFT balances. Address and network remain visible above the button. Requests omit cookies and referrers and use fixed provider origins. Clicking discloses that public address to Blockscout; there are no background provider calls or signing prompts.

Snapshots are session-only, show query time and explorer source, and never change recorded Fund quantities or Portfolio totals. All quantities remain integer minor units with explicit decimals. Unknown decimals remain base units. Native failures, token page failures, unknown data and rate limits are never converted to zero. A 20-page cap and a 45-second timeout bound each refresh. Partial coverage is labeled; a completely failed refresh retains and marks the previous snapshot as stale. Context changes and component destruction abort pending work.

The index may lag. A successful snapshot means the returned indexed pages were read, not proof of exhaustive holdings at one common block. Unindexed tokens, DeFi/lending/staking positions, bridge claims and other networks are outside coverage. Token metadata is untrusted plain text. No token URLs, images, approvals or transfers are opened automatically.

API source: https://github.com/blockscout/blockscout-api-v2-swagger/blob/main/swagger.yaml

## Validation

- `node --test test/chain-assets.test.mjs test/portfolio-amount.test.mjs test/portfolio-locations.test.mjs`
- `moc -r --package base <SDK-base> test/PortfolioLocations.test.mo`
- Backend compile and old-main → new stable-signature compatibility check.
- Actual component browser regression: `node test/location-chain-browser.test.mjs` (mocked provider), plus the updated asset-workflow regression. These run in Portfolio CI after publication.
- This workspace blocks Chromium process sockets, so browser execution could not be completed locally. The live Blockscout probe also timed out; endpoint/CORS availability still needs verification in the deployed browser.

Backend variants require regenerating Candid declarations and upgrading the backend before deploying this frontend.
