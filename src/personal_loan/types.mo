// Personal Loan v0.1: CAD-denominated, off-chain, two-party shared ledger.
module {
  public type LoanStatus = {
    #proposed;
    #fundingPending;
    #active;
    #readyToClose;
    #closed;
    #rejected;
  };

  public type EntryKind = {
    #initialBorrowing;
    #additionalBorrowing;
    #repayment;
    #reversal : Nat; // ID of the original confirmed entry
  };

  public type EntryStatus = {
    #pendingTerms;
    #pendingFunding;
    #pendingConfirmation;
    #confirmed;
    #disputed;
    #rejected;
  };

  public type Loan = {
    id : Nat;
    borrower : Principal;
    lender : Principal;
    createdBy : Principal;
    clientRequestId : Text;
    originalAmountCents : Nat;
    interestRateBps : Nat; // v0.1: always 0
    dueAt : ?Int;
    note : Text;
    status : LoanStatus;
    closureRequestedBy : ?Principal;
    createdAt : Int;
    updatedAt : Int;
  };

  public type Entry = {
    id : Nat;
    loanId : Nat;
    kind : EntryKind;
    amountCents : Nat;
    proposedBy : Principal;
    clientRequestId : Text;
    effectiveAt : ?Int;
    method : Text; // free-text external payment method; not payment proof
    note : Text;
    status : EntryStatus;
    fundingDeclaredBy : ?Principal;
    confirmedBy : ?Principal;
    createdAt : Int;
    updatedAt : Int;
  };

  // Append-only audit events preserve transitions even when an entry's
  // current pending/confirmed state changes later.
  public type EventKind = {
    #loanProposed;
    #loanAccepted;
    #loanRejected;
    #fundingDeclared;
    #fundingConfirmed;
    #additionalBorrowingRequested;
    #additionalBorrowingAccepted;
    #additionalBorrowingRejected;
    #repaymentSubmitted;
    #repaymentConfirmed;
    #entryDisputed;
    #entryWithdrawn;
    #reversalRequested;
    #reversalConfirmed;
    #closureRequested;
    #loanClosed;
  };

  public type LoanEvent = {
    id : Nat;
    loanId : Nat;
    entryId : ?Nat;
    kind : EventKind;
    actor : Principal;
    at : Int;
  };

  public type Balance = {
    totalBorrowedCents : Nat;
    totalRepaidCents : Nat;
    outstandingCents : Nat;
  };
};
