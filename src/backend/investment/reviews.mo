import Array "mo:base/Array";
import Text "mo:base/Text";
import Char "mo:base/Char";
import Principal "mo:base/Principal";
import Result "mo:base/Result";
module {
  public type Input = {decisionId:Nat;expectedRevision:Nat;investmentRevision:Nat;policyRevision:Nat;outcome:{#maintain;#adjust;#close};conclusion:Text;nextAction:Text;nextReviewAt:?Int};
  public type Review = {id:Nat;fundId:Nat;revision:Nat;input:Input;investmentRevision:Nat;policyRevision:Nat;at:Int;by:Principal};
  public type Receipt = {fundId:Nat;caller:Principal;requestId:Text;input:Input};
  public type State = {reviews:[Review];receipts:[Receipt];nextId:Nat};
  public let empty:State = {reviews=[];receipts=[];nextId=1};
  public func latest(s:State,fundId:Nat,decisionId:Nat):?Review {
    var found:?Review=null;
    for(r in s.reviews.vals()){if(r.fundId == fundId and r.input.decisionId == decisionId)found:=?r};found
  };
  public func replay(s:State,fundId:Nat,caller:Principal,id:Text,input:Input):?Result.Result<State,Text> {
    for(r in s.receipts.vals()){
      if(r.fundId == fundId and r.caller == caller and r.requestId == id)
        return ?(if(r.input == input) #ok(s) else #err("Request ID already used with different input"))
    };null
  };
  func valid(t:Text):Bool {t.size() <= 2000 and Text.trim(t,#predicate(Char.isWhitespace)).size() > 0};
  public func apply(s:State,fundId:Nat,caller:Principal,id:Text,input:Input,investmentRevision:Nat,policyRevision:Nat,now:Int):Result.Result<State,Text> {
    if(Principal.isAnonymous(caller) or id.size() == 0 or id.size() > 80 or Text.trim(id,#predicate(Char.isWhitespace)).size() == 0)return #err("Authentication and request ID required");
    switch(replay(s,fundId,caller,id,input)){case (?r)return r;case null {}};
    if(input.investmentRevision != investmentRevision or input.policyRevision != policyRevision)return #err("Investment or strategy changed; use Refresh investments before reviewing");
    let previous=latest(s,fundId,input.decisionId);
    let revision=switch previous {case null 0;case (?r)r.revision};
    if(input.expectedRevision != revision)return #err("Review changed; refresh before saving");
    switch previous {case (?r){if(r.input.outcome == #close)return #err("Decision already closed; create a new decision to reopen");};case null {}};
    if(not valid(input.conclusion) or not valid(input.nextAction))return #err("Provide a conclusion and next action (up to 2000 characters each)");
    switch(input.outcome,input.nextReviewAt){
      case (#close,null) {};
      case (#close,_) return #err("Closed decisions cannot have a next review date");
      case (_,?at){if(at <= now or at > now+366*86400000000000)return #err("Choose a future review date within one year");};
      case (_,null) return #err("A continuing decision requires a next review date");
    };
    if(Array.filter<Review>(s.reviews,func(r){r.fundId == fundId}).size() >= 2000)return #err("Review history limit reached");
    let review:Review={id=s.nextId;fundId;revision=revision+1;input;investmentRevision;policyRevision;at=now;by=caller};
    #ok({reviews=Array.append<Review>(s.reviews,[review]);receipts=Array.append<Receipt>(s.receipts,[{fundId;caller;requestId=id;input}]);nextId=s.nextId+1})
  };
}
