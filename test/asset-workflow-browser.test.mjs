import assert from 'node:assert/strict';
import { spawn } from 'node:child_process';
import { chromium } from 'playwright';
const server=spawn(process.execPath,['node_modules/vite/bin/vite.js','--config','test/portfolio-browser/vite.config.js']);
let logs='';server.stdout.on('data',d=>logs+=d);server.stderr.on('data',d=>logs+=d);
let browser;
try {
 for(let i=0;i<100;i++){try{if((await fetch('http://127.0.0.1:4182')).ok)break;}catch{}if(i===99)throw Error(logs);await new Promise(r=>setTimeout(r,100));}
 browser=await chromium.launch({headless:true,executablePath:process.env.PORTFOLIO_CHROMIUM||'/usr/bin/chromium',args:['--no-sandbox']});
 const page=await browser.newPage({viewport:{width:1440,height:1000}}),errors=[];page.on('pageerror',e=>errors.push(e.message));
 await page.goto('http://127.0.0.1:4182/?workflow');
 const nav=page.getByRole('navigation',{name:'Asset workflow'});
 const step=async name=>{
  await nav.getByRole('button',{name:name==='holdings'?'portfolio':name,exact:true}).click();
  if(name==='holdings'||name==='portfolio'){
   const toggle=page.getByRole('button',{name:/Manage holdings|Close holding management/});
   if((await toggle.getAttribute('aria-pressed')==='true')!==(name==='holdings'))await toggle.click();
  }
 };
 assert.equal(await nav.getByRole('button',{name:'holdings',exact:true}).count(),0);
 await page.getByRole('button',{name:'+ Add asset definition',exact:true}).click();
 await page.getByLabel('Name',{exact:true}).fill('Test shares');
 await page.getByLabel('Unit',{exact:true}).fill('share');
 assert.equal(await page.getByLabel('Opening quantity',{exact:true}).count(),0);
 await page.getByRole('button',{name:'Save record',exact:true}).click();
 await page.getByRole('cell',{name:'Test shares',exact:false}).waitFor();
 assert.equal(await page.evaluate(()=>window.portfolioFixture.assets.find(a=>a.name==='Test shares').quantity),0n);
 for(const name of ['Broker A','Broker B']){
  await step('locations');
  await page.getByRole('button',{name:'+ Add location',exact:true}).click();
  await page.getByLabel('Location name',{exact:true}).fill(name);
  await page.getByLabel('Location type',{exact:true}).selectOption('blockchain');
  await page.getByLabel('Blockchain network & address',{exact:true}).fill(`Ethereum · ${name}`);
  await page.getByRole('button',{name:'Save location record',exact:true}).click();
  await page.getByRole('status').filter({hasText:'Location portfolio saved'}).waitFor();
  await step('holdings');
  await page.getByRole('button',{name:'+ Add holding',exact:true}).click();
  await page.getByLabel('Asset definition',{exact:true}).selectOption({label:'Test shares'});
  await page.getByLabel('Holding location',{exact:true}).selectOption({label:name});
  await page.getByLabel('Fund-owned quantity',{exact:true}).fill(name==='Broker A'?'2':'3');
  await page.getByRole('button',{name:'Save location record',exact:true}).click();
  await page.getByRole('status').filter({hasText:'Location portfolio saved'}).waitFor();
 }
 await step('definitions');
 assert.equal(await page.getByRole('row').filter({hasText:'Test shares'}).count(),1);
 await step('portfolio');
 const group=page.locator('details').filter({has:page.locator('summary strong').filter({hasText:'Test shares'})});
 assert.match(await group.locator('summary').innerText(),/5 share/);
 assert.match(await group.innerText(),/Broker A[\s\S]*2 share/);
 assert.match(await group.innerText(),/Broker B[\s\S]*3 share/);
 assert.equal(await group.getByText('Unassigned',{exact:true}).count(),0);
 await page.setViewportSize({width:390,height:844});
 assert.ok(await page.evaluate(()=>document.documentElement.scrollWidth<=innerWidth));
 await step('holdings');
 await page.locator('td[data-label="Location"]').filter({hasText:'Broker A'}).waitFor();
 await page.getByLabel('Test role').selectOption('member');
 await step('definitions');
 await page.getByRole('cell',{name:'Test shares',exact:false}).waitFor();
 assert.equal(await page.getByRole('button',{name:'+ Add asset definition',exact:true}).count(),0);
 assert.deepEqual(errors,[]);
 console.log('PASS: definition → two locations → holdings → grouped totals, mobile and read-only role');
} finally { await browser?.close();server.kill('SIGTERM'); }
