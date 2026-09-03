from pathlib import Path


def replace_once(text: str, old: str, new: str, label: str) -> str:
    count = text.count(old)
    if count != 1:
        raise RuntimeError(f"{label}: expected exactly 1 match, found {count}")
    return text.replace(old, new, 1)


# ---------------------------------------------------------------------------
# Backend: private fund visibility must be enforced at the public actor API.
# ---------------------------------------------------------------------------
main_path = Path("src/backend/main.mo")
main = main_path.read_text()

old_group_queries = '''\t// Group query methods
\tpublic query func getGroup(groupId : Nat) : async ?GroupTypes.GroupFund {
\t\tgroups.getGroup(groupId);
\t};

\tpublic query func getAllGroups() : async [GroupTypes.GroupFund] {
\t\tgroups.getAllGroups();
\t};

\tpublic query func getPublicGroups() : async [GroupTypes.GroupFund] {
\t\tgroups.getPublicGroups();
\t};
'''

new_group_queries = '''\tprivate func canReadGroup(caller : Principal, group : GroupTypes.GroupFund) : Bool {
\t\tgroup.isPublic or (
\t\t\tnot Principal.isAnonymous(caller) and
\t\t\tgroups.isMember(group.members, caller)
\t\t)
\t};

\t// Group query methods. Public funds are inspectable by everyone; private
\t// funds are visible only to their members.
\tpublic query ({ caller }) func getGroup(groupId : Nat) : async ?GroupTypes.GroupFund {
\t\tswitch (groups.getGroup(groupId)) {
\t\t\tcase null { null };
\t\t\tcase (?group) {
\t\t\t\tif (canReadGroup(caller, group)) { ?group } else { null };
\t\t\t};
\t\t};
\t};

\tpublic query ({ caller }) func getAllGroups() : async [GroupTypes.GroupFund] {
\t\tArray.filter<GroupTypes.GroupFund>(
\t\t\tgroups.getAllGroups(),
\t\t\tfunc(group : GroupTypes.GroupFund) : Bool { canReadGroup(caller, group) },
\t\t);
\t};

\tpublic query func getPublicGroups() : async [GroupTypes.GroupFund] {
\t\tgroups.getPublicGroups();
\t};
'''
main = replace_once(main, old_group_queries, new_group_queries, "group query privacy")

old_proposal_queries = '''\tpublic query func getProposal(proposalId : Nat) : async ?GroupTypes.GroupProposal {
\t\tgroups.getProposal(proposalId);
\t};

\tpublic query func getGroupProposals(groupId : Nat) : async [GroupTypes.GroupProposal] {
\t\tgroups.getGroupProposals(groupId);
\t};

\tpublic query func getAllProposals() : async [GroupTypes.GroupProposal] {
\t\tgroups.getAllProposals();
\t};
'''

new_proposal_queries = '''\tpublic query ({ caller }) func getProposal(proposalId : Nat) : async ?GroupTypes.GroupProposal {
\t\tswitch (groups.getProposal(proposalId)) {
\t\t\tcase null { null };
\t\t\tcase (?proposal) {
\t\t\t\tswitch (groups.getGroup(proposal.groupId)) {
\t\t\t\t\tcase null { null };
\t\t\t\t\tcase (?group) {
\t\t\t\t\t\tif (canReadGroup(caller, group)) { ?proposal } else { null };
\t\t\t\t\t};
\t\t\t\t};
\t\t\t};
\t\t};
\t};

\tpublic query ({ caller }) func getGroupProposals(groupId : Nat) : async [GroupTypes.GroupProposal] {
\t\tswitch (groups.getGroup(groupId)) {
\t\t\tcase null { [] };
\t\t\tcase (?group) {
\t\t\t\tif (canReadGroup(caller, group)) {
\t\t\t\t\tgroups.getGroupProposals(groupId)
\t\t\t\t} else {
\t\t\t\t\t[]
\t\t\t\t};
\t\t\t};
\t\t};
\t};

\tpublic query ({ caller }) func getAllProposals() : async [GroupTypes.GroupProposal] {
\t\tArray.filter<GroupTypes.GroupProposal>(
\t\t\tgroups.getAllProposals(),
\t\t\tfunc(proposal : GroupTypes.GroupProposal) : Bool {
\t\t\t\tswitch (groups.getGroup(proposal.groupId)) {
\t\t\t\t\tcase null { false };
\t\t\t\t\tcase (?group) { canReadGroup(caller, group) };
\t\t\t\t};
\t\t\t},
\t\t);
\t};
'''
main = replace_once(main, old_proposal_queries, new_proposal_queries, "proposal query privacy")

old_ai_queries = '''\tpublic query func getAIAgentFund(groupId : Nat) : async ?GroupTypes.AIAgentFund {
\t\tgroups.getAIAgentFund(groupId);
\t};

\tpublic query func getAllAIAgentFunds() : async [GroupTypes.AIAgentFund] {
\t\tgroups.getAllAIAgentFunds();
\t};

\tpublic query func getPublicAIAgentFunds() : async [GroupTypes.AIAgentFund] {
\t\tgroups.getPublicAIAgentFunds();
\t};
'''

new_ai_queries = '''\tpublic query ({ caller }) func getAIAgentFund(groupId : Nat) : async ?GroupTypes.AIAgentFund {
\t\tswitch (groups.getAIAgentFund(groupId)) {
\t\t\tcase null { null };
\t\t\tcase (?fund) {
\t\t\t\tif (canReadGroup(caller, fund.groupFund)) { ?fund } else { null };
\t\t\t};
\t\t};
\t};

\tpublic query ({ caller }) func getAllAIAgentFunds() : async [GroupTypes.AIAgentFund] {
\t\tArray.filter<GroupTypes.AIAgentFund>(
\t\t\tgroups.getAllAIAgentFunds(),
\t\t\tfunc(fund : GroupTypes.AIAgentFund) : Bool {
\t\t\t\tcanReadGroup(caller, fund.groupFund)
\t\t\t},
\t\t);
\t};

\tpublic query func getPublicAIAgentFunds() : async [GroupTypes.AIAgentFund] {
\t\tgroups.getPublicAIAgentFunds();
\t};
'''
main = replace_once(main, old_ai_queries, new_ai_queries, "AI fund query privacy")
main_path.write_text(main)


# ---------------------------------------------------------------------------
# Frontend: never guess decimals for arbitrary #ICRC ledgers.
# ---------------------------------------------------------------------------
funds_path = Path("src/frontend/src/routes/funds/+page.svelte")
funds = funds_path.read_text()
old_funds_formatter = '''  function formatTokenAmount(raw, currency) {
    try {
      const value = BigInt(raw ?? 0);
      const decimals = Math.max(0, Math.min(getDecimalsByCurrency(currency), 30));
      const scale = 10n ** BigInt(decimals);
      const whole = value / scale;
      const fraction = (value % scale).toString().padStart(decimals, "0").slice(0, 6).replace(/0+$/, "");
      return fraction ? `${whole}.${fraction}` : whole.toString();
    } catch {
      return "Unavailable";
    }
  }
'''
new_funds_formatter = '''  function isCustomIcrc(currencyVariant) {
    return Boolean(
      currencyVariant &&
      typeof currencyVariant === "object" &&
      Object.prototype.hasOwnProperty.call(currencyVariant, "ICRC")
    );
  }

  function formatTokenAmount(raw, currencyVariant) {
    try {
      const value = BigInt(raw ?? 0);
      if (isCustomIcrc(currencyVariant)) return value.toString();
      const decimals = Math.max(0, Math.min(getDecimalsByCurrency(currencyVariant), 30));
      const scale = 10n ** BigInt(decimals);
      const whole = value / scale;
      const fraction = (value % scale).toString().padStart(decimals, "0").slice(0, 6).replace(/0+$/, "");
      return fraction ? `${whole}.${fraction}` : whole.toString();
    } catch {
      return "Unavailable";
    }
  }
'''
funds = replace_once(funds, old_funds_formatter, new_funds_formatter, "funds custom ICRC formatter")
funds = replace_once(
    funds,
    '''        Balance shown below is the fund's recorded balance field, not a verified live-ledger balance yet.''',
    '''        Balance shown below is the fund's recorded balance field, not a verified live-ledger balance yet. Custom ICRC values are shown as raw ledger base units until token decimals are fetched.''',
    "funds balance notice",
)
funds = replace_once(
    funds,
    '''              <div class="text-[11px] font-semibold uppercase tracking-wide text-slate-400">Recorded balance</div>''',
    '''              <div class="text-[11px] font-semibold uppercase tracking-wide text-slate-400">{isCustomIcrc(group.currency) ? "Recorded base units" : "Recorded balance"}</div>''',
    "funds balance label",
)
funds_path.write_text(funds)


detail_path = Path("src/frontend/src/routes/funds/[id]/+page.svelte")
detail = detail_path.read_text()
old_detail_reactive = '''  $: currency = group ? getCurrencyName(group.currency) : "";
  $: decimals = group ? getDecimalsByCurrency(group.currency) : 8;
'''
new_detail_reactive = '''  $: customIcrc = Boolean(
    group?.currency &&
    typeof group.currency === "object" &&
    Object.prototype.hasOwnProperty.call(group.currency, "ICRC")
  );
  $: currency = group ? getCurrencyName(group.currency) : "";
  $: decimals = group ? (customIcrc ? 0 : getDecimalsByCurrency(group.currency)) : 8;
  $: amountUnit = customIcrc ? "base units" : currency;
'''
detail = replace_once(detail, old_detail_reactive, new_detail_reactive, "detail custom ICRC reactive state")
detail = replace_once(
    detail,
    '''    if (fraction.length > precision) throw new Error(`${currency} supports at most ${precision} decimal places.`);''',
    '''    if (fraction.length > precision) {
      if (customIcrc) throw new Error("Custom ICRC amounts must be entered in raw ledger base units.");
      throw new Error(`${currency} supports at most ${precision} decimal places.`);
    }''',
    "detail custom ICRC parse error",
)
detail = replace_once(
    detail,
    '''          <div class="text-xs uppercase tracking-wide text-slate-400">Recorded balance</div>
          <div class="mt-1 text-2xl font-semibold">{formatTokenAmount(group.balance)} {currency}</div>
          <div class="mt-1 text-xs text-amber-200">Not live-ledger verified</div>''',
    '''          <div class="text-xs uppercase tracking-wide text-slate-400">{customIcrc ? "Recorded base units" : "Recorded balance"}</div>
          <div class="mt-1 text-2xl font-semibold">{formatTokenAmount(group.balance)} {customIcrc ? "base units" : currency}</div>
          <div class="mt-1 text-xs text-amber-200">{customIcrc ? "Custom token decimals not fetched" : "Not live-ledger verified"}</div>''',
    "detail recorded balance display",
)
detail = replace_once(
    detail,
    '''      <div class="mt-4 rounded-xl border border-amber-200 bg-amber-50 px-4 py-3 text-sm text-amber-800">
        Approval currently represents a governance decision. The Group Fund code does not yet execute the treasury transfer automatically, so approved proposals should be treated as <strong>execution pending</strong> until an execution receipt exists.
      </div>
''',
    '''      <div class="mt-4 rounded-xl border border-amber-200 bg-amber-50 px-4 py-3 text-sm text-amber-800">
        Approval currently represents a governance decision. The Group Fund code does not yet execute the treasury transfer automatically, so approved proposals should be treated as <strong>execution pending</strong> until an execution receipt exists.
      </div>

      {#if customIcrc}
        <div class="mt-3 rounded-xl border border-violet-200 bg-violet-50 px-4 py-3 text-sm text-violet-800">
          Custom ICRC token decimals are not fetched yet. Proposal amounts for this fund must be entered as raw ledger <strong>base units</strong>; Defunds will not guess a decimal scale for financial values.
        </div>
      {/if}
''',
    "detail custom ICRC notice",
)
detail = replace_once(
    detail,
    '''              Amount ({currency})
              <input bind:value={proposalAmount} inputmode="decimal" placeholder="0.00" class="rounded-xl border border-slate-300 bg-white px-3 py-2.5 font-normal text-slate-900 outline-none focus:border-sky-500" />''',
    '''              Amount ({amountUnit})
              <input bind:value={proposalAmount} inputmode={customIcrc ? "numeric" : "decimal"} placeholder={customIcrc ? "e.g. 1000000" : "0.00"} class="rounded-xl border border-slate-300 bg-white px-3 py-2.5 font-normal text-slate-900 outline-none focus:border-sky-500" />''',
    "detail proposal input unit",
)
detail = replace_once(
    detail,
    '''                  <div class="mt-1 font-semibold text-slate-900">{formatTokenAmount(proposal.amount)} {currency}</div>''',
    '''                  <div class="mt-1 font-semibold text-slate-900">{formatTokenAmount(proposal.amount)} {amountUnit}</div>''',
    "detail proposal amount display",
)
detail_path.write_text(detail)


profile_path = Path("src/frontend/src/lib/components/Profile/GroupPanel.svelte")
profile = profile_path.read_text()
old_profile_formatter = '''  function formatTokenAmount(raw, currencyVariant) {
    try {
      const value = BigInt(raw ?? 0);
      const decimals = Math.max(0, Math.min(getDecimalsByCurrency(currencyVariant), 30));
      const scale = 10n ** BigInt(decimals);
      const whole = value / scale;
      const fraction = (value % scale).toString().padStart(decimals, "0").slice(0, 6).replace(/0+$/, "");
      return fraction ? `${whole}.${fraction}` : whole.toString();
    } catch {
      return "Unavailable";
    }
  }
'''
new_profile_formatter = '''  function isCustomIcrc(currencyVariant) {
    return Boolean(
      currencyVariant &&
      typeof currencyVariant === "object" &&
      Object.prototype.hasOwnProperty.call(currencyVariant, "ICRC")
    );
  }

  function formatTokenAmount(raw, currencyVariant) {
    try {
      const value = BigInt(raw ?? 0);
      if (isCustomIcrc(currencyVariant)) return value.toString();
      const decimals = Math.max(0, Math.min(getDecimalsByCurrency(currencyVariant), 30));
      const scale = 10n ** BigInt(decimals);
      const whole = value / scale;
      const fraction = (value % scale).toString().padStart(decimals, "0").slice(0, 6).replace(/0+$/, "");
      return fraction ? `${whole}.${fraction}` : whole.toString();
    } catch {
      return "Unavailable";
    }
  }
'''
profile = replace_once(profile, old_profile_formatter, new_profile_formatter, "profile custom ICRC formatter")
profile = replace_once(
    profile,
    '''            <input bind:value={customCurrency} placeholder="Ledger canister or configured token identifier" class="rounded-xl border border-slate-300 bg-white px-3 py-2.5 font-mono font-normal text-slate-900 outline-none focus:border-sky-500" />
          </label>''',
    '''            <input bind:value={customCurrency} placeholder="Ledger canister or configured token identifier" class="rounded-xl border border-slate-300 bg-white px-3 py-2.5 font-mono font-normal text-slate-900 outline-none focus:border-sky-500" />
            <span class="text-xs font-normal text-violet-700">Token decimals are not fetched yet; balances and proposal amounts use raw ledger base units.</span>
          </label>''',
    "profile custom ICRC notice",
)
profile = replace_once(
    profile,
    '''              <div class="mt-2 text-xs text-slate-400">{fund.members.length} members · recorded balance {formatTokenAmount(fund.balance, fund.currency)} {getCurrencyName(fund.currency)}</div>''',
    '''              <div class="mt-2 text-xs text-slate-400">{fund.members.length} members · {isCustomIcrc(fund.currency) ? "recorded base units" : "recorded balance"} {formatTokenAmount(fund.balance, fund.currency)} {isCustomIcrc(fund.currency) ? "base units" : getCurrencyName(fund.currency)}</div>''',
    "profile recorded balance unit",
)
profile_path.write_text(profile)

print("Final Funds review fixes applied successfully")
