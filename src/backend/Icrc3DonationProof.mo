import Blob "mo:base/Blob";
import Nat8 "mo:base/Nat8";
import Principal "mo:base/Principal";
import Proof "./Icrc3PayoutProof";

// Strict ICRC-3 transfer receipt validation for incoming donations.
// A ledger block index alone never constitutes evidence of a donation.
module {
  public type Value = Proof.Value;

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

  private func account(value : ?Value, owner : Principal) : Bool {
    switch (value) {
      case (?(#Array(parts))) {
        if (parts.size() < 1 or parts.size() > 2) return false;
        switch (parts[0]) {
          case (#Blob(p)) {
            if (not Blob.equal(p, Principal.toBlob(owner))) return false;
          };
          case (_) return false;
        };
        if (parts.size() == 2) {
          switch (parts[1]) {
            case (#Blob(sub)) {
              let bytes = Blob.toArray(sub);
              if (bytes.size() != 32) return false;
              for (byte in bytes.vals()) {
                if (byte != (0 : Nat8)) return false;
              };
            };
            case (_) return false;
          }
        };
        true
      };
      case (_) false;
    }
  };

  public func isDonationTransfer(
    block : Value,
    donor : Principal,
    treasury : Principal,
    amount : Nat,
  ) : Bool {
    let tx = switch (field(block, "tx")) {
      case (?value) value;
      case null return false;
    };
    switch (field(block, "btype")) {
      case (?(#Text("1xfer"))) {};
      case null {
        switch (field(tx, "op")) {
          case (?(#Text("xfer"))) {};
          case (_) return false;
        }
      };
      case (_) return false;
    };
    switch (field(tx, "amt")) {
      case (?(#Nat(n))) { if (n != amount) return false };
      case (_) return false;
    };
    if (not account(field(tx, "from"), donor)) return false;
    if (not account(field(tx, "to"), treasury)) return false;
    // Reject delegated transfers; the recorded donor must be the sender.
    switch (field(tx, "spender")) {
      case null {};
      case (_) return false;
    };
    true
  };
};
