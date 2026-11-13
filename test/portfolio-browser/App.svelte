<script>
  import LocationPortfolio from '../../src/frontend/src/lib/components/LocationPortfolio.svelte';
  import FundCurrencies from '../../src/frontend/src/lib/components/FundCurrencies.svelte';
  import GroupPortfolio from '../../src/frontend/src/lib/components/GroupPortfolio.svelte';
  import { Principal } from '@dfinity/principal';
  import { makeBackend, owner, member, state } from './backend.js';
  let role='owner';
  let linkedMovementEvents=[],locationRefresh=0,assetRefresh=0,treasury={entries:[],loading:true,error:''};
  $: principalText = role === 'owner' ? owner : member;
  $: backend = makeBackend(principalText);
  const members = [{name:'Owner',principal:Principal.fromText(owner)}, {name:'Observer',principal:Principal.fromText(member)}];
  window.portfolioFixture = state;
</script>
<main class="mx-auto max-w-6xl px-4 py-6">
 <div class="flex flex-wrap justify-between gap-3"><strong>Defunds · browser test fixture</strong><label>Test role <select aria-label="Test role" bind:value={role}><option value="owner">Owner</option><option value="member">Member</option></select></label></div>
 <div class="mt-5 rounded-2xl bg-slate-950 px-6 py-7 text-white"><p class="text-sm text-slate-400">Funds / Example shared fund</p><h1 class="mt-2 text-3xl font-semibold">Outdoor equipment fund</h1><p class="mt-2 text-sm text-slate-300">Illustrative data · mocked API · no live canister</p></div>
 <FundCurrencies {backend} fundId={1n} {principalText} isCreator={role === 'owner'} on:balances={(e)=>treasury=e.detail} on:changed={()=>locationRefresh++}/>
 <LocationPortfolio {backend} fundId={1n} {principalText} {treasury} refreshToken={locationRefresh} on:links={(event)=>linkedMovementEvents=event.detail} on:changed={()=>assetRefresh++}/>
 <GroupPortfolio {backend} fundId={1n} {principalText} isCreator={role === 'owner'} {members} refreshToken={assetRefresh} blockedReversals={linkedMovementEvents} on:changed={()=>locationRefresh++}/>
</main>
