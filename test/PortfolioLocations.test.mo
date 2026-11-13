import Array "mo:base/Array";
import Blob "mo:base/Blob";
import Principal "mo:base/Principal";
import P "../src/backend/portfolio/types";
import Ledger "../src/backend/portfolio/ledger";
import C "../src/backend/fund_currency/types";
import T "../src/backend/portfolio_locations/types";
import L "../src/backend/portfolio_locations/lib";
let user=Principal.fromText("aaaaa-aa");
let treasury=Principal.fromText("rrkah-fqaaa-aaaaa-aaaaq-cai");
let wallet=Principal.fromText("ryjl3-tyaaa-aaaaa-aaaba-cai");
let currencies:[C.Currency]=[{id="manual:CAD";name="Canadian dollar";symbol="CAD";decimals=2;ledger=null;enabled=true}];
var state=L.empty;var ledger=Ledger.empty;
func write(id:Text,op:T.Operation):T.Reply {
  switch(L.apply(state,ledger,1,user,treasury,currencies,id,op,1)){
    case (#err(_)){assert false;loop{}};
    case (#ok((s,p,reply))){state:=s;ledger:=p;reply};
  }
};
func failed(id:Text,op:T.Operation){
  let beforeState=state;let beforeLedger=ledger;
  switch(L.apply(state,ledger,1,user,treasury,currencies,id,op,1)){case (#err(_)){};case (_)assert false};
  assert(state==beforeState and ledger==beforeLedger)
};
// Existing records project as unassigned, without creating or changing assets.
let opening:P.Operation=#create({name="Shared equipment";category="equipment";unit="item";decimals=0;quantity=10;source=null;note="legacy"});
switch(Ledger.apply(ledger,1,user,"legacy",opening,1)){case (#ok((p,_)))ledger:=p;case (_)assert false};
assert(L.positions(state,ledger,1,currencies)[0].locationId==0);
ignore write("A",#addLocation({name="Warehouse A";kind=#storage("A")}));
ignore write("B",#addLocation({name="Warehouse B";kind=#storage("B")}));
ignore write("bind",#bind({assetId=1;expectedRevision=1;definition=#asset(1);locationId=1}));
assert(ledger.assets[0].quantity==10);
ignore write("destination",#create({definition=#asset(1);locationId=2;quantity=0;note="destination"}));
let move:T.Operation=#move({sourceId=1;targetId=2;sourceRevision=1;targetRevision=1;quantity=3;fee=1;note="relocation"});
ignore write("move",move);
assert(ledger.assets[0].quantity==6 and ledger.assets[1].quantity==3);
assert(state.movements[0].sourceEventId==3 and state.movements[0].targetEventId==4);
let stableState=state;let stableLedger=ledger;
ignore write("move",move);assert(state==stableState and ledger==stableLedger);
failed("move",#move({sourceId=1;targetId=2;sourceRevision=2;targetRevision=2;quantity=1;fee=0;note="changed payload"}));
failed("overdraw",#move({sourceId=1;targetId=2;sourceRevision=2;targetRevision=2;quantity=7;fee=0;note=""}));
// The outgoing step would succeed, but a stale incoming revision must roll back both.
failed("stale-target",#move({sourceId=1;targetId=2;sourceRevision=2;targetRevision=1;quantity=1;fee=0;note=""}));
failed("same",#move({sourceId=1;targetId=1;sourceRevision=2;targetRevision=2;quantity=1;fee=0;note=""}));
failed("duplicate",#create({definition=#asset(1);locationId=2;quantity=1;note=""}));
ignore write("cash",#create({definition=#currency("manual:CAD");locationId=1;quantity=12345;note="Fund share only"}));
failed("different-asset",#move({sourceId=1;targetId=3;sourceRevision=2;targetRevision=1;quantity=1;fee=0;note=""}));
ignore write("disable",#updateLocation({id=2;expectedRevision=1;name="Warehouse B";enabled=false}));
failed("disabled-target",#move({sourceId=1;targetId=2;sourceRevision=2;targetRevision=2;quantity=1;fee=0;note=""}));
assert(L.positions(state,ledger,1,currencies).size()==3);
ignore write("wallet",#addLocation({name="External wallet";kind=#wallet({owner=wallet;subaccount=null})}));
failed("duplicate-wallet",#addLocation({name="Same wallet";kind=#wallet({owner=wallet;subaccount=?Blob.fromArray(Array.tabulate<Nat8>(32,func(_){0}))})}));
failed("bad-subaccount",#addLocation({name="Bad";kind=#wallet({owner=wallet;subaccount=?Blob.fromArray([1])})}));
failed("treasury",#addLocation({name="Duplicate treasury";kind=#wallet({owner=treasury;subaccount=null})}));
failed("unknown",#create({definition=#currency("manual:USD");locationId=1;quantity=1;note=""}));
switch(L.apply(state,ledger,2,user,treasury,currencies,"cross",#create({definition=#currency("manual:CAD");locationId=1;quantity=1;note=""}),1)){case (#err(_)){};case (_)assert false};
// Even historical reserved-prefix receipts cannot be reused as half a movement.
ignore write("restore",#updateLocation({id=2;expectedRevision=2;name="Warehouse B";enabled=true}));
let attack:P.Operation=#change({assetId=1;expectedRevision=2;change=#decrease(1);note="old receipt"});
switch(Ledger.apply(ledger,1,user,"location:attack:out",attack,1)){case (#ok((p,_)))ledger:=p;case (_)assert false};
failed("attack",#move({sourceId=1;targetId=2;sourceRevision=3;targetRevision=2;quantity=1;fee=0;note="old receipt"}));
