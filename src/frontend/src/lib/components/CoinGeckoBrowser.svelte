<script>
  import {onMount,onDestroy,createEventDispatcher} from 'svelte';
  import {loadCoinGeckoList,lookupCoinGecko} from '$lib/asset-catalog/coingecko.js';
  export let canSave=false;
  const dispatch=createEventDispatcher();
  let active=true,epoch=0,loading=true,error='',coins=[],fetchedAt=0,query='',previousQuery='',page=1;
  let selected=null,details=[],detailLoading=false,detailError='';
  const pageSize=20;
  const pinned=['bitcoin','ethereum','internet-computer','usd-coin','tether','solana'];
  $: if(query!==previousQuery){previousQuery=query;page=1;}
  $: filtered=coins.filter(c=>c.searchText.includes(query.trim().toLowerCase()));
  $: pages=Math.max(1,Math.ceil(filtered.length/pageSize));
  $: rows=filtered.slice((page-1)*pageSize,page*pageSize);
  onMount(()=>{void load();});
  onDestroy(()=>{active=false;epoch++;});
  async function load(force=false){
    loading=true;error='';
    try{
      const result=await loadCoinGeckoList(fetch,{force});
      if(!active)return;
      coins=[...result.coins].sort((a,b)=>{
        const rank=c=>{const index=pinned.indexOf(c.id);return index<0?pinned.length:index;};
        return rank(a)-rank(b)||a.name.localeCompare(b.name);
      });
      fetchedAt=result.fetchedAt;page=1;
    }catch(e){if(active)error=e.message||'Unable to reach CoinGecko. Saved and custom definitions remain available.';}
    finally{if(active)loading=false;}
  }
  async function inspect(coin){
    const version=++epoch;selected=coin;details=[];detailError='';detailLoading=true;
    try{const result=await lookupCoinGecko(coin.id);if(active&&version===epoch)details=result;}
    catch(e){if(active&&version===epoch)detailError=e.message||'Unable to load token details';}
    finally{if(active&&version===epoch)detailLoading=false;}
  }
</script>
<section aria-labelledby="coingecko-heading" class="my-5 min-w-0 rounded-xl border border-slate-200 p-4">
  <div class="flex flex-wrap justify-between gap-3">
    <div><h3 id="coingecko-heading" class="font-semibold">CoinGecko assets</h3><p class="mt-1 text-sm text-slate-600">Browse third-party assets without signing in. These listings are separate from saved definitions.</p></div>
    <button disabled={loading} on:click={()=>load(true)}>Refresh CoinGecko</button>
  </div>
  <label class="mt-3 block text-sm">Search CoinGecko<input bind:value={query} placeholder="Name, symbol or contract" type="search"/></label>
  {#if error}<p role="alert" class="mt-3 rounded bg-amber-50 p-3 text-sm text-amber-900">{error}</p>{/if}
  {#if loading}<p role="status" class="py-4 text-sm">Loading assets from CoinGecko…</p>{/if}
  {#if coins.length}
    <p class="my-3 text-xs text-slate-500">{filtered.length} matching assets · fetched {new Date(fetchedAt).toLocaleString()} · showing up to {pageSize} per page</p>
    <div class="overflow-x-auto"><table class="w-full text-left text-sm"><thead><tr><th>Asset</th><th>Networks & contracts</th><th>Details</th></tr></thead><tbody>
      {#each rows as coin (coin.id)}<tr class="border-t border-slate-100"><td><strong>{coin.name}</strong><div class="text-xs text-slate-500">{coin.symbol} · {coin.id}</div></td><td class="max-w-xs break-all">{#each coin.networks.slice(0,2) as entry}<div>{entry.network} · {entry.contract}</div>{:else}<span class="text-slate-500">Network / contract not provided</span>{/each}{#if coin.networks.length>2}<span class="text-xs text-slate-500">+{coin.networks.length-2} more networks</span>{/if}</td><td><button on:click={()=>inspect(coin)}>View networks</button></td></tr>
      {:else}<tr><td colspan="3" class="py-4">No matching CoinGecko assets. Try another name or symbol.</td></tr>{/each}
    </tbody></table></div>
    <div class="mt-3 flex flex-wrap items-center gap-3"><button disabled={page<=1} on:click={()=>page--}>Previous</button><span class="text-sm">Page {page} of {pages}</span><button disabled={page>=pages} on:click={()=>page++}>Next</button></div>
  {/if}
  {#if selected}<div class="mt-4 min-w-0 rounded-lg bg-slate-50 p-3" aria-live="polite"><h4 class="font-semibold">{selected.name} · network details</h4>
    {#if detailLoading}<p class="mt-2 text-sm">Loading contracts and precision…</p>{:else if detailError}<p role="alert" class="mt-2 text-sm text-rose-800">{detailError}</p><button on:click={()=>inspect(selected)}>Retry details</button>{:else}
      {#each details as candidate}<div class="mt-3 break-all text-sm"><strong>{candidate.network}</strong> · {candidate.contract} · {candidate.decimals} decimals · Unverified{#if canSave}<button class="ml-2" on:click={()=>dispatch('select',candidate)}>Review & add</button>{/if}</div>{/each}
      {#if !details.length}<p class="mt-2 text-sm text-slate-600">No supported token entries with known precision. Native coins and missing precision require a custom definition.</p>{/if}
      {#if !canSave&&details.length}<p class="mt-3 text-xs text-slate-600">Open a Fund you manage to save a custom definition. Global definitions are maintained by administrators.</p>{/if}
    {/if}
    {#if selected.networks.length}<details class="mt-3 text-sm"><summary>All contracts from the source list</summary>{#each selected.networks as entry}<p class="mt-2 break-all">{entry.network} · {entry.contract}</p>{/each}</details>{/if}
  </div>{/if}
  <a class="mt-3 inline-block text-xs underline" href="https://www.coingecko.com/en/api" target="_blank" rel="noreferrer">Data provided by CoinGecko</a>
</section>
<style>input{display:block;width:100%;box-sizing:border-box;border:1px solid #cbd5e1;border-radius:.5rem;padding:.5rem;margin-top:.25rem}button{border:1px solid #cbd5e1;border-radius:.5rem;padding:.5rem .75rem;background:white}button:disabled{opacity:.5}td,th{padding:.75rem .5rem}button:hover:not(:disabled){background:#f1f5f9}</style>
