import { HttpAgent } from '@dfinity/agent';
import { AuthClient } from '@dfinity/auth-client';
import { get } from 'svelte/store';
import { createActor } from '$declarations/personal_loan';
import { HOST_MAINNET } from '$lib/constants';
import { globalStore } from '$lib/store';

// Personal Loan is NOT connected to Defunds Treasury. Reuse the exact active
// caller identity, but only create an actor for its separately configured canister.
export const loanCanisterConfigured = Boolean(import.meta.env.VITE_PERSONAL_LOAN_CANISTER_ID);

export async function connectPersonalLoan(expectedPrincipal) {
  const canisterId = import.meta.env.VITE_PERSONAL_LOAN_CANISTER_ID;
  if (!canisterId) return null;
  const state = get(globalStore);
  if (!state.isAuthed || !state.principal) {
    throw new Error('Please log in to use Personal Loan.');
  }
  const actual = state.principal.toText();
  if (expectedPrincipal && actual !== expectedPrincipal.toText()) {
    throw new Error('Personal Loan identity differs from the active Defunds account. Please log in again.');
  }

  if (state.authProvider === 'plug' || state.authProvider === 'oisy') {
    if (!state.agent) throw new Error('Wallet session has expired. Please reconnect.');
    // The caller for Personal Loan must be the same Principal as the one used
    // for the rest of Defunds. No hidden Internet Identity fallback is allowed.
    const walletPrincipal = await state.agent.getPrincipal();
    if (walletPrincipal.toText() !== actual) {
      throw new Error('Active wallet account changed. Please reconnect before modifying loans.');
    }
    return createActor(canisterId, { agent: state.agent });
  }

  const client = await AuthClient.create({
    idleOptions: { disableIdle: true, disableDefaultIdleCallback: true }
  });
  if (!(await client.isAuthenticated())) {
    throw new Error('Internet Identity session is not authenticated. Please log out and log in again.');
  }
  if (client.getIdentity().getPrincipal().toText() !== actual) {
    throw new Error('Internet Identity session differs from the active Defunds account. Please log in again.');
  }
  const host = import.meta.env.VITE_PERSONAL_LOAN_HOST || HOST_MAINNET;
  const agent = new HttpAgent({ host, identity: client.getIdentity() });
  if (/localhost|127\\.0\\.0\\.1/.test(host)) await agent.fetchRootKey();
  return createActor(canisterId, { agent });
}
