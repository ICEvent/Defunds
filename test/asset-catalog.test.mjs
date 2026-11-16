import {test} from 'node:test';
import assert from 'node:assert/strict';
import {coinGeckoCandidates,lookupCoinGecko,coinGeckoList,loadCoinGeckoList} from '../src/frontend/src/lib/asset-catalog/coingecko.js';
const coin={id:'usd-coin',name:'USD Coin',symbol:'usdc',detail_platforms:{ethereum:{decimal_place:6,contract_address:'0x'+'a'.repeat(40)},base:{decimal_place:6,contract_address:'0x'+'b'.repeat(40)}}};
test('multi-network metadata retains identity, precision and unverified provenance',()=>{
 const rows=coinGeckoCandidates(coin);assert.equal(rows.length,2);assert.equal(rows[0].assetKey,rows[1].assetKey);assert.notEqual(rows[0].network,rows[1].network);assert.equal(rows[0].decimals,6);assert.equal(rows[0].verified,false);assert.match(rows[0].source,/coingecko/);
});
test('missing precision, native placeholders and unsupported networks never become guessed entries',()=>{
 assert.deepEqual(coinGeckoCandidates({...coin,detail_platforms:{ethereum:{decimal_place:null,contract_address:'0x123'},base:{decimal_place:19,contract_address:'0x123'},'':{decimal_place:8,contract_address:''},unknown:{decimal_place:6,contract_address:'abc'}}}),[]);
});
test('lookup caches successful responses and rejects mismatched provider data',async()=>{
 let count=0;const fetcher=async()=>{count++;return {ok:true,json:async()=>coin}};
 await lookupCoinGecko('usd-coin',fetcher);await lookupCoinGecko('usd-coin',fetcher);assert.equal(count,1);
 await assert.rejects(lookupCoinGecko('different-coin',fetcher),/does not match/);
 await assert.rejects(lookupCoinGecko('../invalid',fetcher),/CoinGecko ID/);
});
test('provider failures are actionable and not cached',async()=>{
 let count=0;const fetcher=async()=>{count++;return {ok:false,status:429}};
 await assert.rejects(lookupCoinGecko('limited',fetcher),/429/);await assert.rejects(lookupCoinGecko('limited',fetcher),/429/);assert.equal(count,2);
});

const listing=[{id:'usd-coin',name:'USD Coin',symbol:'usdc',platforms:{base:'0x'+'d'.repeat(40),ethereum:'0x'+'a'.repeat(40)}}];
test('public source list preserves network contracts without guessing decimals or native chains',()=>{
 const rows=coinGeckoList([...listing,...listing,{id:'bitcoin',name:'Bitcoin',symbol:'btc',platforms:{'':''}},null]);
 assert.equal(rows.length,2);assert.equal(rows[0].networks[0].network,'base');assert.equal(rows[0].symbol,'USDC');
 assert.ok(rows[0].searchText.includes('0x'+'d'.repeat(40)));assert.deepEqual(rows[1].networks,[]);assert.equal(rows[0].decimals,undefined);
 assert.throws(()=>coinGeckoList({error:'bad'}),/invalid asset list/);
});
test('public list caches successful reads, coalesces requests and preserves its last snapshot on failure',async()=>{
 let count=0;const fetcher=async(url,options)=>{count++;assert.match(url,/include_platform=true/);assert.equal(options.credentials,'omit');return {ok:true,json:async()=>listing}};
 const [one,two]=await Promise.all([loadCoinGeckoList(fetcher,{force:true}),loadCoinGeckoList(fetcher,{force:true})]);
 assert.equal(one,two);assert.equal(count,1);assert.equal(await loadCoinGeckoList(fetcher),one);assert.equal(count,1);
 await assert.rejects(loadCoinGeckoList(async()=>({ok:false,status:429}),{force:true}),/429/);
 assert.equal(await loadCoinGeckoList(fetcher),one);
 await assert.rejects(loadCoinGeckoList(async()=>({ok:true,json:async()=>[]}),{force:true}),/no usable assets/);
});
