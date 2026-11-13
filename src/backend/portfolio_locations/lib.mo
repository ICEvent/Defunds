import Array "mo:base/Array";
import Blob "mo:base/Blob";
import Char "mo:base/Char";
import Nat "mo:base/Nat";
import Principal "mo:base/Principal";
import Result "mo:base/Result";
import Text "mo:base/Text";
import P "../portfolio/types";
import Ledger "../portfolio/ledger";
import C "../fund_currency/types";
import T "types";
module {
  public let empty : T.State = {locations=[];bindings=[];movements=[];receipts=[];nextLocationId=1;nextMovementId=1};
  type R<A> = Result.Result<A,Text>;
  public func binding(state : T.State, asset : P.Asset) : T.Binding {
    switch(Array.find<T.Binding>(state.bindings,func(b){b.fundId == asset.fundId and b.assetId == asset.id})){
      case (?b) b;
      case null ({assetId=asset.id;fundId=asset.fundId;definition=#asset(asset.id);locationId=0;performedBy=Principal.fromText("aaaaa-aa");at=asset.createdAt});
    }
  };
  func nonblank(text : Text, max : Nat) : Bool { Text.size(text) <= max and Text.size(Text.trim(text,#predicate(Char.isWhitespace))) > 0 };
  func normalize(kind : T.Kind, treasury : Principal) : R<T.Kind> {
    switch kind {
      case (#wallet(account)) {
        if(Principal.isAnonymous(account.owner) or account.owner == treasury) return #err("Fund backend accounts are reserved for live ledger balances");
        var subaccount = account.subaccount;
        switch subaccount {
          case null {};
          case (?bytes) {
            if(bytes.size() != 32) return #err("Wallet subaccount must contain 32 bytes");
            var zero=true;for(byte in Blob.toArray(bytes).vals()){if(byte != 0)zero:=false};
            if(zero)subaccount:=null;
          };
        };
        #ok(#wallet({owner=account.owner;subaccount}))
      };
      case (#blockchain(ref)) {if(not nonblank(ref,200))return #err("Blockchain network and address reference is required");#ok(#blockchain(Text.trim(ref,#predicate(Char.isWhitespace))))};
      case (#bank(ref)) {if(not nonblank(ref,200))return #err("Bank reference is required");#ok(#bank(Text.trim(ref,#predicate(Char.isWhitespace))))};
      case (#cash(ref)) {if(not nonblank(ref,200))return #err("Cash location is required");#ok(#cash(Text.trim(ref,#predicate(Char.isWhitespace))))};
      case (#storage(ref)) {if(not nonblank(ref,200))return #err("Storage reference is required");#ok(#storage(Text.trim(ref,#predicate(Char.isWhitespace))))};
      case (#other(ref)) {if(not nonblank(ref,200))return #err("Location reference is required");#ok(#other(Text.trim(ref,#predicate(Char.isWhitespace))))};
    }
  };
  func metadata(state:T.State, ledger:P.State, fundId:Nat, currencies:[C.Currency], definition:T.Definition) : R<{name:Text;unit:Text;decimals:Nat8;category:Text}> {
    switch definition {
      case (#currency(id)) {
        switch(Array.find<C.Currency>(currencies,func(c){c.id == id})){
          case null #err("Currency not configured for this fund");
          case (?c) #ok({name=c.name;unit=c.symbol;decimals=c.decimals;category=if(c.ledger == null)"cash" else "crypto"});
        }
      };
      case (#asset(id)) {
        let root=switch(Ledger.find(ledger,id)){case null return #err("Asset definition not found");case (?a)a};
        if(root.fundId != fundId or binding(state,root).definition != #asset(id)) return #err("Invalid asset definition");
        #ok({name=root.name;unit=root.unit;decimals=root.decimals;category=root.category})
      };
    }
  };
  public func positions(state:T.State,ledger:P.State,fundId:Nat,currencies:[C.Currency]) : [T.Position] {
    Array.map<P.Asset,T.Position>(Array.filter<P.Asset>(ledger.assets,func(a){a.fundId == fundId}),func(asset){
      let b=binding(state,asset);
      let m=switch(metadata(state,ledger,fundId,currencies,b.definition)){case (#ok(v))v;case (#err(_))({name=asset.name;unit=asset.unit;decimals=asset.decimals;category=asset.category})};
      {asset;definition=b.definition;locationId=b.locationId;name=m.name;unit=m.unit;decimals=m.decimals}
    })
  };
  func location(state:T.State,fundId:Nat,id:Nat) : R<T.Location> {
    switch(Array.find<T.Location>(state.locations,func(l){l.fundId == fundId and l.id == id})){
      case null #err("Location not found in this fund");
      case (?l) {if(l.enabled)#ok(l) else #err("Location is disabled for new holdings or movements")};
    }
  };
  func unique(state:T.State,ledger:P.State,fundId:Nat,definition:T.Definition,locationId:Nat,except:Nat) : Bool {
    for(a in ledger.assets.vals()){
      if(a.fundId == fundId and a.id != except){let b=binding(state,a);if(b.definition == definition and b.locationId == locationId)return false}
    };true
  };
  // All transitions are pure: source and destination are committed together by
  // the actor only after every step succeeds. No ledger transfers are sent.
  public func apply(state:T.State,ledger:P.State,fundId:Nat,caller:Principal,treasury:Principal,currencies:[C.Currency],requestId:Text,operation:T.Operation,now:Int) : R<(T.State,P.State,T.Reply)> {
    if(Principal.isAnonymous(caller) or not nonblank(requestId,80)) return #err("Authentication and a valid request ID are required");
    for(r in state.receipts.vals()){
      if(r.fundId == fundId and r.caller == caller and r.requestId == requestId){
        return if(r.operation == operation)#ok((state,ledger,r.reply)) else #err("Request ID already used with different input")
      }
    };
    if(Array.filter<T.Receipt>(state.receipts,func(r){r.fundId == fundId}).size() >= 5_000)return #err("Location history limit reached");
    var nextState=state;var nextLedger=ledger;
    let prefix="location:" # requestId;
    // Refuse pre-existing low-level receipts. They must never be interpreted
    // as half of a new movement, even after a quantity reversal.
    for(r in ledger.receipts.vals()){
      if(r.fundId == fundId and r.caller == caller and (r.requestId == prefix # ":out" or r.requestId == prefix # ":in" or r.requestId == prefix # ":new"))return #err("Internal request ID conflict; use a fresh request ID")
    };
    let reply:T.Reply=switch operation {
      case (#addLocation(input)) {
        if(not nonblank(input.name,120))return #err("Location name is required");
        if(Array.filter<T.Location>(state.locations,func(l){l.fundId == fundId}).size() >= 50)return #err("Location limit reached");
        let kind=switch(normalize(input.kind,treasury)){case (#err(e))return #err(e);case (#ok(k))k};
        if(Array.find<T.Location>(state.locations,func(l){l.fundId == fundId and l.kind == kind}) != null)return #err("This location already exists; restore it instead");
        let item:T.Location={id=state.nextLocationId;fundId;name=Text.trim(input.name,#predicate(Char.isWhitespace));kind;enabled=true;revision=1;createdAt=now};
        nextState:={state with locations=Array.append<T.Location>(state.locations,[item]);nextLocationId=state.nextLocationId+1};#location(item)
      };
      case (#updateLocation(input)) {
        let old=switch(Array.find<T.Location>(state.locations,func(l){l.fundId == fundId and l.id == input.id})){case null return #err("Location not found");case (?l)l};
        if(old.revision != input.expectedRevision)return #err("Location changed; refresh before saving");
        if(not nonblank(input.name,120))return #err("Location name is required");
        let item={old with name=Text.trim(input.name,#predicate(Char.isWhitespace));enabled=input.enabled;revision=old.revision+1};
        nextState:={state with locations=Array.map<T.Location,T.Location>(state.locations,func(l){if(l.id == old.id)item else l})};#location(item)
      };
      case (#bind(input)) {
        ignore switch(location(state,fundId,input.locationId)){case (#err(e))return #err(e);case (#ok(l))l};
        let asset=switch(Ledger.find(ledger,input.assetId)){case null return #err("Asset not found");case (?a)a};
        if(asset.fundId != fundId)return #err("Asset not found");
        if(asset.revision != input.expectedRevision)return #err("Asset changed; refresh before saving");
        if(Array.find<T.Binding>(state.bindings,func(b){b.assetId == asset.id}) != null)return #err("Position already located; record a movement to change its location");
        if(input.definition != #asset(asset.id) and Array.find<T.Binding>(state.bindings,func(b){b.fundId == fundId and b.definition == #asset(asset.id)}) != null)return #err("This asset is already used as a shared definition");
        let m=switch(metadata(state,ledger,fundId,currencies,input.definition)){case (#err(e))return #err(e);case (#ok(v))v};
        if(asset.decimals != m.decimals or asset.unit != m.unit)return #err("Holding unit and precision must match the asset definition");
        if(not unique(state,ledger,fundId,input.definition,input.locationId,asset.id))return #err("Holding already exists at this location, including archived holdings");
        let b:T.Binding={assetId=asset.id;fundId;definition=input.definition;locationId=input.locationId;performedBy=caller;at=now};
        nextState:={state with bindings=Array.append<T.Binding>(state.bindings,[b])};#position(b)
      };
      case (#create(input)) {
        ignore switch(location(state,fundId,input.locationId)){case (#err(e))return #err(e);case (#ok(l))l};
        let m=switch(metadata(state,ledger,fundId,currencies,input.definition)){case (#err(e))return #err(e);case (#ok(v))v};
        if(not unique(state,ledger,fundId,input.definition,input.locationId,0))return #err("Holding already exists at this location, including archived holdings");
        let op:P.Operation=#create({name=m.name;category=m.category;unit=m.unit;decimals=m.decimals;quantity=input.quantity;source=null;note=input.note});
        let (updated,asset)=switch(Ledger.apply(ledger,fundId,caller,prefix # ":new",op,now)){case (#err(e))return #err(e);case (#ok(v))v};
        nextLedger:=updated;
        let b:T.Binding={assetId=asset.id;fundId;definition=input.definition;locationId=input.locationId;performedBy=caller;at=now};
        nextState:={state with bindings=Array.append<T.Binding>(state.bindings,[b])};#position(b)
      };
      case (#move(input)) {
        if(input.sourceId == input.targetId or input.quantity == 0 or input.quantity + input.fee > 10 ** 36)return #err("Invalid movement quantity or fee");
        let source=switch(Ledger.find(ledger,input.sourceId)){case null return #err("Source not found");case (?a)a};
        let target=switch(Ledger.find(ledger,input.targetId)){case null return #err("Target not found");case (?a)a};
        if(source.fundId != fundId or target.fundId != fundId)return #err("Positions must belong to this fund");
        let from=binding(state,source);let to=binding(state,target);
        if(from.locationId == 0 or to.locationId == 0 or from.locationId == to.locationId or from.definition != to.definition)return #err("Choose the same asset at two different recorded locations");
        if(source.unit != target.unit or source.decimals != target.decimals)return #err("Position units must match");
        ignore switch(location(state,fundId,to.locationId)){case (#err(e))return #err(e);case (#ok(l))l};
        let out:P.Operation=#change({assetId=source.id;expectedRevision=input.sourceRevision;change=#decrease(input.quantity+input.fee);note=input.note});
        let (afterSource,_)=switch(Ledger.apply(ledger,fundId,caller,prefix # ":out",out,now)){case (#err(e))return #err(e);case (#ok(v))v};
        let incoming:P.Operation=#change({assetId=target.id;expectedRevision=input.targetRevision;change=#increase(input.quantity);note=input.note});
        let (afterTarget,_)=switch(Ledger.apply(afterSource,fundId,caller,prefix # ":in",incoming,now)){case (#err(e))return #err(e);case (#ok(v))v};
        nextLedger:=afterTarget;
        let movement:T.Movement={id=state.nextMovementId;fundId;sourceId=source.id;targetId=target.id;quantity=input.quantity;fee=input.fee;performedBy=caller;at=now;note=input.note;sourceEventId=ledger.nextEventId;targetEventId=afterSource.nextEventId};
        nextState:={state with movements=Array.append<T.Movement>(state.movements,[movement]);nextMovementId=state.nextMovementId+1};#movement(movement)
      };
    };
    let receipt:T.Receipt={fundId;caller;requestId;operation;reply;at=now};
    nextState:={nextState with receipts=Array.append<T.Receipt>(state.receipts,[receipt])};
    #ok((nextState,nextLedger,reply))
  };
}
