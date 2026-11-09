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
    #fundingCancellationRequested;
    #fundingCancelled;
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
    performedBy : Principal;
    at : Int;
  };

  // Separate stable storage keeps previously persisted Loan and Entry shapes
  // unchanged. Only a participant can inspect these bilateral approvals.
  public type FundingCancellationRequest = {
    loanId : Nat;
    entryId : Nat;
    requestedBy : Principal;
    createdAt : Int;
  };

  // Immutable per-loan snapshot; separately persisted to retain the v0.1
  // Loan/Entry/Balance record shapes and safe legacy upgrades.
  public type CurrencyDefinition = {
    code : Text; // 2-12 uppercase ASCII letters/digits; token/network alias
    symbol : Text;
    decimals : Nat; // 0..18; immutable for each created loan
    kind : Text; // "fiat" | "crypto"
  };

  // Asset identity is versioned separately from CurrencyDefinition so that
  // stable Loan / Entry / earlier catalog records remain upgrade-compatible.
  // standard = "fiat" | "native" | "erc20" | "icrc".
  // address = token contract on EVM, ledger canister Principal for ICRC,
  // and empty for native or fiat. Network identifies the blockchain/chain.
  public type AssetReference = {
    network : Text;
    standard : Text;
    address : Text;
  };

  public type Balance = {
    totalBorrowedCents : Nat;
    totalRepaidCents : Nat;
    outstandingCents : Nat;
  };
};
