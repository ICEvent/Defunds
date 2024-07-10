import { writable } from 'svelte/store';
import {HttpAgent } from "@dfinity/agent"
import * as ICRCLEDGER from "../../declarations/icrc1_ledger_canister/index"
import { HOST_MAINNET, ICP_LEDGER_CANISTER_ID } from './lib/constants';

const initialValue = {
    isAuthed: false,
    principal: undefined,
    notifications: [],
    loading: false,
    icpledger: ICRCLEDGER.createActor(new HttpAgent({
        host: HOST_MAINNET
      }),ICP_LEDGER_CANISTER_ID, { actorOptions: {} })
};

export const globalStore = writable(initialValue);
