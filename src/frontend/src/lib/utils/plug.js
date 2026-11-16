import {
  DEFUND_CANISTER_ID,
  GOVERNANCE_CANISTER_ID,
  HOST_MAINNET,
  ICP_LEDGER_CANISTER_ID
} from '$lib/constants';

// The extension must explicitly approve each canister that Defunds will call.
// Keep the optional personal-loan canister separate from the Treasury actor.
export const plugWhitelist = () => [
  DEFUND_CANISTER_ID,
  GOVERNANCE_CANISTER_ID,
  ICP_LEDGER_CANISTER_ID,
  import.meta.env.VITE_PERSONAL_LOAN_CANISTER_ID
].filter(Boolean);

function getPlug() {
  if (typeof window === 'undefined') return null;
  return window.ic?.plug ?? null;
}

async function connectedSession(plug) {
  const agent = plug.agent;
  if (!agent || typeof agent.getPrincipal !== 'function') {
    throw new Error('Plug did not provide a signing agent. Reconnect and approve Defunds canisters.');
  }
  const principal = await agent.getPrincipal();
  if (!principal || principal.isAnonymous?.()) {
    throw new Error('Plug returned an anonymous account.');
  }
  return { agent, principal };
}

export async function connectPlug() {
  const plug = getPlug();
  if (!plug) {
    throw new Error('Plug extension not detected. Install Plug in this browser and reload, or choose Internet Identity/OISY.');
  }
  await plug.requestConnect({ whitelist: plugWhitelist(), host: HOST_MAINNET });
  if (!(await plug.isConnected())) throw new Error('Plug wallet connection was not approved.');
  return connectedSession(plug);
}

// Session restoration must NEVER trigger an unprompted permission popup.
export async function verifyConnection() {
  const plug = getPlug();
  if (!plug || !(await plug.isConnected())) return null;
  return connectedSession(plug);
}

export async function disconnectPlug() {
  const plug = getPlug();
  if (plug && typeof plug.disconnect === 'function') await plug.disconnect();
}
