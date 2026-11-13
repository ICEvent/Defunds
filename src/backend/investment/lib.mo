import Array "mo:base/Array";
import Text "mo:base/Text";
import Char "mo:base/Char";
import Principal "mo:base/Principal";
import Result "mo:base/Result";
import T "types";
module {
  public let empty:T.State={items=[];events=[];receipts=[];nextId=1;nextEventId=1};
  let max:Nat=1_000_000_000_000_000_000_000_000_000_000_000_000;
  func text(t:Text,n:Nat):Bool {t.size() <= n and Text.trim(t,#predicate(Char.isWhitespace)).size() > 0};
  public func find(s:T.State,fund:Nat,id:Nat):?T.Investment {Array.find<T.Investment> (s.items,func(i){i.fundId == fund and i.id == id})};
  func held(i:T.Investment,id:Nat):Nat {switch(Array.find<T.Account> (i.accounts,func(a){a.locationId == id})){case null 0;case (?a)a.quantity}};
  func put(accounts:[T.Account],id:Nat,q:Nat):[T.Account] {Array.append<T.Account> (Array.filter<T.Account> (accounts,func(a){a.locationId != id}),if(q == 0)[] else [{locationId=id;quantity=q}])};
  public func apply(s:T.State,fund:Nat,caller:Principal,requestId:Text,op:T.Operation,now:Int):Result.Result<(T.State,T.Investment),Text> {
    if(Principal.isAnonymous(caller) or not text(requestId,80))return #err("Authentication and request ID required");
    for(r in s.receipts.vals()){if(r.fundId == fund and r.caller == caller and r.requestId == requestId)return if(r.operation == op)#ok((s,r.result)) else #err("Request ID already used with different input")};
    if(Array.filter<T.Event> (s.events,func(e){e.fundId == fund}).size() >= 2_000)return #err("Investment history limit reached");
    let item:T.Investment=switch op {
      case (#create(m)) {
        if(not text(m.name,120) or not text(m.assetName,120) or not text(m.unit,40) or not text(m.currencyId,80) or not text(m.currency,40) or m.decimals > 18 or m.moneyDecimals > 18)return #err("Invalid investment metadata");
        if(Array.filter<T.Investment> (s.items,func(i){i.fundId == fund}).size() >= 100)return #err("Investment limit reached");
        {id=s.nextId;fundId=fund;metadata=m;revision=1;quantity=0;cost=0;invested=0;proceeds=0;income=0;expenses=0;realized=0;accounts=[];valuation=null;createdAt=now;createdBy=caller}
      };
      case (#record(input)) {
        let old=switch(find(s,fund,input.id)){case null return #err("Investment not found");case (?i)i};
        if(old.revision != input.expectedRevision)return #err("Investment changed; refresh before saving");
        if(input.note.size() > 2_000)return #err("Note too long");
        var i=old;
        switch(input.action){
          case (#buy(t)) {
            if(t.locationId == 0 or t.quantity == 0 or t.amount == 0 or t.quantity > max or t.amount+t.fee > max or old.quantity+t.quantity > max or old.cost+t.amount+t.fee > max)return #err("Invalid purchase quantity or amount");
            i:={old with quantity=old.quantity+t.quantity;cost=old.cost+t.amount+t.fee;invested=old.invested+t.amount+t.fee;accounts=put(old.accounts,t.locationId,held(old,t.locationId)+t.quantity);valuation=null}
          };
          case (#sell(t)) {
            if(t.quantity == 0 or t.quantity > held(old,t.locationId) or t.amount > max or t.fee > max)return #err("Invalid sale or insufficient investment holding");
            let released=if(t.quantity == old.quantity)old.cost else old.cost*t.quantity/old.quantity;
            i:={old with quantity=old.quantity-t.quantity;cost=old.cost-released;proceeds=old.proceeds+t.amount;expenses=old.expenses+t.fee;realized=old.realized+t.amount-t.fee-released;accounts=put(old.accounts,t.locationId,held(old,t.locationId)-t.quantity);valuation=null}
          };
          case (#income(t)) {if(t.amount > max or t.fee > max)return #err("Amount too large");i:={old with income=old.income+t.amount;expenses=old.expenses+t.fee;realized=old.realized+t.amount-t.fee}};
          case (#expense(amount)) {if(amount == 0 or amount > max)return #err("Invalid expense");i:={old with expenses=old.expenses+amount;realized=old.realized-amount}};
          case (#transfer(t)) {
            if(t.from == t.to or t.to == 0 or t.quantity == 0 or t.quantity > held(old,t.from) or t.fee > max)return #err("Invalid transfer or insufficient investment holding");
            i:={old with accounts=put(put(old.accounts,t.from,held(old,t.from)-t.quantity),t.to,held(old,t.to)+t.quantity);expenses=old.expenses+t.fee;realized=old.realized-t.fee}
          };
          case (#valuation(v)) {
            if(v.amount > max or not text(v.source,500) or (old.quantity == 0 and v.amount != 0))return #err("Invalid valuation or source");
            i:={old with valuation=?{amount=v.amount;quantity=old.quantity;at=now;performedBy=caller;source=v.source}}
          };
        };
        {i with revision=old.revision+1}
      };
    };
    let event:T.Event={id=s.nextEventId;fundId=fund;investmentId=item.id;operation=op;at=now;performedBy=caller};
    let receipt:T.Receipt={fundId=fund;caller;requestId;operation=op;result=item};
    #ok(({items=if(find(s,fund,item.id) == null)Array.append<T.Investment> (s.items,[item]) else Array.map<T.Investment,T.Investment> (s.items,func(i){if(i.id == item.id)item else i});events=Array.append<T.Event> (s.events,[event]);receipts=Array.append<T.Receipt> (s.receipts,[receipt]);nextId=if(item.id == s.nextId)s.nextId+1 else s.nextId;nextEventId=s.nextEventId+1},item))
  };
}
