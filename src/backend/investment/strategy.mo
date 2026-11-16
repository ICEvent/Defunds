import Array "mo:base/Array";
import Text "mo:base/Text";
import Char "mo:base/Char";
import Principal "mo:base/Principal";
import Result "mo:base/Result";
module {
  public type Rules = {maxWeight:Nat;staleDays:Nat;shock:Nat;thesis:Text};
  public type Policy = {fundId:Nat;revision:Nat;rules:Rules;at:Int;by:Principal};
  public type DecisionInput = {investmentId:Nat;investmentRevision:Nat;policyRevision:Nat;action:{#hold;#review;#add;#reduce;#exit};rationale:Text;reviewAt:Int};
  public type Decision = {id:Nat;fundId:Nat;input:DecisionInput;policy:?Policy;at:Int;by:Principal};
  public type Operation = {#policy:{expectedRevision:Nat;rules:Rules};#decision:DecisionInput};
  public type Receipt = {fundId:Nat;caller:Principal;requestId:Text;operation:Operation};
  public type State = {policies:[Policy];decisions:[Decision];receipts:[Receipt];nextId:Nat};
  public let empty:State={policies=[];decisions=[];receipts=[];nextId=1};
  public func current(s:State,fund:Nat):?Policy {
    var found:?Policy=null;
    for(p in s.policies.vals()){if(p.fundId == fund)found:=?p};found
  };
  public func replay(s:State,fund:Nat,caller:Principal,id:Text,op:Operation):?Result.Result<State,Text> {
    for(r in s.receipts.vals()){
      if(r.fundId == fund and r.caller == caller and r.requestId == id)
        return ?(if(r.operation == op) #ok(s) else #err("Request ID already used with different input"))
    };null
  };
  func nonempty(t:Text):Bool {Text.trim(t,#predicate(Char.isWhitespace)).size() > 0};
  public func apply(s:State,fund:Nat,caller:Principal,id:Text,op:Operation,now:Int):Result.Result<State,Text> {
    if(Principal.isAnonymous(caller) or id.size() > 80 or not nonempty(id))return #err("Authentication and request ID required");
    switch(replay(s,fund,caller,id,op)){case (?r)return r;case null {}};
    if(Array.filter<Receipt>(s.receipts,func(r){r.fundId == fund}).size() >= 2000)return #err("Strategy history limit reached");
    let policy=current(s,fund);
    let revision=switch policy{case null 0;case (?p)p.revision};
    var policies=s.policies;var decisions=s.decisions;var next=s.nextId;
    switch op {
      case (#policy(input)) {
        if(input.expectedRevision != revision)return #err("Strategy changed; refresh before saving");
        let r=input.rules;
        if(r.maxWeight < 1 or r.maxWeight > 100 or r.staleDays < 1 or r.staleDays > 3650 or r.shock > 100 or r.thesis.size() > 2000 or not nonempty(r.thesis))return #err("Invalid strategy rules or thesis");
        policies:=Array.append<Policy>(policies,[{fundId=fund;revision=revision+1;rules=r;at=now;by=caller}]);
      };
      case (#decision(input)) {
        if(input.policyRevision != revision)return #err("Strategy changed; refresh before recording a decision");
        if(input.rationale.size() > 2000 or not nonempty(input.rationale) or input.reviewAt <= now or input.reviewAt > now+366*86400000000000)return #err("Provide a rationale and a future review date within one year");
        decisions:=Array.append<Decision>(decisions,[{id=next;fundId=fund;input;policy;at=now;by=caller}]);next+=1;
      };
    };
    #ok({policies;decisions;nextId=next;receipts=Array.append<Receipt>(s.receipts,[{fundId=fund;caller;requestId=id;operation=op}])})
  };
}
