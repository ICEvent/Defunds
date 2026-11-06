import { HttpAgent } from '@dfinity/agent';
import { AuthClient } from '@dfinity/auth-client';
import { createActor } from '$declarations/personal_loan';
import { HOST_MAINNET } from '$lib/constants';

// Personal Loan is deliberately NOT connected to Defunds Treasury.
// Explicit configuration avoids accidentally sending private data to an
// unrelated canister or assuming a production canister has been deployed.
export const loanCanisterConfigured = Boolean(import.meta.env.VITE_PERSONAL_LOAN_CANISTER_ID);

export async function connectPersonalLoan() {
  const canisterId = import.meta.env.VITE_PERSONAL_LOAN_CANISTER_ID;
  if (!canisterId) return null;
  const client = await AuthClient.create({
    idleOptions: { disableIdle: true, disableDefaultIdleCallback: true }
  });
  if (!(await client.isAuthenticated())) return null;
  const host = import.meta.env.VITE_PERSONAL_LOAN_HOST || HOST_MAINNET;
  const agent = new HttpAgent({ host, identity: client.getIdentity() });
  if (/localhost|127\.0\.0\.1/.test(host)) {
    await agent.fetchRootKey();
  }
  return createActor(canisterId, { agent });
}
