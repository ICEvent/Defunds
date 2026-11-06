import test from 'node:test';
import assert from 'node:assert/strict';
import { parseLoanCalendarDay } from '../src/frontend/src/lib/utils/personal-loan-date.js';

test('accepts the date entered in the loan form', () => {
  const due = parseLoanCalendarDay('2027-01-01', true);
  assert.equal(due, BigInt(Date.parse('2027-01-01T23:59:59.999Z')) * 1_000_000n);
  assert.equal(parseLoanCalendarDay(' 2027-01-01 ', true), due);
  const repayment = parseLoanCalendarDay('2027-01-01');
  assert.equal(repayment, BigInt(Date.parse('2027-01-01T12:00:00.000Z')) * 1_000_000n);
});

test('diagnostic errors show the actual value received by the form', () => {
  assert.throws(
    () => parseLoanCalendarDay('01/01/2027'),
    /date-v3-20261106.*01\\/01\\/2027/,
  );
  assert.throws(
    () => parseLoanCalendarDay(undefined),
    /date-v3-20261106.*undefined/,
  );
});

test('accepts leap years and zero-padded dates', () => {
  assert.equal(
    parseLoanCalendarDay('2028-02-29'),
    BigInt(Date.parse('2028-02-29T12:00:00Z')) * 1_000_000n,
  );
  assert.equal(
    parseLoanCalendarDay('2026-11-06'),
    BigInt(Date.parse('2026-11-06T12:00:00Z')) * 1_000_000n,
  );
});

test('rejects impossible or malformed dates rather than normalizing', () => {
  const invalid = [
    '', '2027-1-1', '2027-02-29', '2027-04-31', '2027-00-15',
    '2027-13-01', '2027-01-00', '2027-01-32', 'abc',
    '2027-01-01T00:00:00Z', null,
  ];
  for (const value of invalid) {
    assert.throws(() => parseLoanCalendarDay(value), /date/i, String(value));
  }
});
