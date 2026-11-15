export const NETWORKS = [
  {id:'eip155:1', name:'Ethereum', symbol:'ETH', explorer:'https://eth.blockscout.com'},
  {id:'eip155:8453', name:'Base', symbol:'ETH', explorer:'https://base.blockscout.com'},
  {id:'eip155:10', name:'Optimism', symbol:'ETH', explorer:'https://optimism.blockscout.com'},
];
export function networkAccount(location) {
  if (location.kind.chainAccount) return location.kind.chainAccount;
  if (location.kind.wallet) return {network:'ic:mainnet', address:location.kind.wallet.owner.toText()};
  return null;
}
export function networkName(id) { return NETWORKS.find(n=>n.id===id)?.name ?? (id==='ic:mainnet'?'Internet Computer':id); }
export function validateChainAddress(network, address) {
  if (!network.trim() || !address.trim()) throw new Error('Network and address are required');
  if (!/^[a-z0-9:-]{4,64}$/.test(network)) throw new Error('Use a network identifier such as eip155:1 or bitcoin:mainnet');
  if (network.startsWith('eip155:')&&!/^eip155:[1-9][0-9]*$/.test(network)) throw new Error('Use a canonical positive EVM Chain ID');
  if (network.startsWith('eip155:') && !/^0x[\da-fA-F]{40}$/.test(address)) throw new Error('Use a 0x address with 40 hexadecimal characters');
}
function integer(value) { if (typeof value!=='string'||!/^\d+$/.test(value)) throw new Error('Provider returned an invalid balance'); return BigInt(value); }
async function json(url, fetcher, signal) {
  const response=await fetcher(url,{signal,credentials:'omit',referrerPolicy:'no-referrer',headers:{Accept:'application/json'}});
  if (!response.ok) throw new Error(`Provider request failed (${response.status})`);
  return response.json();
}
// Read-only indexed snapshot. A provider failure is unknown, never a zero balance.
export async function fetchChainAssets(network,address,{fetcher=fetch,signal,maxPages=20}={}) {
  validateChainAddress(network,address);
  const chain=NETWORKS.find(n=>n.id===network);
  if (!chain) throw new Error('Automatic asset discovery is not supported for this network yet');
  const base=`${chain.explorer}/api/v2/addresses/${address.toLowerCase()}`;
  const assets=[], errors=[]; let tokenPages=0, tokensComplete=false;
  try {
    const account=await json(base,fetcher,signal);
    assets.push({id:`${network}:native`,name:chain.symbol,symbol:chain.symbol,type:'Native',quantity:integer(account.coin_balance),decimals:18,reference:{network,standard:'native',address:''}});
  } catch(e) { if(signal?.aborted)throw e;errors.push(`Native balance: ${e.message}`); }
  try {
    let params=null; const cursors=new Set(), seen=new Set();
    do {
      const url=new URL(`${base}/tokens`);
      if(params) for(const [key,value] of Object.entries(params)) if(value!==null)url.searchParams.set(key,String(value));
      const page=await json(url.toString(),fetcher,signal);
      if(!Array.isArray(page.items)||!Object.hasOwn(page,'next_page_params'))throw new Error('Invalid token page');
      tokenPages++;
      for(const item of page.items) {
        const token=item.token;
        const contract=token?.address_hash??token?.address;
        if(!/^0x[\da-fA-F]{40}$/.test(contract??''))throw new Error('Invalid token contract in provider response');
        const tokenId=item.token_id??item.token_instance?.id??'';
        const id=`${network}:${contract.toLowerCase()}:${tokenId}`;
        if(seen.has(id))continue;
        const decimals=token.decimals==null?null:Number(token.decimals);
        if(decimals!==null&&(!Number.isInteger(decimals)||decimals<0||decimals>255))throw new Error('Invalid token precision');
        const quantity=integer(item.value);
        seen.add(id);
        assets.push({id,contract,reference:{network,standard:({'ERC-20':'erc20','ERC-721':'erc721','ERC-1155':'erc1155'})[token.type]??'unknown',address:contract.toLowerCase()},name:token.name??'Unnamed token',symbol:token.symbol??'Unknown',type:token.type??'Unknown',tokenId:String(tokenId),quantity,decimals:token.type==='ERC-721'||token.type==='ERC-1155'?0:decimals});
      }
      params=page.next_page_params;
      if(params!==null&&(typeof params!=='object'||Array.isArray(params)||Object.keys(params).length===0))throw new Error('Invalid pagination cursor');
      if(params) {const cursor=JSON.stringify(params);if(cursors.has(cursor))throw new Error('Provider repeated a pagination cursor');cursors.add(cursor);}
      if(tokenPages>=maxPages&&params){errors.push('Token page limit reached; more assets may exist');break;}
      tokensComplete=params===null;
    }while(params);
  }catch(e){if(signal?.aborted)throw e;errors.push(`Token discovery: ${e.message}`);}
  return {network,address,assets,errors,tokensComplete,tokenPages,checkedAt:Date.now(),source:chain.explorer,coverage:'Indexed native coin, ERC-20 and NFT balances. Indexing can lag; DeFi positions and unindexed assets are not covered.'};
}
