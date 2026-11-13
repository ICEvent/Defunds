import L "../portfolio_locations/types";
module {
  public type Metadata = {name:Text; definition:L.Definition; assetName:Text; unit:Text; decimals:Nat8; currencyId:Text; currency:Text; moneyDecimals:Nat8};
  public type Account = {locationId:Nat; quantity:Nat};
  public type Valuation = {amount:Nat; quantity:Nat; at:Int; performedBy:Principal; source:Text};
  public type Investment = {id:Nat; fundId:Nat; metadata:Metadata; revision:Nat; quantity:Nat; cost:Nat; invested:Nat; proceeds:Nat; income:Nat; expenses:Nat; realized:Int; accounts:[Account]; valuation:?Valuation; createdAt:Int; createdBy:Principal};
  public type Trade = {locationId:Nat; quantity:Nat; amount:Nat; fee:Nat};
  public type Action = {#buy:Trade; #sell:Trade; #income:{amount:Nat;fee:Nat}; #expense:Nat; #transfer:{from:Nat;to:Nat;quantity:Nat;fee:Nat}; #valuation:{amount:Nat;source:Text}};
  public type Operation = {#create:Metadata; #record:{id:Nat;expectedRevision:Nat;action:Action;note:Text}};
  public type Event = {id:Nat;fundId:Nat;investmentId:Nat;operation:Operation;at:Int;performedBy:Principal};
  public type Receipt = {fundId:Nat;caller:Principal;requestId:Text;operation:Operation;result:Investment};
  public type State = {items:[Investment];events:[Event];receipts:[Receipt];nextId:Nat;nextEventId:Nat};
}
