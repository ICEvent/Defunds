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

  public type Balance = {
    totalBorrowedCents : Nat;
    totalRepaidCents : Nat;
    outstandingCents : Nat;
  };
};
