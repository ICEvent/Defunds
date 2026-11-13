import Principal "mo:base/Principal";
import Proof "../../src/backend/Icrc3PayoutProof";
persistent actor DonationLedger {
 type Arg = { start : Nat; length : Nat };
 type Response = { log_length : Nat; blocks : [{ id : Nat; block : Proof.Value }]; archived_blocks : [{ args : [Arg]; callback : shared query [Arg] -> async Response }] };
 var entries : [{ id : Nat; block : Proof.Value }] = [];
 var decimals : Nat8 = 6;
 var archived = false;
 public shared func setArchived(value : Bool) : async () { archived := value };
 public shared func configure(sender : Principal, receiver : Principal, amount : Nat, precision : Nat8, index : Nat) : async () {
  decimals := precision;
  entries := [{ id = index; block = #Map([("btype",#Text("1xfer")),("tx",#Map([("from",#Array([#Blob(Principal.toBlob(sender))])),("to",#Array([#Blob(Principal.toBlob(receiver))])),("amt",#Nat(amount))]))]) }];
 };
 public query func icrc1_decimals() : async Nat8 { decimals };
 public query func archive(_args : [Arg]) : async Response { { log_length = 100; blocks = entries; archived_blocks = [] } };
 public query func icrc3_get_blocks(args : [Arg]) : async Response {
  if (archived) { { log_length = 100; blocks = []; archived_blocks = [{ args; callback = DonationLedger.archive }] } }
  else { { log_length = 100; blocks = entries; archived_blocks = [] } }
 };
}
