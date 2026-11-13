import test from 'node:test';
import assert from 'node:assert/strict';
import { parseDonationTransactions } from '../src/frontend/src/lib/utils/donation-history.js';
const transfer = { to: 'treasury', from: 'donor', amount: { e8s: 100n } };
const tx = (operation, created_at_time = []) => ({ id: 1n, transaction: { operation, created_at_time } });
test('reads Index created_at_time and only incoming transfers', () => {
    const result = parseDonationTransactions({ Ok: { transactions: [
        tx({ Transfer: transfer }, [{ timestamp_nanos: 123n }]),
        tx({ Transfer: { ...transfer, to: 'external' } }),
        tx({ Approve: {} }),
        tx({ TransferFrom: transfer })
    ] } }, 'treasury', 'ICP');
    assert.equal(result.length, 2);
    assert.equal(result[0].timestamp, 123n);
    assert.equal(result[0].amount, 100n);
    assert.equal(result[1].timestamp, null);
});
test('surfaces Index errors instead of silently showing an empty list', () => {
    assert.throws(() => parseDonationTransactions({ Err: { message: 'Unavailable' } }), /Unavailable/);
});
