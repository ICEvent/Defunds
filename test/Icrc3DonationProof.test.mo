import Principal "mo:base/Principal";
import Blob "mo:base/Blob";
import Proof "../src/backend/Icrc3DonationProof";
let donor = Principal.fromText("aaaaa-aa");
let treasury = Principal.fromText("2vxsx-fae");
func account(p : Principal) : Proof.Value { #Array([#Blob(Principal.toBlob(p))]) };
func block(src : Principal, dst : Principal, amount : Nat, kind : Text) : Proof.Value {
 #Map([("btype", #Text(kind)), ("tx", #Map([("from",account(src)),("to",account(dst)),("amt",#Nat(amount))]))])
};
assert Proof.isDonationTransfer(block(donor,treasury,100,"1xfer"),donor,treasury,100);
assert not Proof.isDonationTransfer(block(treasury,treasury,100,"1xfer"),donor,treasury,100);
assert not Proof.isDonationTransfer(block(donor,donor,100,"1xfer"),donor,treasury,100);
assert not Proof.isDonationTransfer(block(donor,treasury,101,"1xfer"),donor,treasury,100);
assert not Proof.isDonationTransfer(block(donor,treasury,100,"1mint"),donor,treasury,100);
assert not Proof.isDonationTransfer(#Map([]),donor,treasury,100);
let delegated : Proof.Value = #Map([("btype",#Text("1xfer")),("tx",#Map([("from",account(donor)),("to",account(treasury)),("amt",#Nat(100)),("spender",account(donor))]))]);
assert not Proof.isDonationTransfer(delegated,donor,treasury,100);
let subaccount : Proof.Value = #Map([("btype",#Text("1xfer")),("tx",#Map([("from",account(donor)),("to",#Array([#Blob(Principal.toBlob(treasury)),#Blob(Blob.fromArray([1]))])),("amt",#Nat(100))]))]);
assert not Proof.isDonationTransfer(subaccount,donor,treasury,100);
