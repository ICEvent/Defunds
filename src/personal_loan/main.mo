import Array "mo:base/Array";
import Char "mo:base/Char";
import Nat "mo:base/Nat";
import Principal "mo:base/Principal";
import Result "mo:base/Result";
import Text "mo:base/Text";
import Time "mo:base/Time";

import Types "types";
import Ledger "ledger";

// Isolated, off-chain, interest-free personal loan ledger. No token transfers.
// Stable fields are intentionally kept separate from the deployed Defunds fund.
persistent actor PersonalLoan {
  type Loan = Types.Loan;
  type Entry = Types.Entry;
  type Balance = Types.Balance;
  type R<T> = Result.Result<T, Text>;

  var loans : [Loan] = [];
  // Separate persistent mapping preserves upgrade compatibility with existing
  // stable Loan records created by v0.1 (which were implicitly CAD).
  // An absent entry always means CAD; the mapping is immutable per loan.
  var loanCurrencies : [(Nat, Text)] = [];
  // New metadata snapshots are opt-in; legacy loans still default to CAD/2.
  var loanCurrencyDefinitions : [(Nat, Types.CurrencyDefinition)] = [];
  // Each authenticated caller owns a distinct editable currency catalog.
  var userCurrencies : [(Principal, Types.CurrencyDefinition)] = [];
  // Blockchain identity is not a ticker. It is stored in separate persistent
  // mappings so existing CurrencyDefinition stable shapes are unchanged.
  var userAssetReferences : [(Principal, Text, Types.AssetReference)] = [];
  var loanAssetReferences : [(Nat, Types.AssetReference)] = [];
  var entries : [Entry] = [];
  var fundingCancellationRequests : [Types.FundingCancellationRequest] = [];
  var events : [Types.LoanEvent] = [];
  var nextEventId : Nat = 1;
  var nextLoanId : Nat = 1;
  var nextEntryId : Nat = 1;

  private func appendEvent(loanId : Nat, entryId : ?Nat, kind : Types.EventKind, caller : Principal) {
    let event : Types.LoanEvent = {
      id = nextEventId;
      loanId;
      entryId;
      kind;
      performedBy = caller;
      at = Time.now();
    };
    nextEventId += 1;
    events := Array.append<Types.LoanEvent>(events, [event]);
  };

  private func participant(loan : Loan, user : Principal) : Bool {
    not Principal.isAnonymous(user) and (user == loan.borrower or user == loan.lender);
  };

  private func otherParty(loan : Loan, user : Principal) : Principal {
    if (user == loan.borrower) loan.lender else loan.borrower;
  };

  private func loanById(id : Nat) : ?Loan {
    Array.find<Loan>(loans, func(x) { x.id == id });
  };

  private func entryById(loanId : Nat, entryId : Nat) : ?Entry {
    Array.find<Entry>(entries, func(x) { x.loanId == loanId and x.id == entryId });
  };

  private func findRequest(loanId : Nat, caller : Principal, requestId : Text) : ?Entry {
    Array.find<Entry>(entries, func(x) {
      x.loanId == loanId and x.proposedBy == caller and x.clientRequestId == requestId
    });
  };

  private func validRequestId(requestId : Text) : Bool {
    Text.size(requestId) > 0 and Text.size(requestId) <= 128;
  };

  private func validNote(note : Text) : Bool {
    Text.size(note) <= 500;
  };

  // The original currency API remains fiat-only for legacy Candid clients.
  // Custom and crypto definitions use createPersonalLoanWithAsset instead.
  private func supportedCurrency(currency : Text) : Bool {
    currency == "CAD" or currency == "USD" or currency == "EUR" or
    currency == "GBP" or currency == "CNY";
  };

  private func makeCurrency(code : Text, symbol : Text, decimals : Nat, kind : Text) : Types.CurrencyDefinition {
    { code; symbol; decimals; kind };
  };

  private func builtinCurrency(code : Text) : ?Types.CurrencyDefinition {
    switch (code) {
      case ("CAD") ?makeCurrency("CAD", "$", 2, "fiat");
      case ("USD") ?makeCurrency("USD", "$", 2, "fiat");
      case ("EUR") ?makeCurrency("EUR", "€", 2, "fiat");
      case ("GBP") ?makeCurrency("GBP", "£", 2, "fiat");
      case ("CNY") ?makeCurrency("CNY", "¥", 2, "fiat");
      case ("BTC") ?makeCurrency("BTC", "₿", 8, "crypto");
      case ("ETH") ?makeCurrency("ETH", "Ξ", 18, "crypto");
      case ("ICP") ?makeCurrency("ICP", "ICP", 8, "crypto");
      case ("CKBTC") ?makeCurrency("CKBTC", "ckBTC", 8, "crypto");
      case ("CKETH") ?makeCurrency("CKETH", "ckETH", 18, "crypto");
      case (_) null;
    };
  };

  private func assetRef(network : Text, standard : Text, address : Text) : Types.AssetReference {
    { network; standard; address };
  };

  private func builtinAssetReference(code : Text) : ?Types.AssetReference {
    switch (code) {
      case ("CAD" or "USD" or "EUR" or "GBP" or "CNY") ?assetRef("", "fiat", "");
      case ("BTC") ?assetRef("bitcoin:mainnet", "native", "");
      case ("ETH") ?assetRef("eip155:1", "native", "");
      case ("ICP") ?assetRef("ic:mainnet", "icrc", "ryjl3-tyaaa-aaaaa-aaaba-cai");
      case ("CKBTC") ?assetRef("ic:mainnet", "icrc", "mxzaz-hqaaa-aaaar-qaada-cai");
      case ("CKETH") ?assetRef("ic:mainnet", "icrc", "ss2fx-dyaaa-aaaar-qacoq-cai");
      case (_) null;
    };
  };

  private func validNetwork(network : Text) : Bool {
    if (Text.size(network) < 4 or Text.size(network) > 64) return false;
    for (ch in Text.toIter(network)) {
      let n = Char.toNat32(ch);
      if (not ((n >= 97 and n <= 122) or (n >= 48 and n <= 57) or n == 45 or n == 58)) return false;
    };
    true;
  };

  private func isHex(ch : Char) : Bool {
    let n = Char.toNat32(ch);
    (n >= 48 and n <= 57) or (n >= 65 and n <= 70) or (n >= 97 and n <= 102);
  };

  private func validEvmAddress(address : Text) : Bool {
    if (Text.size(address) != 42 or not Text.startsWith(address, #text "0x")) return false;
    var i : Nat = 0;
    for (ch in Text.toIter(address)) {
      if (i >= 2 and not isHex(ch)) return false;
      i += 1;
    };
    true;
  };

  private func validLedgerId(address : Text) : Bool {
    // Metadata-only structural validation. An actual transfer integration
    // must validate Principal checksum and query the ledger's ICRC metadata.
    if (Text.size(address) < 10 or Text.size(address) > 64) return false;
    for (ch in Text.toIter(address)) {
      let n = Char.toNat32(ch);
      if (not ((n >= 97 and n <= 122) or (n >= 50 and n <= 55) or n == 45)) return false;
    };
    true;
  };

  private func validAssetReference(def : Types.CurrencyDefinition, ref : Types.AssetReference) : Bool {
    if (def.kind == "fiat") {
      return ref.standard == "fiat" and ref.network == "" and ref.address == "";
    };
    if (not validNetwork(ref.network)) return false;
    switch (ref.standard) {
      case ("native") { ref.address == "" };
      case ("erc20") {
        Text.startsWith(ref.network, #text "eip155:") and
        Text.size(ref.network) > 7 and validEvmAddress(ref.address)
      };
      case ("icrc") {
        (ref.network == "ic:mainnet" or ref.network == "ic:local") and
        validLedgerId(ref.address)
      };
      case (_) false;
    };
  };

  private func sameAssetReference(a : Types.AssetReference, b : Types.AssetReference) : Bool {
    a.network == b.network and a.standard == b.standard and a.address == b.address;
  };

  private func userAssetReference(owner : Principal, code : Text) : ?Types.AssetReference {
    switch (Array.find<(Principal, Text, Types.AssetReference)>(
      userAssetReferences, func(entry) { entry.0 == owner and entry.1 == code }
    )) {
      case (?( _, _, ref )) ?ref;
      case null null;
    };
  };

  private func referenceOf(loanId : Nat) : Types.AssetReference {
    switch (Array.find<(Nat, Types.AssetReference)>(
      loanAssetReferences, func(entry) { entry.0 == loanId }
    )) {
      case (?( _, ref )) ref;
      case null {
        // Legacy custom crypto loans may predate on-chain asset identity:
        // clearly mark as unverified, rather than inventing a contract ID.
        switch (builtinAssetReference(currencyOf(loanId))) {
          case (?ref) ref;
          case null assetRef("", "unverified", "");
        };
      };
    };
  };

  private func validDefinition(def : Types.CurrencyDefinition) : Bool {
    if (Text.size(def.code) < 2 or Text.size(def.code) > 12 or Text.size(def.symbol) > 12 or
        def.decimals > 18 or (def.kind != "fiat" and def.kind != "crypto")) return false;
    if (Text.contains(def.symbol, #char '\n') or Text.contains(def.symbol, #char '\r') or
        Text.contains(def.symbol, #char '\t')) return false;
    for (ch in Text.toIter(def.code)) {
      let n = Char.toNat32(ch);
      if (not ((n >= 65 and n <= 90) or (n >= 48 and n <= 57))) return false;
    };
    true;
  };

  private func sameDefinition(a : Types.CurrencyDefinition, b : Types.CurrencyDefinition) : Bool {
    a.code == b.code and a.symbol == b.symbol and
    a.decimals == b.decimals and a.kind == b.kind;
  };

  private func ownedCurrency(owner : Principal, code : Text) : ?Types.CurrencyDefinition {
    switch (Array.find<(Principal, Types.CurrencyDefinition)>(
      userCurrencies, func(pair) { pair.0 == owner and pair.1.code == code }
    )) {
      case (?(_, def)) ?def;
      case null null;
    };
  };

  private func allowedDefinition(caller : Principal, def : Types.CurrencyDefinition) : Bool {
    if (not validDefinition(def)) return false;
    switch (builtinCurrency(def.code)) {
      case (?preset) sameDefinition(def, preset);
      case null switch (ownedCurrency(caller, def.code)) {
        case (?custom) sameDefinition(def, custom);
        case null false;
      };
    };
  };

  private func currencyOf(loanId : Nat) : Text {
    switch (Array.find<(Nat, Text)>(loanCurrencies, func(pair) { pair.0 == loanId })) {
      case (?(_, code)) code;
      case null "CAD"; // Legacy v0.1 loans were always CAD.
    };
  };

  private func definitionOf(loanId : Nat) : Types.CurrencyDefinition {
    switch (Array.find<(Nat, Types.CurrencyDefinition)>(
      loanCurrencyDefinitions, func(pair) { pair.0 == loanId }
    )) {
      case (?(_, def)) def;
      case null switch (builtinCurrency(currencyOf(loanId))) {
        case (?preset) preset; // v0.1/v0.2 historic CAD, USD, EUR, GBP, CNY
        case null makeCurrency(currencyOf(loanId), "", 2, "fiat");
      };
    };
  };

  // User preferences do not affect the immutable metadata of existing loans.
  public shared query ({ caller }) func getMyCurrencies() : async R<[Types.CurrencyDefinition]> {
    if (Principal.isAnonymous(caller)) return #err("Authentication required");
    #ok(Array.map<(Principal, Types.CurrencyDefinition), Types.CurrencyDefinition>(
      Array.filter<(Principal, Types.CurrencyDefinition)>(
        userCurrencies, func(pair) { pair.0 == caller }
      ), func(pair) { pair.1 }
    ));
  };

  public shared ({ caller }) func upsertMyCurrency(def : Types.CurrencyDefinition) : async R<()> {
    if (Principal.isAnonymous(caller)) return #err("Authentication required");
    if (not validDefinition(def)) return #err("Invalid code, symbol, kind or decimals (0–18)");
    switch (builtinCurrency(def.code)) {
      case (?_) return #err("Built-in currency definitions cannot be edited");
      case null {};
    };
    switch (ownedCurrency(caller, def.code)) {
      case null {
        let count = Array.filter<(Principal, Types.CurrencyDefinition)>(
          userCurrencies, func(pair) { pair.0 == caller }
        ).size();
        if (count >= 40) return #err("Maximum 40 custom currencies per user");
        userCurrencies := Array.append(userCurrencies, [(caller, def)]);
      };
      case (?_) {
        userCurrencies := Array.map<(Principal, Types.CurrencyDefinition), (Principal, Types.CurrencyDefinition)>(
          userCurrencies, func(pair) {
            if (pair.0 == caller and pair.1.code == def.code) (caller, def) else pair
          }
        );
      };
    };
    #ok(());
  };

  // New callers must save the definition AND network/contract atomically.
  // Older upsertMyCurrency is retained for fiat/legacy clients only.
  public shared ({ caller }) func upsertMyCurrencyWithReference(
    def : Types.CurrencyDefinition, ref : Types.AssetReference
  ) : async R<()> {
    if (Principal.isAnonymous(caller)) return #err("Authentication required");
    if (not validDefinition(def) or not validAssetReference(def, ref))
      return #err("Invalid currency or network/contract/ledger reference");
    switch (builtinCurrency(def.code)) {
      case (?_) return #err("Built-in currency definitions cannot be edited");
      case null {};
    };
    switch (ownedCurrency(caller, def.code)) {
      case null {
        let count = Array.filter<(Principal, Types.CurrencyDefinition)>(
          userCurrencies, func(pair) { pair.0 == caller }
        ).size();
        if (count >= 40) return #err("Maximum 40 custom currencies per user");
        userCurrencies := Array.append(userCurrencies, [(caller, def)]);
      };
      case (?_) {
        userCurrencies := Array.map<(Principal, Types.CurrencyDefinition), (Principal, Types.CurrencyDefinition)>(
          userCurrencies, func(pair) {
            if (pair.0 == caller and pair.1.code == def.code) (caller, def) else pair
          }
        );
      };
    };
    userAssetReferences := Array.append<(Principal, Text, Types.AssetReference)>(
      Array.filter<(Principal, Text, Types.AssetReference)>(
        userAssetReferences, func(entry) { not (entry.0 == caller and entry.1 == def.code) }
      ),
      [(caller, def.code, ref)]
    );
    #ok(());
  };

  public shared query ({ caller }) func getMyAssetReferences() : async R<[(Text, Types.AssetReference)]> {
    if (Principal.isAnonymous(caller)) return #err("Authentication required");
    #ok(Array.map<(Principal, Text, Types.AssetReference), (Text, Types.AssetReference)>(
      Array.filter<(Principal, Text, Types.AssetReference)>(
        userAssetReferences, func(entry) { entry.0 == caller }
      ), func(entry) { (entry.1, entry.2) }
    ));
  };

  public shared query ({ caller }) func getLoanAssetReference(loanId : Nat) : async R<Types.AssetReference> {
    switch (requireParticipant(loanId, caller)) {
      case (#err(e)) #err(e);
      case (#ok(_)) #ok(referenceOf(loanId));
    };
  };

  public shared ({ caller }) func deleteMyCurrency(code : Text) : async R<()> {
    if (Principal.isAnonymous(caller)) return #err("Authentication required");
    if (ownedCurrency(caller, code) == null) return #err("Custom currency not found");
    userCurrencies := Array.filter<(Principal, Types.CurrencyDefinition)>(
      userCurrencies, func(pair) { not (pair.0 == caller and pair.1.code == code) }
    );
    userAssetReferences := Array.filter<(Principal, Text, Types.AssetReference)>(
      userAssetReferences, func(entry) { not (entry.0 == caller and entry.1 == code) }
    );
    #ok(());
  };

  private func replaceLoan(next : Loan) {
    loans := Array.map<Loan, Loan>(loans, func(x) {
      if (x.id == next.id) next else x;
    });
  };

  private func replaceEntry(next : Entry) {
    entries := Array.map<Entry, Entry>(entries, func(x) {
      if (x.id == next.id) next else x;
    });
  };

  private func confirmedCandidate(original : Entry) : [Entry] {
    Array.map<Entry, Entry>(entries, func(x) {
      if (x.id == original.id) {
        { original with status = #confirmed; updatedAt = Time.now() }
      } else x;
    });
  };

  private func newEntry(
    loanId : Nat,
    kind : Types.EntryKind,
    amountCents : Nat,
    caller : Principal,
    requestId : Text,
    status : Types.EntryStatus,
    effectiveAt : ?Int,
    method : Text,
    note : Text,
  ) : Entry {
    let now = Time.now();
    let entry : Entry = {
      id = nextEntryId;
      loanId;
      kind;
      amountCents;
      proposedBy = caller;
      clientRequestId = requestId;
      effectiveAt;
      method;
      note;
      status;
      fundingDeclaredBy = null;
      confirmedBy = null;
      createdAt = now;
      updatedAt = now;
    };
    nextEntryId += 1;
    entries := Array.append<Entry>(entries, [entry]);
    entry;
  };

  private func requireParticipant(loanId : Nat, caller : Principal) : R<Loan> {
    switch (loanById(loanId)) {
      case (?loan) {
        if (participant(loan, caller)) #ok(loan) else #err("Loan unavailable");
      };
      case null #err("Loan unavailable");
    };
  };

  private func canConfirmEntry(loan : Loan, entry : Entry, caller : Principal) : Bool {
    switch (entry.kind) {
      case (#initialBorrowing) { caller == loan.borrower and entry.fundingDeclaredBy == ?loan.lender };
      case (#additionalBorrowing) { caller == loan.borrower and entry.fundingDeclaredBy == ?loan.lender };
      case (_) { caller == otherParty(loan, entry.proposedBy) };
    };
  };

  // Currency is immutable once a loan has been proposed. Keep the old
  // createPersonalLoan signature for existing UIs/Candid clients (CAD default).
  public shared ({ caller }) func createPersonalLoan(
    borrower : Principal,
    lender : Principal,
    initialAmountCents : Nat,
    dueAt : ?Int,
    note : Text,
    requestId : Text,
  ) : async R<Nat> {
    createLoan(caller, borrower, lender, initialAmountCents, "CAD", null, dueAt, note, requestId);
  };

  public shared ({ caller }) func createPersonalLoanWithCurrency(
    borrower : Principal,
    lender : Principal,
    initialAmountMinor : Nat,
    currency : Text,
    dueAt : ?Int,
    note : Text,
    requestId : Text,
  ) : async R<Nat> {
    createLoan(caller, borrower, lender, initialAmountMinor, currency, null, dueAt, note, requestId);
  };

  // The new API accepts a caller-approved catalog definition. The exact
  // decimals/symbol/type are snapshotted and visible to BOTH parties.
  public shared ({ caller }) func createPersonalLoanWithAsset(
    borrower : Principal,
    lender : Principal,
    amountMinor : Nat,
    asset : Types.CurrencyDefinition,
    dueAt : ?Int,
    note : Text,
    requestId : Text,
  ) : async R<Nat> {
    createLoan(caller, borrower, lender, amountMinor, asset.code, ?asset, dueAt, note, requestId);
  };

  private func createLoan(
    caller : Principal,
    borrower : Principal,
    lender : Principal,
    initialAmountCents : Nat,
    currency : Text,
    asset : ?Types.CurrencyDefinition,
    dueAt : ?Int,
    note : Text,
    requestId : Text,
  ) : R<Nat> {
    if (Principal.isAnonymous(caller) or Principal.isAnonymous(borrower) or Principal.isAnonymous(lender)) {
      return #err("Authentication required");
    };
    if (borrower == lender or (caller != borrower and caller != lender)) {
      return #err("Distinct borrower and lender required; creator must be a participant");
    };
    if (initialAmountCents == 0 or not validRequestId(requestId) or not validNote(note)) {
      return #err("Invalid amount, request ID or note");
    };
    switch (Array.find<Loan>(loans, func(x) {
      x.createdBy == caller and x.clientRequestId == requestId;
    })) {
      case (?existing) {
        if (existing.borrower == borrower and existing.lender == lender and
            existing.originalAmountCents == initialAmountCents and
            existing.dueAt == dueAt and existing.note == note and
            currencyOf(existing.id) == currency and
            (switch (asset) {
              case null true;
              case (?def) sameDefinition(definitionOf(existing.id), def);
            })) {
          return #ok(existing.id);
        };
        return #err("Request ID conflict");
      };
      case null {};
    };
    switch (asset) {
      case (null) {
        if (not supportedCurrency(currency)) {
          return #err("Use createPersonalLoanWithAsset for crypto or custom currencies");
        };
      };
      case (?def) {
        if (def.code != currency or not allowedDefinition(caller, def)) {
          return #err("Currency definition is not in your catalog or has mismatched precision");
        };
      };
    };
    let now = Time.now();
    let loan : Loan = {
      id = nextLoanId;
      borrower;
      lender;
      createdBy = caller;
      clientRequestId = requestId;
      originalAmountCents = initialAmountCents;
      interestRateBps = 0;
      dueAt;
      note;
      status = #proposed;
      closureRequestedBy = null;
      createdAt = now;
      updatedAt = now;
    };
    nextLoanId += 1;
    loans := Array.append<Loan>(loans, [loan]);
    loanCurrencies := Array.append<(Nat, Text)>(loanCurrencies, [(loan.id, currency)]);
    let snapshot = switch (asset) {
      case (?def) def;
      case null switch (builtinCurrency(currency)) {
        case (?builtin) builtin;
        case null makeCurrency(currency, "", 2, "fiat");
      };
    };
    loanCurrencyDefinitions := Array.append<(Nat, Types.CurrencyDefinition)>(
      loanCurrencyDefinitions, [(loan.id, snapshot)]
    );
    appendEvent(loan.id, null, #loanProposed, caller);
    #ok(loan.id);
  };

  public shared ({ caller }) func acceptLoan(loanId : Nat) : async R<Nat> {
    let loan = switch (requireParticipant(loanId, caller)) {
      case (#err(e)) return #err(e);
      case (#ok(value)) value;
    };
    if (loan.status != #proposed or caller == loan.createdBy) {
      return #err("Only the invited counterparty can accept proposed terms");
    };
    let initial = newEntry(
      loanId, #initialBorrowing, loan.originalAmountCents, loan.createdBy,
      "initial:" # Nat.toText(loanId), #pendingFunding, null, "", "Initial borrowing",
    );
    replaceLoan({ loan with status = #fundingPending; updatedAt = Time.now() });
    appendEvent(loanId, ?initial.id, #loanAccepted, caller);
    #ok(initial.id);
  };

  public shared ({ caller }) func rejectLoan(loanId : Nat) : async R<()> {
    let loan = switch (requireParticipant(loanId, caller)) {
      case (#err(e)) return #err(e);
      case (#ok(value)) value;
    };
    if (loan.status != #proposed or caller == loan.createdBy) {
      return #err("Only the invited counterparty can reject proposed terms");
    };
    replaceLoan({ loan with status = #rejected; updatedAt = Time.now() });
    appendEvent(loanId, null, #loanRejected, caller);
    #ok(());
  };

  public shared ({ caller }) func requestAdditionalBorrowing(
    loanId : Nat,
    amountCents : Nat,
    note : Text,
    requestId : Text,
  ) : async R<Nat> {
    let loan = switch (requireParticipant(loanId, caller)) {
      case (#err(e)) return #err(e);
      case (#ok(value)) value;
    };
    if (not validRequestId(requestId) or not validNote(note)) return #err("Invalid request");
    switch (findRequest(loanId, caller, requestId)) {
      case (?existing) {
        if (existing.kind == #additionalBorrowing and existing.amountCents == amountCents and existing.note == note)
          return #ok(existing.id);
        return #err("Request ID conflict");
      };
      case null {};
    };
    if (loan.status != #active or amountCents == 0) return #err("Loan must be active and amount positive");
    let created = newEntry(
      loanId, #additionalBorrowing, amountCents, caller, requestId,
      #pendingTerms, null, "", note,
    );
    appendEvent(loanId, ?created.id, #additionalBorrowingRequested, caller);
    #ok(created.id);
  };

  public shared ({ caller }) func acceptAdditionalBorrowing(loanId : Nat, entryId : Nat) : async R<()> {
    let loan = switch (requireParticipant(loanId, caller)) {
      case (#err(e)) return #err(e);
      case (#ok(value)) value;
    };
    let entry = switch (entryById(loanId, entryId)) {
      case null return #err("Entry unavailable");
      case (?value) value;
    };
    if (loan.status != #active or entry.kind != #additionalBorrowing or entry.status != #pendingTerms or caller == entry.proposedBy) {
      return #err("Only the counterpart can accept pending borrowing terms");
    };
    replaceEntry({ entry with status = #pendingFunding; updatedAt = Time.now() });
    appendEvent(loanId, ?entryId, #additionalBorrowingAccepted, caller);
    #ok(());
  };

  public shared ({ caller }) func rejectAdditionalBorrowing(loanId : Nat, entryId : Nat) : async R<()> {
    ignore switch (requireParticipant(loanId, caller)) {
      case (#err(e)) return #err(e);
      case (#ok(value)) value;
    };
    let entry = switch (entryById(loanId, entryId)) {
      case null return #err("Entry unavailable");
      case (?value) value;
    };
    if (entry.kind != #additionalBorrowing or entry.status != #pendingTerms or caller == entry.proposedBy) {
      return #err("Only the counterpart can reject pending borrowing terms");
    };
    replaceEntry({ entry with status = #rejected; updatedAt = Time.now() });
    appendEvent(loanId, ?entryId, #additionalBorrowingRejected, caller);
    #ok(());
  };

  // The creator may withdraw an unaccepted request or a disputed entry.
  // Funded borrowing declarations cannot be retracted unilaterally.
  public shared ({ caller }) func withdrawPendingEntry(loanId : Nat, entryId : Nat) : async R<()> {
    ignore switch (requireParticipant(loanId, caller)) {
      case (#err(e)) return #err(e);
      case (#ok(value)) value;
    };
    let entry = switch (entryById(loanId, entryId)) {
      case null return #err("Entry unavailable");
      case (?value) value;
    };
    if (entry.proposedBy != caller) return #err("Only the requester can withdraw an entry");
    let cancellable = switch (entry.status) {
      case (#pendingTerms) true;
      case (#disputed) {
        // Once the lender has declared a borrowing delivered, the borrower
        // must not be able to erase the disputed delivery single-handedly.
        switch (entry.kind) {
          case (#repayment) true;
          case (#reversal(_)) true;
          case (_) false;
        };
      };
      case (#pendingConfirmation) {
        switch (entry.kind) {
          case (#repayment) true;
          case (#reversal(_)) true;
          case (_) false;
        };
      };
      case (_) false;
    };
    if (not cancellable) return #err("Entry cannot be withdrawn in this state");
    replaceEntry({ entry with status = #rejected; updatedAt = Time.now() });
    appendEvent(loanId, ?entryId, #entryWithdrawn, caller);
    #ok(());
  };

  // Two explicit authorizations are required to cancel accepted borrowing
  // while funding has NOT been declared. The first party requests; the
  // counterparty's call approves. No funds are recorded, and no party may
  // cancel a declared, disputed or confirmed transfer unilaterally.
  //
  // Bool: false = pending the counterparty; true = cancelled by both parties.
  public shared ({ caller }) func requestFundingCancellation(
    loanId : Nat,
    entryId : Nat,
  ) : async R<Bool> {
    let loan = switch (requireParticipant(loanId, caller)) {
      case (#err(e)) return #err(e);
      case (#ok(value)) value;
    };
    let entry = switch (entryById(loanId, entryId)) {
      case null return #err("Entry unavailable");
      case (?value) value;
    };
    if (entry.status != #pendingFunding) {
      return #err("Only accepted but undelivered borrowing can be cancelled");
    };
    switch (entry.kind) {
      case (#initialBorrowing) {
        if (loan.status != #fundingPending) return #err("Initial loan is not awaiting funding");
      };
      case (#additionalBorrowing) {
        if (loan.status != #active) return #err("Loan is not active");
      };
      case (_) return #err("Not a borrowing entry");
    };
    let existing = Array.find<Types.FundingCancellationRequest>(
      fundingCancellationRequests,
      func(x) { x.loanId == loanId and x.entryId == entryId },
    );
    switch (existing) {
      case null {
        fundingCancellationRequests := Array.append<Types.FundingCancellationRequest>(
          fundingCancellationRequests,
          [{ loanId; entryId; requestedBy = caller; createdAt = Time.now() }],
        );
        appendEvent(loanId, ?entryId, #fundingCancellationRequested, caller);
        #ok(false);
      };
      case (?request) {
        if (request.requestedBy == caller) {
          // Idempotent repeat; never count a single caller twice.
          return #ok(false);
        };
        // Both participants have now approved cancellation. A pending entry
        // never contributed to the confirmed ledger balance.
        fundingCancellationRequests := Array.filter<Types.FundingCancellationRequest>(
          fundingCancellationRequests,
          func(x) { not (x.loanId == loanId and x.entryId == entryId) },
        );
        replaceEntry({ entry with status = #rejected; updatedAt = Time.now() });
        if (entry.kind == #initialBorrowing) {
          replaceLoan({ loan with status = #rejected; updatedAt = Time.now() });
        };
        appendEvent(loanId, ?entryId, #fundingCancelled, caller);
        #ok(true);
      };
    };
  };

  // The requester can retract their still-unapproved cancellation request.
  public shared ({ caller }) func withdrawFundingCancellationRequest(
    loanId : Nat,
    entryId : Nat,
  ) : async R<()> {
    ignore switch (requireParticipant(loanId, caller)) {
      case (#err(e)) return #err(e);
      case (#ok(value)) value;
    };
    let current = switch (entryById(loanId, entryId)) {
      case null return #err("Entry unavailable");
      case (?value) value;
    };
    if (current.status != #pendingFunding) return #err("Funding is no longer pending");
    let requester = Array.find<Types.FundingCancellationRequest>(
      fundingCancellationRequests,
      func(x) { x.loanId == loanId and x.entryId == entryId },
    );
    switch (requester) {
      case null return #err("No cancellation request exists");
      case (?request) {
        if (request.requestedBy != caller) return #err("Only the requester can retract cancellation");
      };
    };
    fundingCancellationRequests := Array.filter<Types.FundingCancellationRequest>(
      fundingCancellationRequests,
      func(x) { not (x.loanId == loanId and x.entryId == entryId) },
    );
    appendEvent(loanId, ?entryId, #entryWithdrawn, caller);
    #ok(());
  };

  // Borrowing only affects the ledger after a separate lender delivery
  // declaration and borrower acknowledgement.
  public shared ({ caller }) func declareFunding(
    loanId : Nat,
    entryId : Nat,
    effectiveAt : Int,
    method : Text,
  ) : async R<()> {
    let loan = switch (requireParticipant(loanId, caller)) {
      case (#err(e)) return #err(e);
      case (#ok(value)) value;
    };
    let entry = switch (entryById(loanId, entryId)) {
      case null return #err("Entry unavailable");
      case (?value) value;
    };
    if (caller != loan.lender or (entry.status != #pendingFunding and entry.status != #disputed) or Text.size(method) > 100) {
      return #err("Only the lender can declare pending funding");
    };
    switch (entry.kind) {
      case (#initialBorrowing) {
        if (loan.status != #fundingPending) return #err("Initial loan is not awaiting funding");
      };
      case (#additionalBorrowing) {
        if (loan.status != #active) return #err("Loan is not active");
      };
      case (_) return #err("Not a borrowing entry");
    };
    // Delivery supersedes a not-yet-agreed cancellation proposal; it cannot
    // later cancel money that either party has declared delivered.
    fundingCancellationRequests := Array.filter<Types.FundingCancellationRequest>(
      fundingCancellationRequests,
      func(x) { not (x.loanId == loanId and x.entryId == entryId) },
    );
    replaceEntry({
      entry with
      status = #pendingConfirmation;
      effectiveAt = ?effectiveAt;
      method;
      fundingDeclaredBy = ?caller;
      updatedAt = Time.now();
    });
    appendEvent(loanId, ?entryId, #fundingDeclared, caller);
    #ok(());
  };

  public shared ({ caller }) func confirmFunding(loanId : Nat, entryId : Nat) : async R<()> {
    let loan = switch (requireParticipant(loanId, caller)) {
      case (#err(e)) return #err(e);
      case (#ok(value)) value;
    };
    let entry = switch (entryById(loanId, entryId)) {
      case null return #err("Entry unavailable");
      case (?value) value;
    };
    if (entry.status != #pendingConfirmation or not canConfirmEntry(loan, entry, caller)) {
      return #err("Borrower must acknowledge lender-declared delivery");
    };
    switch (entry.kind) {
      case (#initialBorrowing) {
        if (loan.status != #fundingPending) return #err("Invalid initial funding state");
      };
      case (#additionalBorrowing) {
        if (loan.status != #active) return #err("Loan is not active");
      };
      case (_) return #err("Not a borrowing entry");
    };
    replaceEntry({ entry with status = #confirmed; confirmedBy = ?caller; updatedAt = Time.now() });
    if (entry.kind == #initialBorrowing) {
      replaceLoan({ loan with status = #active; updatedAt = Time.now() });
    };
    appendEvent(loanId, ?entryId, #fundingConfirmed, caller);
    #ok(());
  };

  public shared ({ caller }) func submitRepayment(
    loanId : Nat,
    amountCents : Nat,
    effectiveAt : Int,
    method : Text,
    note : Text,
    requestId : Text,
  ) : async R<Nat> {
    let loan = switch (requireParticipant(loanId, caller)) {
      case (#err(e)) return #err(e);
      case (#ok(value)) value;
    };
    if (not validRequestId(requestId) or not validNote(note) or Text.size(method) > 100) {
      return #err("Invalid request");
    };
    switch (findRequest(loanId, caller, requestId)) {
      case (?existing) {
        if (existing.kind == #repayment and existing.amountCents == amountCents and
            existing.effectiveAt == ?effectiveAt and existing.method == method and existing.note == note)
          return #ok(existing.id);
        return #err("Request ID conflict");
      };
      case null {};
    };
    let balance = Ledger.calculate(loanId, entries);
    if (loan.status != #active or amountCents == 0 or amountCents > balance.outstandingCents) {
      return #err("Invalid repayment amount or loan status");
    };
    let created = newEntry(
      loanId, #repayment, amountCents, caller, requestId,
      #pendingConfirmation, ?effectiveAt, method, note,
    );
    appendEvent(loanId, ?created.id, #repaymentSubmitted, caller);
    #ok(created.id);
  };

  public shared ({ caller }) func confirmRepayment(loanId : Nat, entryId : Nat) : async R<()> {
    let loan = switch (requireParticipant(loanId, caller)) {
      case (#err(e)) return #err(e);
      case (#ok(value)) value;
    };
    let entry = switch (entryById(loanId, entryId)) {
      case null return #err("Entry unavailable");
      case (?value) value;
    };
    if (loan.status != #active or entry.kind != #repayment or entry.status != #pendingConfirmation or not canConfirmEntry(loan, entry, caller)) {
      return #err("Only the other party may confirm a pending repayment");
    };
    let candidate = confirmedCandidate(entry);
    if (not Ledger.validBalance(loanId, candidate)) return #err("Repayment exceeds outstanding principal");
    replaceEntry({ entry with status = #confirmed; confirmedBy = ?caller; updatedAt = Time.now() });
    appendEvent(loanId, ?entryId, #repaymentConfirmed, caller);
    #ok(());
  };

  public shared ({ caller }) func disputeEntry(loanId : Nat, entryId : Nat) : async R<()> {
    let loan = switch (requireParticipant(loanId, caller)) {
      case (#err(e)) return #err(e);
      case (#ok(value)) value;
    };
    let entry = switch (entryById(loanId, entryId)) {
      case null return #err("Entry unavailable");
      case (?value) value;
    };
    if (entry.status != #pendingConfirmation or not canConfirmEntry(loan, entry, caller)) {
      return #err("Only the awaiting counterparty may dispute a pending entry");
    };
    replaceEntry({ entry with status = #disputed; updatedAt = Time.now() });
    appendEvent(loanId, ?entryId, #entryDisputed, caller);
    #ok(());
  };

  public shared ({ caller }) func requestReversal(
    loanId : Nat,
    originalEntryId : Nat,
    note : Text,
    requestId : Text,
  ) : async R<Nat> {
    let loan = switch (requireParticipant(loanId, caller)) {
      case (#err(e)) return #err(e);
      case (#ok(value)) value;
    };
    if (not validRequestId(requestId) or not validNote(note)) return #err("Invalid request");
    switch (findRequest(loanId, caller, requestId)) {
      case (?existing) {
        if (existing.kind == #reversal(originalEntryId) and existing.note == note)
          return #ok(existing.id);
        return #err("Request ID conflict");
      };
      case null {};
    };
    if (loan.status != #active) return #err("Loan is not active");
    let original = switch (entryById(loanId, originalEntryId)) {
      case null return #err("Entry unavailable");
      case (?value) value;
    };
    if (original.status != #confirmed) return #err("Only confirmed entries may be reversed");
    switch (original.kind) {
      case (#reversal(_)) return #err("A reversal cannot be reversed");
      case (_) {};
    };
    for (e in entries.vals()) {
      if (e.loanId == loanId) {
        switch (e.kind) {
          case (#reversal(target)) {
            if (target == originalEntryId and e.status != #rejected and e.status != #disputed)
              return #err("Existing reversal request");
          };
          case (_) {};
        };
      };
    };
    let created = newEntry(
      loanId, #reversal(originalEntryId), original.amountCents, caller, requestId,
      #pendingConfirmation, ?Time.now(), "", note,
    );
    appendEvent(loanId, ?created.id, #reversalRequested, caller);
    #ok(created.id);
  };

  public shared ({ caller }) func confirmReversal(loanId : Nat, entryId : Nat) : async R<()> {
    let loan = switch (requireParticipant(loanId, caller)) {
      case (#err(e)) return #err(e);
      case (#ok(value)) value;
    };
    let entry = switch (entryById(loanId, entryId)) {
      case null return #err("Entry unavailable");
      case (?value) value;
    };
    if (loan.status != #active or entry.status != #pendingConfirmation or not canConfirmEntry(loan, entry, caller)) {
      return #err("Only the other party may confirm a pending reversal");
    };
    switch (entry.kind) {
      case (#reversal(originalId)) {
        if (Ledger.confirmedReversalExists(loanId, originalId, entries)) return #err("Already reversed");
        let candidate = confirmedCandidate(entry);
        if (not Ledger.validBalance(loanId, candidate)) return #err("Reversal would make balance negative");
      };
      case (_) return #err("Not a reversal");
    };
    replaceEntry({ entry with status = #confirmed; confirmedBy = ?caller; updatedAt = Time.now() });
    appendEvent(loanId, ?entryId, #reversalConfirmed, caller);
    #ok(());
  };

  public shared ({ caller }) func requestClosure(loanId : Nat) : async R<()> {
    let loan = switch (requireParticipant(loanId, caller)) {
      case (#err(e)) return #err(e);
      case (#ok(value)) value;
    };
    if (loan.status != #active or Ledger.calculate(loanId, entries).outstandingCents != 0) {
      return #err("Only a zero-balance active loan may be closed");
    };
    for (entry in entries.vals()) {
      if (entry.loanId == loanId and entry.status != #confirmed and entry.status != #rejected) {
        return #err("Resolve pending or disputed entries before closure");
      };
    };
    replaceLoan({
      loan with
      status = #readyToClose;
      closureRequestedBy = ?caller;
      updatedAt = Time.now();
    });
    appendEvent(loanId, null, #closureRequested, caller);
    #ok(());
  };

  public shared ({ caller }) func confirmClosure(loanId : Nat) : async R<()> {
    let loan = switch (requireParticipant(loanId, caller)) {
      case (#err(e)) return #err(e);
      case (#ok(value)) value;
    };
    if (loan.status != #readyToClose or loan.closureRequestedBy != ?otherParty(loan, caller) or
        Ledger.calculate(loanId, entries).outstandingCents != 0) {
      return #err("Only the other party may confirm a zero-balance closure");
    };
    replaceLoan({
      loan with
      status = #closed;
      closureRequestedBy = null;
      updatedAt = Time.now();
    });
    appendEvent(loanId, null, #loanClosed, caller);
    #ok(());
  };

  // Read the audit log with the same loan participant ACL as financial entries.
  // Entries are append-only; a status change never deletes the old event.
  public shared query ({ caller }) func getLoanEvents(
    loanId : Nat,
    offset : Nat,
    limit : Nat,
  ) : async R<[Types.LoanEvent]> {
    switch (requireParticipant(loanId, caller)) {
      case (#err(e)) #err(e);
      case (#ok(_)) {
        if (limit == 0 or limit > 100) return #err("Limit must be between 1 and 100");
        let matching = Array.filter<Types.LoanEvent>(events, func(x) { x.loanId == loanId });
        let length = matching.size();
        if (offset >= length) return #ok([]);
        let available = length - offset;
        let count = if (limit > available) available else limit;
        // Newest first: the first page is the latest 100 events rather
        // than silently truncating the latest activity.
        #ok(Array.tabulate<Types.LoanEvent>(count, func(i) {
          matching[length - (offset + i + 1)]
        }));
      };
    };
  };

  // Never expose unfiltered loan or ledger enumeration.
  public shared query ({ caller }) func getMyLoans() : async [Loan] {
    Array.filter<Loan>(loans, func(x) { participant(x, caller) });
  };

  public shared query ({ caller }) func getLoan(loanId : Nat) : async R<Loan> {
    requireParticipant(loanId, caller);
  };

  public shared query ({ caller }) func getLoanCurrencyDefinition(
    loanId : Nat
  ) : async R<Types.CurrencyDefinition> {
    switch (requireParticipant(loanId, caller)) {
      case (#err(e)) #err(e);
      case (#ok(_)) #ok(definitionOf(loanId));
    };
  };

  public shared query ({ caller }) func getLoanCurrency(loanId : Nat) : async R<Text> {
    switch (requireParticipant(loanId, caller)) {
      case (#err(e)) #err(e);
      case (#ok(_)) #ok(currencyOf(loanId));
    };
  };

  public shared query ({ caller }) func getFundingCancellationRequests(
    loanId : Nat,
  ) : async R<[Types.FundingCancellationRequest]> {
    switch (requireParticipant(loanId, caller)) {
      case (#err(e)) #err(e);
      case (#ok(_)) {
        #ok(Array.filter<Types.FundingCancellationRequest>(
          fundingCancellationRequests,
          func(x) { x.loanId == loanId },
        ));
      };
    };
  };

  public shared query ({ caller }) func getLoanEntries(loanId : Nat) : async R<[Entry]> {
    switch (requireParticipant(loanId, caller)) {
      case (#err(e)) #err(e);
      case (#ok(_)) #ok(Array.filter<Entry>(entries, func(x) { x.loanId == loanId }));
    };
  };

  public shared query ({ caller }) func getBalance(loanId : Nat) : async R<Balance> {
    switch (requireParticipant(loanId, caller)) {
      case (#err(e)) #err(e);
      case (#ok(_)) #ok(Ledger.calculate(loanId, entries));
    };
  };
};
