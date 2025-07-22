import { DERIVATION_ORIGION } from '$lib/constants';

export const whitelist = ['32pz7-5qaaa-aaaag-qacra-cai'];
export const host = DERIVATION_ORIGION;

export const connectPlug = async () => {
  const connected = await window.ic.plug.requestConnect({
    whitelist,
    host
  });
  
  if (connected) {
    const agent = await window.ic.plug.agent;
    const principal = await window.ic.plug.getPrincipal();
    // const balance = await window.ic.plug.requestBalance();
    return { principal, agent };
  }
  return null;
};

export const verifyConnection = async () => {
  let isConnected = await window.ic.plug.isConnected();
  if (isConnected) {
    const agent = await window.ic.plug.agent;
    const principal = await window.ic.plug.getPrincipal();
    return { principal, agent };
  }
};
