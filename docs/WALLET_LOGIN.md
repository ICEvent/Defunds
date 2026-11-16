# Defunds wallet login (Plug / OISY)

## Scope

The login dialog supports **Internet Identity (II)**, **Plug**, and **OISY**.

- **II** retains existing `AuthClient` delegation and `oneblock.page` derivation origin on mainnet. Local Personal Loan test mode continues to use its configured local II provider.
- **Plug** uses the injected extension (`window.ic.plug`), requires explicit consent for the Defunds backend, governance, ICP ledger and the separately configured Personal Loan canister, and uses the extension's agent and Principal for actor calls.
- **OISY** uses the official ICRC signer flow via `@icp-sdk/signer` (`ICRC-25/27/29/49`) and a `SignerAgent`. It is **experimental until a real OISY wallet and the full Defunds backend call surface have been verified**.

## Identity and account safety

A wallet Principal **is not automatically the same as an II Principal**. Even if the user opens OISY with the same II passkey, a dApp-specific II Principal is generally different from the wallet Principal. Defunds does not silently link, migrate, or grant access between these accounts. Existing loans, funds and permissions remain assigned to their original Principal.

`sessionStorage` records only the selected provider, never keys. A saved II session can be restored; Plug is restored without opening an approval dialog if the extension reports an existing connection; OISY requires a fresh explicit connection after reload.

On logout, Defunds disconnects the active wallet where supported, resets every actor to the anonymous agent, clears selected-provider state, and must not inadvertently reactivate a stale II delegation.

## Known limitations / release gate

1. **OISY and other account-based signers may require ICRC-21 consent messages for each canister update call**. Defunds' custom backend and standalone Personal Loan canister have not yet been confirmed to implement these messages for all authenticated updates. A successful account connection does **not** guarantee that loan creation, proposal creation, fund transfers or governance updates will succeed. Verify wallet approval against each real method before production.
2. The app currently uses legacy `@dfinity/*` AgentJS dependencies and generated actors. `@icp-sdk/signer` uses the newer `@icp-sdk/core`. Verify agent compatibility (including canister queries, signed updates, principal comparisons, root keys, and Candid types), or migrate the generated actor stack, before merging.
3. New npm dependencies have been declared in the frontend workspace. The root `package-lock.json` **must be regenerated with npm install** and committed; `npm ci` is not expected to work until that is complete.
4. Plug requires its browser extension. OISY is suitable for web/mobile but its pop-up must be triggered by a click. Local PocketIC flows need separate wallet signer configuration if testing against local canisters.
5. Existing code paths that independently create their own `AuthClient` or `HttpAgent` must be audited for the active wallet session. Personal Loan has been updated, but the wider app has not received a complete actor audit.

## Verification checklist

- [ ] From repository root: `npm install` and commit `package-lock.json`.
- [ ] `npm ci`, `npm run build`, and any TypeScript/Svelte checks.
- [ ] II login, navigation, logout, reload and derivation-origin regression tests.
- [ ] Plug installed: connect, reject, switch principal, reload, disconnect from extension, logout.
- [ ] Plug missing: show actionable error, never crash.
- [ ] OISY: connect with signer popup, reject, reload, logout, account mismatch, mobile popup behavior.
- [ ] Verify backend, governance, ICRC-1 ledger and Personal Loan reads and writes with each provider.
- [ ] Confirm ICRC-21 support for Defunds, governance, and Personal Loan update endpoints before declaring OISY write support.
- [ ] Confirm a wallet Principal never inherits a different II Principal's funds, loans or group roles.
- [ ] Check concurrent tab/provider switching does not leave signed actors attached to a stale Principal.

Official references:
- https://docs.plugwallet.ooo/developer-guides/connect-to-plug/
- https://docs.internetcomputer.org/guides/digital-assets/wallet-integration/
- https://docs.oisy.com/for-developers/using-oisy-wallet-in-your-icp-dapp
