#!/usr/bin/env bash
# Runs only against a fresh local dfx replica. NEVER use --network ic here.
set -euo pipefail

export DFX_WARNING=-mainnet_plaintext_identity

BORROWER_NAME="loan-ci-borrower"
LENDER_NAME="loan-ci-lender"
OUTSIDER_NAME="loan-ci-outsider"

dfx identity new "$BORROWER_NAME" --storage-mode plaintext >/dev/null 2>&1
dfx identity new "$LENDER_NAME" --storage-mode plaintext >/dev/null 2>&1
dfx identity new "$OUTSIDER_NAME" --storage-mode plaintext >/dev/null 2>&1
BORROWER="$(dfx identity get-principal --identity "$BORROWER_NAME")"
LENDER="$(dfx identity get-principal --identity "$LENDER_NAME")"

dfx start --clean --background
cleanup() { dfx stop || true; }
trap cleanup EXIT
dfx deploy personal_loan

call_as() {
  local user="$1" method="$2" args="$3"
  dfx canister call personal_loan "$method" "$args" --identity "$user" 2>&1
}
assert_ok() {
  local output="$1"
  if ! grep -Eq '(^|[[:space:]])ok([[:space:]]|=|\\})' <<< "$output"; then
    echo "Expected #ok, received: $output" >&2
    exit 1
  fi
}
assert_err() {
  local output="$1"
  if ! grep -Eq '(^|[[:space:]])err([[:space:]]|=|\\})' <<< "$output"; then
    echo "Expected #err, received: $output" >&2
    exit 1
  fi
}
assert_balance() {
  local user="$1" cents="$2"
  local output
  output="$(call_as "$user" getBalance '(1 : nat)')"
  assert_ok "$output"
  output="${output//_/}"
  if ! grep -Fq "outstandingCents = $cents" <<< "$output"; then
    echo "Wrong balance (expected $cents): $output" >&2
    exit 1
  fi
}

# Candid principals and integer-cent values; timestamps are nanoseconds.
PROPOSE="(principal \"$BORROWER\", principal \"$LENDER\", 1000000 : nat, null, \"Private loan\", \"initial-req-001\")"
assert_ok "$(call_as "$BORROWER_NAME" createPersonalLoan "$PROPOSE")"
assert_ok "$(call_as "$BORROWER_NAME" createPersonalLoan "$PROPOSE")" # idempotent request
# Existing v0.1 Candid clients remain CAD by default. New loans can lock in a
# selected two-decimal currency; no FX conversion or cross-currency settlement.
assert_ok "$(call_as "$BORROWER_NAME" getLoanCurrency '(1 : nat)')"
if ! grep -Fq '"CAD"' <<< "$(call_as "$BORROWER_NAME" getLoanCurrency '(1 : nat)')"; then
  echo "Existing CAD loan returned wrong currency" >&2; exit 1
fi
USD_PROPOSE="(principal \"$BORROWER\", principal \"$LENDER\", 250050 : nat, \"USD\", null, \"USD loan\", \"currency-req-001\")"
assert_ok "$(call_as "$BORROWER_NAME" createPersonalLoanWithCurrency "$USD_PROPOSE")"
assert_ok "$(call_as "$BORROWER_NAME" createPersonalLoanWithCurrency "$USD_PROPOSE")"
if ! grep -Fq '"USD"' <<< "$(call_as "$LENDER_NAME" getLoanCurrency '(2 : nat)')"; then
  echo "Loan 2 did not retain USD" >&2; exit 1
fi
BAD_CURRENCY="(principal \"$BORROWER\", principal \"$LENDER\", 250050 : nat, \"XYZ\", null, \"unsupported currency\", \"bad-currency\")"
assert_err "$(call_as "$BORROWER_NAME" createPersonalLoanWithCurrency "$BAD_CURRENCY")"
CONFLICT_CURRENCY="(principal \"$BORROWER\", principal \"$LENDER\", 250050 : nat, \"EUR\", null, \"USD loan\", \"currency-req-001\")"
assert_err "$(call_as "$BORROWER_NAME" createPersonalLoanWithCurrency "$CONFLICT_CURRENCY")"
assert_err "$(call_as "$OUTSIDER_NAME" getLoanCurrency '(2 : nat)')"
assert_err "$(call_as "$OUTSIDER_NAME" getLoan '(1 : nat)')"
assert_err "$(call_as "$BORROWER_NAME" acceptLoan '(1 : nat)')"
assert_ok "$(call_as "$LENDER_NAME" acceptLoan '(1 : nat)')"
assert_err "$(call_as "$BORROWER_NAME" confirmFunding '(1 : nat, 1 : nat)')"
assert_balance "$BORROWER_NAME" 0

assert_ok "$(call_as "$LENDER_NAME" declareFunding '(1 : nat, 1 : nat, 1800000000000000000 : int, "Interac")')"
# Initial funding can also be disputed without recording confirmed debt.
# Lender can re-declare with corrected payment details for a fresh review.
assert_ok "$(call_as "$BORROWER_NAME" disputeEntry '(1 : nat, 1 : nat)')"
assert_balance "$BORROWER_NAME" 0
assert_err "$(call_as "$BORROWER_NAME" withdrawPendingEntry '(1 : nat, 1 : nat)')"
assert_ok "$(call_as "$LENDER_NAME" declareFunding '(1 : nat, 1 : nat, 1800000000000000000 : int, "Bank Transfer")')"
if ! grep -Fq '"Bank Transfer"' <<< "$(call_as "$BORROWER_NAME" getLoanEntries '(1 : nat)')"; then
  echo "Corrected funding method was not retained" >&2
  exit 1
fi
assert_ok "$(call_as "$BORROWER_NAME" confirmFunding '(1 : nat, 1 : nat)')"
assert_err "$(call_as "$BORROWER_NAME" confirmFunding '(1 : nat, 1 : nat)')" # no replay
assert_balance "$BORROWER_NAME" 1000000

# Additional borrowing: only accepted and funded borrowing changes balance.
assert_ok "$(call_as "$BORROWER_NAME" requestAdditionalBorrowing '(1 : nat, 300000 : nat, "Extra cash", "extra-001")')"
assert_balance "$LENDER_NAME" 1000000
assert_err "$(call_as "$BORROWER_NAME" acceptAdditionalBorrowing '(1 : nat, 2 : nat)')"
assert_ok "$(call_as "$LENDER_NAME" acceptAdditionalBorrowing '(1 : nat, 2 : nat)')"
assert_ok "$(call_as "$LENDER_NAME" declareFunding '(1 : nat, 2 : nat, 1800100000000000000 : int, "Interac")')"
# The borrower disputes receipt. The claim remains auditable and cannot
# be unilaterally withdrawn after delivery was declared.
assert_ok "$(call_as "$BORROWER_NAME" disputeEntry '(1 : nat, 2 : nat)')"
assert_balance "$BORROWER_NAME" 1000000
assert_err "$(call_as "$BORROWER_NAME" withdrawPendingEntry '(1 : nat, 2 : nat)')"
assert_ok "$(call_as "$LENDER_NAME" declareFunding '(1 : nat, 2 : nat, 1800100000000000000 : int, "Interac")')"
assert_ok "$(call_as "$BORROWER_NAME" confirmFunding '(1 : nat, 2 : nat)')"
assert_balance "$LENDER_NAME" 1300000

# Two individually valid pending repayments cannot both overdraw at confirmation.
REP1='(1 : nat, 1000000 : nat, 1800200000000000000 : int, "Interac", "part 1", "rep-001")'
REP2='(1 : nat, 500000 : nat, 1800300000000000000 : int, "Interac", "part 2", "rep-002")'
assert_ok "$(call_as "$BORROWER_NAME" submitRepayment "$REP1")"
assert_ok "$(call_as "$BORROWER_NAME" submitRepayment "$REP1")" # idempotent
assert_ok "$(call_as "$BORROWER_NAME" submitRepayment "$REP2")"
assert_balance "$LENDER_NAME" 1300000 # pending entries ignored
assert_err "$(call_as "$BORROWER_NAME" confirmRepayment '(1 : nat, 3 : nat)')"
assert_ok "$(call_as "$LENDER_NAME" confirmRepayment '(1 : nat, 3 : nat)')"
assert_balance "$BORROWER_NAME" 300000
assert_err "$(call_as "$LENDER_NAME" confirmRepayment '(1 : nat, 4 : nat)')" # overpayment
assert_ok "$(call_as "$BORROWER_NAME" withdrawPendingEntry '(1 : nat, 4 : nat)')"

# Reversing the original initial borrowing now would make balance negative.
assert_ok "$(call_as "$BORROWER_NAME" requestReversal '(1 : nat, 1 : nat, "test reversal", "rev-001")')"
assert_err "$(call_as "$LENDER_NAME" confirmReversal '(1 : nat, 5 : nat)')"
assert_ok "$(call_as "$BORROWER_NAME" withdrawPendingEntry '(1 : nat, 5 : nat)')"

assert_ok "$(call_as "$BORROWER_NAME" submitRepayment '(1 : nat, 300000 : nat, 1800400000000000000 : int, "Interac", "final", "rep-003")')"
assert_ok "$(call_as "$LENDER_NAME" confirmRepayment '(1 : nat, 6 : nat)')"
assert_balance "$LENDER_NAME" 0
assert_ok "$(call_as "$BORROWER_NAME" requestClosure '(1 : nat)')"
assert_err "$(call_as "$BORROWER_NAME" confirmClosure '(1 : nat)')"
assert_ok "$(call_as "$LENDER_NAME" confirmClosure '(1 : nat)')"
assert_err "$(call_as "$BORROWER_NAME" requestAdditionalBorrowing '(1 : nat, 100 : nat, "post closure", "extra-closed")')"

# The second USD loan has not been funded yet. Initial pending funding
# cancellation must be approved by BOTH parties; cancelling the initial
# agreement rejects the unfunded loan, without creating a balance.
assert_ok "$(call_as "$LENDER_NAME" acceptLoan '(2 : nat)')"
assert_ok "$(call_as "$BORROWER_NAME" requestFundingCancellation '(2 : nat, 7 : nat)')"
assert_ok "$(call_as "$BORROWER_NAME" requestFundingCancellation '(2 : nat, 7 : nat)')" # same caller cannot approve twice
assert_err "$(call_as "$OUTSIDER_NAME" getFundingCancellationRequests '(2 : nat)')"
if ! grep -Fq 'requestedBy' <<< "$(call_as "$LENDER_NAME" getFundingCancellationRequests '(2 : nat)')"; then
  echo "Lender cannot see pending cancellation approval" >&2; exit 1
fi
assert_ok "$(call_as "$LENDER_NAME" requestFundingCancellation '(2 : nat, 7 : nat)')"
if ! grep -Fq 'rejected' <<< "$(call_as "$BORROWER_NAME" getLoan '(2 : nat)')"; then
  echo "Initial unfunded loan was not rejected after bilateral cancellation" >&2; exit 1
fi
assert_err "$(call_as "$BORROWER_NAME" requestFundingCancellation '(2 : nat, 7 : nat)')"

# Third loan: cancellation of accepted additional borrowing should unblock
# closure after the ACTUAL funded amount has been fully repaid.
LOAN3="(principal \"$BORROWER\", principal \"$LENDER\", 100000 : nat, null, \"Funding cancellation regression\", \"loan-3\")"
assert_ok "$(call_as "$BORROWER_NAME" createPersonalLoan "$LOAN3")"
assert_ok "$(call_as "$LENDER_NAME" acceptLoan '(3 : nat)')"
assert_ok "$(call_as "$LENDER_NAME" declareFunding '(3 : nat, 8 : nat, 1800000000000000000 : int, "Interac")')"
assert_ok "$(call_as "$BORROWER_NAME" confirmFunding '(3 : nat, 8 : nat)')"
assert_ok "$(call_as "$BORROWER_NAME" requestAdditionalBorrowing '(3 : nat, 25000 : nat, "Undelivered extra", "extra-3")')"
assert_ok "$(call_as "$LENDER_NAME" acceptAdditionalBorrowing '(3 : nat, 9 : nat)')"
assert_ok "$(call_as "$BORROWER_NAME" submitRepayment '(3 : nat, 100000 : nat, 1800200000000000000 : int, "Interac", "Paid in full", "repay-3")')"
assert_ok "$(call_as "$LENDER_NAME" confirmRepayment '(3 : nat, 10 : nat)')"
if ! grep -Fq 'outstandingCents = 0' <<< "$(call_as "$BORROWER_NAME" getBalance '(3 : nat)')"; then
  echo "Third loan should have zero confirmed outstanding debt" >&2; exit 1
fi
assert_err "$(call_as "$BORROWER_NAME" requestClosure '(3 : nat)')" # accepted extra blocks closure
assert_ok "$(call_as "$BORROWER_NAME" requestFundingCancellation '(3 : nat, 9 : nat)')"
assert_err "$(call_as "$OUTSIDER_NAME" requestFundingCancellation '(3 : nat, 9 : nat)')"
assert_err "$(call_as "$LENDER_NAME" withdrawFundingCancellationRequest '(3 : nat, 9 : nat)')"
assert_ok "$(call_as "$BORROWER_NAME" withdrawFundingCancellationRequest '(3 : nat, 9 : nat)')"
assert_ok "$(call_as "$LENDER_NAME" requestFundingCancellation '(3 : nat, 9 : nat)')"
assert_ok "$(call_as "$BORROWER_NAME" requestFundingCancellation '(3 : nat, 9 : nat)')"
assert_err "$(call_as "$LENDER_NAME" declareFunding '(3 : nat, 9 : nat, 1800200000000000000 : int, "Interac")')"
assert_ok "$(call_as "$BORROWER_NAME" requestClosure '(3 : nat)')"
assert_ok "$(call_as "$LENDER_NAME" confirmClosure '(3 : nat)')"

# Asset currency definitions are caller-managed and snapshotted per loan.
# BTC smallest unit is one satoshi (8 decimals); ETH smallest unit is one wei
# (18 decimals). No floating point, token transfers or FX conversion.
BTC_DEF='record { code = "BTC"; symbol = "₿"; decimals = 8 : nat; kind = "crypto" }'
BTC_LOAN="(principal \"$BORROWER\", principal \"$LENDER\", 1 : nat, $BTC_DEF, null, \"One satoshi\", \"btc-1\")"
assert_ok "$(call_as "$BORROWER_NAME" createPersonalLoanWithAsset "$BTC_LOAN")" # Loan 4
assert_ok "$(call_as "$BORROWER_NAME" createPersonalLoanWithAsset "$BTC_LOAN")" # idempotent
if ! grep -Fq 'decimals = 8' <<< "$(call_as "$LENDER_NAME" getLoanCurrencyDefinition '(4 : nat)')"; then
  echo "BTC loan precision not visible to counterpart" >&2; exit 1
fi
assert_err "$(call_as "$OUTSIDER_NAME" getLoanCurrencyDefinition '(4 : nat)')"
assert_ok "$(call_as "$LENDER_NAME" acceptLoan '(4 : nat)')"
assert_ok "$(call_as "$LENDER_NAME" declareFunding '(4 : nat, 11 : nat, 1800000000000000000 : int, "On-chain (reported)")')"
assert_ok "$(call_as "$BORROWER_NAME" confirmFunding '(4 : nat, 11 : nat)')"
if ! grep -Fq 'outstandingCents = 1' <<< "$(call_as "$LENDER_NAME" getBalance '(4 : nat)')"; then
  echo "BTC one-satoshi balance was not exact" >&2; exit 1
fi

ETH_DEF='record { code = "ETH"; symbol = "Ξ"; decimals = 18 : nat; kind = "crypto" }'
ETH_LOAN="(principal \"$BORROWER\", principal \"$LENDER\", 1 : nat, $ETH_DEF, null, \"One wei\", \"eth-1\")"
assert_ok "$(call_as "$BORROWER_NAME" createPersonalLoanWithAsset "$ETH_LOAN")" # Loan 5
assert_ok "$(call_as "$LENDER_NAME" acceptLoan '(5 : nat)')" # Entry 12
assert_ok "$(call_as "$LENDER_NAME" declareFunding '(5 : nat, 12 : nat, 1800000000000000000 : int, "On-chain (reported)")')"
assert_ok "$(call_as "$BORROWER_NAME" confirmFunding '(5 : nat, 12 : nat)')"
assert_ok "$(call_as "$BORROWER_NAME" requestAdditionalBorrowing '(5 : nat, 1 : nat, "Second wei", "extra-wei")')" # Entry 13
assert_ok "$(call_as "$LENDER_NAME" acceptAdditionalBorrowing '(5 : nat, 13 : nat)')"
assert_ok "$(call_as "$LENDER_NAME" declareFunding '(5 : nat, 13 : nat, 1800000000000000000 : int, "On-chain (reported)")')"
assert_ok "$(call_as "$BORROWER_NAME" confirmFunding '(5 : nat, 13 : nat)')"
assert_ok "$(call_as "$BORROWER_NAME" submitRepayment '(5 : nat, 1 : nat, 1800000000000000000 : int, "On-chain (reported)", "One wei repaid", "rep-wei")')" # Entry 14
assert_ok "$(call_as "$LENDER_NAME" confirmRepayment '(5 : nat, 14 : nat)')"
if ! grep -Fq 'outstandingCents = 1' <<< "$(call_as "$LENDER_NAME" getBalance '(5 : nat)')"; then
  echo "ETH one-wei repayment lost precision" >&2; exit 1
fi

SOL_DEF='record { code = "SOL"; symbol = "SOL"; decimals = 9 : nat; kind = "crypto" }'
SOL_EDIT='record { code = "SOL"; symbol = "SOL"; decimals = 6 : nat; kind = "crypto" }'
SOL_REF='record { network = "solana:mainnet"; standard = "native"; address = "" }'
assert_ok "$(call_as "$BORROWER_NAME" upsertMyCurrencyWithReference "($SOL_DEF, $SOL_REF)")"
if ! grep -Fq '"solana:mainnet"' <<< "$(call_as "$BORROWER_NAME" getMyAssetReferences '()')"; then
  echo "Borrower's SOL native chain reference was not saved" >&2; exit 1
fi
if grep -Fq '"solana:mainnet"' <<< "$(call_as "$LENDER_NAME" getMyAssetReferences '()')"; then
  echo "Private SOL asset reference leaked" >&2; exit 1
fi
if grep -Fq 'code = "SOL"' <<< "$(call_as "$LENDER_NAME" getMyCurrencies '()')"; then
  echo "Borrower currency catalog leaked into lender account" >&2; exit 1
fi
SOL_LOAN="(principal \"$BORROWER\", principal \"$LENDER\", 1 : nat, $SOL_DEF, $SOL_REF, null, \"One lamport\", \"sol-1\")"
assert_err "$(call_as "$BORROWER_NAME" createPersonalLoanWithAsset "(principal \"$BORROWER\", principal \"$LENDER\", 1 : nat, $SOL_DEF, null, \"No asset ref\", \"sol-unbound\")")"
assert_ok "$(call_as "$BORROWER_NAME" createPersonalLoanWithReference "$SOL_LOAN")" # Loan 6
assert_err "$(call_as "$LENDER_NAME" createPersonalLoanWithReference "$SOL_LOAN")" # not lender's catalog
assert_ok "$(call_as "$BORROWER_NAME" upsertMyCurrencyWithReference "($SOL_EDIT, $SOL_REF)")"
if ! grep -Fq 'decimals = 9' <<< "$(call_as "$LENDER_NAME" getLoanCurrencyDefinition '(6 : nat)')"; then
  echo "Editing owner catalog mutated existing loan precision" >&2; exit 1
fi
assert_err "$(call_as "$BORROWER_NAME" createPersonalLoanWithAsset "(principal \"$BORROWER\", principal \"$LENDER\", 1 : nat, $SOL_DEF, null, \"Old precision\", \"sol-old\")")"
assert_ok "$(call_as "$BORROWER_NAME" deleteMyCurrency '("SOL")')"
# A response can be lost. Retrying the exact original request must still
# return the same loan even if its catalog entry was subsequently deleted.
assert_ok "$(call_as "$BORROWER_NAME" createPersonalLoanWithReference "$SOL_LOAN")"
if ! grep -Fq 'decimals = 9' <<< "$(call_as "$LENDER_NAME" getLoanCurrencyDefinition '(6 : nat)')"; then
  echo "Deleting custom currency corrupted original loan definition" >&2; exit 1
fi
if ! grep -Fq '"solana:mainnet"' <<< "$(call_as "$LENDER_NAME" getLoanAssetReference '(6 : nat)')"; then
  echo "SOL Loan lost immutable native chain identity" >&2; exit 1
fi

# ERC-20: even the same ticker must be tied to its network and contract.
USDC_DEF='record { code = "USDC"; symbol = "$"; decimals = 6 : nat; kind = "crypto" }'
USDC_REF='record { network = "eip155:1"; standard = "erc20"; address = "0xA0b86991c6218b36c1d19D4a2e9Eb0cE3606eB48" }'
USDC_OTHER='record { network = "eip155:137"; standard = "erc20"; address = "0xA0b86991c6218b36c1d19D4a2e9Eb0cE3606eB48" }'
USDC_BAD='record { network = "eip155:1"; standard = "erc20"; address = "0x123" }'
USDC_BAD_CHAIN='record { network = "eip155:abc"; standard = "erc20"; address = "0xA0b86991c6218b36c1d19D4a2e9Eb0cE3606eB48" }'
USDC_ZERO_CHAIN='record { network = "eip155:0"; standard = "erc20"; address = "0xA0b86991c6218b36c1d19D4a2e9Eb0cE3606eB48" }'
assert_err "$(call_as "$BORROWER_NAME" upsertMyCurrencyWithReference "($USDC_DEF, $USDC_BAD)")"
assert_err "$(call_as "$BORROWER_NAME" upsertMyCurrencyWithReference "($USDC_DEF, $USDC_BAD_CHAIN)")"
assert_err "$(call_as "$BORROWER_NAME" upsertMyCurrencyWithReference "($USDC_DEF, $USDC_ZERO_CHAIN)")"
assert_ok "$(call_as "$BORROWER_NAME" upsertMyCurrencyWithReference "($USDC_DEF, $USDC_REF)")"
assert_err "$(call_as "$BORROWER_NAME" createPersonalLoanWithReference "(principal \"$BORROWER\", principal \"$LENDER\", 1 : nat, $USDC_DEF, $USDC_OTHER, null, \"Wrong chain\", \"usdc-wrong\")")"
USDC_LOAN="(principal \"$BORROWER\", principal \"$LENDER\", 1 : nat, $USDC_DEF, $USDC_REF, null, \"USDC on Ethereum\", \"usdc-eth-1\")"
assert_ok "$(call_as "$BORROWER_NAME" createPersonalLoanWithReference "$USDC_LOAN")" # Loan 7
assert_err "$(call_as "$OUTSIDER_NAME" getLoanAssetReference '(7 : nat)')"
if ! grep -Fq '"eip155:1"' <<< "$(call_as "$LENDER_NAME" getLoanAssetReference '(7 : nat)')"; then
  echo "Counterparty cannot inspect USDC blockchain network" >&2; exit 1
fi
if ! grep -Fq '"0xA0b86991c6218b36c1d19D4a2e9Eb0cE3606eB48"' <<< "$(call_as "$LENDER_NAME" getLoanAssetReference '(7 : nat)')"; then
  echo "Counterparty cannot inspect USDC contract address" >&2; exit 1
fi
# User catalog changes apply only to FUTURE loans, never the agreed asset.
assert_ok "$(call_as "$BORROWER_NAME" upsertMyCurrencyWithReference "($USDC_DEF, $USDC_OTHER)")"
if ! grep -Fq '"eip155:1"' <<< "$(call_as "$LENDER_NAME" getLoanAssetReference '(7 : nat)')"; then
  echo "Editing contract network corrupted immutable USDC loan identity" >&2; exit 1
fi
assert_ok "$(call_as "$BORROWER_NAME" deleteMyCurrency '("USDC")')"
assert_ok "$(call_as "$BORROWER_NAME" createPersonalLoanWithReference "$USDC_LOAN")" # replay after deletion
if ! grep -Fq '"eip155:1"' <<< "$(call_as "$LENDER_NAME" getLoanAssetReference '(7 : nat)')"; then
  echo "Deleting custom asset corrupted the loan contract reference" >&2; exit 1
fi
assert_err "$(call_as "$BORROWER_NAME" upsertMyCurrency '(record { code = "BTC"; symbol = "fake"; decimals = 2 : nat; kind = "fiat" })')"
assert_err "$(call_as "$BORROWER_NAME" upsertMyCurrency '(record { code = "INVALID CODE"; symbol = ""; decimals = 8 : nat; kind = "crypto" })')"

# Persistent actor upgrade must retain the closed loan, payment totals and audit.
dfx deploy personal_loan --mode upgrade
if ! grep -Fq '"CAD"' <<< "$(call_as "$BORROWER_NAME" getLoanCurrency '(1 : nat)')"; then
  echo "CAD currency did not survive canister upgrade" >&2; exit 1
fi
if ! grep -Fq '"USD"' <<< "$(call_as "$LENDER_NAME" getLoanCurrency '(2 : nat)')"; then
  echo "USD currency did not survive canister upgrade" >&2; exit 1
fi
assert_balance "$BORROWER_NAME" 0
assert_balance "$LENDER_NAME" 0
if ! grep -Fq 'decimals = 18' <<< "$(call_as "$BORROWER_NAME" getLoanCurrencyDefinition '(5 : nat)')"; then
  echo "ETH precision snapshot did not survive canister upgrade" >&2; exit 1
fi
if ! grep -Fq 'decimals = 9' <<< "$(call_as "$LENDER_NAME" getLoanCurrencyDefinition '(6 : nat)')"; then
  echo "Deleted custom currency's immutable snapshot did not survive canister upgrade" >&2; exit 1
fi
if ! grep -Fq '"eip155:1"' <<< "$(call_as "$BORROWER_NAME" getLoanAssetReference '(7 : nat)')"; then
  echo "USDC loan contract network did not survive canister upgrade" >&2; exit 1
fi
if ! grep -Fq '"0xA0b86991c6218b36c1d19D4a2e9Eb0cE3606eB48"' <<< "$(call_as "$LENDER_NAME" getLoanAssetReference '(7 : nat)')"; then
  echo "USDC contract address did not survive canister upgrade" >&2; exit 1
fi

# Both parties can read the same historical events, outsider cannot.
assert_ok "$(call_as "$BORROWER_NAME" getLoanEvents '(1 : nat, 0 : nat, 100 : nat)')"
assert_ok "$(call_as "$LENDER_NAME" getLoanEvents '(1 : nat, 0 : nat, 100 : nat)')"
assert_err "$(call_as "$OUTSIDER_NAME" getLoanEvents '(1 : nat, 0 : nat, 100 : nat)')"
assert_err "$(call_as "$OUTSIDER_NAME" getLoanEntries '(1 : nat)')"
assert_err "$(call_as "$OUTSIDER_NAME" getBalance '(1 : nat)')"
echo "PASS: mutually confirmed Personal Loan E2E with borrower, lender and outsider"
