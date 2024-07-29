export const idlFactory = ({ IDL }) => {
  const Result = IDL.Variant({ 'ok' : IDL.Nat, 'err' : IDL.Text });
  const Time = IDL.Int;
  const Donation = IDL.Record({
    'txid' : IDL.Text,
    'currency' : IDL.Text,
    'timestamp' : IDL.Int,
    'amount' : IDL.Nat,
    'donor' : IDL.Principal,
  });
  return IDL.Service({
    'donate' : IDL.Func([IDL.Nat, IDL.Text, IDL.Text], [Result], []),
    'getDonationHistory' : IDL.Func(
        [IDL.Nat, IDL.Nat, IDL.Opt(Time), IDL.Opt(Time)],
        [IDL.Vec(Donation)],
        ['query'],
      ),
    'getDonorCredit' : IDL.Func([IDL.Text], [IDL.Opt(IDL.Nat)], ['query']),
    'getDonorHistory' : IDL.Func(
        [IDL.Principal, IDL.Nat],
        [IDL.Vec(Donation)],
        ['query'],
      ),
    'updateExchangeRates' : IDL.Func([IDL.Text, IDL.Nat], [Result], []),
  });
};
export const init = ({ IDL }) => { return []; };
