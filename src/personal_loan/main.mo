import Array "mo:base/Array";
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
  var entries : [Entry] = [];
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

  // Caller is always one of the actual parties; requestId is scoped to creator.
  public shared ({ caller }) func createPersonalLoan(
    borrower : Principal,
    lender : Principal,
    initialAmountCents : Nat,
    dueAt : ?Int,
    note : Text,
    requestId : Text,
  ) : async R<Nat> {
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
            existing.dueAt == dueAt and existing.note == note) {
          return #ok(existing.id);
        };
        return #err("Request ID conflict");
      };
      case null {};
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
