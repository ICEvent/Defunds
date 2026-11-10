import assert from 'node:assert/strict';
import test from 'node:test';
import { resolvePersonalLoanBuildId } from '../src/frontend/scripts/personal-loan-mainnet-id.js';

const validId = 'xzg3o-4yaaa-aaaal-as2la-cai';
const readFile = () => JSON.stringify({personal_loan:{ic:validId}});

test('dfx --ic build reads network-qualified canister_ids.json automatically', () => {
  assert.deepEqual(resolvePersonalLoanBuildId({
    network:'ic', explicitId:'', filePath:'/project/canister_ids.json', readFile
  }), {id:validId, source:'canister_ids.json'});
});

test('dfx --ic build also reads a flat personal_loan entry (no .ic)', () => {
  const flat = () => JSON.stringify({personal_loan:validId});
  assert.deepEqual(resolvePersonalLoanBuildId({
    network:'ic', explicitId:'', filePath:'/project/canister_ids.json', readFile:flat
  }), {id:validId, source:'canister_ids.json'});
});

test('local network does not inherit mainnet Personal Loan ID', () => {
  let calls = 0;
  assert.deepEqual(resolvePersonalLoanBuildId({
    network:'local', explicitId:'', readFile:()=>{ calls++; return readFile(); }
  }), {id:null,source:'non-mainnet'});
  assert.equal(calls, 0);
});

test('explicit local/test override takes priority without reading mainnet JSON', () => {
  let calls = 0;
  assert.deepEqual(resolvePersonalLoanBuildId({
    network:'ic', explicitId:'rrkah-fqaaa-aaaaa-aaaaq-cai',
    readFile:()=>{ calls++; return readFile(); }
  }), {id:'rrkah-fqaaa-aaaaa-aaaaq-cai',source:'environment'});
  assert.equal(calls, 0);
});

test('missing root config and missing ID do not invent deployed canister', () => {
  assert.deepEqual(resolvePersonalLoanBuildId({
    network:'ic', explicitId:'', readFile:()=>{const err=new Error('ENOENT');err.code='ENOENT';throw err;}
  }), {id:null,source:'missing-file'});
  assert.deepEqual(resolvePersonalLoanBuildId({
    network:'ic', explicitId:'', readFile:()=>JSON.stringify({backend:{ic:validId}})
  }), {id:null,source:'missing-id'});
});

test('malformed JSON and invalid canister IDs are rejected', () => {
  assert.throws(()=>resolvePersonalLoanBuildId({
    network:'ic', explicitId:'', readFile:()=>'{'
  }), /Cannot read canister_ids.json/);
  for (const invalid of ['not a principal', 'aaaaa-aa', '2vxsx-fae', 123]) {
    assert.throws(()=>resolvePersonalLoanBuildId({
      network:'ic', explicitId:'', readFile:()=>JSON.stringify({personal_loan:{ic:invalid}})
    }), /Invalid personal_loan ID/);
    assert.throws(()=>resolvePersonalLoanBuildId({
      network:'ic', explicitId:'', readFile:()=>JSON.stringify({personal_loan:invalid})
    }), /Invalid personal_loan ID/);
  }
});
