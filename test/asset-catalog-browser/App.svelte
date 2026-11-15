<script>
import Catalog from '../../src/frontend/src/lib/components/GlobalAssetCatalog.svelte';
let tokens=[{id:1n,assetKey:'usdc',name:'USD Coin',symbol:'USDC',network:'base',standard:'erc20',contract:'0x'+'a'.repeat(40),decimals:6,source:'test',verified:true,enabled:true,revision:1n}],customIds=[];
window.catalogFixture={saved:[],imports:[]};
const backend={
getFundAssetCatalog:async()=>({ok:{networks:[{id:'ethereum',name:'Ethereum'},{id:'base',name:'Base'}],tokens:[...tokens],customIds:[...customIds],canManage:true,canPublish:false}}),
saveFundCustomAsset:async(fund,id,revision,input)=>{window.catalogFixture.saved.push({fund,id,revision,input});const t={...input,id:2n,revision:1n};tokens=[...tokens,t];customIds=[2n];return {ok:t}},
importGlobalAsset:async(fund,id)=>{window.catalogFixture.imports.push({fund,id});return {ok:{id:'catalog:'+id}}}
};
</script>
<div class="mx-auto max-w-6xl p-4"><Catalog {backend} fundId={1n}/></div>
