import { readFileSync } from 'node:fs';

// Used ONLY by Vite's Node-side config, never bundled into browser code.
// DFX passes DFX_NETWORK=ic when it runs a workspace frontend build for --ic.
export function resolvePersonalLoanBuildId({
  network = process.env.DFX_NETWORK,
  explicitId = process.env.VITE_PERSONAL_LOAN_CANISTER_ID,
  filePath,
  readFile = readFileSync
} = {}) {
  // An explicit override supports isolated local PocketIC test scripts.
  if (explicitId) return { id: explicitId, source: 'environment' };
  if (network !== 'ic') return { id: null, source: 'non-mainnet' };

  let json;
  try {
    json = JSON.parse(readFile(filePath, 'utf8'));
  } catch (e) {
    if (e?.code === 'ENOENT') return { id: null, source: 'missing-file' };
    throw new Error('Cannot read canister_ids.json for mainnet Personal Loan: ' + e.message);
  }

  // Support both the caller's flat file:
  //   { "personal_loan": "rrkah-fqaaa-aaaaa-aaaaq-cai" }
  // and DFX's network-qualified form:
  //   { "personal_loan": { "ic": "rrkah-fqaaa-aaaaa-aaaaq-cai" } }.
  const entry = json?.personal_loan;
  if (entry == null) return { id: null, source: 'missing-id' };

  // A present entry must be either a direct Principal string or a network
  // mapping. Never silently treat a number/boolean/array as a missing ID.
  const isNetworkMapping = typeof entry === 'object' && !Array.isArray(entry);
  if (typeof entry !== 'string' && !isNetworkMapping) {
    throw new Error('Invalid personal_loan ID in canister_ids.json; expected a Canister Principal');
  }

  const id = typeof entry === 'string' ? entry : entry.ic;
  if (id == null || id === '') return { id: null, source: 'missing-id' };
  if (typeof id !== 'string' || !/^[a-z2-7]+(?:-[a-z2-7]+)+$/.test(id) ||
      id === 'aaaaa-aa' || id === '2vxsx-fae') {
    throw new Error('Invalid personal_loan ID in canister_ids.json; expected a Canister Principal');
  }
  return { id, source: 'canister_ids.json' };
}
