import type { Principal } from '@dfinity/principal';
import type { ActorMethod } from '@dfinity/agent';
import type { IDL } from '@dfinity/candid';

export interface Donation {
  'currency' : string,
  'timestamp' : bigint,
  'amount' : bigint,
  'donor' : Principal,
}
export type Result = { 'ok' : bigint } |
  { 'err' : string };
export type Time = bigint;
export interface _SERVICE {
  'donate' : ActorMethod<[bigint, string], Result>,
  'getDoantions' : ActorMethod<[], Array<Donation>>,
  'getDonationHistory' : ActorMethod<
    [bigint, bigint, [] | [Time], [] | [Time]],
    Array<Donation>
  >,
  'getDonorHistory' : ActorMethod<[Principal], Array<Donation>>,
}
export declare const idlFactory: IDL.InterfaceFactory;
export declare const init: (args: { IDL: typeof IDL }) => IDL.Type[];
