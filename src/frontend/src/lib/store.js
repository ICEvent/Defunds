import { writable } from 'svelte/store';
import { HttpAgent } from "@dfinity/agent"
import * as ICPLEDGER from "$declarations/icrc1_ledger_canister/index"
import { createActor } from '$declarations/backend';
import { DEFUND_CANISTER_ID, HOST_MAINNET, ICP_LEDGER_CANISTER_ID } from '$lib/constants';

const initialValue = {
  isAuthed: false,
  principal: undefined,
  notifications: [],
  loading: false,
  icpledger: ICPLEDGER.createActor(new HttpAgent({
    host: HOST_MAINNET
  }), ICP_LEDGER_CANISTER_ID, { actorOptions: {} }),
  backend: createActor(DEFUND_CANISTER_ID, {
    agent: new HttpAgent({
      host: HOST_MAINNET
    })
  }),
};

export const globalStore = writable(initialValue);

export const setAgent = (agent) => {
  globalStore.update(store => {
    return {
      ...store,
      icpledger: ICPLEDGER.createActor(agent, ICP_LEDGER_CANISTER_ID, { actorOptions: {} }),
      backend: createActor(DEFUND_CANISTER_ID, { agent })
    };
  });
};