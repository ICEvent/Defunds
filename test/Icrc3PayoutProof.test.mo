import Blob "mo:base/Blob";
import Text "mo:base/Text";
import Proof "../src/backend/Icrc3PayoutProof";

let treasury = Blob.fromArray([1, 2, 3]);
let recipient = Blob.fromArray([4, 5, 6]);
let memo = Text.encodeUtf8("grant:7");
let now : Nat = 1_750_000_000_000_000_000;

func account(owner : Blob) : Proof.Value {
  #Array([#Blob(owner)])
};

func transfer(txType : Text, src : Blob, dst : Blob, amt : Nat, evidence : Blob, ts : Nat) : Proof.Value {
  #Map([
    ("btype", #Text(txType)),
    ("ts", #Nat(ts + 1)),
    ("tx", #Map([
      ("amt", #Nat(amt)),
      ("from", account(src)),
      ("to", account(dst)),
      ("memo", #Blob(evidence)),
      ("ts", #Nat(ts)),
    ])),
  ])
};

let valid = transfer("1xfer", treasury, recipient, 500, memo, now);
assert Proof.isGrantTransfer(valid, treasury, recipient, 500, memo, now);
assert not Proof.isGrantTransfer(valid, recipient, recipient, 500, memo, now);
assert not Proof.isGrantTransfer(valid, treasury, treasury, 500, memo, now);
assert not Proof.isGrantTransfer(valid, treasury, recipient, 501, memo, now);
assert not Proof.isGrantTransfer(valid, treasury, recipient, 500, Text.encodeUtf8("grant:8"), now);
assert not Proof.isGrantTransfer(valid, treasury, recipient, 500, memo, now + 1);
assert not Proof.isGrantTransfer(transfer("2xfer", treasury, recipient, 500, memo, now), treasury, recipient, 500, memo, now);
assert not Proof.isGrantTransfer(transfer("1mint", treasury, recipient, 500, memo, now), treasury, recipient, 500, memo, now);

let legacy : Proof.Value = #Map([
  ("ts", #Nat(now + 1)),
  ("tx", #Map([
    ("op", #Text("xfer")),
    ("amt", #Nat(500)),
    ("from", account(treasury)),
    ("to", account(recipient)),
    ("memo", #Blob(memo)),
    ("ts", #Nat(now)),
  ])),
]);
assert Proof.isGrantTransfer(legacy, treasury, recipient, 500, memo, now);

let withSpender : Proof.Value = #Map([
  ("btype", #Text("1xfer")),
  ("tx", #Map([
    ("amt", #Nat(500)),
    ("from", account(treasury)),
    ("to", account(recipient)),
    ("memo", #Blob(memo)),
    ("ts", #Nat(now)),
    ("spender", account(treasury)),
  ])),
]);
assert not Proof.isGrantTransfer(withSpender, treasury, recipient, 500, memo, now);
