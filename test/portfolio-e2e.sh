#!/usr/bin/env bash
# Local-only integration test. Test fixture bypasses only Fund creation eligibility;
# every Portfolio operation executes the unmodified production actor after upgrade.
set -euo pipefail
export DFX_WARNING=-mainnet_plaintext_identity
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$ROOT"
TASK_TMP="$(mktemp -d)"
FIXTURE_CANISTER="portfolio-e2e"
cleanup() { if [[ -f "$TASK_TMP/dfx.json" ]]; then (cd "$TASK_TMP" && dfx stop >/dev/null 2>&1) || true; fi; rm -rf "$TASK_TMP"; }
trap cleanup EXIT
for role in owner member outsider; do
  dfx identity new "portfolio-test-$role" --storage-mode plaintext >/dev/null 2>&1 || true
done
OWNER="$(dfx identity get-principal --identity portfolio-test-owner)"
MEMBER="$(dfx identity get-principal --identity portfolio-test-member)"
OUTSIDER="$(dfx identity get-principal --identity portfolio-test-outsider)"
# A separate project and state directory keep this from resetting any developer replica.
cp -R src/backend "$TASK_TMP/backend"
python3 - "$TASK_TMP" <<'PY'
import json, pathlib, sys
root = pathlib.Path(sys.argv[1])
p = root / 'backend/main.mo'
s = p.read_text()
needle = 'persistent actor Defunds{'
assert s.count(needle) == 1
s = s.replace(needle, needle + '''
  // Generated test fixture only; removed by upgrade before exercising Portfolio.
  public shared ({ caller }) func portfolioTestCreateFund() : async Nat {
    groups.createGroupFund(caller, "Portfolio test", "Local fixture", true, #ICP).id
  };
''')
p.write_text(s)
(root / 'dfx.json').write_text(json.dumps({
 'canisters': {'portfolio-e2e': {'type':'motoko','main':'backend/main.mo','args':'--enhanced-orthogonal-persistence'}},
 'networks': {'local': {'bind':'127.0.0.1:4957','type':'ephemeral'}}, 'version': 1
}))
PY
CACHE="$(dfx cache show)"
# Compile production source independently. No test-only endpoint in this WASM.
"$CACHE/moc" --enhanced-orthogonal-persistence --package base "$CACHE/base" -o "$TASK_TMP/production.wasm" src/backend/main.mo
# dfx needs the current production Candid for all post-upgrade calls.
"$CACHE/moc" --idl --enhanced-orthogonal-persistence --package base "$CACHE/base" -o "$TASK_TMP/production.wasm" src/backend/main.mo
cd "$TASK_TMP"
dfx start --clean --background
dfx deploy "$FIXTURE_CANISTER" --identity portfolio-test-owner
call() { local who="$1" method="$2" args="$3"; dfx canister call "$FIXTURE_CANISTER" "$method" "$args" --network local --identity "$who"; }
ok() { if ! grep -Eq '(^|[[:space:]])ok([[:space:]]|=|\})' <<< "$1"; then echo "Expected ok: $1" >&2; exit 1; fi; }
err() { if ! grep -Eq '(^|[[:space:]])err([[:space:]]|=|\})' <<< "$1"; then echo "Expected err: $1" >&2; exit 1; fi; }
contains() { if ! grep -Fq "$2" <<< "${1//_/}"; then echo "Missing '$2' in: $1" >&2; exit 1; fi; }
call portfolio-test-owner portfolioTestCreateFund '()' >/dev/null
call portfolio-test-outsider portfolioTestCreateFund '()' >/dev/null
# Preserve fixture-created groups through the real upgrade hooks.
dfx canister install "$FIXTURE_CANISTER" --mode upgrade --wasm-memory-persistence keep --upgrade-unchanged --wasm "$TASK_TMP/production.wasm" --network local --identity portfolio-test-owner
cp "$TASK_TMP/production.did" "$TASK_TMP/.dfx/local/canisters/$FIXTURE_CANISTER/$FIXTURE_CANISTER.did"
ok "$(call portfolio-test-owner addGroupMember "(1, \"Observer\", principal \"$MEMBER\", 0)")"
CREATE='(1, "create-asset", variant { create = record { name="ETH"; category="crypto"; unit="ETH"; decimals=2:nat8; quantity=200; source=null; note="opening" } })'
RESULT="$(call portfolio-test-owner writeFundPortfolio "$CREATE")"; ok "$RESULT"; contains "$RESULT" 'quantity = 200'
ok "$(call portfolio-test-owner writeFundPortfolio "$CREATE")" # same request, one asset/event
READ='(1, 0, 100, false)'
ok "$(call portfolio-test-member listFundPortfolioAssets "$READ")" # zero voting power
err "$(call portfolio-test-outsider listFundPortfolioAssets "$READ")" # even public Fund
err "$(call anonymous listFundPortfolioAssets "$READ")"
CHANGE='(1, "increase", variant { change = record {assetId=1; expectedRevision=1; change=variant {increase=100}; note="add"} })'
err "$(call portfolio-test-member writeFundPortfolio "$CHANGE")"
ok "$(call portfolio-test-owner setFundPortfolioManager "(1, principal \"$MEMBER\", true)")"
RESULT="$(call portfolio-test-member writeFundPortfolio "$CHANGE")"; ok "$RESULT"; contains "$RESULT" 'quantity = 300'
ok "$(call portfolio-test-member writeFundPortfolio "$CHANGE")" # no duplicate increase
err "$(call portfolio-test-owner writeFundPortfolio '(1, "stale", variant {change=record {assetId=1;expectedRevision=1;change=variant {decrease=50};note=""}})')"
err "$(call portfolio-test-outsider writeFundPortfolio '(2, "cross-fund", variant {change=record {assetId=1;expectedRevision=2;change=variant {decrease=50};note=""}})')"
RESULT="$(call portfolio-test-owner writeFundPortfolio '(1, "sell", variant {change=record {assetId=1;expectedRevision=2;change=variant {decrease=50};note="sell"}})')"; ok "$RESULT"; contains "$RESULT" 'quantity = 250'
err "$(call portfolio-test-owner writeFundPortfolio '(1, "overdraw", variant {change=record {assetId=1;expectedRevision=3;change=variant {decrease=251};note=""}})')"
ok "$(call portfolio-test-owner writeFundPortfolio '(1, "value", variant {change=record {assetId=1;expectedRevision=3;change=variant {valuation=record {amount=720000;currency="USD";decimals=2:nat8}};note="value"}})')"
# Upgrade populated Portfolio: assets, valuations, grants, receipts and histories persist.
BEFORE="$(call portfolio-test-owner listFundPortfolioAssets "$READ")"
HISTORY="$(call portfolio-test-owner listFundPortfolioHistory '(1,1,0,100)')"
dfx canister install "$FIXTURE_CANISTER" --mode upgrade --wasm-memory-persistence keep --upgrade-unchanged --wasm "$TASK_TMP/production.wasm" --network local --identity portfolio-test-owner
AFTER="$(call portfolio-test-owner listFundPortfolioAssets "$READ")"
[[ "$BEFORE" == "$AFTER" ]] || { echo 'Assets changed across upgrade' >&2; exit 1; }
[[ "$HISTORY" == "$(call portfolio-test-owner listFundPortfolioHistory '(1,1,0,100)')" ]] || { echo 'History changed across upgrade' >&2; exit 1; }
MANAGERS="$(call portfolio-test-owner getFundPortfolioManagers '(1)')"; ok "$MANAGERS"; contains "$MANAGERS" "$MEMBER"
ok "$(call portfolio-test-owner writeFundPortfolio "$CREATE")" # receipt persisted; no extra event
[[ "$HISTORY" == "$(call portfolio-test-owner listFundPortfolioHistory '(1,1,0,100)')" ]] || { echo 'Retry appended duplicate history' >&2; exit 1; }
ok "$(call portfolio-test-owner removeGroupMember "(1, principal \"$MEMBER\")")"
err "$(call portfolio-test-member listFundPortfolioAssets "$READ")"
ok "$(call portfolio-test-owner addGroupMember "(1, \"Observer\", principal \"$MEMBER\", 0)")"
err "$(call portfolio-test-member writeFundPortfolio '(1, "removed-manager", variant {change=record {assetId=1;expectedRevision=4;change=variant {increase=1};note=""}})')"
ok "$(call portfolio-test-owner writeFundPortfolio '(1, "reverse", variant {change=record {assetId=1;expectedRevision=4;change=variant {reverse=3};note="correct sale"}})')"
err "$(call portfolio-test-owner writeFundPortfolio '(1, "reverse-again", variant {change=record {assetId=1;expectedRevision=5;change=variant {reverse=3};note=""}})')"
ok "$(call portfolio-test-owner writeFundPortfolio '(1, "exit", variant {change=record {assetId=1;expectedRevision=5;change=variant {decrease=300};note="exit"}})')"
ok "$(call portfolio-test-owner writeFundPortfolio '(1, "archive", variant {change=record {assetId=1;expectedRevision=6;change=variant {archive=true};note="archive"}})')"
RESULT="$(call portfolio-test-owner listFundPortfolioAssets "$READ")"; ok "$RESULT"; contains "$RESULT" 'vec {}'
ok "$(call portfolio-test-owner listFundPortfolioHistory '(1,1,0,100)')"
echo 'PASS: production Portfolio APIs, authorization, idempotency and populated upgrade'
