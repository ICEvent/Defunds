<script>
  import { analyzeInvestments } from '$lib/portfolio/investment-analysis';
  import { formatUnits } from '$lib/portfolio/amount';
  export let items = [];
  export let policy = null;
  let maxWeight = Number(policy?.rules.maxWeight ?? 25), staleDays = Number(policy?.rules.staleDays ?? 7), shock = Number(policy?.rules.shock ?? 20);
  let now = BigInt(Date.now()) * 1000000n;
  $: result = calculate(items, maxWeight, staleDays, shock, now);
  function calculate(items, maxWeight, staleDays, shock, now) {
    try { return { groups: analyzeInvestments(items, { maxWeight, staleDays, shock }, now), error: '' }; }
    catch (e) { return { groups: [], error: e.message }; }
  }
  function money(value, decimals, currency) {
    return value === null ? 'Unknown' : `${value < 0n ? '−' : ''}${formatUnits(value < 0n ? -value : value, decimals)} ${currency}`;
  }
</script>
<section class="mt-5 rounded-xl border border-sky-200 bg-sky-50 p-4" aria-labelledby="analysis-heading">
  <h3 id="analysis-heading" class="font-semibold">Strategy & decision support</h3>
  <p class="mt-1 text-sm text-slate-600">Explore your own review rules. These simulation controls apply to this view only. They start from the saved strategy when available. Analysis covers up to 100 loaded investment records, not total Portfolio assets; it may exclude additional investments.</p>
  <div class="mt-3 grid gap-3 sm:grid-cols-3">
    <label>Concentration limit (%)<input type="number" min="1" max="100" step="1" bind:value={maxWeight}/></label>
    <label>Valuation freshness (days)<input type="number" min="1" max="3650" step="1" bind:value={staleDays}/></label>
    <label>Simulated price decline (%)<input type="number" min="0" max="100" step="1" bind:value={shock}/></label>
  </div>
  <button type="button" class="mt-3 rounded-lg border border-slate-300 px-3 py-2 text-sm" on:click={()=>now=BigInt(Date.now())*1000000n}>Recheck valuation freshness</button>
  {#if result.error}<p role="alert" class="mt-3 text-sm text-rose-800">{result.error}</p>{/if}
  {#each result.groups as group (group.key)}
    <div class="mt-4 border-t border-sky-200 pt-3">
      <h4 class="font-semibold">{group.currency} settlement group</h4>
      <p class="text-sm text-slate-600">Fresh valuation coverage: {group.rows.filter(r=>r.value!==null).length}/{group.rows.length}. {group.complete ? 'Weights are within this settlement group only.' : 'Concentration assessment unavailable until every holding has a current valuation.'}</p>
      <ul class="mt-3 space-y-3">{#each group.rows as row (row.item.id)}
        <li class="rounded-lg bg-white p-3 text-sm">
          <strong>{row.item.metadata.name}</strong>
          <p class="mt-1">Weight: {row.weight===null?'Unknown':`${Number(row.weight)/100}%`} · {row.overweight?'Review concentration':'Review status'}</p>
          <p class="mt-1">{row.reason}</p>
          <p class="mt-1 text-slate-600">After simulated {shock}% decline: holding value {money(row.scenarioValue,group.decimals,group.currency)} · total P/L {money(row.scenarioTotal,group.decimals,group.currency)}</p>
        </li>
      {/each}</ul>
    </div>
  {:else}{#if !result.error}<p class="mt-3 text-sm">Add investments to begin analysis.</p>{/if}{/each}
  <p class="mt-3 text-xs text-slate-600">Scenario assumes a uniform decline in open holding values; realized P/L stays fixed. No forecast, FX conversion, new fees, liquidity model or transaction is included. Defaults are editable examples. No historical drawdown is inferred from a single valuation.</p>
</section>
<style>
  label { display: grid; gap: 6px; font-size: 14px; }
  input { width: 100%; min-width: 0; border: 1px solid #cbd5e1; border-radius: 8px; padding: 8px; color: #0f172a; background: white; }
  input:focus-visible, button:focus-visible { outline: 2px solid #0284c7; outline-offset: 2px; }
</style>
