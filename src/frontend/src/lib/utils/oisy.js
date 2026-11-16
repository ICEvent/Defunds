// OISY is an ICRC-25/27/29/49 wallet signer, not an Internet Identity session.
// Import lazily so the II and Plug login paths do not load the wallet SDK.
let activeSigner = null;

export async function connectOisy() {
  if (typeof window === 'undefined') throw new Error('OISY requires a web browser.');
  const [{ Signer }, { PostMessageTransport }, { SignerAgent }] = await Promise.all([
    import('@icp-sdk/signer'),
    import('@icp-sdk/signer/web'),
    import('@icp-sdk/signer/agent')
  ]);
  const signer = new Signer({
    transport: new PostMessageTransport({ url: 'https://oisy.com/sign' })
  });

  try {
    const accounts = await signer.getAccounts();
    if (!accounts?.length) throw new Error('OISY did not share an account.');
    // OISY exposes a wallet principal, which is normally DIFFERENT from the
    // per-app Internet Identity principal. Do not merge identities implicitly.
    const principal = accounts[0].owner;
    if (!principal || principal.isAnonymous?.()) throw new Error('OISY returned an invalid account.');
    const agent = await SignerAgent.create({ signer, account: principal });
    activeSigner = signer;
    return { agent, principal };
  } catch (error) {
    await signer.close?.().catch?.(() => {});
    throw error;
  }
}

export async function disconnectOisy() {
  const signer = activeSigner;
  activeSigner = null;
  if (signer && typeof signer.close === 'function') {
    await signer.close();
  }
}
