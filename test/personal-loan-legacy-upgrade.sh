#!/usr/bin/env bash
# CI-only: verify v0.1 stable Loan records survive the addition of loanCurrencies.
# This test uses a throwaway GitHub runner. NEVER invoke on a user replica.
set -euo pipefail
if [[ "${CI:-}" != "true" || "${DFX_NETWORK:-local}" != "local" ]]; then
  echo "Refusing legacy upgrade test outside isolated CI local network" >&2
  exit 1
fi
export DFX_NETWORK=local
LEGACY_SHA="a7bcde2ec01c661db5d71a1a7b1ef9f74b5058e6"
REPO_ROOT="$(git rev-parse --show-toplevel)"
cd "$REPO_ROOT"
CURRENT_BACKEND="$(mktemp)"
cp src/personal_loan/main.mo "$CURRENT_BACKEND"
restore() {
  cp "$CURRENT_BACKEND" src/personal_loan/main.mo
  rm -f "$CURRENT_BACKEND"
  dfx stop >/dev/null 2>&1 || true
}
trap restore EXIT

if ! git cat-file -e "${LEGACY_SHA}^{commit}" 2>/dev/null; then
  git fetch --depth=1 origin "$LEGACY_SHA"
fi
git show "$LEGACY_SHA:src/personal_loan/main.mo" > src/personal_loan/main.mo

dfx start --clean --background
dfx identity new loan-legacy-a --storage-mode plaintext >/dev/null 2>&1
dfx identity new loan-legacy-b --storage-mode plaintext >/dev/null 2>&1
A="$(dfx identity get-principal --identity loan-legacy-a)"
B="$(dfx identity get-principal --identity loan-legacy-b)"
dfx deploy personal_loan
output="$(dfx canister call personal_loan createPersonalLoan \
  "(principal \"$A\", principal \"$B\", 1000000 : nat, null, \"Original CAD agreement\", \"legacy-1\")" \
  --identity loan-legacy-a)"
if ! grep -Eq '(^|[[:space:]])ok([[:space:]]|=|\\})' <<< "$output"; then
  echo "Could not create v0.1 loan: $output" >&2
  exit 1
fi

# Preserve the same canister ID and existing stable data when upgrading source.
cp "$CURRENT_BACKEND" src/personal_loan/main.mo
dfx deploy personal_loan --mode upgrade

loan="$(dfx canister call personal_loan getLoan '(1 : nat)' --identity loan-legacy-a)"
if ! grep -q 'originalAmountCents = 1_000_000' <<< "$loan"; then
  echo "Original CAD principal did not survive upgrade: $loan" >&2
  exit 1
fi
currency="$(dfx canister call personal_loan getLoanCurrency '(1 : nat)' --identity loan-legacy-a)"
if ! grep -q '"CAD"' <<< "$currency"; then
  echo "Legacy loan default currency is not CAD: $currency" >&2
  exit 1
fi
echo "PASS: v0.1 persisted loan upgraded and remains CAD with original principal intact"
