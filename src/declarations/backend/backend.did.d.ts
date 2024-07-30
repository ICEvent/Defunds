import type { Principal } from '@dfinity/principal';
import type { ActorMethod } from '@dfinity/agent';
import type { IDL } from '@dfinity/candid';

export interface Grant {
  'applicant' : Principal,
  'grantStatus' : Status,
  'title' : string,
  'grantType' : string,
  'submitime' : bigint,
  'recipient' : Principal,
  'reference' : string,
  'description' : string,
  'grantId' : bigint,
  'currency' : string,
  'amount' : bigint,
}
export interface NewGrant {
  'title' : string,
  'grantType' : string,
  'recipient' : Principal,
  'reference' : string,
  'description' : string,
  'currency' : string,
  'amount' : bigint,
}
export type Result = { 'ok' : bigint } |
  { 'err' : string };
export type Status = { 'review' : null } |
  { 'cancelled' : null } |
  { 'expired' : null } |
  { 'submitted' : null } |
  { 'approved' : null } |
  { 'rejected' : null };
export interface _SERVICE {
  'applyGrant' : ActorMethod<[NewGrant], Result>,
  'getDonorCredit' : ActorMethod<[string], [] | [bigint]>,
  'getGrants' : ActorMethod<[bigint, bigint], Array<Grant>>,
  'updateExchangeRates' : ActorMethod<[string, bigint], Result>,
}
export declare const idlFactory: IDL.InterfaceFactory;
export declare const init: (args: { IDL: typeof IDL }) => IDL.Type[];
