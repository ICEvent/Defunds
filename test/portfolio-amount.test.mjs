import { test } from 'node:test';
import assert from 'node:assert/strict';
import { parseUnits, formatUnits, summarize } from '../src/frontend/src/lib/portfolio/amount.js';
test('decimal quantities preserve all precision and reject rounding', () => {
  assert.equal(parseUnits('2.50', 2), 250n);
  assert.equal(parseUnits('0.000000000000000001', 18), 1n);
  for (const input of ['-1', '1e3', '2.001', 'NaN']) assert.throws(() => parseUnits(input, 2));
  assert.throws(() => parseUnits('1', 19));
  assert.equal(formatUnits(100n, 0), '100');
  assert.equal(formatUnits(1050n, 2), '10.5');
  assert.equal(formatUnits(0n, 2), '0');
});
test('summary keeps currencies separate, includes explicit zero and excludes stale and archived values', () => {
  const asset = (amount, decimals, currency, extra = {}) => ({ archived: false, quantityRevision: 2n, valuation: [{ amount, decimals, currency, quantityRevision: 2n }], ...extra });
  const result = summarize([
    asset(100n, 2, 'CAD'), asset(25n, 1, 'CAD'), asset(0n, 2, 'USD'),
    asset(9900n, 2, 'CAD', { quantityRevision: 3n }),
    asset(999n, 0, 'CAD', { archived: true }), { archived: false, valuation: [], quantityRevision: 1n },
  ]);
  assert.deepEqual(result.totals, [{ currency: 'CAD', amount: 35n * 10n ** 17n }, { currency: 'USD', amount: 0n }]);
  assert.equal(result.unvalued, 2);
});
