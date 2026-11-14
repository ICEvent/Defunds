import test from 'node:test';
import assert from 'node:assert/strict';
import { parseDonationTransactions, resolveDonationTimes } from '../src/frontend/src/lib/utils/donation-history.js';
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

test('resolves omitted sender time from the ledger block at the exact transaction index', async () => {
    const donations = [{ txid: 12n, timestamp: null }, { txid: 13n, timestamp: 456n }];
    const result = await resolveDonationTimes(donations, {
        query_blocks: async (request) => {
            assert.deepEqual(request, { start: 12n, length: 1n });
            return { first_block_index: 12n, blocks: [{ timestamp: { timestamp_nanos: 123n } }], archived_blocks: [] };
        }
    }, () => assert.fail('no archive needed'));
    assert.equal(result[0].timestamp, 123n);
    assert.equal(result[1].timestamp, 456n);
    assert.equal(donations[0].timestamp, null);
});

test('follows the matching archive callback for old donations', async () => {
    const callback = ['archive', 'get_blocks'];
    const result = await resolveDonationTimes([{ txid: 12n, timestamp: null }], {
        query_blocks: async () => ({ first_block_index: 100n, blocks: [], archived_blocks: [
            { start: 0n, length: 10n, callback: ['wrong', 'get_blocks'] },
            { start: 10n, length: 5n, callback }
        ] })
    }, async (actual, request) => {
        assert.deepEqual(actual, callback);
        assert.deepEqual(request, { start: 12n, length: 1n });
        return { Ok: { blocks: [{ timestamp: { timestamp_nanos: 789n } }] } };
    });
    assert.equal(result[0].timestamp, 789n);
});

test('keeps donations visible with an honest missing time on network or archive failure', async () => {
    const donations = [{ txid: 12n, timestamp: null }];
    assert.deepEqual(await resolveDonationTimes(donations, {
        query_blocks: async () => { throw new Error('offline'); }
    }), donations);
    assert.deepEqual(await resolveDonationTimes(donations, {
        query_blocks: async () => ({ first_block_index: 100n, blocks: [], archived_blocks: [
            { start: 10n, length: 5n, callback: ['archive', 'get_blocks'] }
        ] })
    }, async () => ({ Err: { Other: { error_message: 'unavailable' } } })), donations);
});
