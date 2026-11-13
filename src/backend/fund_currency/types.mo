module {
  // IDs are canonical asset identities, never display tickers.
  public type Currency = { id : Text; symbol : Text; name : Text; decimals : Nat8; ledger : ?Principal; enabled : Bool };
  public type Entry = { fundId : Nat; currency : Currency };
  public type Balance = { currency : Currency; balance : { #ok : Nat; #err : Text }; checkedAt : Int };
}
