export const idlFactory = ({ IDL }) => {
  const NewGrant = IDL.Record({
    'title' : IDL.Text,
    'grantType' : IDL.Text,
    'recipient' : IDL.Principal,
    'reference' : IDL.Text,
    'description' : IDL.Text,
    'currency' : IDL.Text,
    'amount' : IDL.Nat,
  });
  const Result = IDL.Variant({ 'ok' : IDL.Nat, 'err' : IDL.Text });
  const Status = IDL.Variant({
    'review' : IDL.Null,
    'cancelled' : IDL.Null,
    'expired' : IDL.Null,
    'submitted' : IDL.Null,
    'approved' : IDL.Null,
    'rejected' : IDL.Null,
  });
  const Grant = IDL.Record({
    'applicant' : IDL.Principal,
    'grantStatus' : Status,
    'title' : IDL.Text,
    'grantType' : IDL.Text,
    'submitime' : IDL.Int,
    'recipient' : IDL.Principal,
    'reference' : IDL.Text,
    'description' : IDL.Text,
    'grantId' : IDL.Int,
    'currency' : IDL.Text,
    'amount' : IDL.Nat,
  });
  return IDL.Service({
    'applyGrant' : IDL.Func([NewGrant], [Result], []),
    'getDonorCredit' : IDL.Func([IDL.Text], [IDL.Opt(IDL.Nat)], ['query']),
    'getGrant' : IDL.Func([IDL.Nat], [IDL.Opt(Grant)], ['query']),
    'getGrants' : IDL.Func([IDL.Nat, IDL.Nat], [IDL.Vec(Grant)], ['query']),
    'updateExchangeRates' : IDL.Func([IDL.Text, IDL.Nat], [Result], []),
  });
};
export const init = ({ IDL }) => { return []; };
