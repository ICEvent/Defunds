<script>
  import { onMount, onDestroy } from 'svelte';
  export let backend, fundId, items, canWrite, policyRevision;
  let queue=[],selected=null,decision=null,latestReview=null,reviews=[],more=false,busy=false,loading=true,error='',success='',active=true,epoch=0,pending=null;
  let filter='open',outcome='maintain',conclusion='',nextAction='',nextDate='',now=BigInt(Date.now())*1000000n;
  onMount(()=>{void load();});
  onDestroy(()=>{active=false;epoch++;});
  $: due=queue.filter(q=>!q.closed&&q.reviewAt[0]!==undefined&&q.reviewAt[0]<=now);
  $: visible=queue.filter(q=>filter==='all'||(filter==='due'?due.includes(q):!q.closed)).sort(compare);
  function compare(a,b){if(a.closed!==b.closed)return a.closed?1:-1;const x=a.reviewAt[0]??0n,y=b.reviewAt[0]??0n;return x<y?-1:x>y?1:0;}
  function unwrap(r){if('err'in r)throw Error(r.err);return r.ok;}
  function date(at){return at===undefined?'None':new Date(Number(at/1000000n)).toLocaleString();}
  function name(id){return items.find(i=>i.id===id)?.metadata.name??`Investment #${id}`;}
  async function load(){
    const version=++epoch;loading=true;error='';selected=null;decision=null;reviews=[];pending=null;
    try{const rows=unwrap(await backend.getFundInvestmentReviewQueue(fundId));if(active&&version===epoch){queue=rows;now=BigInt(Date.now())*1000000n;}}
    catch(e){if(active&&version===epoch)error=e.message||'Unable to load review queue';}
    finally{if(active&&version===epoch)loading=false;}
  }
  async function open(row,append=false){
    if(busy)return;
    const version=++epoch;busy=true;error='';success='';
    if(!append){selected=row;decision=null;reviews=[];more=false;pending=null;outcome='maintain';conclusion='';nextAction='';nextDate='';}
    try{
      const data=unwrap(await backend.getFundInvestmentReviewHistory(fundId,row.decisionId,append?(reviews.at(-1)?.id??0n):0n,50n));
      if(!active||version!==epoch)return;
      decision=data.decision;latestReview=data.latestReview?.[0]??null;reviews=append?[...reviews,...data.reviews]:data.reviews;more=data.reviews.length===50;
    }catch(e){if(active&&version===epoch)error=e.message||'Unable to load decision';}
    finally{if(active&&version===epoch)busy=false;}
  }
  async function save(){
    if(busy||!selected||!decision)return;
    error='';success='';
    const version=epoch;
    try{
      const ms=outcome==='close'?null:new Date(nextDate).getTime();
      if(!conclusion.trim()||!nextAction.trim()||(outcome!=='close'&&(!Number.isFinite(ms)||ms<=Date.now()||ms>Date.now()+366*86400000)))throw Error('Provide a conclusion, next action, and a future review time within one year for continuing decisions.');
      const item=items.find(i=>i.id===decision.input.investmentId);
      if(!item)throw Error('Investment is unavailable; refresh before reviewing.');
      const input={investmentRevision:item.revision,policyRevision,decisionId:selected.decisionId,expectedRevision:selected.revision,outcome:{[outcome]:null},conclusion:conclusion.trim(),nextAction:nextAction.trim(),nextReviewAt:ms===null?[]:[BigInt(ms)*1000000n]};
      const key=JSON.stringify(input,(_,v)=>typeof v==='bigint'?v.toString():v);
      if(pending?.key!==key)pending={key,id:crypto.randomUUID()};
      busy=true;
      unwrap(await backend.writeFundInvestmentReview(fundId,pending.id,input));
      if(!active||version!==epoch)return;
      await load();if(active)success='Review recorded. Queue updated.';
    }catch(e){if(active&&version===epoch)error=e.message||'Unable to save. Retry with the same values.';}
    finally{if(active)busy=false;}
  }
</script>
<section aria-labelledby="review-heading" class="mt-4 rounded-xl border border-slate-200 p-4">
  <h4 id="review-heading" class="font-semibold">Decision follow-up</h4>
  <p class="mt-1 text-sm text-slate-600">Review conclusions, record the next action, and schedule another review or close the decision. This queue includes all recorded decisions, including older journal entries. Dates appear here; no external notifications or trades are sent.</p>
  <div class="mt-3 flex flex-wrap items-end gap-3">
    <p aria-live="polite" class="text-sm">{due.length} due · {queue.filter(q=>!q.closed).length} open · {queue.filter(q=>q.closed).length} closed</p>
    <label>Review queue filter<select bind:value={filter}><option value="open">Open</option><option value="due">Due</option><option value="all">All</option></select></label>
    <button type="button" disabled={busy||loading} on:click={load}>Refresh review queue</button>
  </div>
  {#if error}<p role="alert" class="mt-3 text-sm text-rose-800">{error}</p>{/if}
  {#if success}<p role="status" class="mt-3 text-sm text-emerald-700">{success}</p>{/if}
  {#if loading}<p class="mt-3 text-sm">Loading review queue…</p>{:else}
    <ul class="mt-3 space-y-2">{#each visible as row (row.decisionId)}
      <li class="flex flex-wrap items-center justify-between gap-2 rounded-lg border p-3 text-sm">
        <div><strong>{name(row.investmentId)} · decision #{row.decisionId}</strong><p>{row.closed?'Closed':`Review ${date(row.reviewAt[0])}${row.reviewAt[0]<=now?' · Due':''}`}</p></div>
        <button type="button" disabled={busy} on:click={()=>open(row)}>View decision #{row.decisionId}</button>
      </li>
    {:else}<li class="text-sm">No decisions match this filter.</li>{/each}</ul>
  {/if}
  {#if selected&&decision}
    <div class="mt-4 border-t pt-3">
      <h5 class="font-semibold">Decision #{decision.id} · {name(decision.input.investmentId)}</h5>
      <p class="mt-1 whitespace-pre-wrap text-sm">Original action: {Object.keys(decision.input.action)[0]} · {decision.input.rationale}</p>
      <p class="mt-1 text-xs text-slate-500">Original investment revision {decision.input.investmentRevision} · strategy revision {decision.input.policyRevision}. Current investment revision {items.find(i=>i.id===decision.input.investmentId)?.revision??'Unknown'} · strategy revision {policyRevision}.</p>
      {#if latestReview}<div class="mt-3 rounded-lg border border-sky-200 p-3 text-sm"><strong>Latest review · {Object.keys(latestReview.input.outcome)[0]}</strong><p class="whitespace-pre-wrap">Conclusion: {latestReview.input.conclusion}</p><p class="whitespace-pre-wrap">Next action: {latestReview.input.nextAction}</p></div>{/if}
      <p class="mt-3 text-xs text-slate-500">Review history is shown oldest first.</p>
      <ol class="mt-3 space-y-2">{#each reviews as review (review.id)}<li class="rounded-lg bg-slate-50 p-3 text-sm">
        <strong>Review {review.revision} · {Object.keys(review.input.outcome)[0]}</strong>
        <p class="whitespace-pre-wrap">{review.input.conclusion}</p><p class="whitespace-pre-wrap">Next action: {review.input.nextAction}</p>
        <p>Next review: {date(review.input.nextReviewAt[0])}</p>
        <p class="break-words text-xs text-slate-500">{date(review.at)} · {review.by.toText()} · investment revision {review.investmentRevision} · strategy revision {review.policyRevision}</p>
      </li>{:else}<li class="text-sm">No reviews recorded.</li>{/each}</ol>
      {#if more}<button type="button" class="mt-2" disabled={busy} on:click={()=>open(selected,true)}>Load more reviews</button>{/if}
      {#if canWrite&&!selected.closed}
        <form class="mt-4" on:submit|preventDefault={save}>
          <fieldset disabled={busy} class="grid gap-3 sm:grid-cols-2">
            <label>Review outcome<select bind:value={outcome}><option value="maintain">Maintain decision</option><option value="adjust">Adjust plan</option><option value="close">Close decision</option></select></label>
            {#if outcome!=='close'}<label>Next review time (your local time)<input required type="datetime-local" bind:value={nextDate}/></label>{/if}
            <label class="sm:col-span-2">Review conclusion<textarea required maxlength="2000" bind:value={conclusion}/></label>
            <label class="sm:col-span-2">Next action<textarea required maxlength="2000" bind:value={nextAction}/></label>
          </fieldset>
          <p class="mt-2 text-xs text-slate-600">Closing is final for this decision. Create a new decision for a new plan. An adjustment records intent and does not change holdings or the saved strategy.</p>
          <button class="mt-3" disabled={busy}>Save review</button>
        </form>
      {/if}
    </div>
  {/if}
</section>
<style>
  label {display:grid;gap:6px;font-size:14px;min-width:0;}
  input,select,textarea {width:100%;min-width:0;border:1px solid #cbd5e1;border-radius:8px;padding:8px;background:white;color:#0f172a;}
  textarea {min-height:80px;}
  button {border:1px solid #cbd5e1;border-radius:8px;padding:10px 12px;font-size:14px;}
  button:disabled {opacity:.5;}
  button:focus-visible,input:focus-visible,select:focus-visible,textarea:focus-visible {outline:2px solid #0284c7;outline-offset:2px;}
</style>
