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

# Project-specific PocketIC must never reuse the user's shared DFX local state.
# See https://internetcomputer.org/docs/building-apps/developer-tools/dfx/dfx-start
LOCAL_PORT="${PERSONAL_LOAN_LOCAL_PORT:-4945}"
if ! [[ "$LOCAL_PORT" =~ ^[0-9]{4,5}$ ]] || (( 10#$LOCAL_PORT < 1000 || 10#$LOCAL_PORT > 65535 )); then
  echo "PERSONAL_LOAN_LOCAL_PORT must be a TCP port (1000-65535)" >&2
  exit 1
fi

for binary in dfx npm jq; do
  if ! command -v "$binary" >/dev/null 2>&1; then
    echo "Missing required tool: $binary" >&2
    exit 1
  fi
done

if [[ "${1:-}" != "" && "${1:-}" != "--prepare-only" && "${1:-}" != "--smoke" ]]; then
  echo "Usage: bash scripts/personal-loan-local.sh [--prepare-only|--smoke]" >&2
  exit 1
fi

# An older Vite instance on 5173 can silently serve stale /loans code even
# after the checkout is updated. Fail before deploying or modifying config.
echo "Personal Loan source commit: $(git rev-parse --short HEAD)"
if command -v curl >/dev/null 2>&1 && curl --silent --max-time 3 --output /dev/null http://127.0.0.1:5173/; then
  echo "Port 5173 is already serving HTTP, possibly from a stale Vite process." >&2
  echo "Stop the old frontend terminal (Ctrl+C) before launching this test page." >&2
  echo "For process lookup: fuser -n tcp 5173 2>/dev/null || ss -ltnp | grep ':5173'" >&2
  exit 1
fi

# DFX 0.30.1's global packtool is only needed for the other Motoko canisters.
# Temporarily use a base-only build config and add a pinned local II canister.
# Restore original dfx.json *exactly* when the script exits.
BACKUP="$(mktemp "$ROOT/.dfx.personal-loan-backup.XXXXXX")"
cp "$ROOT/dfx.json" "$BACKUP"
restore() {
  if [[ -f "$BACKUP" ]]; then
    cp "$BACKUP" "$ROOT/dfx.json"
    rm -f "$BACKUP"
  fi
}
trap restore EXIT

II_RELEASE="release-2025-08-29"
jq --arg release "$II_RELEASE" --arg bind "127.0.0.1:$LOCAL_PORT" '
  del(.defaults.build.packtool)
  | del(.output_env_file)
  # A dfx.json local network definition isolates PocketIC checkpoints under
  # .dfx/network/local for this project rather than the global shared network.
  | .networks.local = {"bind": $bind, "type": "ephemeral"}
  | .canisters.internet_identity = {
      "type":"custom",
      "candid":("https://github.com/dfinity/internet-identity/releases/download/" + $release + "/internet_identity.did"),
      "wasm":("https://github.com/dfinity/internet-identity/releases/download/" + $release + "/internet_identity_dev.wasm.gz"),
      "init_arg":"(null)",
      "remote": {"id":{"ic":"rdmx6-jaaaa-aaaaa-aaadq-cai"}},
      "frontend":{}
    }
' "$BACKUP" > "$ROOT/dfx.json"

echo "Using isolated project-specific local network: 127.0.0.1:$LOCAL_PORT"
echo "Local checkpoint directory: $ROOT/.dfx/network/local"
echo "Existing global DFX shared network state will not be modified."
if dfx ping local >/dev/null 2>&1; then
  echo "Reusing responding project-local PocketIC."
else
  echo "Starting project-specific PocketIC (never --clean)..."
  if command -v timeout >/dev/null 2>&1; then
    timeout 120s dfx start --background || {
      echo "PocketIC did not start. Original shared state was not cleaned." >&2
      echo "Try a fresh git worktree; see docs/PERSONAL_LOAN_LOCAL_TEST.md." >&2
      exit 1
    }
  else
    dfx start --background || {
      echo "PocketIC startup failed. Original shared state was not cleaned." >&2
      exit 1
    }
  fi
fi
if ! dfx ping local >/dev/null 2>&1; then
  echo "Project-local PocketIC did not report healthy on $LOCAL_PORT; refusing deployment." >&2
  exit 1
fi

npm ci
dfx canister create --all

# The test ledger and a local Internet Identity are the only canisters deployed.
# Preserve existing enhanced orthogonal persistent state when the local
# personal_loan canister already exists. In auto mode the option applies
# to upgrades, not to fresh first-time installs.
dfx deploy personal_loan --network local --mode auto --wasm-memory-persistence keep
dfx deploy internet_identity --network local --argument '(null)'

# Build Candid artifacts for the existing Defunds frontend imports.
dfx build icp_index --check
dfx build icrc1_ledger_canister --check
dfx generate backend
dfx generate governance
dfx generate personal_loan
dfx generate icp_index
dfx generate icrc1_ledger_canister

export VITE_PERSONAL_LOAN_BUILD="$(git rev-parse --short HEAD)"
export VITE_PERSONAL_LOAN_TEST_MODE=true
export VITE_PERSONAL_LOAN_HOST="http://127.0.0.1:$LOCAL_PORT"
export VITE_PERSONAL_LOAN_CANISTER_ID="$(dfx canister id personal_loan)"
II_ID="$(dfx canister id internet_identity)"
export VITE_PERSONAL_LOAN_IDENTITY_PROVIDER="http://$II_ID.localhost:$LOCAL_PORT"

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

if [[ "${1:-}" == "--smoke" ]]; then
  npm --workspace frontend run dev -- --host 127.0.0.1 --port 5173 --strictPort > /tmp/defunds-personal-loan-vite.log 2>&1 &
  vite_pid="$!"
  trap 'kill "$vite_pid" 2>/dev/null || true; restore' EXIT
  for attempt in $(seq 1 30); do
    if curl -fsS http://127.0.0.1:5173/loans > /tmp/defunds-personal-loan-page.html 2>/dev/null; then
      # Vite can return an HTML shell for SvelteKit routes; verify the actual
      # JS module the browser imports rather than expecting text in SSR HTML.
      if ! curl -fsS http://127.0.0.1:5173/src/lib/utils/personal-loan-date.js \
          -o /tmp/defunds-personal-loan-date.js ||
          ! grep -Fq 'date-v3-20261106' /tmp/defunds-personal-loan-date.js; then
        echo "Vite is not serving the expected Personal Loan date parser." >&2
        echo "Stop the old frontend; then update this worktree and restart." >&2
        exit 1
      fi
      echo "PASS: browser test page responds at /loans"
      exit 0
    fi
    if ! kill -0 "$vite_pid" 2>/dev/null; then
      cat /tmp/defunds-personal-loan-vite.log >&2
      echo "Vite exited before test page was ready" >&2
      exit 1
    fi
    sleep 1
  done
  cat /tmp/defunds-personal-loan-vite.log >&2
  echo "Vite /loans smoke check timed out" >&2
  exit 1
fi

# Foreground dev server. Ctrl-C closes Vite but preserves local replica data.
npm --workspace frontend run dev -- --host 127.0.0.1 --port 5173 --strictPort
