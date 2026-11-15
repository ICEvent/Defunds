module {
  public type Network = { id : Text; name : Text; family : {#evm; #icp; #solana; #bitcoin; #other}; enabled : Bool };
  public type Token = { id : Nat; assetKey : Text; name : Text; symbol : Text; network : Text; standard : Text; contract : Text; decimals : Nat8; source : Text; verified : Bool; enabled : Bool; revision : Nat };
  public type Input = { assetKey : Text; name : Text; symbol : Text; network : Text; standard : Text; contract : Text; decimals : Nat8; source : Text; verified : Bool; enabled : Bool };
}
