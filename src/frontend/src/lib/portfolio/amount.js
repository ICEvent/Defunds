export function parseUnits(value, decimals) {
  const precision = Number(decimals);
  if (!Number.isInteger(precision) || precision < 0 || precision > 18) throw new Error('Invalid precision');
  const text = String(value).trim();
  if (!/^\d+(\.\d+)?$/.test(text) || text.length > 60) throw new Error('Enter a positive decimal number');
  const [whole, fraction = ''] = text.split('.');
  if (fraction.length > precision) throw new Error(`Use at most ${precision} decimal places`);
  const amount = BigInt(whole + fraction.padEnd(precision, '0'));
  if (amount > 10n ** 36n) throw new Error('Amount is too large');
  return amount;
}
export function formatUnits(value, decimals) {
  const precision = Number(decimals);
  const text = BigInt(value).toString().padStart(precision + 1, '0');
  if (!precision) return text;
  return `${text.slice(0, -precision)}.${text.slice(-precision)}`.replace(/\.?0+$/, '');
}
export function summarize(assets) {
  const totals = new Map();
  let unvalued = 0;
  for (const asset of assets.filter(a => !a.archived)) {
    const v = asset.valuation[0];
    if (!v || v.quantityRevision !== asset.quantityRevision) { unvalued++; continue; }
    totals.set(v.currency, (totals.get(v.currency) ?? 0n) + v.amount * 10n ** BigInt(18 - Number(v.decimals)));
  }
  return { totals: [...totals].map(([currency, amount]) => ({ currency, amount })), unvalued };
}
