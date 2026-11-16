<script>
  import { onDestroy, createEventDispatcher } from 'svelte';
  import InvestmentAnalysis from './InvestmentAnalysis.svelte';
  import InvestmentReviews from './InvestmentReviews.svelte';
  export let backend, fundId, items, strategy, canWrite;
  const dispatch=createEventDispatcher();
  let active=true,busy=false,error='',message='',pending=null;
  let policy=strategy.policy[0]??null;
  let maxWeight=Number(policy?.rules.maxWeight??25),staleDays=Number(policy?.rules.staleDays??7),shock=Number(policy?.rules.shock??20),thesis=policy?.rules.thesis??'';
  let investmentId=items[0]?.id.toString()??'',action='review',rationale='',reviewDate='';
  onDestroy(()=>{active=false;});
  function date(at){return new Date(Number(at/1000000n)).toLocaleString();}
  async function save(kind){
    if(busy)return;
    error='';message='';
    try{
      let operation;
      if(kind==='policy'){
        if(![maxWeight,staleDays,shock].every(Number.isInteger)||maxWeight<1||maxWeight>100||staleDays<1||staleDays>3650||shock<0||shock>100||!thesis.trim())throw Error('Provide valid whole-number rules and an investment thesis.');
        operation={policy:{expectedRevision:policy?.revision??0n,rules:{maxWeight:BigInt(maxWeight),staleDays:BigInt(staleDays),shock:BigInt(shock),thesis:thesis.trim()}}};
      }else{
        const item=items.find(i=>i.id.toString()===investmentId);
        const ms=new Date(reviewDate).getTime();
        if(!item||!rationale.trim()||!Number.isFinite(ms)||ms<=Date.now()||ms>Date.now()+366*86400000)throw Error('Choose an investment, explain the decision, and set a future review time within one year.');
        operation={decision:{investmentId:item.id,investmentRevision:item.revision,policyRevision:policy?.revision??0n,action:{[action]:null},rationale:rationale.trim(),reviewAt:BigInt(ms)*1000000n}};
      }
      const key=JSON.stringify(operation,(_,v)=>typeof v==='bigint'?v.toString():v);
      if(pending?.key!==key)pending={key,id:crypto.randomUUID()};
      busy=true;
      const result=await backend.writeFundInvestmentStrategy(fundId,pending.id,operation);
      if(!active)return;
      if('err'in result)throw Error(result.err);
      pending=null;message=kind==='policy'?'Strategy saved':'Decision recorded';dispatch('saved');
    }catch(e){if(active)error=e.message||'Unable to save. Retry with the same values.';}
    finally{if(active)busy=false;}
  }
</script>
<section class="mt-5 rounded-xl border border-slate-200 p-4" aria-labelledby="strategy-heading">
  <h3 id="strategy-heading" class="font-semibold">Investment strategy & decision journal</h3>
  <p class="mt-1 text-sm text-slate-600">{policy?`Saved strategy revision ${policy.revision} · ${date(policy.at)}`:'No saved strategy. Analysis uses editable example rules.'} Strategy updates and decisions use Fund Portfolio write permissions. Saving a decision records intent; it does not execute or approve a trade.</p>
  {#if policy}<p class="mt-2 whitespace-pre-wrap text-sm">{policy.rules.thesis}</p>{/if}
  {#if error}<p role="alert" class="mt-3 text-sm text-rose-800">{error}</p>{/if}
  {#if message}<p role="status" class="mt-3 text-sm text-emerald-700">{message}</p>{/if}
  {#if canWrite}
    <details class="mt-3"><summary class="cursor-pointer font-semibold">Edit saved strategy</summary>
      <form class="mt-3" on:submit|preventDefault={()=>save('policy')}>
        <fieldset disabled={busy} class="grid gap-3 sm:grid-cols-3">
          <label>Saved concentration limit (%)<input required type="number" min="1" max="100" step="1" bind:value={maxWeight}/></label>
          <label>Saved valuation freshness (days)<input required type="number" min="1" max="3650" step="1" bind:value={staleDays}/></label>
          <label>Saved decline scenario (%)<input required type="number" min="0" max="100" step="1" bind:value={shock}/></label>
          <label class="sm:col-span-3">Investment thesis & review conditions<textarea required maxlength="2000" bind:value={thesis}/></label>
        </fieldset>
        <button class="mt-3" disabled={busy}>Save strategy</button>
      </form>
    </details>
    <details class="mt-3"><summary class="cursor-pointer font-semibold">Record investment decision</summary>
      <form class="mt-3" on:submit|preventDefault={()=>save('decision')}>
        <fieldset disabled={busy} class="grid gap-3 sm:grid-cols-2">
          <label>Decision investment<select required bind:value={investmentId}>{#each items as item}<option value={item.id.toString()}>{item.metadata.name}</option>{/each}</select></label>
          <label>Decision action<select bind:value={action}>{#each ['review','hold','add','reduce','exit'] as option}<option value={option}>{option}</option>{/each}</select></label>
          <label>Review time (your local time)<input required type="datetime-local" bind:value={reviewDate}/></label>
          <label class="sm:col-span-2">Decision rationale<textarea required maxlength="2000" bind:value={rationale}/></label>
        </fieldset>
        <p class="mt-2 text-xs text-slate-600">Records the investment revision and saved strategy revision. Unsaved simulation settings are not included. Review dates appear in this journal; no notification is scheduled.</p>
        <button class="mt-3" disabled={busy||!items.length}>Save decision</button>
      </form>
    </details>
  {/if}
  <InvestmentReviews {backend} {fundId} {items} {canWrite} policyRevision={policy?.revision??0n}/>
  <InvestmentAnalysis {items} {policy}/>
  <details class="mt-4"><summary class="cursor-pointer font-semibold">Decision history ({strategy.decisionCount??strategy.decisions.length})</summary>
    <p class="mt-2 text-xs text-slate-500">Showing the latest 50 records at most. Earlier records remain stored.</p><ol class="mt-3 space-y-3">{#each [...strategy.decisions].reverse() as decision (decision.id)}
      <li class="rounded-lg border p-3 text-sm">
        <strong>{items.find(i=>i.id===decision.input.investmentId)?.metadata.name??`Investment #${decision.input.investmentId}`} · {Object.keys(decision.input.action)[0]}</strong>
        <p class="whitespace-pre-wrap">{decision.input.rationale}</p>
        <p>Review {date(decision.input.reviewAt)} · original schedule; see Decision follow-up for current status</p>
        <p class="break-words text-xs text-slate-500">Recorded {date(decision.at)} · {decision.by.toText()} · investment revision {decision.input.investmentRevision} · strategy revision {decision.input.policyRevision}</p>
      </li>
    {:else}<li class="text-sm">No decisions recorded.</li>{/each}</ol>
  </details>
  <details class="mt-3"><summary class="cursor-pointer text-sm">Strategy history ({strategy.policyCount??strategy.policies.length})</summary>
    <p class="mt-2 text-xs text-slate-500">Showing the latest 50 strategy versions at most.</p><ol class="mt-2 space-y-2 text-sm">{#each [...strategy.policies].reverse() as p (p.revision)}<li class="break-words">Revision {p.revision} · {date(p.at)} · {p.by.toText()}<p>Limit {p.rules.maxWeight}% · freshness {p.rules.staleDays} days · decline {p.rules.shock}%</p><p class="whitespace-pre-wrap">{p.rules.thesis}</p></li>{/each}</ol>
  </details>
</section>
<style>
  label { display: grid; gap: 6px; font-size: 14px; min-width: 0; }
  input, select, textarea { width: 100%; min-width: 0; border: 1px solid #cbd5e1; border-radius: 8px; padding: 8px; background: white; color: #0f172a; }
  textarea { min-height: 80px; }
  button { border: 1px solid #cbd5e1; border-radius: 8px; padding: 10px 12px; font-size: 14px; }
  button:disabled { opacity: .5; }
  button:focus-visible, input:focus-visible, select:focus-visible, textarea:focus-visible, summary:focus-visible { outline: 2px solid #0284c7; outline-offset: 2px; }
</style>
