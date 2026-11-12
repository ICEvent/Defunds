module {
  public type AssetRef = { network : Text; canisterId : Principal; assetId : Nat };
  public type Valuation = { amount : Nat; currency : Text; decimals : Nat8; quantityRevision : Nat; at : Int; performedBy : Principal };
  public type HoldingStatus = { #held; #locked; #disposed };
  public type Asset = {
    id : Nat; fundId : Nat; name : Text; category : Text; unit : Text; decimals : Nat8;
    quantity : Nat; quantityRevision : Nat; revision : Nat; status : HoldingStatus;
    archived : Bool; valuation : ?Valuation; source : ?AssetRef; createdAt : Int;
  };
  public type NewAsset = { name : Text; category : Text; unit : Text; decimals : Nat8; quantity : Nat; source : ?AssetRef; note : Text };
  public type Change = {
    #increase : Nat; #decrease : Nat; #reverse : Nat;
    #valuation : { amount : Nat; currency : Text; decimals : Nat8 };
    #details : { name : Text; category : Text; status : HoldingStatus };
    #archive : Bool;
  };
  public type EventKind = { #opening; #change : Change };
  public type Event = {
    id : Nat; fundId : Nat; assetId : Nat; kind : EventKind; delta : Int;
    performedBy : Principal; at : Int; note : Text; after : Asset;
  };
  public type Operation = { #create : NewAsset; #change : { assetId : Nat; expectedRevision : Nat; change : Change; note : Text } };
  public type Receipt = { fundId : Nat; caller : Principal; requestId : Text; operation : Operation; result : Asset };
  public type ManagerEvent = { fundId : Nat; principal : Principal; granted : Bool; performedBy : Principal; at : Int };
  public type State = { assets : [Asset]; events : [Event]; receipts : [Receipt]; nextAssetId : Nat; nextEventId : Nat };
}
