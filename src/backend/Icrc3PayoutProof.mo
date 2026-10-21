import Blob "mo:base/Blob";
import Nat8 "mo:base/Nat8";

// ICRC-3's lossless generic block value. Do not decode a ledger block into a
// narrower record: doing so could ignore security-relevant fields.
module {
  public type Value = {
    #Blob : Blob;
    #Text : Text;
    #Nat : Nat;
    #Int : Int;
    #Array : [Value];
    #Map : [(Text, Value)];
  };

  private func field(value : Value, name : Text) : ?Value {
    switch (value) {
      case (#Map(entries)) {
        for ((key, v) in entries.vals()) {
          if (key == name) return ?v;
        };
        null
      };
      case (_) null;
    }
  };

  private func natEquals(value : ?Value, expected : Nat) : Bool {
    switch (value) {
      case (?(#Nat(valueNat))) valueNat == expected;
      case (_) false;
    }
  };

  private func blobEquals(value : ?Value, expected : Blob) : Bool {
    switch (value) {
      case (?(#Blob(valueBlob))) Blob.equal(valueBlob, expected);
      case (_) false;
    }
  };

  private func defaultSubaccount(value : Value) : Bool {
    switch (value) {
      case (#Blob(bytes)) {
        let chars = Blob.toArray(bytes);
        if (chars.size() != 32) return false;
        for (ch in chars.vals()) {
          if (ch != (0 : Nat8)) return false;
        };
        true
      };
      case (_) false;
    }
  };

  private func accountEquals(value : ?Value, owner : Blob) : Bool {
    switch (value) {
      case (?(#Array(parts))) {
        if (parts.size() < 1 or parts.size() > 2) return false;
        if (not blobEquals(?parts[0], owner)) return false;
        if (parts.size() == 2 and not defaultSubaccount(parts[1])) return false;
        true
      };
      case (_) false;
    }
  };

  // A block index is not proof of payment: validate the operation, source,
  // recipient, exact amount, unique grant memo and original attempt timestamp.
  public func isGrantTransfer(
    block : Value,
    treasuryOwner : Blob,
    recipientOwner : Blob,
    amount : Nat,
    grantMemo : Blob,
    createdAt : Nat,
  ) : Bool {
    let transaction = switch (field(block, "tx")) {
      case (?value) value;
      case null return false;
    };
    switch (field(block, "btype")) {
      case (?(#Text(op))) {
        if (op != "1xfer") return false;
      };
      case null {
        // Older ICRC-1 Ledgers use tx.op instead of btype.
        switch (field(transaction, "op")) {
          case (?(#Text("xfer"))) {};
          case (_) return false;
        }
      };
      case (_) return false;
    };
    if (not natEquals(field(transaction, "amt"), amount)) return false;
    if (not accountEquals(field(transaction, "from"), treasuryOwner)) return false;
    if (not accountEquals(field(transaction, "to"), recipientOwner)) return false;
    if (not blobEquals(field(transaction, "memo"), grantMemo)) return false;
    if (not natEquals(field(transaction, "ts"), createdAt)) return false;
    // icrc1_transfer is never authorized to spend from another subaccount.
    switch (field(transaction, "spender")) {
      case null {};
      case (_) return false;
    };
    true
  };
};
