import { test } from 'node:test';
import assert from 'node:assert/strict';
import { replayInvestment as replay } from '../src/frontend/src/lib/portfolio/investment.js';
const buy = { id:'1', at:1n, kind:'buy', account:'A', quantity:100n, amount:1000n };
test('partial exit reconciles realized, unrealized and cash flows', () => {
  const r = replay([buy,{id:'2',at:2n,kind:'sell',account:'A',quantity:30n,amount:400n}],{at:3n,quantity:70n,amount:650n});
  assert.equal(r.realized,100n); assert.equal(r.unrealized,-50n); assert.equal(r.total,50n);
  assert.equal(r.total,r.proceeds+r.income+r.value-r.invested-r.expenses);
});
test('additional purchase, income and fees reconcile', () => {
  const r = replay([buy,{...buy,id:'2',at:2n,quantity:50n,amount:600n,fee:10n},
    {id:'3',at:3n,kind:'income',amount:40n},
    {id:'4',at:4n,kind:'sell',account:'A',quantity:60n,amount:780n,fee:5n}],{at:5n,quantity:90n,amount:990n});
  assert.equal(r.total,195n);
  assert.equal(r.total,r.proceeds+r.income+r.value-r.invested-r.expenses);
});
test('transfer preserves pooled cost and cannot spend another account holding', () => {
  const events=[buy,{id:'2',at:2n,kind:'transfer',from:'A',to:'B',quantity:40n}];
  const r=replay(events); assert.equal(r.quantity,100n); assert.equal(r.cost,1000n); assert.equal(r.realized,0n);
  assert.throws(()=>replay([...events,{id:'3',at:3n,kind:'sell',account:'B',quantity:41n,amount:500n}]));
});
test('final exit consumes rounding residue and supports loss beyond principal', () => {
  const r=replay([{...buy,quantity:3n,amount:10n},
    {id:'2',at:2n,kind:'sell',account:'A',quantity:1n,amount:1n},
    {id:'3',at:3n,kind:'sell',account:'A',quantity:2n,amount:0n,fee:5n}]);
  assert.equal(r.cost,0n); assert.equal(r.total,-14n);
});
test('missing estimate is unknown, explicit zero is a complete loss', () => {
  assert.equal(replay([buy]).total,null);
  assert.equal(replay([buy],{at:1n,quantity:100n,amount:0n}).total,-1000n);
});
test('reject duplicate events, stale estimates, imprecise input and invalid order', () => {
  assert.throws(()=>replay([buy,buy]));
  assert.throws(()=>replay([buy],{at:2n,quantity:99n,amount:500n}));
  assert.throws(()=>replay([buy],{at:0n,quantity:100n,amount:500n}));
  assert.throws(()=>replay([{...buy,amount:1.1}]));
  assert.throws(()=>replay([buy,{id:'2',at:0n,kind:'expense',amount:1n}]));
});
