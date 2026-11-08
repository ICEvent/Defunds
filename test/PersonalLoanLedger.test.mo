import Types "../src/personal_loan/types";
import Ledger "../src/personal_loan/ledger";
import Nat "mo:base/Nat";
import Principal "mo:base/Principal";

// Run: moc -r --package base "$(dfx cache show)/base" test/PersonalLoanLedger.test.mo

let user = Principal.fromText("aaaaa-aa");

func entry(id : Nat, kind : Types.EntryKind, amount : Nat, status : Types.EntryStatus) : Types.Entry {
  {
    id;
    loanId = 42;
    kind;
    amountCents = amount;
    proposedBy = user;
    clientRequestId = Nat.toText(id);
    effectiveAt = null;
    method = "";
    note = "";
    status;
    fundingDeclaredBy = null;
    confirmedBy = null;
    createdAt = 0;
    updatedAt = 0;
  };
};

let initial = entry(1, #initialBorrowing, 1_000_000, #confirmed); // CAD 10,000
let repay1 = entry(2, #repayment, 100_000, #confirmed); // CAD 1,000
let repay2 = entry(3, #repayment, 150_000, #confirmed); // CAD 1,500
let extra = entry(4, #additionalBorrowing, 300_000, #confirmed); // CAD 3,000
let repay3 = entry(5, #repayment, 200_000, #confirmed); // CAD 2,000
let pending = entry(6, #additionalBorrowing, 900_000, #pendingConfirmation);

let history = [initial, repay1, repay2, extra, repay3, pending];
let balance = Ledger.calculate(42, history);
assert (balance.totalBorrowedCents == 1_300_000);
assert (balance.totalRepaidCents == 450_000);
assert (balance.outstandingCents == 850_000);
assert (Ledger.validBalance(42, history));
assert (Ledger.calculate(43, history).outstandingCents == 0);

// A confirmed reversal of the 3,000 additional borrowing excludes it.
let rollbackExtra = entry(7, #reversal(4), 300_000, #confirmed);
let reversed = [initial, repay1, repay2, extra, repay3, rollbackExtra];
assert (Ledger.calculate(42, reversed).outstandingCents == 550_000);
assert (Ledger.confirmedReversalExists(42, 4, reversed));

// A reversal of the initial borrowing would make remaining balance negative.
let rollbackInitial = entry(8, #reversal(1), 1_000_000, #confirmed);
let invalid = [initial, repay1, repay2, extra, repay3, rollbackInitial];
assert (not Ledger.validBalance(42, invalid));

// Pending repayment must not affect the confirmed balance.
let waitingRepay = entry(9, #repayment, 700_000, #pendingConfirmation);
assert (Ledger.calculate(42, [initial, waitingRepay]).outstandingCents == 1_000_000);

ignore 0;
