# Personal Loan — Local Browser Acceptance Test

**Status:** Local/off-chain QA only. This is not a mainnet deployment.

## Requirements

- Linux/WSL2 or macOS, `dfx` **0.30.1**, Node.js >= 22, `npm`, `jq`.
- Clone/checkout branch `feat/personal-loan-ledger-20261105` in `ICEvent/Defunds`.
- Access to GitHub releases on first startup to download the pinned local II development WASM.
- Two independent browser profiles (e.g. regular + private window), each with a **different local Internet Identity account**.

## Start (from repository root)

```bash
git checkout feat/personal-loan-ledger-20261105
git pull --ff-only
bash scripts/personal-loan-local.sh
```

### When the global shared PocketIC returns HTTP 400 on WSL2

The script uses a **project-specific local network**, bound to **127.0.0.1:4945**, and saves its checkpoints in this repository's `.dfx/network/local`. It does **not** resume the broken shared network stored under `~/.local/share/dfx/network/local`. Avoid `dfx start --clean`, which could erase the other projects' checkpoints.

If the current checkout contains old `.dfx/local` canister IDs or corrupted project-specific checkpoints, the safest completely fresh environment is a **separate Git worktree**, without deleting anything:

```bash
# Run from your original Defunds checkout; stop the hanging process first (Ctrl+C).
git fetch origin
git worktree add --detach ../defunds-personal-loan-test origin/feat/personal-loan-ledger-20261105
cd ../defunds-personal-loan-test
bash scripts/personal-loan-local.sh
```

Worktrees have separate `.dfx/` data directories. Your original checkout, original shared network and old canister states remain untouched. The test network uses port 4945, independently of shared 4943. You may set `PERSONAL_LOAN_LOCAL_PORT=4955` if port 4945 is occupied. Use a worktree when you want an entirely separate test ledger; do not copy its local Principal IDs into a production loan.

The temporary `dfx.json` network configuration is restored when Vite closes. To run DFX commands against this isolated local network, keep the script running in a separate terminal; rerun the script to reconnect later.


The script:
1. Creates a backup of `dfx.json`, uses a temporary local-only configuration and restores the original file on exit.
2. Starts/reuses this project's separate PocketIC on **127.0.0.1:4945** **without** `--clean`. The default global shared network (4943) and its state are not touched.
3. Installs npm dependencies, creates missing local canister IDs and deploys only `personal_loan` plus a **local** Internet Identity (pinned `release-2025-08-29`).
4. Generates the Candid declarations needed by the existing Defunds frontend.
5. Starts Vite in the foreground at **http://127.0.0.1:5173/loans**.
6. Sets `VITE_PERSONAL_LOAN_TEST_MODE=true` only for the local Vite process. The production `oneblock.page` derivation origin is deliberately disabled in this local mode.

**Do not run `dfx start --clean` on an existing development workspace**; it deletes local state. Do not use `--network ic` or paste real bank/payment details into test entries.

```bash
# For CI / preparation without keeping Vite open:
bash scripts/personal-loan-local.sh --smoke
```

## Test with two real browser logins

**Browser A — borrower**
1. Open `http://127.0.0.1:5173/loans`.
2. Click **Login** in the navigation, choose Internet Identity. Register/login using the **local** II.
3. Copy **Your authenticated Principal** from the Loans page.
4. Share it with browser B's user.

**Browser B — lender**
1. Open **the same URL and origin** in another browser profile (not the same logged-in tab).
2. Log into a different local II account.
3. Copy the lender Principal and share it with A.

**Create the loan**
1. A selects **Borrower**, enters B's Principal and **CAD 10000.00**, submits **Propose loan**.
2. B clicks **Refresh**, then **Invitations**, selects the new proposal and **Accept terms**.
3. B selects the loan, chooses the correct funding date/method and **Declare funds delivered**. No money is actually sent.
4. A clicks **Refresh**, selects the loan and clicks **Confirm** to acknowledge receipt.
5. Both should see **CAD $10,000.00 outstanding**.

**Test partial repayments and additional borrowing**

| Action | Who initiates | Who confirms | Expected balance |
|---|---|---|---|
| Initial borrowing CAD 10,000 | A proposes | B accepts/declares, A acknowledges | CAD 10,000 |
| Repay CAD 1,000 | A records | B confirms receipt | CAD 9,000 |
| Repay CAD 1,500 | A records | B confirms receipt | CAD 7,500 |
| Additional borrowing CAD 3,000 | A requests | B approves/declares, A acknowledges | CAD 10,500 |
| Repay CAD 2,000 | A records | B confirms receipt | CAD 8,500 |

Click **Refresh** after the other participant changes a record. Verify each pending entry **does not** change the balance before mutual confirmation, and verify the **Audit timeline**.

**Negative checks**
- A cannot confirm their own repayment.
- B can reject A's pending additional borrowing.
- A rejected or disputed repayment does not alter the confirmed balance.
- Repeating a request after a failed network response does not create a second debt entry if the form payload is unchanged.
- A third II identity cannot view the Loan or its entries.
- To close: repay the remaining balance, get the lender's confirmation, then request/confirm closure from different participants. A closed loan cannot be reopened with new borrowing.

## Production vs. local identity

Local II and the test origin use a different principal derivation than Defunds' production `https://oneblock.page` setup. **Do not copy production principals into your local loan test.** Share the principals displayed after each browser signs into the local test page.

This MVP **only records mutually acknowledged, off-chain CAD movements** and does not transfer money, prove bank settlement or create legally enforced debts.

## Troubleshooting

- **Login blocked:** confirm the local II URL printed by the script is accessible in your browser, the two browser sessions use the identical `http://127.0.0.1:5173` origin, and that local test mode is enabled.
- **Loans not connected:** check `VITE_PERSONAL_LOAN_CANISTER_ID` and `VITE_PERSONAL_LOAN_HOST` in the script's output; use the script instead of a generic `npm run dev`.
- **No invitation shown:** click Refresh, then Invitations; verify the sender entered exactly the Principal of the intended recipient.
- **Network root key / certificate errors:** check the isolated PocketIC listens on `127.0.0.1:4945` and II is local, not production.
- **Port already in use:** stop the other Vite process on 5173 or choose a different `PERSONAL_LOAN_LOCAL_PORT`. Do not stop other project's replicas or clean their state.
- **`Error: dfx is already running` while 4945 is not healthy:** a WSL restart can leave the *project-local* `.dfx/network/local/pid` behind even after the process exits. The launcher now checks this PID against the OS; **only if no process exists**, it renames that PID file with a `.stale.<timestamp>` suffix before starting PocketIC. This leaves canisters/checkpoints untouched. If the PID **is alive**, the launcher deliberately refuses to kill it and prints the PID/process and ports. Never run `dfx killall`, `pkill dfx` or `dfx start --clean` as a shortcut; they could affect other projects or erase checkpoints. Inspect with:
  ```bash
  cd ~/projects/defunds-personal-loan-test
  cat .dfx/network/local/pid 2>/dev/null || true
  ps -eo pid,ppid,stat,args | grep -E '[d]fx start|[p]ocket-ic|[p]ocketic' || true
  ss -lntp | grep -E ':4943|:4945' || true
  ```
- **Source commit differs from the current PR head:** in the test worktree, run `git fetch origin` and `git switch --detach origin/feat/personal-loan-ledger-20261105` (only when there are no unsaved local edits), then rerun the launcher. The launcher prints the source commit at startup so a stale test server is easy to identify.
- **Persistent warnings from other Defunds pages:** those pages may still rely on existing Defunds backend canisters. This script is scoped to `/loans` only.

## Automated checks

The PR includes Motoko ledger fixtures, local three-principal (borrower/lender/outsider) Canister E2E, canister upgrade persistence, and GitHub Actions frontend/preview build checks. Browser login through two manually operated local II accounts is the final interactive acceptance test; do not call it automated unless it is automated separately.

## Loan Detail UI acceptance — transaction workflow

For a loan with a nonempty description, verify the **Loan description** appears in the list preview and in its detail panel. An empty description should show a neutral placeholder, not a stale description from another loan.

In an **Active** loan, the New transaction area has exactly two options:
- **Additional borrowing:** amount and borrowing-specific Note; only requests another borrowing, with no repayment/date controls.
- **Repayment:** choose a manually entered partial amount, or select **Repay full outstanding balance**. The amount is displayed automatically from the *confirmed* balance and checked again against the live canister balance immediately before the repayment record is submitted. The repayment's date, method and Note are independent of the borrowing form.

For a confirmed outstanding balance of **CAD 8,500.00**, select Repayment → Repay full outstanding balance and Record repayment. A pending repayment for CAD 8,500.00 should appear, but Outstanding remains CAD 8,500.00 until the other party confirms receipt. Then Outstanding becomes CAD 0.00, and loan closure remains a separate bilateral step.

The **Audit timeline** should display readable action names such as *Repayment recorded* and *Repayment confirmed*, with the same transaction's amount and its Note, plus the event timestamp. Amounts in audit events are descriptive and must **not** be added together to calculate debt; both events refer to the same repayment.
