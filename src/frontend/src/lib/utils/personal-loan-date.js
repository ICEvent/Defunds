// Native <input type="date"> supplies YYYY-MM-DD; do not interpret a
// display-localized calendar label or rely on double-escaped regex literals.
export const LOAN_DATE_PARSER_VERSION = 'date-v3-20261106';

export function parseLoanCalendarDay(value, endOfDay = false) {
  // Trim harmless whitespace, but reject non-strings so broken bindings are
  // obvious in the error shown to the developer/tester.
  const isoDate = typeof value === 'string' ? value.trim() : '';
  const parts = isoDate.split('-');
  const hasFormat = parts.length === 3
    && /^[0-9]{4}$/.test(parts[0])
    && /^[0-9]{2}$/.test(parts[1])
    && /^[0-9]{2}$/.test(parts[2]);

  if (!hasFormat) {
    throw new Error(
      'Loan date ' + LOAN_DATE_PARSER_VERSION
      + ': expected YYYY-MM-DD, received ' + JSON.stringify(value)
    );
  }

  const suffix = endOfDay ? 'T23:59:59.999Z' : 'T12:00:00.000Z';
  const stamp = Date.parse(isoDate + suffix);

  if (!Number.isFinite(stamp) || new Date(stamp).toISOString().slice(0, 10) !== isoDate) {
    throw new Error(
      'Loan date ' + LOAN_DATE_PARSER_VERSION
      + ': invalid calendar day ' + JSON.stringify(isoDate)
    );
  }
  return BigInt(stamp) * 1_000_000n;
}
