// Calendar dates from <input type="date"> use YYYY-MM-DD with no timezone.
// Store an explicit UTC timestamp in nanoseconds to avoid locale parsing drift.
export function parseLoanCalendarDay(isoDate, endOfDay = false) {
  if (typeof isoDate !== 'string' || !/^\d{4}-\d{2}-\d{2}$/.test(isoDate)) {
    throw new Error('Select a valid date.');
  }

  const suffix = endOfDay ? 'T23:59:59.999Z' : 'T12:00:00.000Z';
  const stamp = Date.parse(isoDate + suffix);

  // Date.parse can normalize impossible days; reject those instead.
  if (!Number.isFinite(stamp) || new Date(stamp).toISOString().slice(0, 10) !== isoDate) {
    throw new Error('Invalid calendar date.');
  }

  return BigInt(stamp) * 1_000_000n;
}
