<script>
  import { Principal } from '@dfinity/principal';
  import { parseUnits, formatUnits, summarize } from '$lib/portfolio/amount';
  export let backend;
  export let fundId;
  export let principalText = '';
  export let isCreator = false;
  export let members = [];
  let assets = [], managers = [], history = [];
  let loading = false, busy = false, error = '', success = '';
  let includeArchived = false, form = '', selected = null, historyAsset = null;
  let name = '', category = 'equipment', unit = 'item', decimals = 0, quantity = '', note = '';
  let currency = 'CAD', valuationDecimals = 2, amount = '', status = 'held';
  let useSource = false, sourceNetwork = 'ic', sourceCanister = '', sourceAssetId = '';
  let reverseId = 0n;
  let managerPrincipal = '', historyMore = false, historyCursor = 0n;
  let context, epoch = 0, active = true, pendingRequest = null;
  import { onDestroy, tick } from 'svelte';
  let formElement;
  onDestroy(() => { active = false; epoch++; });
  $: canWrite = isCreator || managers.some(p => p.toText() === principalText);
  $: summary = summarize(assets);
  $: shown = assets.filter(a => includeArchived || !a.archived);
  $: if (backend && fundId !== undefined && principalText && (context?.actor !== backend || context?.id !== fundId || context?.principal !== principalText)) {
    context = { actor: backend, id: fundId, principal: principalText };
    void load();
  }
  function unwrap(result) { if ('err' in result) throw new Error(result.err); return result.ok; }
  async function load() {
    const version = ++epoch;
    loading = true; error = ''; assets = []; managers = []; history = []; historyAsset = null; form = ''; pendingRequest = null;
    try {
      const actor = backend, id = fundId;
      const all = []; let cursor = 0n;
      while (true) {
        const batch = unwrap(await actor.listFundPortfolioAssets(id, cursor, 100n, true));
        all.push(...batch);
        if (batch.length < 100) break;
        cursor = batch.at(-1).id;
      }
      const roles = unwrap(await actor.getFundPortfolioManagers(id));
      if (!active || version !== epoch) return;
      assets = all; managers = roles;
    } catch (e) { if (active && version === epoch) error = e.message || 'Unable to load portfolio'; }
    finally { if (active && version === epoch) loading = false; }
  }
  async function open(kind, asset = null) {
    form = kind; selected = asset; error = ''; success = ''; pendingRequest = null;
    name = asset?.name ?? ''; category = asset?.category ?? 'equipment'; unit = asset?.unit ?? 'item';
    decimals = Number(asset?.decimals ?? 0); quantity = ''; note = ''; amount = ''; currency = 'CAD'; valuationDecimals = 2;
    status = asset ? Object.keys(asset.status)[0] : 'held'; useSource = false; sourceNetwork = 'ic'; sourceCanister = ''; sourceAssetId = '';
    await tick();
    formElement?.scrollIntoView({ block: 'nearest' });
    formElement?.querySelector('input, select, textarea, button')?.focus({ preventScroll: true });
  }
  async function write(operation) {
    const key = JSON.stringify(operation, (_, value) => typeof value === 'bigint' ? value.toString() : value);
    if (!pendingRequest || pendingRequest.key !== key) pendingRequest = { key, id: crypto.randomUUID() };
    const version = epoch;
    busy = true; error = ''; success = '';
    try {
      unwrap(await backend.writeFundPortfolio(fundId, pendingRequest.id, operation));
      if (!active || version !== epoch) return;
      form = ''; pendingRequest = null; await load(); success = error ? '' : 'Portfolio saved';
    } catch (e) { if (active && version === epoch) error = e.message || 'Unable to save; retry with the same values'; }
    finally { if (active) busy = false; }
  }
  async function submit() {
    try {
      let operation;
      if (form === 'create') {
        let source = [];
        if (useSource) {
          if (!/^\d+$/.test(sourceAssetId) || sourceAssetId.length > 40) throw new Error('Enter a valid ICEvent asset ID');
          source = [{ network: sourceNetwork.trim(), canisterId: Principal.fromText(sourceCanister.trim()), assetId: BigInt(sourceAssetId) }];
        }
        operation = { create: { name: name.trim(), category: category.trim(), unit: unit.trim(), decimals: Number(decimals), quantity: parseUnits(quantity || '0', decimals), source, note } };
      } else {
        let change;
        if (form === 'increase' || form === 'decrease') change = { [form]: parseUnits(quantity, selected.decimals) };
        else if (form === 'valuation') change = { valuation: { amount: parseUnits(amount, valuationDecimals), currency: currency.trim().toUpperCase(), decimals: Number(valuationDecimals) } };
        else if (form === 'details') change = { details: { name: name.trim(), category: category.trim(), status: { [status]: null } } };
        else if (form === 'reverse') change = { reverse: reverseId };
        else if (form === 'archive') change = { archive: !selected.archived };
        else throw new Error('Unknown operation');
        operation = { change: { assetId: selected.id, expectedRevision: selected.revision, change, note } };
      }
      await write(operation);
    } catch (e) { error = e.message; }
  }
  async function showHistory(asset, append = false) {
    const version = epoch;
    busy = true; error = '';
    try {
      const next = unwrap(await backend.listFundPortfolioHistory(fundId, asset.id, append ? historyCursor : 0n, 50n));
      if (!active || version !== epoch) return;
      historyAsset = asset; history = append ? [...history, ...next] : next;
      historyMore = next.length === 50; historyCursor = next.at(-1)?.id ?? historyCursor;
    } catch (e) { if (active && version === epoch) error = e.message; }
    finally { if (active) busy = false; }
  }
  async function setManager(enabled) {
    const version = epoch;
    busy = true; error = '';
    try {
      unwrap(await backend.setFundPortfolioManager(fundId, Principal.fromText(managerPrincipal), enabled));
      if (active && version === epoch) { await load(); success = error ? '' : 'Portfolio access updated'; }
    } catch (e) { if (active && version === epoch) error = e.message; }
    finally { if (active) busy = false; }
  }
  function value(asset) {
    const v = asset.valuation[0];
    return !v ? 'Not valued' : v.quantityRevision !== asset.quantityRevision ? 'Quantity changed · revalue' : `${v.currency} ${formatUnits(v.amount, v.decimals)}`;
  }
  function date(nanos) { return new Date(Number(nanos / 1_000_000n)).toLocaleString(); }
  function eventLabel(event) { return 'opening' in event.kind ? 'Opening holding' : Object.keys(event.kind.change)[0]; }
</script>

<section class="mt-6 rounded-2xl bg-white p-5 text-slate-950 sm:p-6" aria-labelledby="portfolio-heading">
  <div class="flex flex-wrap items-start justify-between gap-4">
    <div><h2 id="portfolio-heading" class="text-2xl font-semibold">Portfolio</h2><p class="mt-1 text-sm text-slate-500">Member-only asset records · manual valuations · no transfers</p></div>
    <div class="flex gap-2"><button disabled={busy || loading} on:click={load} class="secondary">Refresh</button>{#if canWrite}<button disabled={busy || loading} on:click={() => open('create')} class="primary">+ Add asset</button>{/if}</div>
  </div>
  {#if error && !form}<div role="alert" class="mt-4 rounded-xl bg-rose-50 p-3 text-sm text-rose-800">{error}</div>{/if}
  {#if success}<p role="status" class="mt-3 text-sm text-emerald-700">{success}</p>{/if}
  {#if loading}<p class="py-8 text-slate-500">Loading portfolio…</p>{:else}
    <div class="my-6 flex flex-wrap gap-x-10 gap-y-3 border-y border-slate-100 py-5">
      {#each summary.totals as total}<div><div class="text-xs text-slate-500">Known valuation · {total.currency}</div><div class="mt-1 text-xl font-semibold">{total.currency} {formatUnits(total.amount, 18)}</div></div>{/each}
      <div><div class="text-xs text-slate-500">Awaiting valuation</div><div class="mt-1 text-xl font-semibold">{summary.unvalued} assets</div></div>
    </div>
    <label class="mb-3 flex items-center gap-2 text-sm text-slate-500"><input type="checkbox" bind:checked={includeArchived} /> Show archived</label>
    <!-- Keyboard focus lets users scroll the asset table without a pointer. -->
    <!-- svelte-ignore a11y-no-noninteractive-tabindex -->
    <div class="overflow-x-auto" role="region" aria-label="Portfolio assets" tabindex="0"><table class="w-full text-left text-sm"><thead><tr class="border-b border-slate-200 text-slate-500"><th scope="col">Asset</th><th scope="col">Holding</th><th scope="col">Valuation</th><th scope="col">Status</th><th scope="col">Actions</th></tr></thead><tbody>
      {#each shown as asset (asset.id)}<tr class="border-b border-slate-100">
        <td><strong>{asset.name}</strong><div class="mt-1 text-xs text-slate-500">{asset.category}{#if asset.source.length} · ICEvent reference (unverified){/if}</div></td>
        <td>{formatUnits(asset.quantity, asset.decimals)} {asset.unit}</td><td>{value(asset)}{#if asset.valuation[0]}<div class="mt-1 text-xs text-slate-400">{date(asset.valuation[0].at)}</div>{/if}</td>
        <td>{asset.archived ? 'Archived' : Object.keys(asset.status)[0]}</td>
        <td><div class="flex flex-wrap gap-2">
          <button disabled={busy} on:click={() => showHistory(asset)} class="link">History</button>
          {#if canWrite && !asset.archived}<button disabled={busy} on:click={() => open('increase', asset)} class="link">Increase</button><button disabled={busy} on:click={() => open('decrease', asset)} class="link">Decrease</button><button disabled={busy} on:click={() => open('valuation', asset)} class="link">Revalue</button><button disabled={busy} on:click={() => open('details', asset)} class="link">Edit</button>{/if}
          {#if canWrite && (asset.quantity === 0n || asset.archived)}<button disabled={busy} on:click={() => open('archive', asset)} class="link">{asset.archived ? 'Restore' : 'Archive'}</button>{/if}
        </div></td>
      </tr>{:else}<tr><td colspan="5" class="py-10 text-center text-slate-500">No assets yet.</td></tr>{/each}
    </tbody></table></div>
  {/if}
  {#if form && canWrite}
    <form bind:this={formElement} aria-labelledby="portfolio-form-heading" on:submit|preventDefault={submit} class="mt-6 border-t border-slate-200 pt-5">
      <h3 id="portfolio-form-heading" class="text-lg font-semibold">{form === 'create' ? 'Add asset' : `${form.charAt(0).toUpperCase() + form.slice(1)} · ${selected.name}`}</h3>
      {#if error}<div role="alert" class="mt-3 rounded-xl bg-rose-50 p-3 text-sm text-rose-800">{error}</div>{/if}
      <fieldset disabled={busy} class="mt-4 grid gap-4 sm:grid-cols-2">
        {#if form === 'create' || form === 'details'}
          <label>Name<input required maxlength="120" bind:value={name} /></label>
          <label>Category<select bind:value={category}><option value="cash">Cash</option><option value="crypto">Crypto</option><option value="investment">Investment</option><option value="equipment">Equipment</option><option value="receivable">Receivable</option><option value="other">Other</option></select></label>
        {/if}
        {#if form === 'create'}
          <label>Unit<input required maxlength="24" bind:value={unit} /></label><label>Quantity decimal places<input required type="number" min="0" max="18" step="1" bind:value={decimals} /></label>
        {/if}
        {#if ['create', 'increase', 'decrease'].includes(form)}<label>{form === 'create' ? 'Opening quantity' : 'Quantity'}<input required={form !== 'create'} inputmode="decimal" bind:value={quantity} placeholder="0" /></label>{/if}
        {#if form === 'valuation'}
          <p class="text-sm text-slate-500 sm:col-span-2">Record the total value of this entire holding, not a unit price.</p>
          <label>Total valuation<input required inputmode="decimal" bind:value={amount} /></label><label>Currency code<input required pattern="[A-Za-z0-9]{1,12}" maxlength="12" bind:value={currency} /></label><label>Value decimal places<input required type="number" min="0" max="18" step="1" bind:value={valuationDecimals} /></label>
        {/if}
        {#if form === 'details'}<label>Holding status<select bind:value={status}><option value="held">Held</option><option value="locked">Locked</option><option value="disposed">Disposed (requires zero holding)</option></select></label>{/if}
        {#if form === 'create'}
          <label class="flex items-center gap-2 sm:col-span-2"><input type="checkbox" bind:checked={useSource} /> Add an ICEvent resource reference</label>
          {#if useSource}<p class="text-sm text-amber-800 sm:col-span-2">Reference only. This does not verify ownership or grant access to ICEvent data.</p><label>Network / local instance<input required maxlength="64" bind:value={sourceNetwork} /></label><label>ICEvent ledger canister<input required bind:value={sourceCanister} /></label><label>Asset ID<input required inputmode="numeric" bind:value={sourceAssetId} /></label>{/if}
        {/if}
        {#if form === 'reverse'}<p class="text-sm text-slate-600 sm:col-span-2">Reverse transaction #{reverseId.toString()}? This adds a correction entry and keeps the original record.</p>{/if}
        {#if form === 'archive'}<p class="text-sm text-slate-600 sm:col-span-2">{selected.archived ? 'Restore this asset to the portfolio?' : 'Archive this zero holding? All history will remain available.'}</p>{/if}
        <label class="sm:col-span-2">Note<textarea maxlength="2000" rows="2" bind:value={note}></textarea></label>
        <div class="flex gap-2 sm:col-span-2"><button type="submit" class="primary">{busy ? 'Saving…' : 'Save record'}</button><button type="button" class="secondary" on:click={() => form = ''}>Cancel</button></div>
      </fieldset>
    </form>
  {/if}
  {#if historyAsset}<div class="mt-6 border-t border-slate-200 pt-5"><div class="flex justify-between"><h3 class="font-semibold">History · {historyAsset.name}</h3><button class="link" on:click={() => historyAsset = null}>Close</button></div>
    {#if historyAsset.source[0]}<p class="mt-2 break-all text-xs text-slate-500">Unverified ICEvent reference: {historyAsset.source[0].network} / {historyAsset.source[0].canisterId.toText()} / {historyAsset.source[0].assetId.toString()}</p>{/if}
    <ol class="mt-3 divide-y divide-slate-100">{#each history as event}<li class="py-3 text-sm"><div class="flex justify-between gap-3"><strong>#{event.id.toString()} · {eventLabel(event)}</strong><span class="text-slate-500">{date(event.at)}</span></div>
      <div class="mt-1">{event.delta !== 0n ? `${event.delta > 0n ? '+' : '-'}${formatUnits(event.delta < 0n ? -event.delta : event.delta, event.after.decimals)} ${event.after.unit}` : ''} · Balance {formatUnits(event.after.quantity, event.after.decimals)} {event.after.unit}</div>
      {#if 'change' in event.kind && 'valuation' in event.kind.change}<p>{event.kind.change.valuation.currency} {formatUnits(event.kind.change.valuation.amount, event.kind.change.valuation.decimals)}</p>{/if}
      {#if canWrite && !historyAsset.archived && event.delta !== 0n && ('opening' in event.kind || ('change' in event.kind && ('increase' in event.kind.change || 'decrease' in event.kind.change)))}
        <button disabled={busy} class="link" on:click={() => { open('reverse', historyAsset); reverseId = event.id; }}>Reverse transaction</button>
      {/if}
      {#if event.note}<p class="mt-1 whitespace-pre-wrap">{event.note}</p>{/if}<p class="mt-1 break-all text-xs text-slate-400">By {event.performedBy.toText()}</p>
    </li>{/each}</ol>
    {#if historyMore}<button class="secondary" disabled={busy} on:click={() => showHistory(historyAsset, true)}>Load more history</button>{/if}
  </div>{/if}
  {#if isCreator}<details class="mt-6 border-t border-slate-200 pt-4"><summary class="cursor-pointer text-sm font-semibold">Portfolio managers</summary><p class="mt-2 text-xs text-slate-500">Managers can edit assets. Voting power does not grant portfolio write access.</p>
    <ul class="mt-2 text-xs text-slate-600">{#each managers as manager}<li class="break-all py-1">{manager.toText()}</li>{:else}<li>Only the fund creator can currently edit.</li>{/each}</ul>
    <div class="mt-3 flex flex-wrap gap-2"><select aria-label="Fund member" bind:value={managerPrincipal}><option value="">Select a member</option>{#each members as member}<option value={member.principal.toText()}>{member.name || member.principal.toText()}</option>{/each}</select><button disabled={busy || !managerPrincipal} class="secondary" on:click={() => setManager(true)}>Grant</button><button disabled={busy || !managerPrincipal} class="secondary" on:click={() => setManager(false)}>Revoke</button></div>
  </details>{/if}
</section>
<style>
  fieldset { min-width: 0; }
  th, td { padding: 14px 12px 14px 0; vertical-align: top; }
  td { overflow-wrap: anywhere; }
  th { font-weight: 500; white-space: nowrap; }
  label { display: grid; gap: 6px; font-size: 14px; }
  input:not([type=checkbox]), select, textarea { border: 1px solid #cbd5e1; border-radius: 10px; padding: 9px 12px; background: white; color: #0f172a; min-width: 0; }
  .primary, .secondary { border-radius: 10px; padding: 9px 15px; font-size: 14px; font-weight: 600; }
  .primary { background: #0284c7; color: white; }
  .secondary { border: 1px solid #cbd5e1; color: #334155; background: white; }
  .link { color: #0369a1; font-size: 12px; }
  button:disabled { opacity: .45; cursor: not-allowed; }
  button:focus-visible, input:focus-visible, select:focus-visible, textarea:focus-visible { outline: 2px solid #0284c7; outline-offset: 3px; }
</style>
