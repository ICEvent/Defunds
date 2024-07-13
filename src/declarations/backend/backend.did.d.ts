import type { Principal } from '@dfinity/principal';
import type { ActorMethod } from '@dfinity/agent';
import type { IDL } from '@dfinity/candid';

export interface Donation {
  'txid' : string,
  'currency' : string,
  'timestamp' : bigint,
  'amount' : bigint,
  'donor' : Principal,
}
export type Result = { 'ok' : bigint } |
  { 'err' : string };
export type Time = bigint;
export interface _SERVICE {
  'donate' : ActorMethod<
    [bigint, string, { 'txid' : string } | { 'block' : bigint }],
    Result
  >,
  'getDonationHistory' : ActorMethod<
    [bigint, bigint, [] | [Time], [] | [Time]],
    Array<Donation>
  >,
  'getDonorCredit' : ActorMethod<[string], [] | [bigint]>,
  'getDonorHistory' : ActorMethod<[Principal, bigint], Array<Donation>>,
  'updateExchangeRates' : ActorMethod<[string, bigint], Result>,
}
export declare const idlFactory: IDL.InterfaceFactory;
export declare const init: (args: { IDL: typeof IDL }) => IDL.Type[];
