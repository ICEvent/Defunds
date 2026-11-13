#!/usr/bin/env bash
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
TASK_TMP="$(mktemp -d)"
trap '(cd "$TASK_TMP" && dfx stop >/dev/null 2>&1) || true; rm -rf "$TASK_TMP"' EXIT
cp -R "$ROOT/src" "$TASK_TMP/src"
mkdir -p "$TASK_TMP/test/fixtures"
cp "$ROOT/test/fixtures/DonationLedger.mo" "$TASK_TMP/test/fixtures/"
cat > "$TASK_TMP/dfx.json" <<'JSON'
{"canisters":{"backend":{"type":"motoko","main":"src/backend/main.mo","args":"--enhanced-orthogonal-persistence"},"ledger":{"type":"motoko","main":"test/fixtures/DonationLedger.mo","args":"--enhanced-orthogonal-persistence"}},"networks":{"local":{"bind":"127.0.0.1:4967","type":"ephemeral"}},"version":1}
JSON
cd "$TASK_TMP"
dfx start --background --clean
dfx deploy
DONOR="$(dfx identity get-principal)"
TREASURY="$(dfx canister id backend)"
LEDGER="$(dfx canister id ledger)"
call() { dfx canister call backend "$1" "$2"; }
ok() { grep -q 'ok' <<< "$1"; }
err() { grep -q 'err' <<< "$1"; }
ARGS="(variant { ICRC = \"$LEDGER\" }, 0, 1000000 : nat64)"
err "$(call donateIcrc "$ARGS")"
ok "$(call setIcrcLedgerGovernanceRate "(principal \"$LEDGER\", 100000000 : nat64)")"
dfx canister call ledger configure "(principal \"$TREASURY\", principal \"$TREASURY\", 1000000, 6 : nat8, 0)"
err "$(call donateIcrc "$ARGS")"
dfx canister call ledger configure "(principal \"$DONOR\", principal \"$DONOR\", 1000000, 6 : nat8, 0)"
err "$(call donateIcrc "$ARGS")"
dfx canister call ledger configure "(principal \"$DONOR\", principal \"$TREASURY\", 1000000, 6 : nat8, 0)"
err "$(call donateIcrc "(variant { ICRC = \"$LEDGER\" }, 0, 1000001 : nat64)")"
err "$(dfx canister call backend donateIcrc "$ARGS" --identity anonymous)"
err "$(dfx canister call backend setIcrcLedgerGovernanceRate "(principal \"$LEDGER\", 1 : nat64)" --identity anonymous)"
err "$(call donateIcrc '(variant { ICRC = "mxzaz-hqaaa-aaaar-qaada-cai" }, 0, 1000000 : nat64)')"
ok "$(call donateIcrc "$ARGS")"
err "$(call donateIcrc "$ARGS")"
# Same ledger, new blocks: precision normalization, archives and concurrent replay.
for precision in 8 18; do
  amount=100000000
  if [[ "$precision" == 18 ]]; then amount=1000000000000000000; fi
  dfx canister call ledger configure "(principal \"$DONOR\", principal \"$TREASURY\", $amount, $precision : nat8, $precision)"
  dfx canister call ledger setArchived '(true)'
  decimal_args="(variant { ICRC = \"$LEDGER\" }, $precision, $amount : nat64)"
  call donateIcrc "$decimal_args" > "$TASK_TMP/result-a" &
  pid_a=$!
  call donateIcrc "$decimal_args" > "$TASK_TMP/result-b" &
  pid_b=$!
  wait "$pid_a"; wait "$pid_b"
  test "$(grep -l 'ok' "$TASK_TMP/result-a" "$TASK_TMP/result-b" | wc -l)" -eq 1
  test "$(grep -l 'err' "$TASK_TMP/result-a" "$TASK_TMP/result-b" | wc -l)" -eq 1
done
RECEIPT="$(call getMyIcrcDonationReceipts '()')"
test "$(grep -c 'score = 100_000_000' <<< "$RECEIPT")" -eq 3
rates="$(call getExchangeRates '()')"
grep -q '100_000_000' <<< "$RECEIPT"
grep -q 'decimals = 6' <<< "$RECEIPT"
dfx canister install backend --mode upgrade --wasm-memory-persistence keep --upgrade-unchanged
err "$(call donateIcrc "$ARGS")"
test "$rates" = "$(call getExchangeRates '()')"
err "$(call donateIcrc "$decimal_args")"
test "$RECEIPT" = "$(call getMyIcrcDonationReceipts '()')"
echo 'Donation verification and populated upgrade passed'
