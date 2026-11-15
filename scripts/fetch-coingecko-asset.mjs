// Keep API keys in the environment; never put them in frontend VITE_ variables.
import {writeFile} from 'node:fs/promises';
const [id,output]=process.argv.slice(2);
if(!/^[a-z0-9-]{1,80}$/.test(id??'')||!output)throw new Error('Usage: node scripts/fetch-coingecko-asset.mjs usd-coin /tmp/usdc.json');
const key=process.env.COINGECKO_DEMO_API_KEY;
const response=await fetch(`https://api.coingecko.com/api/v3/coins/${id}?localization=false&tickers=false&market_data=false&community_data=false&developer_data=false`,{headers:key?{'x-cg-demo-api-key':key}:{},signal:AbortSignal.timeout(20000)});
if(!response.ok)throw new Error(`CoinGecko request failed (${response.status})`);
const data=await response.json();
if(data.id!==id)throw new Error('Response ID mismatch');
await writeFile(output,JSON.stringify(data,null,2));
console.log(`Saved ${id} metadata to ${output}`);
