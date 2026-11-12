import Blob "mo:base/Blob";
persistent actor FundLedger {
  var account : ?{owner:Principal;subaccount:?Blob} = null;
  var balance : Nat = 0;
  public shared func setTestBalance(value:{owner:Principal;subaccount:?Blob},amount:Nat) : async () { account:=?value;balance:=amount };
  public query func icrc1_symbol() : async Text { "TEST" };
  public query func icrc1_name() : async Text { "Test ledger" };
  public query func icrc1_decimals() : async Nat8 { 6 };
  public query func icrc1_balance_of(value:{owner:Principal;subaccount:?Blob}) : async Nat { if(account == ?value) balance else 0 };
}
