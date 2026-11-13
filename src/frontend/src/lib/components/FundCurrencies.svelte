<script>
  import { Principal } from '@dfinity/principal';
  import { formatUnits } from '$lib/portfolio/amount';
  import { createEventDispatcher, onDestroy, onMount } from 'svelte';
  export let catalogOnly = false;
  export let backend;
  export let fundId;
  export let isCreator = false;
  export let principalText = '';
  let currencies=[], balances=[], account=null, loading=false, busy=false, error='', draftType='ledger';
  let ledger='', code='CAD', name='Canadian dollar', decimals=2;
  let context, epoch=0, active=true;
  const dispatch=createEventDispatcher();
  onDestroy(()=>{active=false;epoch++;});
  onMount(()=>{
    const refresh=()=>{if(document.visibilityState==='visible'&&!loading&&!busy)void load();};
    document.addEventListener('visibilitychange',refresh);window.addEventListener('focus',refresh);
    return ()=>{document.removeEventListener('visibilitychange',refresh);window.removeEventListener('focus',refresh);};
  });
  $: if(backend && principalText && (context?.backend!==backend || context?.id!==fundId || context?.principal!==principalText)){
    context={backend,id:fundId,principal:principalText};void load();
  }
  function unwrap(r){if('err'in r)throw new Error(r.err);return r.ok;}
  async function load(){
    const version=++epoch, actor=backend, id=fundId;
    loading=true;error='';currencies=[];balances=[];account=null;dispatch('balances',{entries:[],loading:true,error:''});
    try{
      const [c,a]=await Promise.all([actor.getFundCurrencies(id),actor.getFundTreasuryAccount(id)]);
      if(!active||version!==epoch)return;
      currencies=unwrap(c);account=unwrap(a);dispatch('currencies',{currencies});
      const b=await actor.getFundTreasuryBalances(id);
      if(!active||version!==epoch)return;
      balances=unwrap(b);dispatch('balances',{entries:balances,loading:false,error:''});
    }catch(e){if(active&&version===epoch){error=e.message||'Unable to refresh fund currencies';dispatch('balances',{entries:[],loading:false,error});}}
    finally{if(active&&version===epoch)loading=false;}
  }
  async function save(){
    const version=epoch;busy=true;error='';
    try{
      const r=draftType==='ledger'?await backend.addFundLedgerCurrency(fundId,Principal.fromText(ledger.trim())):await backend.addFundManualCurrency(fundId,code.trim().toUpperCase(),name.trim(),Number(decimals));
      unwrap(r);if(active&&version===epoch){await load();dispatch('changed');}
    }catch(e){if(active&&version===epoch)error=e.message||'Unable to configure currency';}
    finally{if(active)busy=false;}
  }
  async function toggle(currency){
    const version=epoch;busy=true;error='';
    try{unwrap(await backend.setFundCurrencyEnabled(fundId,currency.id,!currency.enabled));if(active&&version===epoch){await load();dispatch('changed');}}
    catch(e){if(active&&version===epoch)error=e.message;}
    finally{if(active)busy=false;}
  }
  function hex(bytes){return Array.from(bytes,b=>b.toString(16).padStart(2,'0')).join('');}
  function date(n){return new Date(Number(n/1000000n)).toLocaleString();}
</script>
<section class="mt-6 rounded-2xl bg-white p-5 text-slate-950 sm:p-6" aria-labelledby="treasury-heading">
  <div class="flex flex-wrap justify-between gap-3"><div><h2 id="treasury-heading" class="text-xl font-semibold">{catalogOnly ? 'Currency definitions' : 'Portfolio · Fund treasury'}</h2><p class="mt-1 text-sm text-slate-500">{catalogOnly ? 'Currencies are asset definitions too. Configure currency metadata here, then select it when adding a holding.' : 'Ledger balances are separate from manually recorded assets. No exchange-rate total.'}</p></div><button class="button" disabled={loading||busy} on:click={load}>{loading?'Refreshing…':'Refresh balances'}</button></div>
  {#if error}<p role="alert" class="mt-3 rounded-xl bg-rose-50 p-3 text-sm text-rose-800">{error}</p>{/if}
  {#if !catalogOnly}
  {#if account}<details class="mt-4 text-sm"><summary class="cursor-pointer font-semibold">Deposit account · use both owner and subaccount</summary><dl class="mt-3 grid gap-2"><dt>Owner Principal</dt><dd class="break-all font-mono text-xs">{account.owner.toText()}</dd><dt>Subaccount (32-byte hex)</dt><dd class="break-all font-mono text-xs">{hex(account.subaccount)}</dd></dl><p class="mt-2 text-xs text-amber-800">This hex is a subaccount, not a legacy ICP account identifier. Sending to the owner's default account does not fund this Fund.</p></details>{/if}
  {#if balances.length}<div class="mt-5 grid gap-4 sm:grid-cols-2">{#each balances as entry (entry.currency.id)}<article class="border-b border-slate-100 pb-4"><div class="font-semibold">{entry.currency.symbol} <span class="text-xs font-normal text-slate-500">{entry.currency.name}</span></div>{#if 'ok'in entry.balance}<p class="mt-1 text-xl font-semibold">{formatUnits(entry.balance.ok,entry.currency.decimals)} {entry.currency.symbol}</p>{:else}<p class="mt-1 text-sm text-rose-700">Balance unavailable · {entry.balance.err}</p>{/if}<p class="mt-1 break-all text-xs text-slate-500">Ledger {entry.currency.ledger[0]?.toText()}</p><p class="mt-1 text-xs text-slate-400">Checked {date(entry.checkedAt)}{entry.currency.enabled?'':' · Disabled for new proposals'}</p></article>{/each}</div>{:else if !loading}<p class="mt-4 text-sm text-slate-500">No readable on-chain balances. Manual currencies do not have a ledger balance.</p>{/if}
  <p class="mt-4 text-xs text-slate-500">Transfers to configured ledger accounts appear when this page opens, regains focus or balances refresh. These are current balances, not a transaction-history import; they cannot be edited as manual holdings.</p>
  {/if}
  <details open={catalogOnly} class="mt-5 border-t border-slate-100 pt-4"><summary class="cursor-pointer text-sm font-semibold">Fund currencies</summary><ul class="mt-3 divide-y divide-slate-100">{#each currencies as currency (currency.id)}<li class="flex flex-wrap items-center justify-between gap-2 py-3"><div class="min-w-0"><strong>{currency.symbol}</strong> · {currency.decimals} decimals · {currency.ledger.length?'On-chain ledger':'Manual / legacy record'}<div class="break-all text-xs text-slate-500">{currency.id}</div></div>{#if isCreator}<button class="button" disabled={busy||loading} on:click={()=>toggle(currency)}>{currency.enabled?'Disable for proposals':'Enable for proposals'}</button>{:else}<span class="text-xs text-slate-500">{currency.enabled?'Enabled':'Disabled'}</span>{/if}</li>{/each}</ul>
  {#if isCreator}<form on:submit|preventDefault={save} class="mt-4"><fieldset disabled={busy||loading} class="grid min-w-0 gap-3 sm:grid-cols-2"><label>Currency type<select bind:value={draftType}><option value="ledger">On-chain ICRC ledger</option><option value="manual">Custom accounting currency</option></select></label>{#if draftType==='ledger'}<label>Ledger canister Principal<input required bind:value={ledger} placeholder="Ledger ID, not ticker"/></label><p class="text-xs text-slate-500 sm:col-span-2">Symbol, name and decimal precision are read from the ledger. Metadata identifies the configured ledger; it is not an endorsement of the token.</p>{:else}<label>Code<input required maxlength="12" pattern={'[A-Za-z0-9]{1,12}'} bind:value={code}/></label><label>Name<input required maxlength="100" bind:value={name}/></label><label>Decimal places<input required type="number" min="0" max="18" step="1" bind:value={decimals}/></label><p class="text-xs text-slate-500 sm:col-span-2">Manual currencies such as CAD are for accounting proposals only. They do not represent an on-chain CAD balance.</p>{/if}<button class="button sm:col-span-2" type="submit">{busy?'Saving…':'Add currency'}</button></fieldset></form>{/if}</details>
</section>
<style>
  label{display:grid;gap:6px;font-size:14px;min-width:0}input,select{min-width:0;max-width:100%;border:1px solid #cbd5e1;border-radius:10px;padding:9px 12px;background:white;color:#0f172a}.button{border:1px solid #cbd5e1;border-radius:10px;padding:9px 13px;font-size:13px;font-weight:600;white-space:normal}button:disabled{opacity:.5}button:focus-visible,input:focus-visible,select:focus-visible{outline:2px solid #0284c7;outline-offset:2px}
</style>
