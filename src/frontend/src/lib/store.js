import { writable } from 'svelte/store';
import { HttpAgent } from "@dfinity/agent"
import * as ICPLEDGER from "$declarations/icrc1_ledger_canister/index";
import { createActor } from '$declarations/backend';
import { createActor as createGovernanceActor } from '$declarations/governance';
import { DEFUND_CANISTER_ID, GOVERNANCE_CANISTER_ID, HOST_MAINNET, ICP_LEDGER_CANISTER_ID } from '$lib/constants';

const initialAgent = new HttpAgent({ host: HOST_MAINNET });

const initialValue = {
  agent: initialAgent,
  authProvider: null,
  isAuthed: false,
  principal: undefined,
  notifications: [],
  loading: false,
  icpledger: ICPLEDGER.createActor(ICP_LEDGER_CANISTER_ID, {
    agent: initialAgent
  }),
  backend: createActor(DEFUND_CANISTER_ID, {
    agent: initialAgent
  }),
  governance: createGovernanceActor(GOVERNANCE_CANISTER_ID, { agent: initialAgent }),
};

export const globalStore = writable(initialValue);

export const setAgent = (agent) => {
  globalStore.update(store => {
    return {
      ...store,
      agent,
      icpledger: ICPLEDGER.createActor(ICP_LEDGER_CANISTER_ID, { agent }),
      backend: createActor(DEFUND_CANISTER_ID, { agent }),
      governance: createGovernanceActor(GOVERNANCE_CANISTER_ID, { agent })
    };
  });
};