export const idlFactory = ({ IDL }) => {
  const Currency__1 = IDL.Variant({
    'ICP' : IDL.Null,
    'ckBTC' : IDL.Null,
    'ckETH' : IDL.Null,
    'ckUSDC' : IDL.Null,
  });
  const NewGrant = IDL.Record({
    'title' : IDL.Text,
    'recipient' : IDL.Text,
    'description' : IDL.Text,
    'currency' : Currency__1,
    'category' : IDL.Text,
    'proofs' : IDL.Vec(IDL.Text),
    'amount' : IDL.Nat,
  });
  const Result = IDL.Variant({ 'ok' : IDL.Nat, 'err' : IDL.Text });
  const Currency = IDL.Variant({
    'ICP' : IDL.Null,
    'ckBTC' : IDL.Null,
    'ckETH' : IDL.Null,
    'ckUSDC' : IDL.Null,
  });
  const Status = IDL.Variant({
    'review' : IDL.Null,
    'cancelled' : IDL.Null,
    'expired' : IDL.Null,
    'submitted' : IDL.Null,
    'voting' : IDL.Null,
    'approved' : IDL.Null,
    'rejected' : IDL.Null,
  });
  const VoteType = IDL.Variant({ 'reject' : IDL.Null, 'approve' : IDL.Null });
  const Vote = IDL.Record({
    'voteType' : VoteType,
    'grantId' : IDL.Int,
    'voterId' : IDL.Principal,
    'votePower' : IDL.Nat,
    'timestamp' : IDL.Int,
  });
  const VotingStatus = IDL.Record({
    'startTime' : IDL.Int,
    'rejectVotePower' : IDL.Nat,
    'endTime' : IDL.Int,
    'votes' : IDL.Vec(Vote),
    'approvalVotePower' : IDL.Nat,
    'totalVotePower' : IDL.Nat,
  });
  const Grant = IDL.Record({
    'applicant' : IDL.Principal,
    'grantStatus' : Status,
    'title' : IDL.Text,
    'submitime' : IDL.Int,
    'recipient' : IDL.Text,
    'votingStatus' : IDL.Opt(VotingStatus),
    'description' : IDL.Text,
    'grantId' : IDL.Int,
    'currency' : Currency__1,
    'category' : IDL.Text,
    'proofs' : IDL.Vec(IDL.Text),
    'amount' : IDL.Nat,
  });
  const Donation__1 = IDL.Record({
    'donorId' : IDL.Principal,
    'txid' : IDL.Text,
    'currency' : Currency,
    'timestamp' : IDL.Int,
    'amount' : IDL.Nat,
  });
  const Donation = IDL.Record({
    'donorId' : IDL.Principal,
    'txid' : IDL.Text,
    'currency' : Currency,
    'timestamp' : IDL.Int,
    'amount' : IDL.Nat,
  });
  const PowerChange = IDL.Record({
    'source' : Donation,
    'timestamp' : IDL.Int,
    'amount' : IDL.Nat,
  });
  const VotingPower = IDL.Record({
    'userId' : IDL.Principal,
    'totalPower' : IDL.Nat,
    'powerHistory' : IDL.Vec(PowerChange),
  });
  return IDL.Service({
    'applyGrant' : IDL.Func([NewGrant], [Result], []),
    'cancelGrant' : IDL.Func([IDL.Nat], [Result], []),
    'donate' : IDL.Func([IDL.Nat, Currency, IDL.Text], [Result], []),
    'finalizeGrantVoting' : IDL.Func([IDL.Nat], [Result], []),
    'getAllGrants' : IDL.Func([], [IDL.Vec(Grant)], ['query']),
    'getDonorCredit' : IDL.Func([IDL.Text], [IDL.Opt(IDL.Nat)], ['query']),
    'getExchangeRates' : IDL.Func(
        [],
        [IDL.Vec(IDL.Tuple(IDL.Text, IDL.Nat))],
        ['query'],
      ),
    'getGrant' : IDL.Func([IDL.Nat], [IDL.Opt(Grant)], ['query']),
    'getGrantVotingStatus' : IDL.Func(
        [IDL.Nat],
        [IDL.Opt(VotingStatus)],
        ['query'],
      ),
    'getGrants' : IDL.Func(
        [IDL.Vec(Status), IDL.Nat],
        [IDL.Vec(Grant)],
        ['query'],
      ),
    'getMyDonations' : IDL.Func([], [IDL.Vec(Donation__1)], ['query']),
    'getMyGrants' : IDL.Func([], [IDL.Vec(Grant)], ['query']),
    'getTotalVotingPower' : IDL.Func([], [IDL.Nat], ['query']),
    'getVotingPower' : IDL.Func(
        [IDL.Principal],
        [IDL.Opt(VotingPower)],
        ['query'],
      ),
    'startGrantVoting' : IDL.Func([IDL.Nat], [Result], []),
    'updateExchangeRates' : IDL.Func([Currency, IDL.Nat], [Result], []),
    'voteOnGrant' : IDL.Func([IDL.Nat, VoteType], [Result], []),
  });
};
export const init = ({ IDL }) => { return []; };
