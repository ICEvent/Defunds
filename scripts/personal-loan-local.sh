#!/usr/bin/env bash
# Launch an isolated *local* Personal Loan / Internet Identity browser test.
# No mainnet deployment, no "--clean", and no real money transfers.
set -euo pipefail
cd "$(dirname "$0")/.."
ROOT="$PWD"
if [[ "${DFX_NETWORK:-local}" != "local" ]]; then
  echo "Refusing to run: DFX_NETWORK must be local." >&2
  exit 1
fi
export DFX_NETWORK=local

for binary in dfx npm jq; do
  if ! command -v "$binary" >/dev/null 2>&1; then
    echo "Missing required tool: $binary" >&2
    exit 1
  fi
done

if [[ "${1:-}" != "" && "${1:-}" != "--prepare-only" ]]; then
  echo "Usage: bash scripts/personal-loan-local.sh [--prepare-only]" >&2
  exit 1
fi

# DFX 0.30.1's global packtool is only needed for the other Motoko canisters.
# Temporarily use a base-only build config and add a pinned local II canister.
# Restore original dfx.json *exactly* when the script exits.
BACKUP="$(mktemp "$ROOT/.dfx.personal-loan-backup.XXXXXX")"
cp "$ROOT/dfx.json" "$BACKUP"
restore() {
  cp "$BACKUP" "$ROOT/dfx.json"
  rm -f "$BACKUP"
}
trap restore EXIT INT TERM

II_RELEASE="release-2025-08-29"
jq --arg release "$II_RELEASE" '
  del(.defaults.build.packtool)
  | del(.output_env_file)
  | .canisters.internet_identity = {
      "type":"custom",
      "candid":("https://github.com/dfinity/internet-identity/releases/download/" + $release + "/internet_identity.did"),
      "wasm":("https://github.com/dfinity/internet-identity/releases/download/" + $release + "/internet_identity_dev.wasm.gz"),
      "init_arg":"(null)",
      "remote": {"id":{"ic":"rdmx6-jaaaa-aaaaa-aaadq-cai"}},
      "frontend":{}
    }
' "$BACKUP" > "$ROOT/dfx.json"

echo "Starting or reusing local replica (never --clean)..."
if ! dfx start --background; then
  echo "dfx start did not launch a new replica. Checking whether local already responds..."
fi

npm ci
dfx canister create --all

# The test ledger and a local Internet Identity are the only canisters deployed.
dfx deploy personal_loan --network local
dfx deploy internet_identity --network local --argument '(null)'

# Build Candid artifacts for the existing Defunds frontend imports.
dfx build icp_index --check
dfx build icrc1_ledger_canister --check
dfx generate backend
dfx generate governance
dfx generate personal_loan
dfx generate icp_index
dfx generate icrc1_ledger_canister

export VITE_PERSONAL_LOAN_TEST_MODE=true
export VITE_PERSONAL_LOAN_HOST="http://127.0.0.1:4943"
export VITE_PERSONAL_LOAN_CANISTER_ID="$(dfx canister id personal_loan)"
II_ID="$(dfx canister id internet_identity)"
export VITE_PERSONAL_LOAN_IDENTITY_PROVIDER="http://$II_ID.localhost:4943"

echo
echo "Personal Loan local canister: $VITE_PERSONAL_LOAN_CANISTER_ID"
echo "Local Internet Identity:    $VITE_PERSONAL_LOAN_IDENTITY_PROVIDER"
echo "Test page:                  http://127.0.0.1:5173/loans"
echo "Use two independent browser profiles to sign in with two LOCAL II identities."
echo "They are separate from your production oneblock.page-derived principals."
echo "Do NOT enter real bank details; this is an off-chain, local-only ledger."

if [[ "${1:-}" == "--prepare-only" ]]; then
  echo "Preparation complete. Frontend dev server not started."
  exit 0
fi

# Foreground dev server. Ctrl-C closes Vite but preserves local replica data.
npm --workspace frontend run dev -- --host 127.0.0.1 --port 5173 --strictPort
