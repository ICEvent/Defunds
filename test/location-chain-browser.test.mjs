// Exercise actual Location components against mocked external transport; no live balances.
import assert from 'node:assert/strict';
import { spawn } from 'node:child_process';
import { chromium } from 'playwright';
const server=spawn(process.execPath,['node_modules/vite/bin/vite.js','--config','test/portfolio-browser/vite.config.js']);
let logs='';server.stdout.on('data',d=>logs+=d);server.stderr.on('data',d=>logs+=d);
let browser;
try {
 for(let i=0;i<100;i++){try{if((await fetch('http://127.0.0.1:4182')).ok)break;}catch{}if(i===99)throw Error(logs);await new Promise(r=>setTimeout(r,100));}
 browser=await chromium.launch({headless:true,executablePath:process.env.PORTFOLIO_CHROMIUM||'/usr/bin/chromium',args:['--no-sandbox']});
 const page=await browser.newPage({viewport:{width:1440,height:1000}}),errors=[],requests=[];
 page.on('pageerror',e=>errors.push(e.message));let fail=false;
 await page.route('https://*.blockscout.com/api/v2/**',async route=>{
  requests.push(route.request().url());
  if(fail)return route.fulfill({status:429,body:'rate limited'});
  const tokens=new URL(route.request().url()).pathname.endsWith('/tokens');
  await route.fulfill({json:tokens?{items:[{value:'1234567',token_id:null,token:{address_hash:'0x1111111111111111111111111111111111111111',name:'Example USD',symbol:'USD',type:'ERC-20',decimals:'6'}}],next_page_params:null}:{coin_balance:'1500000000000000000'}});
 });
 await page.goto('http://127.0.0.1:4182/?workflow');
 await page.getByRole('navigation',{name:'Asset workflow'}).getByRole('button',{name:'locations',exact:true}).click();
 for(const [name,network] of [['Ethereum wallet','eip155:1'],['Base wallet','eip155:8453']]){
  await page.getByRole('button',{name:'+ Add location',exact:true}).click();
  await page.getByLabel('Location name',{exact:true}).fill(name);
  await page.getByLabel('Location type',{exact:true}).selectOption('blockchain');
  await page.getByLabel('Network',{exact:true}).selectOption(network);
  await page.getByLabel('Blockchain address',{exact:true}).fill('0x1234000000000000000000000000000000000000');
  await page.getByRole('button',{name:'Save location record',exact:true}).click();
  await page.getByRole('status').filter({hasText:'Location portfolio saved'}).waitFor();
 }
 assert.equal(requests.length,0,'only manual refresh calls external services');
 const ethereum=page.locator('li').filter({has:page.locator('strong').filter({hasText:'Ethereum wallet'})}).first();
 const base=page.locator('li').filter({has:page.locator('strong').filter({hasText:'Base wallet'})}).first();
 const before=await page.evaluate(()=>window.portfolioFixture.assets.map(a=>a.quantity));
 await ethereum.getByRole('button',{name:'Update on-chain assets',exact:true}).click();
 await ethereum.getByText('Example USD · USD',{exact:false}).waitFor();
 assert.match(await ethereum.innerText(),/1\.5/);assert.match(await ethereum.innerText(),/1\.234567/);
 assert.ok(requests.every(u=>new URL(u).hostname==='eth.blockscout.com'));
 await base.getByRole('button',{name:'Update on-chain assets',exact:true}).click();
 await base.getByText('Example USD · USD',{exact:false}).waitFor();
 assert.ok(requests.some(u=>new URL(u).hostname==='base.blockscout.com'));
 assert.deepEqual(await page.evaluate(()=>window.portfolioFixture.assets.map(a=>a.quantity)),before,'snapshot cannot mutate Fund holdings');
 fail=true;await ethereum.getByRole('button',{name:'Update on-chain assets',exact:true}).click();
 await ethereum.getByRole('alert').waitFor();assert.match(await ethereum.innerText(),/Previous snapshot retained/);
 await page.setViewportSize({width:390,height:844});
 assert.equal(await page.evaluate(()=>document.documentElement.scrollWidth>window.innerWidth+1),false);
 assert.deepEqual(errors,[]);
 console.log('PASS: separate network/address, same address across chains, click-only refresh, exact balances, failure retains snapshot, no Fund mutation, mobile layout');
}finally{await browser?.close();server.kill('SIGTERM');}
