<script>
  import { onDestroy, tick } from 'svelte';
  import { parseUnits, formatUnits } from '$lib/portfolio/amount';
  import { definitionKey } from '$lib/portfolio/locations';
  export let backend, fundId, principalText = '', refreshToken = 0;
  let items=[], locations=[], currencies=[], definitions=[], canWrite=false;
  let loading=false,busy=false,error='',success='',context,epoch=0,active=true,pending=null;
  let form='',selected=null,history=[],more=false,historyFor=null,formElement;
  let name='',definitionId='',currencyId='',locationId='',targetId='',quantity='',amount='',fee='0',source='',note='';
  onDestroy(()=>{active=false;epoch++;});
  $: if(backend&&principalText&&(context?.backend!==backend||context?.fundId!==fundId||context?.principalText!==principalText||context?.refresh!==refreshToken)){
    context={backend,fundId,principalText,refresh:refreshToken};void load();
  }
  $: if((!backend||!principalText)&&context){epoch++;context=null;items=[];locations=[];currencies=[];definitions=[];canWrite=false;form='';selected=null;history=[];historyFor=null;pending=null;error='';success='';loading=false;}
  $: definition=definitions.find(d=>d.key===definitionId);
  $: currency=currencies.find(c=>c.id===currencyId);
  function unwrap(r){if('err'in r)throw new Error(r.err);return r.ok;}
  function money(value,item){return value===null?'Awaiting valuation':`${formatSigned(value,item.metadata.moneyDecimals)} ${item.metadata.currency}`;}
  function formatSigned(value,decimals){return value<0n?`−${formatUnits(-value,decimals)}`:formatUnits(value,decimals);}
  function value(item){return item.quantity===0n?0n:item.valuation[0]?.amount??null;}
  function unrealized(item){const v=value(item);return v===null?null:v-item.cost;}
  function total(item){const u=unrealized(item);return u===null?null:item.realized+u;}
  function locationName(id){return locations.find(l=>l.id===id)?.name??`Location #${id}`;}
  function date(at){return new Date(Number(at/1000000n)).toLocaleString();}
  async function load(){
    const version=++epoch;loading=true;error='';items=[];locations=[];currencies=[];definitions=[];canWrite=false;form='';selected=null;history=[];historyFor=null;pending=null;
    const actor=backend,id=fundId;
    try{
      const [list,p]=await Promise.all([actor.listFundInvestments(id,0n,100n),actor.getFundLocationPortfolio(id)]);
      const all=unwrap(list),portfolio=unwrap(p);
      if(!active||version!==epoch)return;
      items=all;locations=portfolio.locations;currencies=portfolio.currencies;canWrite=portfolio.canWrite;
      const defs=currencies.map(c=>({key:`currency:${c.id}`,definition:{currency:c.id},name:c.name,unit:c.symbol,decimals:c.decimals}));
      const seen=new Set(defs.map(d=>d.key));
      for(const p of portfolio.positions){const key=definitionKey(p.definition);if(!seen.has(key)&&!p.asset.archived){seen.add(key);defs.push({key,definition:p.definition,name:p.name,unit:p.unit,decimals:p.decimals});}}
      definitions=defs;
    }catch(e){if(active&&version===epoch)error=e.message||'Unable to load investments; check backend deployment';}
    finally{if(active&&version===epoch)loading=false;}
  }
  async function open(kind,item=null){
    form=kind;selected=item;error='';success='';pending=null;name='';note='';source='';quantity='';amount='';fee='0';
    definitionId=definitions[0]?.key??'';currencyId=currencies.find(c=>c.enabled)?.id??'';
    locationId=(kind==='sell'||kind==='transfer'?item?.accounts.find(a=>a.quantity>0n)?.locationId:locations.find(l=>l.enabled)?.id)?.toString()??'';
    targetId='';await tick();formElement?.querySelector('input,select,textarea')?.focus();
  }
  async function submit(){
    try{
      let operation;
      if(form==='create'){
        if(!definition||!currency)throw new Error('Choose an asset and settlement currency');
        operation={create:{name:name.trim(),definition:definition.definition,assetName:definition.name,unit:definition.unit,decimals:definition.decimals,currencyId:currency.id,currency:currency.symbol,moneyDecimals:currency.decimals}};
      }else{
        const m=selected.metadata;let action;
        if(form==='buy'||form==='sell')action={[form]:{locationId:BigInt(locationId),quantity:parseUnits(quantity,m.decimals),amount:parseUnits(amount,m.moneyDecimals),fee:parseUnits(fee||'0',m.moneyDecimals)}};
        else if(form==='income')action={income:{amount:parseUnits(amount,m.moneyDecimals),fee:parseUnits(fee||'0',m.moneyDecimals)}};
        else if(form==='expense')action={expense:parseUnits(amount,m.moneyDecimals)};
        else if(form==='transfer')action={transfer:{from:BigInt(locationId),to:BigInt(targetId),quantity:parseUnits(quantity,m.decimals),fee:parseUnits(fee||'0',m.moneyDecimals)}};
        else if(form==='valuation')action={valuation:{amount:parseUnits(amount,m.moneyDecimals),source:source.trim()}};
        else throw new Error('Unknown action');
        operation={record:{id:selected.id,expectedRevision:selected.revision,action,note:note.trim()}};
      }
      const key=JSON.stringify(operation,(_,v)=>typeof v==='bigint'?v.toString():v);
      if(pending?.key!==key)pending={key,id:crypto.randomUUID()};
      const version=epoch;busy=true;error='';
      try{unwrap(await backend.writeFundInvestment(fundId,pending.id,operation));if(!active||version!==epoch)return;await load();success=error?'':'Investment saved';}
      catch(e){if(active&&version===epoch)error=e.message||'Unable to save; retry with the same values';}
      finally{if(active)busy=false;}
    }catch(e){error=e.message;}
  }
  async function showHistory(item,append=false){
    const version=epoch;busy=true;error='';
    try{const batch=unwrap(await backend.listFundInvestmentHistory(fundId,item.id,append?(history.at(-1)?.id??0n):0n,50n));if(!active||version!==epoch)return;historyFor=item;history=append?[...history,...batch]:batch;more=batch.length===50;}
    catch(e){if(active&&version===epoch)error=e.message;}
    finally{if(active)busy=false;}
  }
  function eventText(e){
    if('create'in e.operation)return 'Investment created';
    const a=e.operation.record.action,m=historyFor.metadata,kind=Object.keys(a)[0],v=a[kind];
    if(kind==='buy'||kind==='sell')return `${kind==='buy'?'Buy':'Sell'} · ${formatUnits(v.quantity,m.decimals)} ${m.unit} · ${money(v.amount,historyFor)} · fee ${money(v.fee,historyFor)} · ${locationName(v.locationId)}`;
    if(kind==='transfer')return `Transfer · ${formatUnits(v.quantity,m.decimals)} ${m.unit} · ${locationName(v.from)} → ${locationName(v.to)} · fee ${money(v.fee,historyFor)}`;
    if(kind==='expense')return `Expense · ${money(v,historyFor)}`;
    if(kind==='income')return `Income · ${money(v.amount,historyFor)} · fee ${money(v.fee,historyFor)}`;
    return `Valuation · ${money(v.amount,historyFor)} · ${v.source}`;
  }
</script>
<section class="mt-6 rounded-2xl bg-white p-5 text-slate-950 sm:p-6" aria-labelledby="investment-heading">
  <div class="flex flex-wrap justify-between gap-3"><div><h2 id="investment-heading" class="text-xl font-semibold">Investments</h2><p class="mt-1 max-w-3xl text-sm text-slate-500">Manual investment journal · recorded separately from Portfolio balances. Recording a trade or transfer updates this journal only. No funds are transferred.</p></div><button class="button" disabled={busy||loading} on:click={load}>Refresh investments</button></div>
  {#if error}<p role="alert" class="mt-3 rounded-xl bg-rose-50 p-3 text-sm text-rose-800">{error}</p>{/if}
  {#if success}<p role="status" class="mt-3 text-sm text-emerald-700">{success}</p>{/if}
  {#if loading}<p class="py-6">Loading investments…</p>{:else}
    <p class="mt-4 text-sm text-slate-500">Valuation coverage: {items.filter(i=>value(i)!==null).length} / {items.length}. Each investment uses its own settlement currency; amounts are not combined across currencies.</p>
    {#if canWrite}<button class="button mt-3" disabled={busy} on:click={()=>open('create')}>+ Add investment</button>{/if}
    <div class="mt-4 space-y-4">{#each items as item (item.id)}
      <article class="rounded-xl border border-slate-200 p-4">
        <h3 class="font-semibold">{item.metadata.name}</h3><p class="text-sm text-slate-500">{item.metadata.assetName} · {formatUnits(item.quantity,item.metadata.decimals)} {item.metadata.unit} · {item.quantity===0n?(item.invested===0n?'Planned':'Exited'):'Holding'}</p>
        <dl class="mt-3 grid grid-cols-2 gap-3 text-sm sm:grid-cols-4">
          {#each [['Total invested',item.invested],['Remaining cost',item.cost],['Current value',value(item)],['Sale proceeds',item.proceeds],['Income',item.income],['Realized P/L',item.realized],['Unrealized P/L',unrealized(item)],['Total P/L',total(item)]] as metric}
            <div><dt class="text-slate-500">{metric[0]}</dt><dd class="mt-1 break-words font-semibold" class:text-rose-700={metric[1]!==null&&metric[1]<0n} class:text-emerald-700={metric[0].includes('P/L')&&metric[1]!==null&&metric[1]>0n}>{money(metric[1],item)}</dd></div>
          {/each}
        </dl>
        {#if item.valuation[0]}<p class="mt-3 break-words text-xs text-slate-500">Valued {date(item.valuation[0].at)} · {item.valuation[0].source}</p>{:else if item.quantity>0n}<p class="mt-3 text-xs text-amber-800">Awaiting valuation after the latest purchase or sale.</p>{/if}
        <ul class="mt-3 text-xs text-slate-600">{#each item.accounts as a}<li>{locationName(a.locationId)} · {formatUnits(a.quantity,item.metadata.decimals)} {item.metadata.unit}</li>{/each}</ul>
        <div class="mt-3 flex flex-wrap gap-2">{#if canWrite}{#each [['buy','Buy / add'],['sell','Sell'],['income','Income'],['expense','Expense'],['transfer','Transfer'],['valuation','Value holding']] as action}<button class="button" disabled={busy} on:click={()=>open(action[0],item)}>{action[1]}</button>{/each}{/if}<button class="button" disabled={busy} on:click={()=>showHistory(item)}>Investment history</button></div>
      </article>
    {:else}<p class="py-5 text-sm text-slate-500">No investments yet.</p>{/each}</div>
  {/if}
  {#if form&&canWrite}
    <form bind:this={formElement} aria-label="Investment entry" class="mt-5 rounded-xl border border-slate-200 p-4" on:submit|preventDefault={submit}>
      <h3 class="font-semibold">{form==='create'?'New investment':`${form} · ${selected.metadata.name}`}</h3>
      <fieldset disabled={busy} class="mt-3 grid gap-3 sm:grid-cols-2">
        {#if form==='create'}
          <label>Investment name<input required maxlength="120" bind:value={name}/></label>
          <label>Investment asset<select aria-label="Investment asset" required bind:value={definitionId}>{#each definitions as d}<option value={d.key}>{d.name} · {d.unit}</option>{/each}</select></label>
          <label>Settlement currency<select aria-label="Settlement currency" required bind:value={currencyId}>{#each currencies.filter(c=>c.enabled) as c}<option value={c.id}>{c.symbol} · {c.id}</option>{/each}</select></label>
        {:else}
          {#if ['buy','sell','transfer'].includes(form)}<label>Investment location<select aria-label="Investment location" required bind:value={locationId}><option value="" disabled>Choose location</option>{#each locations.filter(l=>form==='buy'?l.enabled:selected.accounts.some(a=>a.locationId===l.id&&a.quantity>0n)) as l}<option value={l.id.toString()}>{l.name}</option>{/each}</select></label><label>Investment quantity ({selected.metadata.unit})<input required inputmode="decimal" bind:value={quantity}/></label>{/if}
          {#if form==='transfer'}<label>Destination location<select aria-label="Destination location" required bind:value={targetId}><option value="" disabled>Choose destination</option>{#each locations.filter(l=>l.enabled&&l.id.toString()!==locationId) as l}<option value={l.id.toString()}>{l.name}</option>{/each}</select></label>{:else}<label>{form==='valuation'?'Total holding value':'Investment amount'} ({selected.metadata.currency})<input required inputmode="decimal" bind:value={amount}/></label>{/if}
          {#if ['buy','sell','income','transfer'].includes(form)}<label>Investment fee ({selected.metadata.currency})<input required inputmode="decimal" bind:value={fee}/></label>{/if}
          {#if form==='valuation'}<label>Valuation source<input required maxlength="500" bind:value={source}/></label>{/if}
          <label class="sm:col-span-2">Investment note<textarea maxlength="2000" bind:value={note}></textarea></label>
        {/if}
      </fieldset>
      <p class="mt-3 text-xs text-slate-500">Entries are confirmed manual records, stamped with the current time. Verify amounts before saving. Purchase fees enter cost; other fees reduce realized P/L. Fees must be in the settlement currency.</p>
      <div class="mt-3 flex gap-2"><button type="submit" class="button" disabled={busy}>{busy?'Saving…':'Save investment'}</button><button type="button" class="button" disabled={busy} on:click={()=>{form='';pending=null;error='';}}>Cancel investment</button></div>
    </form>
  {/if}
  {#if historyFor}<div class="mt-5 border-t pt-4"><h3 class="font-semibold">Investment history · {historyFor.metadata.name}</h3><ol class="mt-3 space-y-3 text-sm">{#each history as e (e.id)}<li class="break-words"><strong>{eventText(e)}</strong><p class="text-xs text-slate-500">{date(e.at)} · {e.performedBy.toText()}</p>{#if 'record'in e.operation}<p>{e.operation.record.note}</p>{/if}</li>{/each}</ol>{#if more}<button class="button mt-3" disabled={busy} on:click={()=>showHistory(historyFor,true)}>More investment history</button>{/if}</div>{/if}
</section>

<style>
  p, li, dd { overflow-wrap: anywhere; }
  label { display: grid; gap: 6px; font-size: 14px; min-width: 0; }
  input, select, textarea { width: 100%; min-width: 0; max-width: 100%; border: 1px solid #cbd5e1; border-radius: 10px; padding: 9px 12px; background: white; color: #0f172a; }
  textarea { min-height: 80px; }
  .button { border: 1px solid #cbd5e1; border-radius: 10px; padding: 9px 13px; font-size: 13px; font-weight: 600; min-height: 44px; }
  button:disabled { opacity: .5; }
  button:focus-visible, input:focus-visible, select:focus-visible, textarea:focus-visible { outline: 2px solid #0284c7; outline-offset: 2px; }
</style>
