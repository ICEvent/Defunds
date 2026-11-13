// Browser transport fixture; production authorization and arithmetic are tested
// separately against the Motoko actor in portfolio-e2e.sh.
import { Principal } from '@dfinity/principal';
import { replayInvestment } from '../../src/frontend/src/lib/portfolio/investment.js';
import { owner } from './backend.js';
const journal={items:[],events:[],requests:new Map(),loseResponse:false,calls:[]};
window.investmentFixture=journal;
function clone(x){if(x?.toText)return Principal.fromText(x.toText());if(Array.isArray(x))return x.map(clone);if(x&&typeof x==='object')return Object.fromEntries(Object.entries(x).map(([k,v])=>[k,clone(v)]));return x;}
export function withInvestments(backend,caller){return {...backend,
  async listFundInvestments(){return {ok:clone(journal.items)};},
  async listFundInvestmentHistory(_fund,id,after,limit){return {ok:clone(journal.events.filter(e=>e.investmentId===id&&e.id>after).slice(0,Number(limit)))};},
  async writeFundInvestment(fund,id,operation){
    journal.calls.push(id);if(caller!==owner)return {err:'Portfolio write access denied'};
    if(journal.requests.has(id))return {ok:clone(journal.requests.get(id))};
    let item;const at=BigInt(Date.now())*1000000n;
    if(operation.create){item={id:BigInt(journal.items.length+1),fundId:fund,metadata:operation.create,revision:1n,quantity:0n,cost:0n,invested:0n,proceeds:0n,income:0n,expenses:0n,realized:0n,accounts:[],valuation:[],createdAt:at,createdBy:Principal.fromText(caller)};journal.items.push(item);}
    else{
      const r=operation.record;item=journal.items.find(i=>i.id===r.id);if(r.expectedRevision!==item.revision)return {err:'Investment changed; refresh before saving'};
      const kind=Object.keys(r.action)[0],v=r.action[kind];
      if(kind==='valuation')item.valuation=[{...v,quantity:item.quantity,at,performedBy:Principal.fromText(caller)}];
      else{
        const all=journal.events.filter(e=>e.investmentId===item.id&&e.replay).map(e=>e.replay);
        const event={id,at,kind,...(kind==='expense'?{amount:v}:v)};
        if(kind==='buy'||kind==='sell')event.account=String(v.locationId);
        if(kind==='transfer'){event.from=String(v.from);event.to=String(v.to);}
        let result;try{result=replayInvestment([...all,event]);}catch(e){return {err:e.message};}
        for(const key of ['quantity','cost','invested','proceeds','income','expenses','realized'])item[key]=result[key];
        item.accounts=result.accounts.filter(a=>a.quantity>0n).map(a=>({locationId:BigInt(a.account),quantity:a.quantity}));
        if(kind==='buy'||kind==='sell')item.valuation=[];
        journal.nextReplay=event;
      }
      item.revision++;
    }
    journal.events.push({id:BigInt(journal.events.length+1),fundId:fund,investmentId:item.id,operation,at,performedBy:Principal.fromText(caller),replay:journal.nextReplay});journal.nextReplay=null;
    journal.requests.set(id,clone(item));
    if(journal.loseResponse){journal.loseResponse=false;throw new Error('Response lost; retry with the same values');}
    return {ok:clone(item)};
  }
};}
