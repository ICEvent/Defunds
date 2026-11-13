// Pure replay model. Amounts and quantities are atomic BigInts, in one
// investment's fixed asset and settlement currency. No balance mutations.
export function replayInvestment(events, valuation = null) {
  const accounts = new Map();
  const ids = new Set();
  let quantity = 0n, cost = 0n, invested = 0n, proceeds = 0n;
  let income = 0n, expenses = 0n, realized = 0n;
  const amount = (value, positive = false) => {
    if (typeof value !== 'bigint' || value < 0n || (positive && value === 0n))
      throw new Error('Expected an exact nonnegative BigInt amount');
    return value;
  };
  const account = (id) => {
    if (typeof id !== 'string' || !id.trim()) throw new Error('Account required');
    return accounts.get(id) ?? 0n;
  };
  let lastAt = null;
  for (const e of events) {
    if (typeof e.id !== 'string' || !e.id || ids.has(e.id)) throw new Error('Duplicate or missing event ID');
    ids.add(e.id);
    if (typeof e.at !== 'bigint' || (lastAt !== null && e.at < lastAt)) throw new Error('Events must be chronological');
    lastAt = e.at;
    const fee = amount(e.fee ?? 0n);
    switch (e.kind) {
      case 'buy': {
        const q = amount(e.quantity, true), paid = amount(e.amount, true);
        accounts.set(e.account, account(e.account) + q);
        quantity += q; cost += paid + fee; invested += paid + fee;
        break;
      }
      case 'sell': {
        const q = amount(e.quantity, true), gross = amount(e.amount);
        const held = account(e.account);
        if (q > held) throw new Error('Insufficient account holding');
        // Final sale consumes all rounding residue. Average cost is pooled
        // across accounts belonging to this investment.
        const released = q === quantity ? cost : cost * q / quantity;
        accounts.set(e.account, held - q);
        quantity -= q; cost -= released;
        proceeds += gross; expenses += fee; realized += gross - fee - released;
        break;
      }
      case 'income':
        income += amount(e.amount); expenses += fee;
        realized += e.amount - fee;
        break;
      case 'expense':
        expenses += amount(e.amount) + fee;
        realized -= e.amount + fee;
        break;
      case 'transfer': {
        const q = amount(e.quantity, true), held = account(e.from);
        const target = account(e.to);
        if (e.from === e.to) throw new Error('Choose different accounts');
        if (q > held) throw new Error('Insufficient account holding');
        accounts.set(e.from, held - q); accounts.set(e.to, target + q);
        expenses += fee; realized -= fee;
        break;
      }
      default: throw new Error('Unsupported investment event');
    }
  }
  let value = quantity === 0n ? 0n : null;
  if (valuation !== null) {
    amount(valuation.amount);
    if (typeof valuation.at !== 'bigint' || (lastAt !== null && valuation.at < lastAt))
      throw new Error('Valuation predates investment activity');
    if (valuation.quantity !== quantity) throw new Error('Valuation quantity is stale');
    if (quantity === 0n && valuation.amount !== 0n) throw new Error('Closed holding must have zero value');
    value = valuation.amount;
  }
  const unrealized = value === null ? null : value - cost;
  return { quantity, cost, invested, proceeds, income, expenses, realized,
    value, unrealized, total: unrealized === null ? null : realized + unrealized,
    accounts: [...accounts].map(([account, quantity]) => ({ account, quantity })) };
}
