import Array "mo:base/Array";
import Types "types";

// All balance calculations are derived from confirmed entries.
// A confirmed reversal excludes its original entry, preserving both for audit.
module {
  type Entry = Types.Entry;
  public type Balance = Types.Balance;

  private func isReversed(original : Entry, entries : [Entry]) : Bool {
    for (entry in entries.vals()) {
      if (entry.loanId == original.loanId and entry.status == #confirmed) {
        switch (entry.kind) {
          case (#reversal(target)) {
            if (target == original.id) return true;
          };
          case (_) {};
        };
      };
    };
    false;
  };

  public func calculate(loanId : Nat, entries : [Entry]) : Balance {
    var borrowed : Nat = 0;
    var repaid : Nat = 0;
    for (entry in entries.vals()) {
      if (entry.loanId == loanId and entry.status == #confirmed and not isReversed(entry, entries)) {
        switch (entry.kind) {
          case (#initialBorrowing) { borrowed += entry.amountCents };
          case (#additionalBorrowing) { borrowed += entry.amountCents };
          case (#repayment) { repaid += entry.amountCents };
          case (#reversal(_)) {}; // Reversals are represented by excluding original.
        };
      };
    };
    {
      totalBorrowedCents = borrowed;
      totalRepaidCents = repaid;
      outstandingCents = if (borrowed >= repaid) borrowed - repaid else 0;
    };
  };

  // Mutations call this on the candidate post-confirmation ledger, not an
  // earlier balance snapshot, to reject concurrent overpayment/reversal.
  public func validBalance(loanId : Nat, entries : [Entry]) : Bool {
    let state = calculate(loanId, entries);
    state.totalBorrowedCents >= state.totalRepaidCents;
  };

  public func confirmedReversalExists(loanId : Nat, targetId : Nat, entries : [Entry]) : Bool {
    for (entry in entries.vals()) {
      if (entry.loanId == loanId and entry.status == #confirmed) {
        switch (entry.kind) {
          case (#reversal(target)) { if (target == targetId) return true };
          case (_) {};
        };
      };
    };
    false;
  };
};
