export const idlFactory = ({ IDL }) => {
  const Result = IDL.Variant({ 'ok' : IDL.Nat, 'err' : IDL.Text });
  const Donation = IDL.Record({
    'currency' : IDL.Text,
    'timestamp' : IDL.Int,
    'amount' : IDL.Nat,
    'donor' : IDL.Principal,
  });
  const Time = IDL.Int;
  return IDL.Service({
    'donate' : IDL.Func([IDL.Nat, IDL.Text], [Result], []),
    'getDoantions' : IDL.Func([], [IDL.Vec(Donation)], ['query']),
    'getDonationHistory' : IDL.Func(
        [IDL.Nat, IDL.Nat, IDL.Opt(Time), IDL.Opt(Time)],
        [IDL.Vec(Donation)],
        ['query'],
      ),
    'getDonorHistory' : IDL.Func(
        [IDL.Principal],
        [IDL.Vec(Donation)],
        ['query'],
      ),
  });
};
export const init = ({ IDL }) => { return []; };
