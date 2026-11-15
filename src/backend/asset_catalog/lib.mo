import Array "mo:base/Array";
import Char "mo:base/Char";
import Nat8 "mo:base/Nat8";
import Nat "mo:base/Nat";
import Principal "mo:base/Principal";
import C "../fund_currency/types";
import Result "mo:base/Result";
import Text "mo:base/Text";
import T "types";
module {
  public let networks : [T.Network] = [
    {id="ethereum";name="Ethereum";family=#evm;enabled=true},
    {id="base";name="Base";family=#evm;enabled=true},
    {id="arbitrum";name="Arbitrum One";family=#evm;enabled=true},
    {id="icp";name="Internet Computer";family=#icp;enabled=true},
    {id="solana";name="Solana";family=#solana;enabled=true},
    {id="bitcoin";name="Bitcoin";family=#bitcoin;enabled=true}
  ];
  func clean(t : Text) : Text { Text.trim(t,#predicate(Char.isWhitespace)) };
  func valid(t : Text,max : Nat) : Bool { t.size() > 0 and t.size() <= max };
  public func validate(input : T.Input, nets : [T.Network]) : Result.Result<T.Input,Text> {
    let i = {input with assetKey=clean(input.assetKey);name=clean(input.name);symbol=clean(input.symbol);network=clean(input.network);standard=clean(input.standard);contract=clean(input.contract);source=clean(input.source)};
    if(not valid(i.assetKey,80) or not valid(i.name,120) or not valid(i.symbol,24) or i.contract.size() > 200 or i.source.size() > 500 or Nat8.toNat(i.decimals) > 18) return #err("Invalid asset fields; decimals must be 0..18");
    if(i.verified and not valid(i.source,500))return #err("Verified assets require a source");
    let net=switch(Array.find<T.Network>(nets,func(n){n.id==i.network and n.enabled})){case null return #err("Choose an enabled network");case (?n)n};
    if(i.standard=="native"){
      if(i.contract!="")return #err("Native assets must not have a contract");
    }else{
      if(not valid(i.contract,200))return #err("Contract, mint or ledger identifier is required");
      switch(net.family){
        case (#evm) {
          if(i.standard!="erc20")return #err("EVM tokens must use erc20");
          if(i.contract.size()!=42 or not Text.startsWith(i.contract,#text("0x")))return #err("Invalid EVM contract");
          var index=0;for(c in i.contract.chars()){if(index>=2 and not ((c>='0' and c<='9') or (c>='a' and c<='f') or (c>='A' and c<='F')))return #err("Invalid EVM contract");index+=1};
        };
        case (#icp) {
          if(i.standard!="icrc1" and i.standard!="icrc2")return #err("Choose an ICRC standard");
          // The actor parses the Principal before committing any state.
        };
        case (#solana) {if(i.standard!="spl" and i.standard!="spl2022")return #err("Choose an SPL standard");if(i.contract.size() < 32 or i.contract.size() > 44)return #err("Invalid mint identifier");for(c in i.contract.chars()){if(not Text.contains("123456789ABCDEFGHJKLMNPQRSTUVWXYZabcdefghijkmnopqrstuvwxyz",#char(c)))return #err("Invalid mint identifier")}};
        case (#bitcoin) return #err("Only native Bitcoin is supported");
        case (#other) return #err("Unsupported token network");
      }
    };
    #ok({i with contract=if(net.family==#evm)Text.toLowercase(i.contract) else i.contract})
  };
  public func holdingName(token : T.Token) : Text {
    let suffix = " · " # token.network;
    let chars = Text.toArray(token.name);
    // The network identifier comes from the bounded supported-network table.
    let limit = if(suffix.size() < 120) Nat.sub(120,suffix.size()) else 0;
    Text.fromIter(Array.tabulate<Char>(Nat.min(chars.size(),limit),func(i){chars[i]}).vals()) # suffix
  };
  // A custom and public entry may describe the same on-chain token. Importing
  // either must reuse an existing Fund definition rather than split holdings.
  public func findImported(tokens : [T.Token], token : T.Token, currencies : [C.Currency]) : Result.Result<?C.Currency,Text> {
    for(c in currencies.vals()) {
      let sameLedger = switch(c.ledger) {case (?p) token.network == "icp" and token.standard != "native" and Principal.toText(p) == token.contract;case null false};
      let sameToken = switch(Text.stripStart(c.id,#text("catalog:"))) {
        case null false;
        case (?suffix) switch(Nat.fromText(suffix)) {
          case null false;
          case (?id) switch(Array.find<T.Token>(tokens,func(t){t.id == id})) {
            case null false;
            case (?old) identity(input(old)) == identity(input(token));
          };
        };
      };
      if(sameLedger or sameToken) {
        if(c.decimals != token.decimals)return #err("Asset precision conflicts with the existing Fund definition");
        return #ok(?c);
      };
    };
    #ok(null)
  };
  public func identity(i : T.Input) : Text { i.network # ":" # (if(i.standard=="native")"native" else i.contract) };
  public func input(t : T.Token) : T.Input { {assetKey=t.assetKey;name=t.name;symbol=t.symbol;network=t.network;standard=t.standard;contract=t.contract;decimals=t.decimals;source=t.source;verified=t.verified;enabled=t.enabled} };
}
