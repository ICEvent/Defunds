<script>
  import { Principal } from '@dfinity/principal';
  import { onDestroy, createEventDispatcher, tick } from 'svelte';
  import { parseUnits, formatUnits } from '$lib/portfolio/amount';
  import { definitionKey, assetGroups, walletSubaccount } from '$lib/portfolio/locations';
  export let view = 'all';
  export let manageHoldings = false;
  $: holdingWorkspace = view === 'holdings' || (view === 'portfolio' && manageHoldings);
  export let backend, fundId, principalText = '', refreshToken = 0;
  export let treasury = {entries:[],loading:true,error:''};
  let locations=[], positions=[], currencies=[], canWrite=false, loading=false, busy=false, error='', success='';
  let formElement, selectedLocation;
  let context, epoch=0, active=true, pendingRequest=null, mode='asset', form='', history=[], moreHistory=false;
  let locationName='', kind='wallet', reference='', walletOwner='', subaccount='', locationId='';
  let definitionId='', existingId='', quantity='', note='', sourceId='', targetId='', fee='0';
  const dispatch=createEventDispatcher();
  onDestroy(()=>{active=false;epoch++;});
  $: if(backend && principalText && (context?.actor!==backend || context?.fund!==fundId || context?.principal!==principalText || context?.refresh!==refreshToken)){
    context={actor:backend,fund:fundId,principal:principalText,refresh:refreshToken};void load();
  }
  $: definitions=(()=>{
    const result=currencies.map(c=>({key:`currency:${c.id}`,definition:{currency:c.id},name:`${c.symbol} · ${c.id}`,unit:c.symbol,decimals:c.decimals}));
    const seen=new Set(result.map(d=>d.key));
    for(const p of positions.filter(p=>!p.asset.archived)){const key=definitionKey(p.definition);if(!seen.has(key)){seen.add(key);result.push({key,definition:p.definition,name:p.name,unit:p.unit,decimals:p.decimals});}}
    return result;
  })();
  $: selectedDefinition=definitions.find(d=>d.key===definitionId);
  $: selectedSource=positions.find(p=>p.asset.id.toString()===sourceId);
  $: selectedTarget=positions.find(p=>p.asset.id.toString()===targetId);
  $: targets=selectedSource?positions.filter(p=>!p.asset.archived && p.asset.id!==selectedSource.asset.id && p.locationId!==selectedSource.locationId && locations.some(l=>l.id===p.locationId&&l.enabled) && !('disposed'in p.asset.status) && definitionKey(p.definition)===definitionKey(selectedSource.definition)):[];
  $: totals=assetGroups(positions,treasury.entries,currencies);
  function unwrap(r){if('err'in r)throw new Error(r.err);return r.ok;}
  function locationLabel(id){return id===0n?'Unassigned':locations.find(l=>l.id===id)?.name??'Unknown location';}
  function kindLabel(location){const type=Object.keys(location.kind)[0];return type==='blockchain'?'Blockchain':type;}
  async function load(){
    const version=++epoch;loading=true;error='';positions=[];locations=[];currencies=[];canWrite=false;form='';pendingRequest=null;history=[];
    try{const data=unwrap(await backend.getFundLocationPortfolio(fundId));if(!active||version!==epoch)return;({positions,locations,currencies,canWrite}=data);dispatch('links',data.linkedEventIds??[]);dispatch('snapshot',{positions,locations});}
    catch(e){if(active&&version===epoch)error=e.message||'Unable to load locations';}
    finally{if(active&&version===epoch)loading=false;}
  }
  async function open(kind){form=kind;error='';success='';pendingRequest=null;note='';quantity='';fee='0';sourceId='';targetId='';definitionId=definitions[0]?.key??'';existingId='';locationId=locations.find(l=>l.enabled)?.id.toString()??'';await tick();formElement?.scrollIntoView({block:'nearest'});formElement?.querySelector('input,select,textarea,button')?.focus({preventScroll:true});}
  async function write(operation){
    const key=JSON.stringify(operation,(_,value)=>typeof value==='bigint'?value.toString():value);
    if(!pendingRequest||pendingRequest.key!==key)pendingRequest={key,id:crypto.randomUUID()};
    const version=epoch;busy=true;error='';success='';
    try{unwrap(await backend.writeFundLocationPortfolio(fundId,pendingRequest.id,operation));if(!active||version!==epoch)return;await load();success=error?'':'Location portfolio saved';if(!error)dispatch('changed');}
    catch(e){if(active&&version===epoch)error=e.message||'Unable to save; retry with the same values';}
    finally{if(active)busy=false;}
  }
  async function submit(){
    try{
      if(form==='rename'){await write({updateLocation:{id:selectedLocation.id,expectedRevision:selectedLocation.revision,name:locationName.trim(),enabled:selectedLocation.enabled}});
      }else if(form==='location'){
        const value=kind==='wallet'?{wallet:{owner:Principal.fromText(walletOwner.trim()),subaccount:walletSubaccount(subaccount)}}:{[kind]:reference.trim()};
        await write({addLocation:{name:locationName.trim(),kind:value}});
      }else if(form==='holding'){
        if(!selectedDefinition || !locationId)throw new Error('Choose an asset and a location');
        await write({create:{definition:selectedDefinition.definition,locationId:BigInt(locationId),quantity:parseUnits(quantity||'0',selectedDefinition.decimals),note}});
      }else if(form==='bind'){
        const asset=positions.find(p=>p.asset.id.toString()===existingId)?.asset;
        if(!asset || !selectedDefinition || !locationId)throw new Error('Choose an existing holding, its asset definition and location');
        await write({bind:{assetId:asset.id,expectedRevision:asset.revision,definition:selectedDefinition.definition,locationId:BigInt(locationId)}});
      }else if(form==='move'){
        if(!selectedSource||!selectedTarget)throw new Error('Choose source and target holdings of the same asset');
        await write({move:{sourceId:selectedSource.asset.id,targetId:selectedTarget.asset.id,sourceRevision:selectedSource.asset.revision,targetRevision:selectedTarget.asset.revision,quantity:parseUnits(quantity,selectedSource.decimals),fee:parseUnits(fee||'0',selectedSource.decimals),note}});
      }
    }catch(e){error=e.message;}
  }
  async function toggle(location){await write({updateLocation:{id:location.id,expectedRevision:location.revision,name:location.name,enabled:!location.enabled}});}
  async function loadHistory(append=false){
    const version=epoch;busy=true;error='';
    try{const batch=unwrap(await backend.listFundLocationHistory(fundId,append?BigInt(history.length):0n,50n));if(!active||version!==epoch)return;history=append?[...history,...batch]:batch;moreHistory=batch.length===50;}
    catch(e){if(active&&version===epoch)error=e.message;}
    finally{if(active)busy=false;}
  }
  function movementText(m){const p=positions.find(p=>p.asset.id===m.sourceId);return p?`${formatUnits(m.quantity,p.decimals)} ${p.unit} · fee ${formatUnits(m.fee,p.decimals)} ${p.unit}`:'Movement details unavailable';}
  function date(at){return new Date(Number(at/1000000n)).toLocaleString();}
</script>
<section class="mt-6 rounded-2xl bg-white p-5 text-slate-950 sm:p-6" aria-labelledby="location-heading">
  <div class="flex flex-wrap justify-between gap-3"><div><h2 id="location-heading" class="text-xl font-semibold">{view==='portfolio'?'Portfolio':view==='locations'?'Locations':view==='holdings'?'Holdings':'Asset locations & holdings'}</h2><p class="mt-1 text-sm text-slate-500">{view==='locations'?'Step 2 · Define where assets are held. A location can hold several asset types.':view==='holdings'?'Step 3 · Select an asset definition and a location, then record the Fund-owned quantity.':view==='portfolio'?'Totals by asset definition, with quantities at each location. External holdings are manually recorded.':"Track the Fund's share at each location. External holdings are manually recorded."}</p></div><div class="flex flex-wrap gap-2">{#if view==='portfolio'}<button class="button" aria-pressed={manageHoldings} on:click={()=>dispatch('manageholdings')}>{manageHoldings?'Close holding management':'Manage holdings'}</button>{/if}<button class="button" disabled={busy||loading} on:click={load}>{view==='portfolio'?'Refresh portfolio':'Refresh locations'}</button></div></div>
  {#if error&&!form}<p role="alert" class="mt-3 rounded-xl bg-rose-50 p-3 text-sm text-rose-800">{error}</p>{/if}
  {#if success}<p role="status" class="mt-3 text-sm text-emerald-700">{success}</p>{/if}
  {#if loading}<p class="py-6 text-sm text-slate-500">Loading holdings…</p>{:else}
    <div class="mt-5 flex flex-wrap items-center gap-2">{#if view==='all'}<label class="mr-auto text-sm">View<select aria-label="Holdings view" bind:value={mode}><option value="asset">By asset</option><option value="location">By location</option></select></label>{/if}{#if canWrite}{#if view==='all'||view==='locations'}<button class="button" disabled={busy} on:click={()=>open('location')}>+ Add location</button>{/if}{#if view==='all'||holdingWorkspace}<button class="button" disabled={busy||!definitions.length||!locations.some(l=>l.enabled)} on:click={()=>open('holding')}>+ Add holding</button><button class="button" disabled={busy} on:click={()=>open('bind')}>Assign existing</button><button class="button" disabled={busy} on:click={()=>open('move')}>Record movement</button>{/if}{/if}</div>
    {#if holdingWorkspace}<div class="mt-3 flex flex-wrap gap-3 text-sm"><button class="button" on:click={()=>dispatch('configure','definitions')}>Manage asset definitions</button><button class="button" on:click={()=>dispatch('configure','locations')}>Manage locations</button><button class="button" on:click={()=>dispatch('configure','currencies')}>Manage currencies</button></div>{/if}
    {#if holdingWorkspace&&(!definitions.length||!locations.some(l=>l.enabled))}<p class="mt-4 text-sm text-slate-600">Create an Asset definition and an enabled Location before adding a holding.</p>{/if}
    {#if view==='all'||view==='portfolio'}
    {#if mode==='asset'}
      <div class="mt-4 divide-y divide-slate-100">{#each totals as total (total.key)}<details class="py-4" open><summary class="cursor-pointer"><strong>{total.name}</strong><span class="ml-3">{total.known?formatUnits(total.quantity,total.decimals):'Unknown'} {total.unit}</span>{#if total.unavailable}<span class="ml-2 text-xs text-amber-800">{treasury.loading?'Fund balance pending':'Partial · Fund balance unavailable'}</span>{/if}</summary><ul class="mt-3 space-y-2 text-sm text-slate-600">{#each total.positions.filter(p=>p.locationId!==0n||p.asset.quantity!==0n) as position (position.asset.id)}<li class="flex flex-wrap justify-between gap-2"><span>{locationLabel(position.locationId)} <span class="text-xs text-slate-400">· manual Fund share · #{position.asset.id.toString()}</span></span><span>{formatUnits(position.asset.quantity,position.decimals)} {position.unit}</span></li>{/each}{#each treasury.entries.filter(e=>`currency:${e.currency.id}`===total.key) as entry}<li class="flex flex-wrap justify-between gap-2"><span>Local · Fund treasury · ledger balance</span><span>{'ok'in entry.balance?formatUnits(entry.balance.ok,entry.currency.decimals):'Unavailable'} {entry.currency.symbol}</span></li>{/each}</ul></details>{:else}<p class="py-6 text-sm text-slate-500">No assets yet. Start with Asset definitions, add a Location, then record a Holding.</p>{/each}</div>
    {:else}
      {#each [{id:0n,name:'Unassigned'},...locations] as location (location.id)}
        {@const held=positions.filter(p=>p.locationId===location.id&&!p.asset.archived)}
        {#if held.length}<div class="mt-4 border-b border-slate-100 pb-4"><h3 class="font-semibold">{location.name}</h3><ul class="mt-2 space-y-2 text-sm text-slate-600">{#each held as p}<li>{p.name} · {formatUnits(p.asset.quantity,p.decimals)} {p.unit} <span class="text-xs">· manual Fund share · #{p.asset.id.toString()}</span></li>{/each}</ul></div>{/if}
      {/each}
      {#if treasury.entries.length}<div class="mt-4 border-b border-slate-100 pb-4"><h3 class="font-semibold">Local · Fund treasury · ledger balances</h3><ul class="mt-2 space-y-2 text-sm">{#each treasury.entries as e}<li>{e.currency.symbol} · {'ok'in e.balance?formatUnits(e.balance.ok,e.currency.decimals):'Unavailable'}</li>{/each}</ul></div>{/if}
    {/if}
    {/if}
    {#if form&&canWrite&&(view==='all'||(view==='locations'&&['location','rename'].includes(form))||(holdingWorkspace&&!['location','rename'].includes(form)))}<form bind:this={formElement} aria-label="Location portfolio operation" class="mt-5 border-t border-slate-200 pt-4" on:submit|preventDefault={submit}><h3 class="font-semibold">{form==='rename'?'Rename location':form==='location'?'Add location':form==='holding'?'Add holding':form==='bind'?'Assign existing holding':'Record movement'}</h3>{#if error}<p role="alert" class="mt-3 rounded-xl bg-rose-50 p-3 text-sm text-rose-800">{error}</p>{/if}<fieldset disabled={busy} class="mt-4 grid min-w-0 gap-3 sm:grid-cols-2">
      {#if form==='rename'}<label>Location name<input required maxlength="120" bind:value={locationName}/></label>
      {:else if form==='location'}<label>Location name<input required maxlength="120" bind:value={locationName}/></label><label>Location type<select aria-label="Location type" bind:value={kind}><option value="wallet">External IC wallet</option><option value="blockchain">Blockchain</option><option value="bank">Bank account</option><option value="cash">Cash custody</option><option value="storage">Storage / warehouse</option><option value="other">Other</option></select></label>{#if kind==='wallet'}<label>Wallet owner Principal<input required bind:value={walletOwner}/></label><label>Subaccount hex (optional)<input bind:value={subaccount} placeholder="64 hexadecimal characters"/></label>{:else}<label class="sm:col-span-2">{kind==='blockchain'?'Blockchain network & address':'Location reference'}<input required maxlength="200" bind:value={reference} placeholder={kind==='blockchain'?'e.g. Ethereum · 0x… or Bitcoin · bc1…':'Name or masked reference; do not enter banking credentials'}/></label>{/if}
      {:else if form==='holding'||form==='bind'}
        {#if form==='bind'}<label>Existing unassigned holding<select required bind:value={existingId} on:change={(event)=>{const p=positions.find(p=>p.asset.id.toString()===event.currentTarget.value);if(p)definitionId=definitionKey(p.definition);}}><option value="">Choose holding</option>{#each positions.filter(p=>p.locationId===0n) as p}<option value={p.asset.id.toString()}>#{p.asset.id.toString()} · {p.asset.name}</option>{/each}</select></label>{/if}
        <label>Asset definition<select aria-label="Asset definition" required bind:value={definitionId}>{#each definitions as d}<option value={d.key}>{d.name}</option>{/each}</select></label><label>Holding location<select aria-label="Holding location" required bind:value={locationId}><option value="">Choose location</option>{#each locations.filter(l=>l.enabled) as l}<option value={l.id.toString()}>{l.name}</option>{/each}</select></label>
        {#if form==='holding'}<label>Fund-owned quantity<input inputmode="decimal" bind:value={quantity} placeholder="0"/></label><p class="text-xs text-slate-500 sm:col-span-2">Record only the quantity owned by this Fund, not the entire external wallet balance. Use zero to prepare a destination for a movement.</p>{/if}
      {:else if form==='move'}<label>Source holding<select aria-label="Source holding" required bind:value={sourceId} on:change={()=>targetId=''}><option value="">Choose source</option>{#each positions.filter(p=>p.locationId!==0n&&!p.asset.archived&&p.asset.quantity>0n) as p}<option value={p.asset.id.toString()}>{p.name} · {locationLabel(p.locationId)} · #{p.asset.id.toString()}</option>{/each}</select></label><label>Destination holding<select aria-label="Destination holding" required bind:value={targetId}><option value="">Choose destination</option>{#each targets as p}<option value={p.asset.id.toString()}>{p.name} · {locationLabel(p.locationId)}</option>{/each}</select></label><label>Quantity moved<input required inputmode="decimal" bind:value={quantity}/></label><label>Fee (same asset)<input inputmode="decimal" bind:value={fee}/></label><p class="text-sm text-amber-800 sm:col-span-2">This records a movement already made outside Defunds. It does not send money. Source decreases by quantity plus fee; destination increases by quantity.</p>{/if}
      {#if form!=='location'&&form!=='bind'&&form!=='rename'}<label class="sm:col-span-2">Note<textarea maxlength="2000" rows="2" bind:value={note}></textarea></label>{/if}<div class="flex gap-2 sm:col-span-2"><button type="submit" class="button">{busy?'Saving…':'Save location record'}</button><button type="button" class="button" on:click={()=>form=''}>Cancel location edit</button></div>
    </fieldset></form>{/if}
    {#if view==='all'||view==='locations'}<details open={view==='locations'} class="mt-5 border-t border-slate-100 pt-4"><summary class="cursor-pointer text-sm font-semibold">Manage locations</summary><ul class="mt-3 divide-y divide-slate-100">{#each locations as l}<li class="flex flex-wrap justify-between gap-2 py-3"><div><strong>{l.name}</strong> · {kindLabel(l)} · {l.enabled?'Active':'Disabled for new holdings'}<p class="mt-1 break-all text-xs text-slate-500">{#if 'wallet'in l.kind}{l.kind.wallet.owner.toText()} · {l.kind.wallet.subaccount.length?'Custom subaccount':'Default subaccount'}{:else}{Object.values(l.kind)[0]}{/if}</p></div>{#if canWrite}<div class="flex gap-2"><button class="button" disabled={busy} on:click={async()=>{await open('rename');selectedLocation=l;locationName=l.name;}}>Rename location</button><button class="button" disabled={busy} on:click={()=>toggle(l)}>{l.enabled?'Disable location':'Restore location'}</button></div>{/if}</li>{:else}<li class="text-sm text-slate-500">No external locations.</li>{/each}</ul></details>{/if}
    <details class="mt-5 border-t border-slate-100 pt-4"><summary class="cursor-pointer text-sm font-semibold" on:click={()=>{if(!history.length)void loadHistory();}}>Location & movement history</summary><ol class="mt-3 divide-y divide-slate-100">{#each history as r}<li class="py-3 text-sm"><strong>{Object.keys(r.operation)[0]}</strong> · {date(r.at)}{#if 'movement'in r.reply}<p>#{r.reply.movement.sourceId.toString()} → #{r.reply.movement.targetId.toString()} · {movementText(r.reply.movement)}</p>{/if}<p class="break-all text-xs text-slate-500">By {r.caller.toText()}</p></li>{/each}</ol>{#if moreHistory}<button class="button" disabled={busy} on:click={()=>loadHistory(true)}>Load more location history</button>{/if}</details>
  {/if}
</section>
<style>
  summary, li, p { overflow-wrap: anywhere; }
  label{display:grid;gap:6px;font-size:14px;min-width:0}input,select,textarea{min-width:0;max-width:100%;border:1px solid #cbd5e1;border-radius:10px;padding:9px 12px;background:white;color:#0f172a}.button{border:1px solid #cbd5e1;border-radius:10px;padding:9px 13px;font-size:13px;font-weight:600}button:disabled{opacity:.5}button:focus-visible,input:focus-visible,select:focus-visible,textarea:focus-visible{outline:2px solid #0284c7;outline-offset:2px}
</style>
