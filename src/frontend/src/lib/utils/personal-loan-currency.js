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

// Blockchain asset identity; token tickers are NOT globally unique.
export const BUILTIN_ASSET_REFERENCES = Object.freeze({
  CAD: { network: '', standard: 'fiat', address: '' },
  USD: { network: '', standard: 'fiat', address: '' },
  EUR: { network: '', standard: 'fiat', address: '' },
  GBP: { network: '', standard: 'fiat', address: '' },
  CNY: { network: '', standard: 'fiat', address: '' },
  BTC: { network: 'bitcoin:mainnet', standard: 'native', address: '' },
  ETH: { network: 'eip155:1', standard: 'native', address: '' },
  ICP: { network: 'ic:mainnet', standard: 'icrc', address: 'ryjl3-tyaaa-aaaaa-aaaba-cai' },
  CKBTC: { network: 'ic:mainnet', standard: 'icrc', address: 'mxzaz-hqaaa-aaaar-qaada-cai' },
  CKETH: { network: 'ic:mainnet', standard: 'icrc', address: 'ss2fx-dyaaa-aaaar-qacoq-cai' }
});

export function builtinAssetReference(code) {
  return BUILTIN_ASSET_REFERENCES[code] ? { ...BUILTIN_ASSET_REFERENCES[code] } : null;
}

export function assetReference(value, currency) {
  const asset = currencyDefinition(currency);
  const network = String(value?.network ?? '').trim().toLowerCase();
  const standard = String(value?.standard ?? '').trim().toLowerCase();
  const address = String(value?.address ?? '').trim();
  if (asset.kind === 'fiat') {
    if (network || address || standard !== 'fiat') {
      throw new Error('Fiat currencies must not have a blockchain contract');
    }
    return { network: '', standard: 'fiat', address: '' };
  }
  if (!/^[a-z0-9:-]{4,64}$/.test(network)) {
    throw new Error('Specify a valid blockchain network (e.g. eip155:1 or ic:mainnet)');
  }
  if (standard === 'native') {
    if (address) throw new Error('Native cryptocurrency has no token contract address');
    return { network, standard, address: '' };
  }
  if (standard === 'erc20') {
    if (!/^eip155:[1-9][0-9]{0,10}$/.test(network)) {
      throw new Error('ERC-20 requires a valid EVM Chain ID, for example eip155:1');
    }
    if (!/^0x[0-9a-fA-F]{40}$/.test(address) || /^0x0{40}$/i.test(address)) {
      throw new Error('ERC-20 contract address must be a nonzero 0x followed by 40 hex characters');
    }
    return { network, standard, address };
  }
  if (standard === 'icrc') {
    if (!['ic:mainnet', 'ic:local'].includes(network)) {
      throw new Error('ICRC requires ic:mainnet or ic:local');
    }
    if (!/^[a-z2-7-]{10,64}$/.test(address)) {
      throw new Error('ICRC requires a ledger canister Principal ID');
    }
    return { network, standard, address };
  }
  throw new Error('Choose Native, ERC-20 or ICRC and provide its network/identity');
}

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
