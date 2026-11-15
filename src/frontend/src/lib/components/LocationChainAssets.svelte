<script>
  import { onDestroy } from 'svelte';
  import { NETWORKS, networkAccount, networkName, fetchChainAssets } from '$lib/portfolio/chain-assets';
  import { formatUnits } from '$lib/portfolio/amount';
  export let location;
  let snapshot=null, loading=false, error='', controller, version=0;
  $: account=networkAccount(location);
  $: supported=account&&NETWORKS.some(n=>n.id===account.network);
  $: identity=JSON.stringify([location.id.toString(),location.revision.toString(),account]);
  let previous;
  $: if(identity!==previous){previous=identity;version++;controller?.abort();snapshot=null;loading=false;error='';}
  onDestroy(()=>{version++;controller?.abort();});
  async function refresh(){
    const current=++version;
    controller?.abort();controller=new AbortController();
    const request=controller;
    loading=true;error='';
    const timeout=setTimeout(()=>request.abort(),45000);
    try{
      const result=await fetchChainAssets(account.network,account.address,{signal:request.signal});
      if(current!==version)return;
      if(!result.assets.length&&result.errors.length){error=result.errors.join('; ');return;}
      snapshot=result;
    }catch(e){if(current===version)error=request.signal.aborted?'Refresh timed out. Retry to fetch current balances.':e.message;}
    finally{clearTimeout(timeout);if(current===version)loading=false;}
  }
</script>
<div class="mt-2 min-w-0 text-sm">
  {#if account}<p class="break-all text-xs text-slate-500">Network: {networkName(account.network)} · {account.network}</p>{/if}
  {#if supported}
    <button type="button" class="mt-2 rounded-lg border border-slate-300 px-3 py-2 text-xs font-semibold disabled:opacity-50" disabled={loading||!location.enabled} on:click={refresh}>{loading?'Fetching on-chain assets…':'Update on-chain assets'}</button>
    <p class="mt-1 text-xs text-slate-500">Reads this address through Blockscout. Wallet-wide balances are separate from the Fund-owned holdings.</p>
  {:else if 'blockchain' in location.kind}<p class="text-xs text-amber-800">Network unconfirmed. Set network and address before refreshing.</p>
  {:else if account}<p class="text-xs text-slate-500">Asset discovery is currently available for Ethereum, Base and Optimism.</p>{/if}
  {#if error}<p role="alert" class="mt-2 text-xs text-rose-700">{error}{snapshot?' Previous snapshot retained; it is not current.':''}</p>{/if}
  {#if snapshot}
    <div class="mt-3 rounded-lg bg-slate-50 p-3">
      <p class="text-xs font-semibold">{snapshot.errors.length?'Partial snapshot':'Indexed asset snapshot'} · {new Date(snapshot.checkedAt).toLocaleString()}</p>
      <p class="mt-1 text-xs text-slate-500">{snapshot.coverage}</p>
      {#each snapshot.errors as message}<p class="mt-1 text-xs text-amber-800">{message}</p>{/each}
      <ul class="mt-2 divide-y divide-slate-200">{#each snapshot.assets as asset (asset.id)}<li class="py-2"><div class="flex flex-wrap justify-between gap-2"><span>{asset.name} · {asset.symbol} <span class="text-xs text-slate-500">{asset.type}{asset.tokenId?` #${asset.tokenId}`:''}</span></span><strong>{asset.decimals===null?`${asset.quantity} base units (precision unknown)`:formatUnits(asset.quantity,asset.decimals)}</strong></div>{#if asset.contract}<p class="break-all text-xs text-slate-500">Contract: {asset.contract}</p>{/if}</li>{/each}</ul>
      <a class="mt-2 inline-block text-xs text-sky-700 underline" href={`${snapshot.source}/address/${snapshot.address}`} target="_blank" rel="noopener noreferrer">View source on Blockscout</a>
    </div>
  {/if}
</div>
