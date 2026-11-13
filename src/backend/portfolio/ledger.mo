import Array "mo:base/Array";
import Char "mo:base/Char";
import Int "mo:base/Int";
import Nat "mo:base/Nat";
import Nat8 "mo:base/Nat8";
import Principal "mo:base/Principal";
import Result "mo:base/Result";
import Text "mo:base/Text";
import T "types";

module {
  public let empty : T.State = { assets = []; events = []; receipts = []; nextAssetId = 1; nextEventId = 1 };
  public func find(state : T.State, id : Nat) : ?T.Asset { Array.find<T.Asset>(state.assets, func(a) { a.id == id }) };
  public func validValuation(asset : T.Asset) : ?T.Valuation {
    switch (asset.valuation) { case (?v) { if (v.quantityRevision == asset.quantityRevision) ?v else null }; case null null }
  };
  func nonblank(value : Text, max : Nat) : Bool {
    Text.size(value) > 0 and Text.size(value) <= max and Text.size(Text.trim(value, #predicate(Char.isWhitespace))) > 0
  };
  func validSource(source : ?T.AssetRef) : Bool {
    switch source { case null true; case (?s) { nonblank(s.network, 64) and not Principal.isAnonymous(s.canisterId) } }
  };
  func validCurrency(value : Text) : Bool {
    if (not nonblank(value, 12)) return false;
    for (c in value.chars()) { if (not ((c >= 'A' and c <= 'Z') or (c >= '0' and c <= '9'))) return false };
    true
  };
  // No external calls: the actor authorizes before invoking this transition.
  // Result includes the replacement state, so errors never partially mutate it.
  public func apply(state : T.State, fundId : Nat, caller : Principal, requestId : Text, operation : T.Operation, now : Int) : Result.Result<(T.State, T.Asset), Text> {
    if (Principal.isAnonymous(caller)) return #err("Authentication required");
    if (not nonblank(requestId, 100)) return #err("Invalid request ID");
    for (receipt in state.receipts.vals()) {
      if (receipt.fundId == fundId and receipt.caller == caller and receipt.requestId == requestId) {
        return if (receipt.operation == operation) #ok((state, receipt.result)) else #err("Request ID already used with different input")
      }
    };
    var eventCount = 0;
    for (e in state.events.vals()) { if (e.fundId == fundId) eventCount += 1 };
    if (eventCount >= 5_000) return #err("Portfolio history limit reached");
    var delta : Int = 0;
    var note = "";
    let maxAmount = 10 ** 36;
    let (asset, kind) : (T.Asset, T.EventKind) = switch operation {
      case (#create(input)) {
        if (not nonblank(input.name, 120) or not nonblank(input.category, 40) or not nonblank(input.unit, 32)) return #err("Name, category and unit are required");
        if (Nat8.toNat(input.decimals) > 18 or input.quantity > maxAmount or Text.size(input.note) > 2_000 or not validSource(input.source)) return #err("Invalid asset input");
        var count = 0;
        for (a in state.assets.vals()) {
          if (a.fundId == fundId) {
            count += 1;
            if (input.source != null and a.source == input.source) return #err("This ICEvent resource already has a position in this fund")
          }
        };
        if (count >= 200) return #err("Portfolio asset limit reached");
        note := input.note;
        delta := input.quantity;
        ({ id = state.nextAssetId; fundId; name = input.name; category = input.category; unit = input.unit; decimals = input.decimals;
           quantity = input.quantity; quantityRevision = 1; revision = 1; status = #held; archived = false; valuation = null;
           source = input.source; createdAt = now }, #opening)
      };
      case (#change(input)) {
        let old = switch (find(state, input.assetId)) { case null return #err("Asset not found"); case (?a) a };
        if (old.fundId != fundId) return #err("Asset not found");
        if (old.revision != input.expectedRevision) return #err("Asset changed; refresh before saving");
        if (Text.size(input.note) > 2_000) return #err("Note is too long");
        note := input.note;
        if (old.archived and input.change != #archive(false)) return #err("Restore this archived asset first");
        var quantity = old.quantity;
        var name = old.name;
        var category = old.category;
        var status = old.status;
        var archived = old.archived;
        var valuation = old.valuation;
        var quantityRevision = old.quantityRevision;
        switch (input.change) {
          case (#increase(n)) { if (n == 0 or n > maxAmount) return #err("Invalid quantity"); delta := n };
          case (#decrease(n)) { if (n == 0 or n > maxAmount) return #err("Invalid quantity"); delta := -(n : Int) };
          case (#reverse(id)) {
            let original = switch (Array.find<T.Event>(state.events, func(e) { e.id == id and e.assetId == old.id and e.fundId == fundId })) {
              case null return #err("Original transaction not found"); case (?e) e;
            };
            switch (original.kind) {
              case (#opening) {};
              case (#change(#increase(_))) {};
              case (#change(#decrease(_))) {};
              case (_) return #err("Only opening, increase and decrease transactions can be reversed");
            };
            if (original.delta == 0) return #err("No quantity to reverse");
            for (e in state.events.vals()) {
              if (e.assetId == old.id and e.kind == #change(#reverse(id))) return #err("Transaction already reversed")
            };
            delta := -original.delta
          };
          case (#valuation(v)) {
            if (v.amount > maxAmount or Nat8.toNat(v.decimals) > 18 or not validCurrency(v.currency)) return #err("Invalid valuation");
            valuation := ?{ amount = v.amount; currency = v.currency; decimals = v.decimals; quantityRevision; at = now; performedBy = caller }
          };
          case (#details(d)) {
            if (not nonblank(d.name, 120) or not nonblank(d.category, 40)) return #err("Invalid asset details");
            if (d.status == #disposed and quantity != 0) return #err("Reduce holding to zero before disposal");
            name := d.name; category := d.category; status := d.status
          };
          case (#archive(value)) { if (value and quantity != 0) return #err("Only zero holdings can be archived"); archived := value };
        };
        if (delta != 0) {
          if (status == #disposed) return #err("Restore holding status before changing quantity");
          let next : Int = quantity + delta;
          if (next < 0) return #err("Insufficient holding quantity");
          if (next > maxAmount) return #err("Quantity limit exceeded");
          quantity := Int.abs(next); quantityRevision += 1
        };
        ({ old with name; category; quantity; quantityRevision; status; archived; valuation; revision = old.revision + 1 }, #change(input.change))
      };
    };
    let event : T.Event = { id = state.nextEventId; fundId; assetId = asset.id; kind; delta; performedBy = caller; at = now; note; after = asset };
    let assets = switch operation {
      case (#create(_)) Array.append<T.Asset>(state.assets, [asset]);
      case (_) Array.map<T.Asset,T.Asset>(state.assets, func(a) { if (a.id == asset.id) asset else a });
    };
    let receipt : T.Receipt = { fundId; caller; requestId; operation; result = asset };
    #ok(({ assets; events = Array.append<T.Event>(state.events, [event]); receipts = Array.append<T.Receipt>(state.receipts, [receipt]);
      nextAssetId = state.nextAssetId + (switch operation { case (#create(_)) 1; case (_) 0 }); nextEventId = state.nextEventId + 1 }, asset))
  };
}
