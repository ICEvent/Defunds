# Personal Loan: build the Defunds frontend for ICP mainnet

When DFX builds the frontend with `dfx build --ic` (or `dfx build --network ic`), its build process sets `DFX_NETWORK=ic`. The Vite config now resolves

`VITE_PERSONAL_LOAN_CANISTER_ID <- <repo root>/canister_ids.json["personal_loan"]` (flat), or `["personal_loan"]["ic"]` (nested)

**without manually exporting the variable**. This happens at *build time*, not at runtime. It supports either of these local `canister_ids.json` shapes:

```json
{
  "personal_loan": "ACTUAL-DEPLOYED-LOAN-CANISTER-PRINCIPAL"
}
```

Or the standard network-qualified form:

```json
{
  "personal_loan": { "ic": "ACTUAL-DEPLOYED-LOAN-CANISTER-PRINCIPAL" }
}
```

The values above are placeholders, not real canister IDs. Always use your own actual deployed ID from `dfx canister id personal_loan --network ic` and verify `dfx canister status personal_loan --network ic`. The project may keep `canister_ids.json` untracked or locally modified; this build feature reads but never rewrites it.

Verify the local record:

```bash
cd ~/projects/Defund
jq -r 'if (.personal_loan | type) == "string" then .personal_loan else .personal_loan.ic // "MISSING" end' canister_ids.json
dfx canister id personal_loan --network ic
dfx canister status personal_loan --network ic
dfx build --ic frontend
```

You should see `[Defunds] Mainnet Personal Loan ID loaded from canister_ids.json:` in build output. If no local ID is present, Vite prints a warning and `/loans` remains deliberately disconnected. A build does **not** create or deploy a canister.

Priority: **an existing `VITE_PERSONAL_LOAN_CANISTER_ID` environment variable** overrides the file (also allowing the isolated local test script to inject its own ID); absent that, the file is read **only** if `DFX_NETWORK=ic`. Local and test builds do not silently connect to a production Personal Loan canister.

This only supplies the canister ID. `VITE_PERSONAL_LOAN_HOST` continues to default to `https://ic0.app`. Internet Identity derivation-origin authorization and actual backend deployment remain separate requirements.

The general frontend prebuild hook runs `dfx generate` for all canisters. If that fails because a DID is missing, generate the required declarations separately; this new ID resolver does not replace `dfx generate` or deploy any Canister.
