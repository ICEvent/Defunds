import { test } from 'node:test';
import assert from 'node:assert/strict';
import { analyzeInvestments as analyze } from '../src/frontend/src/lib/portfolio/investment-analysis.js';
const now=1000000000000000000n;
const policy={maxWeight:60,staleDays:7,shock:20};
const item=(id,amount,currencyId='usd')=>({id,metadata:{currencyId,currency:currencyId,moneyDecimals:2},quantity:1n,cost:80n,realized:5n,valuation:[{amount,quantity:1n,at:now}]});
test('weights, concentration and stress P/L use exact amounts',()=>{
 const [g]=analyze([item(1,700n),item(2,300n)],policy,now);
 assert.equal(g.rows[0].weight,7000n);assert.equal(g.rows[0].overweight,true);
 assert.equal(g.rows[0].scenarioValue,560n);assert.equal(g.rows[0].scenarioTotal,485n);
});
test('missing, stale, mismatched and future valuations block group weights',()=>{
 for(const valuation of [[],[{amount:1n,quantity:1n,at:now-8n*86400000000000n}],[{amount:1n,quantity:2n,at:now}],[{amount:1n,quantity:1n,at:now+1n}]]){
 const bad={...item(2,1n),valuation};const [g]=analyze([item(1,700n),bad],policy,now);
 assert.equal(g.complete,false);assert.equal(g.rows[0].weight,null);assert.equal(g.rows[0].overweight,false);assert.equal(g.rows[1].scenarioValue,null);
 }
});
test('currencies and precision stay separate; zero values remain valid',()=>{
 const groups=analyze([item(1,0n),item(2,100n,'cad'),{...item(3,100n),metadata:{currencyId:'usd',currency:'USD',moneyDecimals:8}}],policy,now);
 assert.equal(groups.length,3);assert.equal(groups[0].complete,true);assert.equal(groups[0].rows[0].scenarioTotal,-75n);assert.equal(groups[0].rows[0].weight,null);
});
test('closed holding has zero exposure even without valuation',()=>{
 const [g]=analyze([{...item(1,100n),quantity:0n,cost:0n,valuation:[]}],policy,now);
 assert.equal(g.rows[0].value,0n);assert.equal(g.rows[0].scenarioTotal,5n);
});
test('invalid policies are rejected and total loss supports huge amounts',()=>{
 for(const p of [{shock:101},{staleDays:0},{maxWeight:NaN},{maxWeight:1.5}])assert.throws(()=>analyze([],{...policy,...p},now));
 const [g]=analyze([item(1,10n**40n)],{...policy,shock:100},now);
 assert.equal(g.rows[0].scenarioValue,0n);assert.equal(g.rows[0].scenarioTotal,-75n);
});
