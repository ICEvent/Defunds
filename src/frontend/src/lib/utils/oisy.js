// OISY is an ICRC-25/27/29/49 wallet signer, not an Internet Identity session.
// These imports MUST be resolved before the user clicks OISY Login. Awaiting
// dynamic imports inside connectOisy() loses the browser's user activation,
// which prevents an ICRC-29 signer popup from opening (notably in Safari).
import { Signer } from '@icp-sdk/signer';
import { PostMessageTransport } from '@icp-sdk/signer/web';
import { SignerAgent } from '@icp-sdk/signer/agent';

let activeSigner = null;

export async function connectOisy() {
  if (typeof window === 'undefined') throw new Error('OISY requires a web browser.');

  const signer = new Signer({
    transport: new PostMessageTransport({ url: 'https://oisy.com/sign' })
  });

  try {
    // CRITICAL: this is the first awaited operation. connectOisy() is called
    // synchronously from the OISY button's click handler. Do not place any
    // await, import(), network request, or permission query before this call.
    await signer.openChannel();

    const accounts = await signer.getAccounts();
    if (!accounts?.length) throw new Error('OISY did not share an account.');
    // Wallet principal is normally different from the app's II principal.
    // Never merge the two account identities implicitly.
    const principal = accounts[0].owner;
    if (!principal || principal.isAnonymous?.()) throw new Error('OISY returned an invalid account.');
    const agent = await SignerAgent.create({ signer, account: principal });
    activeSigner = signer;
    return { agent, principal };
  } catch (error) {
    try { await signer.closeChannel(); } catch { /* connection already closed */ }
    throw error;
  }
}

export async function disconnectOisy() {
  const signer = activeSigner;
  activeSigner = null;
  if (signer) await signer.closeChannel();
}
