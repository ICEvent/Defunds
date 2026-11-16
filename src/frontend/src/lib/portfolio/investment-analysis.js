// Deterministic decision support. Money stays in atomic BigInts. Groups are
// isolated by settlement currency ID and precision; no implicit FX conversion.
export function analyzeInvestments(items, policy, now = BigInt(Date.now()) * 1000000n) {
  const { maxWeight, staleDays, shock } = policy;
  if (![maxWeight, staleDays, shock].every(Number.isInteger) || maxWeight < 1 || maxWeight > 100 || staleDays < 1 || staleDays > 3650 || shock < 0 || shock > 100)
    throw new Error('Use whole percentages from 0–100, a weight limit from 1–100, and freshness from 1–3650 days.');
  const groups = new Map();
  for (const item of items) {
    const key = JSON.stringify([item.metadata.currencyId, item.metadata.moneyDecimals]);
    if (!groups.has(key)) groups.set(key, { key, currency: item.metadata.currency, decimals: item.metadata.moneyDecimals, rows: [] });
    const valuation = item.valuation[0];
    const fresh = item.quantity === 0n || !!(valuation && valuation.quantity === item.quantity && valuation.at <= now && now - valuation.at <= BigInt(staleDays) * 86400000000000n);
    const value = item.quantity === 0n ? 0n : fresh ? valuation.amount : null;
    groups.get(key).rows.push({ item, value });
  }
  return [...groups.values()].map(group => {
    const complete = group.rows.every(row => row.value !== null);
    const knownValue = group.rows.reduce((sum, row) => sum + (row.value ?? 0n), 0n);
    const rows = group.rows.map(row => {
      const { item, value } = row;
      const overweight = complete && knownValue > 0n && value * 100n > knownValue * BigInt(maxWeight);
      const weight = complete && knownValue > 0n ? value * 10000n / knownValue : null;
      const scenarioValue = value === null ? null : value * BigInt(100 - shock) / 100n;
      const scenarioTotal = scenarioValue === null ? null : item.realized + scenarioValue - item.cost;
      const reason = value === null ? 'Refresh valuation: missing, stale, future-dated or quantity mismatch.' : overweight ? 'Above the configured concentration limit. Compare pausing additions, redirecting new contributions, or reducing exposure after reviewing fees and liquidity.' : item.quantity === 0n ? 'No open holding. Review the completed outcome or planned entry.' : !complete ? 'Refresh other holdings before assessing concentration.' : 'No concentration rule triggered. Review the investment thesis before changing the position.';
      return { ...row, weight, scenarioValue, scenarioTotal, reason, overweight };
    });
    return { ...group, rows, complete, knownValue };
  });
}
