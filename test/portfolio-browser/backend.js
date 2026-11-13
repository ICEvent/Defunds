// Transport fixture for actual-component browser tests. Motoko and canister E2E
// separately verify financial transitions and permissions; this is not a ledger.
import { Principal } from '@dfinity/principal';
export const owner='aaaaa-aa', member='rrkah-fqaaa-aaaaa-aaaaq-cai';
let nextId=3n;
export const state = { locations:[], bindings:[], locationHistory:[], locationRequests:new Map(), chainBalance:2500000n, currencies:[{id:"ic:rrkah-fqaaa-aaaaa-aaaaq-cai",symbol:"TEST",name:"Test ledger",decimals:6,ledger:[Principal.fromText(member)],enabled:true}], calls:[], managers:[], failNext:false, loseResponse:false, receipts:new Map(), assets:[
 {id:1n,fundId:1n,name:'Shared rowing boat',category:'equipment',unit:'boat',decimals:0,quantity:1n,quantityRevision:1n,revision:1n,status:{held:null},archived:false,source:[],createdAt:1n,valuation:[{amount:1200000n,currency:'CAD',decimals:2,quantityRevision:1n,at:1794355200000000000n,performedBy:Principal.fromText(owner)}]},
 {id:2n,fundId:1n,name:'ETH',category:'crypto',unit:'ETH',decimals:2,quantity:250n,quantityRevision:1n,revision:1n,status:{held:null},archived:false,source:[],createdAt:1n,valuation:[]}
], events:[]};
function clone(value){
 if(value && typeof value.toText === 'function')return Principal.fromText(value.toText());
 if(Array.isArray(value))return value.map(clone);
 if(value && typeof value === 'object')return Object.fromEntries(Object.entries(value).map(([key,item])=>[key,clone(item)]));
 return value;
}
export function makeBackend(caller){return {
 async getFundLocationPortfolio(){return {ok:clone({locations:state.locations,currencies:state.currencies,canWrite:caller===owner||state.managers.includes(caller),positions:state.assets.map(asset=>{
   const binding=state.bindings.find(b=>b.assetId===asset.id)??{definition:{asset:asset.id},locationId:0n};
   const meta='currency'in binding.definition?state.currencies.find(c=>c.id===binding.definition.currency):state.assets.find(a=>a.id===binding.definition.asset);
   return {asset,definition:binding.definition,locationId:binding.locationId,name:meta?.name??asset.name,unit:meta?.symbol??asset.unit,decimals:meta?.decimals??asset.decimals};
 })})};},
 async listFundLocationHistory(_fund,offset,limit){return {ok:clone(state.locationHistory.slice(Number(offset),Number(offset+limit)))};},
 async writeFundLocationPortfolio(fund,id,operation){
   if(caller!==owner&&!state.managers.includes(caller))return {err:'Portfolio write access denied'};
   if(state.locationRequests.has(id))return {ok:clone(state.locationRequests.get(id))};
   const at=1794355200000000000n, performedBy=Principal.fromText(caller);let reply;
   if(operation.addLocation){const input=operation.addLocation;const location={...input,id:BigInt(state.locations.length+1),fundId:fund,enabled:true,revision:1n,createdAt:at};state.locations.push(location);reply={location};}
   else if(operation.updateLocation){const input=operation.updateLocation;const l=state.locations.find(l=>l.id===input.id);Object.assign(l,{name:input.name,enabled:input.enabled,revision:l.revision+1n});reply={location:l};}
   else if(operation.bind){const input=operation.bind;const binding={assetId:input.assetId,fundId:fund,definition:input.definition,locationId:input.locationId,performedBy,at};state.bindings.push(binding);reply={position:binding};}
   else if(operation.create){const input=operation.create;const meta='currency'in input.definition?state.currencies.find(c=>c.id===input.definition.currency):state.assets.find(a=>a.id===input.definition.asset);const asset={id:nextId++,fundId:fund,name:meta.name,category:'equipment',unit:meta.symbol??meta.unit,decimals:meta.decimals,quantity:input.quantity,quantityRevision:1n,revision:1n,status:{held:null},archived:false,source:[],valuation:[],createdAt:at};state.assets.push(asset);const binding={assetId:asset.id,fundId:fund,definition:input.definition,locationId:input.locationId,performedBy,at};state.bindings.push(binding);reply={position:binding};}
   else if(operation.move){const input=operation.move;const source=state.assets.find(a=>a.id===input.sourceId),target=state.assets.find(a=>a.id===input.targetId);if(source.quantity<input.quantity+input.fee)return {err:'Insufficient holding quantity'};source.quantity-=input.quantity+input.fee;target.quantity+=input.quantity;source.revision++;target.revision++;source.quantityRevision++;target.quantityRevision++;reply={movement:{...input,id:BigInt(state.locationHistory.length+1),fundId:fund,performedBy,at,sourceEventId:0n,targetEventId:0n}};}
   state.locationHistory.push({fundId:fund,caller:performedBy,requestId:id,operation,reply:clone(reply),at});state.locationRequests.set(id,clone(reply));return {ok:clone(reply)};
 },
 async getFundCurrencies(){return {ok:clone(state.currencies)};},
 async getFundTreasuryAccount(){return {ok:{owner:Principal.fromText(owner),subaccount:new Uint8Array(32)}};},
 async getFundTreasuryBalances(){return {ok:[{currency:clone(state.currencies[0]),balance:{ok:state.chainBalance},checkedAt:1794355200000000000n}]};},
 async addFundManualCurrency(_fund,code,name,decimals){if(caller!==owner)return {err:'Denied'};const c={id:'manual:'+code,symbol:code,name,decimals,ledger:[],enabled:true};state.currencies.push(c);return {ok:clone(c)};},
 async setFundCurrencyEnabled(_fund,id,enabled){if(caller!==owner)return {err:'Denied'};state.currencies.find(c=>c.id===id).enabled=enabled;return {ok:null};},
 async listFundPortfolioAssets(_fund,after,limit,includeArchived){ return {ok:clone(state.assets.filter(a=>a.id>after && (includeArchived || !a.archived)).slice(0,Number(limit)))}; },
 async getFundPortfolioManagers(){return {ok:state.managers.map(p=>Principal.fromText(p))};},
 async setFundPortfolioManager(_fund,p,enabled){if(caller!==owner)return {err:'Denied'};state.managers=enabled?[...new Set([...state.managers,p.toText()])]:state.managers.filter(x=>x!==p.toText());return {ok:null};},
 async listFundPortfolioHistory(_fund,id,after,limit){return {ok:clone(state.events.filter(e=>e.assetId===id&&e.id>after).slice(0,Number(limit)))};},
 async writeFundPortfolio(fund,id,operation){
   state.calls.push({fund,id,operation});
   if(caller!==owner&&!state.managers.includes(caller))return {err:'Portfolio write access denied'};
   if(state.receipts.has(id))return {ok:clone(state.receipts.get(id))};
   if(state.failNext){state.failNext=false;return {err:'Asset changed; refresh before saving'};}
   let asset,kind,delta=0n;
   if(operation.create){const input=operation.create;asset={...input,id:nextId++,fundId:fund,quantityRevision:1n,revision:1n,status:{held:null},archived:false,valuation:[],createdAt:1n};state.assets.push(asset);kind={opening:null};delta=input.quantity;}
   else {
     const input=operation.change;asset=state.assets.find(a=>a.id===input.assetId);
     if(asset.revision!==input.expectedRevision)return {err:'Asset changed; refresh before saving'};
     const c=input.change;kind={change:c};
     if('increase'in c)delta=c.increase;
     if('decrease'in c)delta=-c.decrease;
     if(asset.quantity+delta<0n)return {err:'Insufficient holding quantity'};
     if(delta){asset.quantity+=delta;asset.quantityRevision++;}
     if(c.valuation)asset.valuation=[{...c.valuation,quantityRevision:asset.quantityRevision,at:1794355200000000000n,performedBy:Principal.fromText(caller)}];
     if(c.details)Object.assign(asset,c.details);
     if('archive'in c)asset.archived=c.archive;
     asset.revision++;
   }
   state.events.push({id:BigInt(state.events.length+1),assetId:asset.id,fundId:fund,kind,delta,at:1794355200000000000n,performedBy:Principal.fromText(caller),note:operation.create?.note??operation.change.note,after:clone(asset)});
   state.receipts.set(id,clone(asset));
   if(state.loseResponse){state.loseResponse=false;throw new Error('Response lost; retry with the same values');}
   return {ok:clone(asset)};
 }
};}
