// CoinGecko platform IDs are explicit: never infer a network from a ticker.
const platforms = {ethereum:['ethereum','erc20'],base:['base','erc20'],'arbitrum-one':['arbitrum','erc20'],'internet-computer':['icp','icrc1'],solana:['solana','spl']};
export function coinGeckoCandidates(data) {
  if (!data || typeof data.id !== 'string' || !/^[a-z0-9-]{1,80}$/.test(data.id) || typeof data.name !== 'string' || typeof data.symbol !== 'string') throw new Error('Invalid CoinGecko coin response');
  const candidates=[];
  for (const [platform, detail] of Object.entries(data.detail_platforms ?? {})) {
    const mapping=platforms[platform];
    if (!mapping || !detail || typeof detail.contract_address !== 'string' || !detail.contract_address.trim()) continue;
    const decimals=detail.decimal_place;
    if (!Number.isInteger(decimals) || decimals < 0 || decimals > 18) continue;
    candidates.push({assetKey:`coingecko:${data.id}`,name:data.name,symbol:data.symbol.toUpperCase(),network:mapping[0],standard:mapping[1],contract:detail.contract_address,decimals,source:`https://www.coingecko.com/en/coins/${data.id}`,verified:false,enabled:true});
  }
  // Native coin precision cannot be inferred from an absent contract.
  return candidates;
}
const cache = new Map();
export async function lookupCoinGecko(id, fetcher=fetch) {
  if (!/^[a-z0-9-]{1,80}$/.test(id)) throw new Error('Enter a CoinGecko ID such as usd-coin');
  const cached=cache.get(id);
  if(cached && Date.now()-cached.at<3600000)return cached.value;
  const response=await fetcher(`https://api.coingecko.com/api/v3/coins/${encodeURIComponent(id)}?localization=false&tickers=false&market_data=false&community_data=false&developer_data=false`,{signal:AbortSignal.timeout(15000)});
  if(!response.ok)throw new Error(`CoinGecko returned ${response.status}. Retry later or import a coin JSON response fetched with your API key.`);
  const data=await response.json();
  if(data.id!==id)throw new Error('CoinGecko response ID does not match');
  const value=coinGeckoCandidates(data);cache.set(id,{at:Date.now(),value});return value;
}

export function coinGeckoList(data) {
  if (!Array.isArray(data)) throw new Error('CoinGecko returned an invalid asset list');
  const seen = new Set();
  return data.flatMap(coin => {
    if (!coin || typeof coin.id !== 'string' || !/^[a-z0-9-]{1,80}$/.test(coin.id) || typeof coin.name !== 'string' || typeof coin.symbol !== 'string' || seen.has(coin.id)) return [];
    seen.add(coin.id);
    const networks = Object.entries(coin.platforms ?? {}).flatMap(([platform, address]) =>
      platform && typeof address === 'string' && address.trim()
        ? [{ network: platforms[platform]?.[0] ?? platform, contract: address }]
        : []);
    return [{ id:coin.id, name:coin.name, symbol:coin.symbol.toUpperCase(), networks,
      searchText:[coin.id,coin.name,coin.symbol,...networks.flatMap(n=>[n.network,n.contract])].join(' ').toLowerCase() }];
  });
}
let listSnapshot = null, listRequest = null;
export async function loadCoinGeckoList(fetcher=fetch, {force=false}={}) {
  if (!force && listSnapshot && Date.now()-listSnapshot.fetchedAt<3600000) return listSnapshot;
  if (listRequest) return listRequest;
  listRequest = (async()=>{
    const response = await fetcher('https://api.coingecko.com/api/v3/coins/list?include_platform=true', {
      signal:AbortSignal.timeout(20000), credentials:'omit', referrerPolicy:'no-referrer'
    });
    if (!response.ok) throw new Error(`CoinGecko returned ${response.status}. Retry later; saved and custom definitions remain available.`);
    const coins = coinGeckoList(await response.json());
    if (!coins.length) throw new Error('CoinGecko returned no usable assets. Retry later; saved and custom definitions remain available.');
    listSnapshot = {coins,fetchedAt:Date.now()};
    return listSnapshot;
  })();
  try { return await listRequest; } finally { listRequest=null; }
}
