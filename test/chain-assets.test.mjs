import test from 'node:test';
import assert from 'node:assert/strict';
import {fetchChainAssets,validateChainAddress,networkAccount} from '../src/frontend/src/lib/portfolio/chain-assets.js';
const address='0xAbCd000000000000000000000000000000001234';
const token=(contract='0x1111111111111111111111111111111111111111',extra={})=>({value:'9007199254740993123456',token:{address_hash:contract,name:'Token',symbol:'T',type:'ERC-20',decimals:'18'},...extra});
const response=body=>({ok:true,json:async()=>body});
test('network identity selects distinct hosts and exact integer balances, paginates and deduplicates',async()=>{
 const urls=[];
 const fetcher=async url=>{urls.push(String(url));const u=new URL(url);return response(!u.pathname.endsWith('/tokens')?{coin_balance:'1000000000000000001'}:u.search?{items:[token(),token('0x2222222222222222222222222222222222222222')],next_page_params:null}:{items:[token()],next_page_params:{items_count:50,value:'123'}});};
 const a=await fetchChainAssets('eip155:1',address,{fetcher});
 assert.equal(a.assets.length,3);assert.equal(a.assets[1].quantity,9007199254740993123456n);assert.deepEqual(a.assets[0].reference,{network:'eip155:1',standard:'native',address:''});assert.equal(a.assets[1].reference.standard,'erc20');assert.equal(a.errors.length,0);assert.equal(a.tokensComplete,true);
 assert.match(urls[2],/items_count=50/);assert.ok(urls.every(u=>u.startsWith('https://eth.blockscout.com/')));
 urls.length=0;await fetchChainAssets('eip155:8453',address,{fetcher});assert.ok(urls.every(u=>u.startsWith('https://base.blockscout.com/')));
});
test('failures and invalid native balances stay unknown; token discovery may still succeed',async()=>{
 const r=await fetchChainAssets('eip155:1',address,{fetcher:async u=>response(String(u).endsWith('/tokens')?{items:[token()],next_page_params:null}:{coin_balance:null})});
 assert.equal(r.assets.length,1);assert.equal(r.assets[0].type,'ERC-20');assert.equal(r.errors.length,1);
});
test('page limits and repeated cursors are visibly partial',async()=>{
 const fetcher=async u=>response(String(u).includes('/tokens')?{items:[token()],next_page_params:{items_count:50}}:{coin_balance:'0'});
 const limited=await fetchChainAssets('eip155:1',address,{fetcher,maxPages:1});assert.equal(limited.tokensComplete,false);assert.match(limited.errors[0],/limit/);
 const repeated=await fetchChainAssets('eip155:1',address,{fetcher});assert.match(repeated.errors[0],/repeated/);
});
test('unknown precision stays unknown and NFT instances remain separate',async()=>{
 const t=token();t.token.decimals=null;
 const nft=id=>({...token(undefined,{token_id:id,value:'1'}),token:{...token().token,type:'ERC-1155',decimals:null}});
 const r=await fetchChainAssets('eip155:10',address,{fetcher:async u=>response(String(u).endsWith('/tokens')?{items:[t,nft('1'),nft('2')],next_page_params:null}:{coin_balance:'0'})});
 assert.equal(r.assets[1].decimals,null);assert.equal(r.assets.length,4);assert.equal(r.assets[2].decimals,0);
});
test('reject malformed addresses and unsupported discovery without requests; legacy network stays unknown',async()=>{
 assert.throws(()=>validateChainAddress('eip155:1','0x123'));
 let calls=0;await assert.rejects(fetchChainAssets('bitcoin:mainnet','bc1address',{fetcher:()=>calls++}),/not supported/);assert.equal(calls,0);
 assert.equal(networkAccount({kind:{blockchain:'Ethereum · 0x123'}}),null);
});
test('provider errors are not empty or zero wallets; cancellation is propagated',async()=>{
 const r=await fetchChainAssets('eip155:1',address,{fetcher:async()=>({ok:false,status:429})});assert.equal(r.assets.length,0);assert.equal(r.errors.length,2);
 const controller=new AbortController();controller.abort();await assert.rejects(fetchChainAssets('eip155:1',address,{signal:controller.signal,fetcher:async()=>{throw new Error('aborted');}}),/aborted/);
});
