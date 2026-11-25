import P "../portfolio/types";
module {
  public type Kind = { #wallet : {owner : Principal; subaccount : ?Blob}; #blockchain : Text; #chainAccount : {network : Text; address : Text}; #multiChainWallet : {reference : Text; accounts : [{network : Text; address : Text}]}; #hardwareWallet : Text; #exchange : Text; #brokerage : Text; #smartContract : Text; #custodian : Text; #bank : Text; #cash : Text; #storage : Text; #other : Text };
  public type Location = {id : Nat; fundId : Nat; name : Text; kind : Kind; enabled : Bool; revision : Nat; createdAt : Int};
  public type Definition = { #currency : Text; #asset : Nat };
  public type Binding = {assetId : Nat; fundId : Nat; definition : Definition; locationId : Nat; performedBy : Principal; at : Int};
  public type Movement = {id : Nat; fundId : Nat; sourceId : Nat; targetId : Nat; quantity : Nat; fee : Nat; performedBy : Principal; at : Int; note : Text; sourceEventId : Nat; targetEventId : Nat};
  public type Position = {asset : P.Asset; definition : Definition; locationId : Nat; name : Text; unit : Text; decimals : Nat8};
  public type Operation = {
    #addLocation : {name : Text; kind : Kind};
    #updateLocation : {id : Nat; expectedRevision : Nat; name : Text; enabled : Bool};
    #addWalletAccount : {id : Nat; expectedRevision : Nat; network : Text; address : Text};
    #setLocationNetwork : {id : Nat; expectedRevision : Nat; network : Text; address : Text};
    #bind : {assetId : Nat; expectedRevision : Nat; definition : Definition; locationId : Nat};
    #create : {definition : Definition; locationId : Nat; quantity : Nat; note : Text};
    #move : {sourceId : Nat; targetId : Nat; sourceRevision : Nat; targetRevision : Nat; quantity : Nat; fee : Nat; note : Text};
  };
  public type Reply = {#location : Location; #position : Binding; #movement : Movement};
  public type Receipt = {fundId : Nat; caller : Principal; requestId : Text; operation : Operation; reply : Reply; at : Int};
  public type State = {locations : [Location]; bindings : [Binding]; movements : [Movement]; receipts : [Receipt]; nextLocationId : Nat; nextMovementId : Nat};
}
