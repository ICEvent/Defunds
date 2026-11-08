import assert from 'node:assert/strict';
import test from 'node:test';
import {
  BUILTIN_CURRENCIES, currencyDefinition, currencyCatalog,
  getBuiltinCurrency, parseAmountMinor, formatAmountMinor
} from '../src/frontend/src/lib/utils/personal-loan-currency.js';
import { getRepaymentCents, parseLoanAmountCents } from '../src/frontend/src/lib/utils/personal-loan-display.js';

test('built-in currencies have precise, immutable fiat and crypto definitions', () => {
  assert.equal(getBuiltinCurrency('CAD').decimals, 2);
  assert.equal(getBuiltinCurrency('BTC').decimals, 8);
  assert.equal(getBuiltinCurrency('ETH').decimals, 18);
  assert.equal(getBuiltinCurrency('ICP').decimals, 8);
  assert.equal(getBuiltinCurrency('CKBTC').decimals, 8);
  assert.equal(getBuiltinCurrency('CKETH').decimals, 18);
  assert.equal(getBuiltinCurrency('BTC').kind, 'crypto');
  assert.equal(BUILTIN_CURRENCIES.length, 10);
});

test('parse crypto minor units exactly with bigint, not floating-point arithmetic', () => {
  assert.equal(parseAmountMinor('0.00000001', 8), 1n);
  assert.equal(parseAmountMinor('1.23456789', 8), 123456789n);
  assert.equal(parseAmountMinor('0.000000000000000001', 18), 1n);
  assert.equal(parseAmountMinor('1.000000000000000001', 18), 1000000000000000001n);
  assert.equal(parseAmountMinor('123456789.000000000000000001', 18), 123456789000000000000000001n);
  assert.equal(parseAmountMinor('200', 0), 200n);
  assert.equal(parseLoanAmountCents('123.45'), 12345n);
});

test('formatting does not lose 18-decimal amounts or show misleading fiat precision', () => {
  assert.equal(formatAmountMinor(1n, getBuiltinCurrency('BTC')), 'BTC ₿0.00000001');
  assert.equal(formatAmountMinor(1n, getBuiltinCurrency('ETH')), 'ETH Ξ0.000000000000000001');
  assert.equal(formatAmountMinor(1000000000000000001n, getBuiltinCurrency('ETH')), 'ETH Ξ1.000000000000000001');
  assert.equal(formatAmountMinor(12345n, getBuiltinCurrency('CAD')), 'CAD $123.45');
  assert.equal(formatAmountMinor(100n, getBuiltinCurrency('CAD')), 'CAD $1.00');
  assert.equal(formatAmountMinor(123456789n, getBuiltinCurrency('ICP')), 'ICP 1.23456789');
});

test('reject invalid precision and unsafe number strings without rounding or truncating', () => {
  for (const amount of ['0.000000001', '0', '-0.1', '1e-8', 'NaN', '1,000', '.1']) {
    assert.throws(() => parseAmountMinor(amount, 8));
  }
  assert.throws(() => parseAmountMinor('1.1', 0), /decimal places/);
  assert.throws(() => parseAmountMinor('0.0000000000000000001', 18), /decimal places/);
  assert.throws(() => parseAmountMinor('1', 19), /precision/);
  assert.throws(() => currencyDefinition({code:'BAD CODE',symbol:'',decimals:8,kind:'crypto'}), /code/);
  assert.throws(() => currencyDefinition({code:'TEST',symbol:'',decimals:19,kind:'crypto'}), /decimals/);
  assert.throws(() => currencyDefinition({code:'TEST',symbol:'',decimals:8,kind:'unknown'}), /Fiat or Crypto/);
});

test('full crypto repayment uses exact canister minor units and checks overpayment', () => {
  assert.equal(getRepaymentCents(false, 5n, '0.00000003', 8), 3n);
  assert.equal(getRepaymentCents(true, 5n, '9999', 8), 5n);
  assert.equal(getRepaymentCents(false, 1n, '0.000000000000000001', 18), 1n);
  assert.throws(() => getRepaymentCents(false, 1n, '0.000000000000000002', 18), /exceeds/);
});

test('manually maintained catalog includes presets and user definitions without replacing presets', () => {
  const sol = currencyDefinition({code:'sol',symbol:'SOL',decimals:9,kind:'crypto'});
  assert.equal(sol.code, 'SOL');
  const result = currencyCatalog([sol, {code:'BTC',symbol:'fake',decimals:2,kind:'fiat'}]);
  assert.equal(result.length, 11);
  assert.equal(result.find(x => x.code === 'BTC').decimals, 8);
  assert.equal(result.find(x => x.code === 'SOL').decimals, 9);
});
