export function definitionKey(definition) {
  return 'currency' in definition ? `currency:${definition.currency}` : `asset:${definition.asset}`;
}
// Exact integer quantities only. Ledger identities, not tickers, join positions.
export function assetGroups(positions, balances, currencies = []) {
  const groups = new Map();
  const ensure = (key, name, unit, decimals) => {
    if (!groups.has(key)) groups.set(key, { key, name, unit, decimals: Number(decimals), quantity: 0n, known: false, unavailable: false, positions: [] });
    const group = groups.get(key);
    if (group.decimals !== Number(decimals)) throw new Error('Asset precision mismatch; refresh before using totals');
    return group;
  };
  for (const position of positions.filter(p => !p.asset.archived)) {
    const group = ensure(definitionKey(position.definition), position.name, position.unit, position.decimals);
    group.quantity += position.asset.quantity; group.known = true; group.positions.push(position);
  }
  for (const currency of currencies.filter(c => c.ledger.length)) {
    const group = ensure(`currency:${currency.id}`, currency.name, currency.symbol, currency.decimals);
    const entry = balances.find(b => b.currency.id === currency.id);
    if (entry && 'ok' in entry.balance) { group.quantity += entry.balance.ok; group.known = true; }
    else group.unavailable = true;
  }
  return [...groups.values()];
}
export function walletSubaccount(text) {
  const value = text.trim();
  if (!value) return [];
  if (!/^[0-9a-fA-F]{64}$/.test(value)) throw new Error('Use exactly 64 hexadecimal characters for a subaccount');
  return [Uint8Array.from(value.match(/../g), byte => parseInt(byte, 16))];
}
