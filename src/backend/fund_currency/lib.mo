import Array "mo:base/Array";
import Char "mo:base/Char";
import Nat8 "mo:base/Nat8";
import Principal "mo:base/Principal";
import Text "mo:base/Text";
import Base "../types";
import T "types";
module {
  public let limit : Nat = 16;
  public func ledgerId(p : Principal) : Text { "ic:" # Principal.toText(p) };
  public func legacy(currency : Base.Currency) : T.Currency {
    let (id,symbol,name,decimals) : (Text,Text,Text,Nat8) = switch currency {
      case (#ICP) ("ryjl3-tyaaa-aaaaa-aaaba-cai","ICP","Internet Computer",8);
      case (#ckBTC) ("mxzaz-hqaaa-aaaar-qaada-cai","ckBTC","Chain-key Bitcoin",8);
      case (#ckETH) ("ss2fx-dyaaa-aaaar-qacoq-cai","ckETH","Chain-key Ether",18);
      case (#ckUSDC) ("xevnm-gaaaa-aaaar-qafnq-cai","ckUSDC","Chain-key USDC",6);
      // Historical custom-token proposals were entered in raw base units.
      case (#ICRC(p)) return {id="legacy:" # p;symbol="ICRC";name="Legacy custom ledger (base units)";decimals=0;ledger=null;enabled=true};
    };
    let ledger = Principal.fromText(id);
    { id = ledgerId(ledger); symbol; name; decimals; ledger = ?ledger; enabled = true }
  };
  public func list(entries : [T.Entry], fundId : Nat, defaultCurrency : Base.Currency) : [T.Currency] {
    let initial = legacy(defaultCurrency);
    var found = false;
    let configured = Array.map<T.Entry,T.Currency>(Array.filter<T.Entry>(entries,func(e){e.fundId == fundId}),func(e){if(e.currency.id == initial.id) found := true; e.currency});
    if(found) configured else Array.append<T.Currency>([initial],configured)
  };
  public func find(entries : [T.Entry], fundId : Nat, defaultCurrency : Base.Currency, id : Text) : ?T.Currency {
    Array.find<T.Currency>(list(entries,fundId,defaultCurrency),func(c){c.id == id})
  };
  public func validSymbol(code : Text) : Bool {
    if(Text.size(code)==0 or Text.size(code) > 12) return false;
    for(c in code.chars()){if(not ((c >= 'A' and c  <=  'Z') or (c >= '0' and c  <=  '9'))) return false};true
  };
  public func validName(name : Text) : Bool { Text.size(name)  <=  100 and Text.size(Text.trim(name,#predicate(Char.isWhitespace))) > 0 };
  public func validMetadata(symbol : Text, name : Text, decimals : Nat8) : Bool {
    Text.size(symbol) > 0 and Text.size(symbol) <= 32 and validName(name) and Nat8.toNat(decimals) <= 18
  };
}
