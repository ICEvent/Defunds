import assert from 'node:assert/strict';
import { spawn } from 'node:child_process';
import { chromium } from 'playwright';
import { mkdir } from 'node:fs/promises';
const server=spawn(process.execPath,['node_modules/vite/bin/vite.js','--config','test/portfolio-browser/vite.config.js']);
let logs='';server.stdout.on('data',d=>logs+=d);server.stderr.on('data',d=>logs+=d);
let browser;
try{
  for(let i=0;i<100;i++){try{if((await fetch('http://127.0.0.1:4182')).ok)break;}catch{}if(i===99)throw Error(logs);await new Promise(r=>setTimeout(r,100));}
  browser=await chromium.launch({headless:true,executablePath:process.env.PORTFOLIO_CHROMIUM||'/usr/bin/chromium',args:['--no-sandbox']});
  const page=await browser.newPage({viewport:{width:1440,height:1024}}),errors=[];page.on('pageerror',e=>errors.push(e.message));
  await page.goto('http://127.0.0.1:4182');
  const region=page.getByRole('region',{name:'Investments',exact:true});
  await region.getByText('No investments yet.').waitFor();
  await page.evaluate(()=>window.portfolioFixture.locations.push({id:1n,name:'Wallet A',enabled:true,revision:1n,kind:{other:'A'}},{id:2n,name:'Wallet B',enabled:true,revision:1n,kind:{other:'B'}}));
  await region.getByRole('button',{name:'Refresh investments'}).click();
  await region.getByRole('button',{name:'+ Add investment'}).click();
  await region.getByLabel('Investment name',{exact:true}).fill('Test strategy');
  await region.getByLabel('Investment asset',{exact:true}).selectOption('asset:2');
  await region.getByRole('button',{name:'Save investment',exact:true}).click();
  await region.getByRole('status').waitFor();
  async function start(name){await region.getByRole('button',{name,exact:true}).click();}
  async function save(){await region.getByRole('button',{name:'Save investment',exact:true}).click();await region.getByRole('status').waitFor();}
  // Changing the adjacent location configuration must refresh the investment
  // selectors without using Refresh investments (PR review regression).
  const places=page.getByRole('region',{name:'Asset locations & holdings',exact:true});
  await places.getByRole('button',{name:'+ Add location',exact:true}).click();
  await places.getByLabel('Location name',{exact:true}).fill('Wallet C');
  await places.getByLabel('Location type').selectOption('other');
  await places.getByLabel('Location reference').fill('external-c');
  await places.getByRole('button',{name:'Save location record',exact:true}).click();
  await places.getByRole('status').filter({hasText:'Location portfolio saved'}).waitFor();
  await start('Buy / add');
  await region.getByLabel('Investment location',{exact:true}).selectOption({label:'Wallet C'});
  await region.getByRole('button',{name:'Cancel investment',exact:true}).click();
  await places.getByText('Manage locations',{exact:true}).click();
  await places.locator('li').filter({hasText:'Wallet C'}).getByRole('button',{name:'Disable location',exact:true}).click();
  await places.getByRole('status').filter({hasText:'Location portfolio saved'}).waitFor();
  await start('Buy / add');
  assert.equal(await region.getByLabel('Investment location',{exact:true}).locator('option').filter({hasText:'Wallet C'}).count(),0);
  await region.getByRole('button',{name:'Cancel investment',exact:true}).click();
  await places.getByText('Manage locations',{exact:true}).click();
  await places.locator('li').filter({hasText:'Wallet C'}).getByRole('button',{name:'Restore location',exact:true}).click();
  await places.getByRole('status').filter({hasText:'Location portfolio saved'}).waitFor();
  await start('Buy / add');
  await region.getByLabel('Investment location',{exact:true}).selectOption({label:'Wallet C'});
  await region.getByRole('button',{name:'Cancel investment',exact:true}).click();
  await start('Buy / add');await region.getByLabel('Investment quantity (ETH)').fill('100');await region.getByLabel('Investment amount (TEST)').fill('1000');
  await page.evaluate(()=>window.investmentFixture.loseResponse=true);
  await region.getByRole('button',{name:'Save investment',exact:true}).click();await region.getByRole('alert').filter({hasText:'Response lost'}).waitFor();await save();
  assert.equal(await page.evaluate(()=>{const a=window.investmentFixture.calls;return a.at(-1)===a.at(-2)}),true);
  await start('Sell');await region.getByLabel('Investment quantity (ETH)').fill('30');await region.getByLabel('Investment amount (TEST)').fill('400');await save();
  await start('Value holding');await region.getByLabel('Total holding value (TEST)').fill('650');await region.getByLabel('Valuation source').fill('Manual market estimate');await save();
  assert.match(await region.innerText(),/Total P\/L\s+50 TEST/);
  assert.match(await region.innerText(),/Unrealized P\/L\s+−50 TEST/);
  await start('Transfer');await region.getByLabel('Investment quantity (ETH)').fill('20');await region.getByLabel('Destination location').selectOption('2');await save();
  assert.match(await region.innerText(),/Wallet B · 20 ETH/);assert.match(await region.innerText(),/Total P\/L\s+50 TEST/);
  await start('Investment history');await region.getByText('Investment history · Test strategy',{exact:true}).waitFor();assert.match(await region.innerText(),/Transfer · 20 ETH/);
  const output=`${process.env.PORTFOLIO_SCREENSHOTS||'/tmp/portfolio-browser-screenshots'}/investments`;
  await mkdir(output,{recursive:true});await page.screenshot({path:`${output}/desktop.png`,fullPage:true});
  await page.setViewportSize({width:390,height:844});await start('Income');await region.getByLabel('Investment amount (TEST)').fill('40');
  await page.screenshot({path:`${output}/mobile.png`,fullPage:true});assert.ok(await page.evaluate(()=>document.documentElement.scrollWidth<=innerWidth));await save();
  assert.match(await region.innerText(),/Total P\/L\s+90 TEST/);
  await page.getByLabel('Test role').selectOption('member');await region.getByText('Manual market estimate',{exact:false}).waitFor();assert.equal(await region.getByRole('button',{name:'+ Add investment'}).count(),0);
  assert.deepEqual(errors,[]);console.log('PASS: investment create, trades, valuation, transfers, retry, income, history, read-only role and mobile layout');
}finally{await browser?.close();server.kill('SIGTERM');}
