import {test} from 'node:test';
import assert from 'node:assert/strict';
import {assetGroups,definitionKey,walletSubaccount} from '../src/frontend/src/lib/portfolio/locations.js';
const currency={id:'ic:ledger-a',name:'Token',symbol:'SAME',decimals:2,ledger:['ledger-a']};
const position=(quantity,locationId=1n)=>({asset:{quantity,archived:false},definition:{currency:currency.id},locationId,name:'Token',unit:'SAME',decimals:2});
test('same asset joins across places and live treasury; same tickers do not join',()=>{
 const other={...currency,id:'ic:ledger-b',ledger:['ledger-b']};
 const groups=assetGroups([position(500n),position(800n,2n)],[{currency,balance:{ok:1000n}},{currency:other,balance:{ok:3n}}],[currency,other]);
 assert.equal(groups.length,2);assert.equal(groups[0].quantity,2300n);assert.equal(groups[0].positions.length,2);assert.equal(groups[1].quantity,3n);
 assert.notEqual(definitionKey({asset:1n}),definitionKey({currency:'1'}));
});
test('unknown live balance stays incomplete, explicit zero remains known, archived holdings excluded',()=>{
 const groups=assetGroups([{...position(100n),asset:{quantity:100n,archived:true}}],[{currency,balance:{err:'Unavailable'}}],[currency]);
 assert.equal(groups[0].known,false);assert.equal(groups[0].unavailable,true);
 const partial=assetGroups([position(500n)],[],[currency])[0];assert.equal(partial.quantity,500n);assert.equal(partial.unavailable,true);
 const zero=assetGroups([],[{currency,balance:{ok:0n}}],[currency])[0];assert.equal(zero.known,true);assert.equal(zero.unavailable,false);
});
test('precision mismatch fails rather than silently adding different minor units',()=>{
 assert.throws(()=>assetGroups([{...position(100n),decimals:3}],[{currency,balance:{ok:1n}}],[currency]),/precision mismatch/);
});
test('wallet subaccounts preserve exact bytes and reject invalid hex',()=>{
 assert.deepEqual(walletSubaccount(''),[]);assert.equal(walletSubaccount('01'.repeat(32))[0].length,32);
 assert.throws(()=>walletSubaccount('1'));assert.throws(()=>walletSubaccount('zz'.repeat(32)));
});
