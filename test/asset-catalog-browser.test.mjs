import assert from 'node:assert/strict';
import {spawn} from 'node:child_process';
import {createRequire} from 'node:module';
const require=createRequire(import.meta.url),{chromium}=require(process.env.PLAYWRIGHT_MODULE||'playwright');
const server=spawn(process.execPath,['node_modules/vite/bin/vite.js','--config','test/asset-catalog-browser/vite.config.js'],{stdio:['ignore','pipe','pipe']});let logs='';server.stdout.on('data',d=>logs+=d);server.stderr.on('data',d=>logs+=d);let browser;
try {
 for(let i=0;i<100;i++){try{if((await fetch('http://127.0.0.1:4187')).ok)break;}catch{}if(i===99)throw new Error(logs);await new Promise(r=>setTimeout(r,100));}
 browser=await chromium.launch({headless:true,...(process.env.PORTFOLIO_CHROMIUM?{executablePath:process.env.PORTFOLIO_CHROMIUM}:{}),args:['--no-sandbox']});
 const page=await browser.newPage({viewport:{width:1280,height:900}}),failures=[];page.on('pageerror',e=>{failures.push(e.message);console.error('Catalog page error:',e.message);});
 await page.goto('http://127.0.0.1:4187');await page.getByText('USD Coin',{exact:true}).waitFor().catch(async e=>{throw new Error(`${e.message}\nPage: ${await page.locator('body').innerText()}\nErrors: ${failures.join('; ')}`);});
 assert.equal(await page.getByRole('button',{name:'Edit',exact:true}).count(),0);
 await page.getByRole('button',{name:'+ Add definition'}).click();
 await page.getByLabel('Asset family (optional)').fill('custom:my-token');await page.getByLabel('Name',{exact:true}).fill('My token');await page.getByLabel('Symbol',{exact:true}).fill('MYT');await page.getByLabel('Contract / mint / ledger').fill('0x'+'b'.repeat(40));await page.getByLabel('Decimals').fill('6');
 await page.getByRole('button',{name:'Save definition'}).click();await page.getByText('My token',{exact:true}).waitFor();
 assert.equal(await page.getByRole('button',{name:'Edit',exact:true}).count(),1);
 const saved=await page.evaluate(()=>window.catalogFixture.saved[0].input);assert.equal(saved.verified,false);assert.equal(saved.decimals,6);
 await page.getByRole('row').filter({has:page.getByText('My token',{exact:true})}).getByRole('button',{name:'Add to Fund'}).click();await page.getByText('Asset added to this Fund.',{exact:false}).waitFor();
 assert.equal(await page.evaluate(()=>window.catalogFixture.imports[0].id===2n),true);
 await page.route('https://api.coingecko.com/**',route=>route.fulfill({json:{id:'usd-coin',name:'USD Coin',symbol:'usdc',detail_platforms:{base:{decimal_place:6,contract_address:'0x'+'c'.repeat(40)}}}}));
 await page.getByLabel('CoinGecko ID').fill('usd-coin');await page.getByRole('button',{name:'Look up',exact:true}).click();await page.getByRole('button',{name:'Review & add'}).click();assert.equal(await page.getByLabel('Decimals').inputValue(),'6');
 await page.setViewportSize({width:390,height:844});assert.equal(await page.evaluate(()=>document.documentElement.scrollWidth<=window.innerWidth),true);
 await page.screenshot({path:'/tmp/defunds-asset-catalog-mobile.png',fullPage:true});assert.deepEqual(failures,[]);console.log('Catalog browser checks passed: custom entry, scoped edit, Fund import, optional CoinGecko, mobile layout.');
} finally {await browser?.close();server.kill();}
