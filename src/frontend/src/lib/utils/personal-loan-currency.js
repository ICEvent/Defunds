// Exact asset-denominated amounts for Personal Loan. No floating point, FX,
// payment settlement or token transfer. All amounts are integer minor units.
export const BUILTIN_CURRENCIES = Object.freeze([
  { code: 'CAD', symbol: '$', decimals: 2, kind: 'fiat' },
  { code: 'USD', symbol: '$', decimals: 2, kind: 'fiat' },
  { code: 'EUR', symbol: '€', decimals: 2, kind: 'fiat' },
  { code: 'GBP', symbol: '£', decimals: 2, kind: 'fiat' },
  { code: 'CNY', symbol: '¥', decimals: 2, kind: 'fiat' },
  { code: 'BTC', symbol: '₿', decimals: 8, kind: 'crypto' },
  { code: 'ETH', symbol: 'Ξ', decimals: 18, kind: 'crypto' },
  { code: 'ICP', symbol: 'ICP', decimals: 8, kind: 'crypto' },
  { code: 'CKBTC', symbol: 'ckBTC', decimals: 8, kind: 'crypto' },
  { code: 'CKETH', symbol: 'ckETH', decimals: 18, kind: 'crypto' }
].map(item => Object.freeze(item)));

export function currencyDefinition(value) {
  const code = String(value?.code ?? '').trim().toUpperCase();
  const symbol = String(value?.symbol ?? '').trim();
  const decimals = Number(value?.decimals);
  const kind = String(value?.kind ?? '');
  if (!/^[A-Z0-9]{2,12}$/.test(code)) {
    throw new Error('Currency code must contain 2–12 uppercase letters or digits');
  }
  if (symbol.length > 12 || /[\r\n\t]/.test(symbol)) {
    throw new Error('Currency symbol must be at most 12 characters, without line breaks');
  }
  if (!Number.isInteger(decimals) || decimals < 0 || decimals > 18) {
    throw new Error('Currency decimals must be between 0 and 18');
  }
  if (!['fiat', 'crypto'].includes(kind)) throw new Error('Choose Fiat or Crypto');
  return { code, symbol, decimals, kind };
}

export function getBuiltinCurrency(code) {
  return BUILTIN_CURRENCIES.find(item => item.code === code) ?? null;
}

export function currencyCatalog(custom = []) {
  const byCode = new Map(BUILTIN_CURRENCIES.map(item => [item.code, item]));
  for (const item of custom) {
    const normalized = currencyDefinition(item);
    if (getBuiltinCurrency(normalized.code)) continue; // Built-ins cannot be redefined.
    byCode.set(normalized.code, normalized);
  }
  return [...byCode.values()];
}

export function parseAmountMinor(value, decimals) {
  if (!Number.isInteger(decimals) || decimals < 0 || decimals > 18) {
    throw new Error('Invalid currency precision');
  }
  const input = String(value ?? '').trim();
  // Reject exponents, signs, commas, very large values and truncated fractions.
  if (!/^(0|[1-9][0-9]{0,23})(?:\.([0-9]+))?$/.test(input)) {
    throw new Error(`Enter a positive plain-decimal amount with up to ${decimals} decimal places`);
  }
  const [whole, fraction = ''] = input.split('.');
  if (fraction.length > decimals) {
    throw new Error(`This currency supports at most ${decimals} decimal places`);
  }
  const scale = 10n ** BigInt(decimals);
  const units = BigInt(whole) * scale +
    (fraction ? BigInt(fraction.padEnd(decimals, '0')) : 0n);
  if (units <= 0n) throw new Error('Amount must be positive');
  return units;
}

export function formatAmountMinor(raw, definition = getBuiltinCurrency('CAD')) {
  const def = currencyDefinition(definition);
  const amount = BigInt(raw ?? 0);
  const abs = amount < 0n ? -amount : amount;
  const scale = 10n ** BigInt(def.decimals);
  const whole = abs / scale;
  const fraction = def.decimals === 0 ? '' : (abs % scale).toString().padStart(def.decimals, '0');
  const shown = def.kind === 'crypto' ? fraction.replace(/0+$/, '') : fraction;
  const number = (amount < 0n ? '-' : '') +
    whole.toLocaleString('en-CA') + (shown ? '.' + shown : '');
  return def.code + ' ' + (def.symbol && def.symbol !== def.code ? def.symbol : '') + number;
}
