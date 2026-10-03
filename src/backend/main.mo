import Types "types";
import Nat "mo:base/Nat";
import Array "mo:base/Array";
import Text "mo:base/Text";
import Iter "mo:base/Iter";
import Time "mo:base/Time";
import Buffer "mo:base/Buffer";
import Result "mo:base/Result";
import Nat64 "mo:base/Nat64";
import Int "mo:base/Int";
import Option "mo:base/Option";
import Hash "mo:base/Hash";
import Blob "mo:base/Blob";

import Hex "./hex";

import Principal "mo:base/Principal";
import TrieMap "mo:base/TrieMap";
import Bool "mo:base/Bool";

import ICPTypes "./icptypes";
import GrantTypes "./grant/types";
import Grants "./grant";

import GroupTypes "./group/types";
import Groups "./group";

persistent actor Defunds{

	type Donation = Types.Donation;
	type VotingPower = Types.VotingPower;
	type PowerChange = Types.PowerChange;

	type Grant = GrantTypes.Grant;
	type NewGrant = GrantTypes.NewGrant;

	type GrantVoteSnapshot = {
		eligibleVoters : [(Principal, Nat64)];
		eligibleVoterCount : Nat;
		totalVotingPower : Nat64;
		createdAt : Int;
		minVotePercentage : Nat;
		minPowerPercentage : Nat;
		approvalPercentage : Nat;
		legacyRawWeighting : Bool;
	};

	type TreasuryCommitmentStatus = {
		#awaitingFunding;
		#committed;
		#paying : { createdAt : Nat64 };
		#reconciliationRequired : { createdAt : Nat64 };
		#paid : Nat64;
	};

	type TreasuryCommitment = {
		grantId : Nat;
		currency : Types.Currency;
		amount : Nat64;
		status : TreasuryCommitmentStatus;
		createdAt : Int;
		updatedAt : Int;
	};

	transient let ICP_FEE : Nat64 = 10_000;
	transient let ICP_TX_DEDUP_WINDOW_NANOS : Nat64 = 24 * 60 * 60 * 1_000_000_000;

	var _stable_grantId = 1; // Unique ID for each grant
	var _accumulated_donations : Nat64 = 0; // Accumulated donations
	var _avaliable_funds : Nat64 = 0; // Total Available donations
	var _accumulated_voting_power : Nat64 = 0; // Accumulated voting power

	var upgradeCredits : [(Principal, Nat)] = [];
	var upgradeExchangeRates : [(Text, Nat64)] = [];
	var upgradeGrantVoteSnapshots : [(Nat, GrantVoteSnapshot)] = [];
	var upgradeTreasuryCommitments : [(Nat, TreasuryCommitment)] = [];
	var upgradeProcessedDonationBlocks : [Nat64] = [];
	var _stable_grants : [(Nat, Grant)] = [];
	var upgradeDonations : [(Nat64, Donation)] = [];

	var _stable_groupId = 1; // Unique ID for each grant
	var _stable_proposalId = 1; // Unique ID for each proposal
	var _stable_groups : [(Nat, GroupTypes.LegacyGroupFund)] = [];
	var _stable_groupCurrencies : [(Nat, Types.Currency)] = [];
	var _stable_proposals : [(Nat, GroupTypes.GroupProposal)] = [];
	var _stable_aiAgentFunds : [(Nat, GroupTypes.AIAgentFundRecord)] = [];

	transient let nat64Hash = func(n : Nat64) : Hash.Hash {
		Text.hash(Nat64.toText(n));
	};

	transient let natHash = func(n : Nat) : Hash.Hash {
		Text.hash(Nat.toText(n));
	};

	transient var donations = TrieMap.TrieMap<Nat64, Donation>(Nat64.equal, nat64Hash);
	transient var processedDonationBlocks = TrieMap.TrieMap<Nat64, Bool>(Nat64.equal, nat64Hash);
	processedDonationBlocks := TrieMap.fromEntries<Nat64, Bool>(
		Iter.map<Nat64, (Nat64, Bool)>(
			Iter.fromArray(upgradeProcessedDonationBlocks),
			func(blockIndex) { (blockIndex, true) },
		),
		Nat64.equal,
		nat64Hash,
	);
	transient var grantVoteSnapshots = TrieMap.TrieMap<Nat, GrantVoteSnapshot>(Nat.equal, natHash);
	grantVoteSnapshots := TrieMap.fromEntries<Nat, GrantVoteSnapshot>(
		Iter.fromArray(upgradeGrantVoteSnapshots),
		Nat.equal,
		natHash,
	);

	transient var treasuryCommitments = TrieMap.TrieMap<Nat, TreasuryCommitment>(Nat.equal, natHash);
	treasuryCommitments := TrieMap.fromEntries<Nat, TreasuryCommitment>(
		Iter.fromArray(upgradeTreasuryCommitments),
		Nat.equal,
		natHash,
	);
	transient var treasuryMutationVersion : Nat = 0;

	private func bumpTreasuryVersion() {
		treasuryMutationVersion += 1;
	};

	var upgradeConcilMembers : [Principal] = [];
	transient var concilMembers = TrieMap.TrieMap<Principal, Bool>(Principal.equal, Principal.hash);
	concilMembers := TrieMap.fromEntries<Principal, Bool>(Iter.map<Principal, (Principal, Bool)>(Iter.fromArray(upgradeConcilMembers), func(p) { (p, true) }), Principal.equal, Principal.hash);

	var DEFAULT_PAGE_SIZE = 50;

	transient let grants = Grants.Grants(_stable_grantId, _stable_grants);
	transient let groups = Groups.Groups(_stable_groupId, _stable_groups, _stable_groupCurrencies, _stable_proposalId, _stable_proposals, Principal.fromActor(Defunds), _stable_aiAgentFunds);

	transient let ICPLedger : actor {
		query_blocks : shared query ICPTypes.GetBlocksArgs -> async ICPTypes.QueryBlocksResponse;
		transfer : shared ICPTypes.TransferArgs -> async ICPTypes.Result_6;
		account_balance : shared query ICPTypes.BinaryAccountBalanceArgs -> async ICPTypes.Tokens;
		account_identifier : shared query ICPTypes.Account -> async Blob;

	} = actor "ryjl3-tyaaa-aaaaa-aaaba-cai";

	type Icrc1Account = {
		owner : Principal;
		subaccount : ?Blob;
	};

	type Icrc1TransferArg = {
		from_subaccount : ?Blob;
		to : Icrc1Account;
		amount : Nat;
		fee : ?Nat;
		memo : ?Blob;
		created_at_time : ?Nat64;
	};

	type Icrc1TransferError = {
		#BadFee : { expected_fee : Nat };
		#BadBurn : { min_burn_amount : Nat };
		#InsufficientFunds : { balance : Nat };
		#TooOld;
		#CreatedInFuture : { ledger_time : Nat64 };
		#TemporarilyUnavailable;
		#Duplicate : { duplicate_of : Nat };
		#GenericError : { error_code : Nat; message : Text };
	};

	type Icrc1TransferResult = {
		#Ok : Nat;
		#Err : Icrc1TransferError;
	};

	private func icrc1LedgerActor(canisterId : Principal) : actor {
		icrc1_transfer : shared Icrc1TransferArg -> async Icrc1TransferResult;
	} {
		actor (Principal.toText(canisterId));
	};

	private func getIcrcLedgerCanister(currency : Types.Currency) : ?Principal {
		switch (currency) {
			case (#ICP) { null };
			case (#ckBTC) { ?Principal.fromText("mxzaz-hqaaa-aaaar-qaada-cai") };
			case (#ckETH) { ?Principal.fromText("ss2fx-dyaaa-aaaar-qacoq-cai") };
			case (#ckUSDC) { ?Principal.fromText("xevnm-gaaaa-aaaar-qafnq-cai") };
			case (#ICRC(canisterText)) {
				?Principal.fromText(canisterText);
			};
		};
	};

	transient var donorCredits = TrieMap.TrieMap<Principal, Nat>(Principal.equal, Principal.hash);
	donorCredits := TrieMap.fromEntries<Principal, Nat>(Iter.fromArray(upgradeCredits), Principal.equal, Principal.hash);
	transient var donorExchangeRates = TrieMap.TrieMap<Text, Nat64>(Text.equal, Text.hash);
	donorExchangeRates := TrieMap.fromEntries<Text, Nat64>(Iter.fromArray(upgradeExchangeRates), Text.equal, Text.hash);

	// Add these state variables
	var upgradeVotingPowers : [(Principal, VotingPower)] = [];
	transient var votingPowers = TrieMap.TrieMap<Principal, VotingPower>(Principal.equal, Principal.hash);
	votingPowers := TrieMap.fromEntries<Principal, VotingPower>(Iter.fromArray(upgradeVotingPowers), Principal.equal, Principal.hash);

	private func currencyToText(currency : Types.Currency) : Text {
		switch (currency) {
			case (#ICP) { "ICP" };
			case (#ckBTC) { "ckBTC" };
			case (#ckETH) { "ckETH" };
			case (#ckUSDC) { "ckUSDC" };
			case (#ICRC(token)) { token };
		};
	};
	var minVotePercentage : Nat = 50; // minimum share of snapshotted contributors who must vote
	var minPowerPercentage : Nat = 50; // minimum share of snapshotted governance power that must participate
	var approvalPercentage : Nat = 50; // approval power must be strictly greater than this percentage of participating power
	var maxAmountPercentage : Nat = 5; // 5% of total funds maximum

	private func integerSqrt(value : Nat64) : Nat64 {
		if (value < 2) {
			return value;
		};
		var x0 = value / 2;
		var x1 = (x0 + value / x0) / 2;
		while (x1 < x0) {
			x0 := x1;
			x1 := (x0 + value / x0) / 2;
		};
		x0;
	};

	private func currentGovernancePower() : Nat64 {
		var total : Nat64 = 0;
		for ((_, power) in votingPowers.entries()) {
			if (power.totalPower > 0) {
				total += integerSqrt(power.totalPower);
			};
		};
		total;
	};

	private func contributionScoreAt(power : VotingPower, snapshotAt : Int) : Nat64 {
		var score : Nat64 = 0;
		for (change in power.powerHistory.vals()) {
			if (change.timestamp <= snapshotAt) {
				score += change.amount;
			};
		};
		score;
	};

	private func buildGrantVoteSnapshotAt(snapshotAt : Int) : GrantVoteSnapshot {
		let voters = Buffer.Buffer<(Principal, Nat64)>(0);
		var eligibleVoterCount : Nat = 0;
		var total : Nat64 = 0;
		for ((principal, power) in votingPowers.entries()) {
			let historicalScore = contributionScoreAt(power, snapshotAt);
			if (historicalScore > 0) {
				let governancePower = integerSqrt(historicalScore);
				if (governancePower > 0) {
					voters.add((principal, governancePower));
					eligibleVoterCount += 1;
					total += governancePower;
				};
			};
		};
		{
			eligibleVoters = Buffer.toArray(voters);
			eligibleVoterCount = eligibleVoterCount;
			totalVotingPower = total;
			createdAt = snapshotAt;
			minVotePercentage = minVotePercentage;
			minPowerPercentage = minPowerPercentage;
			approvalPercentage = approvalPercentage;
			legacyRawWeighting = false;
		};
	};

	private func buildGrantVoteSnapshot() : GrantVoteSnapshot {
		buildGrantVoteSnapshotAt(Time.now());
	};

	private func snapshotVotingPower(snapshot : GrantVoteSnapshot, voter : Principal) : ?Nat64 {
		if (snapshot.legacyRawWeighting) {
			switch (votingPowers.get(voter)) {
				case null { null };
				case (?power) {
					if (power.totalPower == 0) { null } else { ?power.totalPower };
				};
			};
		} else {
			for ((principal, power) in snapshot.eligibleVoters.vals()) {
				if (principal == voter) {
					return ?power;
				};
			};
			null;
		};
	};

	private func isValidIcpAccountIdentifier(value : Text) : Bool {
		if (Text.size(value) != 64) {
			return false;
		};
		for (char in Text.toIter(value)) {
			let n = Char.toNat32(char);
			let isDigit = n >= 48 and n <= 57;
			let isLowerHex = n >= 97 and n <= 102;
			let isUpperHex = n >= 65 and n <= 70;
			if (not (isDigit or isLowerHex or isUpperHex)) {
				return false;
			};
		};
		true;
	};

	private func committedIcpLiability() : Nat {
		var total : Nat = 0;
		for ((_, commitment) in treasuryCommitments.entries()) {
			switch (commitment.status) {
				case (#committed) {
					switch (commitment.currency) {
						case (#ICP) {
							total += Nat64.toNat(commitment.amount) + Nat64.toNat(ICP_FEE);
						};
						case (_) {};
					};
				};
				case (#paying(_)) {
					switch (commitment.currency) {
						case (#ICP) {
							total += Nat64.toNat(commitment.amount) + Nat64.toNat(ICP_FEE);
						};
						case (_) {};
					};
				};
				case (#reconciliationRequired(_)) {
					switch (commitment.currency) {
						case (#ICP) {
							total += Nat64.toNat(commitment.amount) + Nat64.toNat(ICP_FEE);
						};
						case (_) {};
					};
				};
				case (_) {};
			};
		};
		total;
	};

	private func upsertAwaitingFunding(grant : Grant) {
		let now = Time.now();
		switch (treasuryCommitments.get(Int.abs(grant.grantId))) {
			case null {
				treasuryCommitments.put(
					Int.abs(grant.grantId),
					{
						grantId = Int.abs(grant.grantId);
						currency = grant.currency;
						amount = grant.amount;
						status = #awaitingFunding;
						createdAt = now;
						updatedAt = now;
					},
				);
				bumpTreasuryVersion();
			};
			case (?existing) {
				switch (existing.status) {
					case (#paid(_)) {};
					case (#paying(_)) {};
					case (#reconciliationRequired(_)) {};
					case (_) {
						treasuryCommitments.put(
							existing.grantId,
							{
								existing with
								currency = grant.currency;
								amount = grant.amount;
								status = #awaitingFunding;
								updatedAt = now;
							},
						);
				bumpTreasuryVersion();
					};
				};
			};
		};
	};

	private func markCommitted(grant : Grant) {
		let grantId = Int.abs(grant.grantId);
		let now = Time.now();
		switch (treasuryCommitments.get(grantId)) {
			case null {
				treasuryCommitments.put(
					grantId,
					{
						grantId = grantId;
						currency = grant.currency;
						amount = grant.amount;
						status = #committed;
						createdAt = now;
						updatedAt = now;
					},
				);
				bumpTreasuryVersion();
			};
			case (?existing) {
				treasuryCommitments.put(
					grantId,
					{
						existing with
						currency = grant.currency;
						amount = grant.amount;
						status = #committed;
						updatedAt = now;
					},
				);
				bumpTreasuryVersion();
			};
		};
	};

	private func resetPayoutToCommitted(grantId : Nat, createdAt : Nat64) {
		switch (treasuryCommitments.get(grantId)) {
			case null {};
			case (?existing) {
				switch (existing.status) {
					case (#paying({ createdAt = currentCreatedAt })) {
						if (currentCreatedAt == createdAt) {
							treasuryCommitments.put(
								grantId,
								{
									existing with
									status = #committed;
									updatedAt = Time.now();
								},
							);
							bumpTreasuryVersion();
						};
					};
					case (_) {};
				};
			};
		};
	};

	private func requirePayoutReconciliation(grantId : Nat, createdAt : Nat64) {
		switch (treasuryCommitments.get(grantId)) {
			case null {};
			case (?existing) {
				switch (existing.status) {
					case (#paying({ createdAt = currentCreatedAt })) {
						if (currentCreatedAt == createdAt) {
							treasuryCommitments.put(
								grantId,
								{
									existing with
									status = #reconciliationRequired({ createdAt = createdAt });
									updatedAt = Time.now();
								},
							);
							bumpTreasuryVersion();
						};
					};
					case (_) {};
				};
			};
		};
	};

	private func beginOrResumeIcpPayout(grantId : Nat) : Result.Result<Nat64, Text> {
		switch (treasuryCommitments.get(grantId)) {
			case null { #err("Treasury commitment not found") };
			case (?existing) {
				switch (existing.status) {
					case (#awaitingFunding) {
						#err("Grant is approved but awaiting treasury funding")
					};
					case (#paid(blockIndex)) {
						#err("PAID:" # Nat64.toText(blockIndex))
					};
					case (#paying({ createdAt })) {
						let nowInt = Time.now();
						if (nowInt < 0) {
							return #err("Invalid system time");
						};
						let nowNat = Int.abs(nowInt);
						if (nowNat > 18_446_744_073_709_551_615) {
							return #err("System time exceeds Nat64 range");
						};
						let now = Nat64.fromNat(nowNat);

						// An old ambiguous attempt must never be silently resent with a
						// fresh timestamp: the first transfer may have succeeded even if
						// this canister never received the response.
						if (
							now > createdAt and
							now - createdAt > ICP_TX_DEDUP_WINDOW_NANOS
						) {
							treasuryCommitments.put(
								grantId,
								{
									existing with
									status = #reconciliationRequired({ createdAt = createdAt });
									updatedAt = nowInt;
								},
							);
							bumpTreasuryVersion();
							#err("Payout requires ledger reconciliation before retry")
						} else {
							#ok(createdAt)
						};
					};
					case (#reconciliationRequired(_)) {
						#err("Payout requires ledger reconciliation before retry")
					};
					case (#committed) {
						let nowInt = Time.now();
						if (nowInt < 0) {
							return #err("Invalid system time");
						};
						let nowNat = Int.abs(nowInt);
						if (nowNat > 18_446_744_073_709_551_615) {
							return #err("System time exceeds Nat64 range");
						};
						let createdAt = Nat64.fromNat(nowNat);
						treasuryCommitments.put(
							grantId,
							{
								existing with
								status = #paying({ createdAt = createdAt });
								updatedAt = nowInt;
							},
						);
						bumpTreasuryVersion();
						#ok(createdAt);
					};
				};
			};
		};
	};

	private func ensureGrantReleased(grantId : Nat) : Bool {
		switch (grants.getGrant(grantId)) {
			case null { false };
			case (?grant) {
				switch (grant.grantStatus) {
					case (#released) { true };
					case (#approved) { grants.changeGrantStatus(grantId, #released) };
					case (_) { false };
				};
			};
		};
	};

	private func markPaid(grantId : Nat, blockIndex : Nat64) {
		switch (treasuryCommitments.get(grantId)) {
			case null {};
			case (?existing) {
				treasuryCommitments.put(
					grantId,
					{
						existing with
						status = #paid(blockIndex);
						updatedAt = Time.now();
					},
				);
				bumpTreasuryVersion();
			};
		};
	};

	private func tryCommitApprovedGrant(grant : Grant) : async Result.Result<TreasuryCommitment, Text> {
		let grantId = Int.abs(grant.grantId);
		if (grant.grantStatus != #approved) {
			return #err("Grant must be approved before funds can be committed");
		};

		switch (treasuryCommitments.get(grantId)) {
			case (?existing) {
				switch (existing.status) {
					case (#committed) { return #ok(existing) };
					case (#paying(_)) { return #ok(existing) };
					case (#reconciliationRequired(_)) { return #ok(existing) };
					case (#paid(_)) { return #ok(existing) };
					case (#awaitingFunding) {};
				};
			};
			case null {};
		};

		switch (grant.currency) {
			case (#ICP) {
				if (not isValidIcpAccountIdentifier(grant.recipient)) {
					return #err("Invalid ICP recipient account identifier");
				};
				let treasuryAccount = await ICPLedger.account_identifier({
					owner = Principal.fromActor(Defunds);
					subaccount = null;
				});

				// Snapshot the local treasury version before querying the ledger. If a
				// payout or reservation mutates treasury state while this query is in
				// flight, discard the returned balance and retry from the top.
				let versionBeforeBalance = treasuryMutationVersion;
				let freshBalance = await ICPLedger.account_balance({ account = treasuryAccount });
				if (treasuryMutationVersion != versionBeforeBalance) {
					return await tryCommitApprovedGrant(grant);
				};

				switch (treasuryCommitments.get(grantId)) {
					case (?current) {
						switch (current.status) {
							case (#committed) { return #ok(current) };
							case (#paying(_)) { return #ok(current) };
							case (#reconciliationRequired(_)) { return #ok(current) };
							case (#paid(_)) { return #ok(current) };
							case (#awaitingFunding) {};
						};
					};
					case null {};
				};

				let requiredNat = Nat64.toNat(grant.amount) + Nat64.toNat(ICP_FEE);
				let liveNat = Nat64.toNat(freshBalance.e8s);
				let refreshedReservedNat = committedIcpLiability();

				if (refreshedReservedNat + requiredNat > liveNat) {
					upsertAwaitingFunding(grant);
					switch (treasuryCommitments.get(grantId)) {
						case (?commitment) { #ok(commitment) };
						case null { #err("Failed to record awaiting-funding commitment") };
					};
				} else {
					markCommitted(grant);
					switch (treasuryCommitments.get(grantId)) {
						case (?commitment) { #ok(commitment) };
						case null { #err("Failed to record treasury commitment") };
					};
				};
			};
			case (_) {
				upsertAwaitingFunding(grant);
				switch (treasuryCommitments.get(grantId)) {
					case (?commitment) { #ok(commitment) };
					case null { #err("Failed to record unsupported-currency commitment") };
				};
			};
		};
	};

	private func isConcilMemberInternal(member : Principal) : Bool {
		Option.isSome(concilMembers.get(member));
	};

	private func canManageConcilMembers(caller : Principal) : Bool {
		Principal.isController(caller) or isConcilMemberInternal(caller);
	};

	public shared ({ caller }) func updateVotingPolicy(
		newMinVote : Nat,
		newMinPower : Nat,
		newMaxAmount : Nat,
	) : async Result.Result<Nat, Text> {
		if (Principal.isAnonymous(caller)) {
			#err("Anonymous users cannot update policy");
		} else if (not canManageConcilMembers(caller)) {
			#err("Only controllers or council members can update policy");
		} else if (newMinVote > 100 or newMinPower > 100 or newMaxAmount > 100) {
			#err("Policy percentages must be between 0 and 100");
		} else {
			minVotePercentage := newMinVote;
			minPowerPercentage := newMinPower;
			maxAmountPercentage := newMaxAmount;
			#ok(1);
		};
	};

	public shared ({ caller }) func updateMainFundGovernancePolicy(
		newMinVote : Nat,
		newMinPower : Nat,
		newApproval : Nat,
		newMaxAmount : Nat,
	) : async Result.Result<Nat, Text> {
		if (Principal.isAnonymous(caller)) {
			#err("Anonymous users cannot update policy");
		} else if (not canManageConcilMembers(caller)) {
			#err("Only controllers or council members can update policy");
		} else if (
			newMinVote > 100 or
			newMinPower > 100 or
			newApproval >= 100 or
			newMaxAmount > 100
		) {
			#err("Policy percentages are out of range");
		} else {
			minVotePercentage := newMinVote;
			minPowerPercentage := newMinPower;
			approvalPercentage := newApproval;
			maxAmountPercentage := newMaxAmount;
			#ok(1);
		};
	};

	public query func getVotingPolicy() : async (Nat, Nat, Nat) {
		(minVotePercentage, minPowerPercentage, maxAmountPercentage);
	};

	public query func getMainFundGovernancePolicy() : async (Nat, Nat, Nat, Nat) {
		(minVotePercentage, minPowerPercentage, approvalPercentage, maxAmountPercentage);
	};

	system func preupgrade() {
		upgradeCredits := Iter.toArray(donorCredits.entries());
		upgradeExchangeRates := Iter.toArray(donorExchangeRates.entries());
		upgradeGrantVoteSnapshots := Iter.toArray(grantVoteSnapshots.entries());
		upgradeTreasuryCommitments := Iter.toArray(treasuryCommitments.entries());
		upgradeProcessedDonationBlocks := Iter.toArray(processedDonationBlocks.keys());
		upgradeDonations := Iter.toArray(donations.entries());

		_stable_grants := grants.toStable();
		_stable_grantId := grants.getNextGrantId();
		_stable_groups := groups.toStable();
		_stable_groupCurrencies := groups.toStableCurrencies();
		_stable_groupId := groups.getNextGroupId();
		_stable_proposals := groups.toStableProposals();
		_stable_proposalId := groups.getNextProposalId();
		_stable_aiAgentFunds := groups.toStableAIAgentFunds();

		upgradeVotingPowers := Iter.toArray(votingPowers.entries());
		upgradeConcilMembers := Iter.toArray(Iter.map<(Principal, Bool), Principal>(concilMembers.entries(), func((p, _)) { p }));
	};

	system func postupgrade() {
		upgradeCredits := [];
		upgradeExchangeRates := [];
		upgradeVotingPowers := [];
		upgradeConcilMembers := [];
		grantVoteSnapshots := TrieMap.fromEntries<Nat, GrantVoteSnapshot>(
			Iter.fromArray(upgradeGrantVoteSnapshots),
			Nat.equal,
			natHash,
		);
		upgradeGrantVoteSnapshots := [];
		treasuryCommitments := TrieMap.fromEntries<Nat, TreasuryCommitment>(
			Iter.fromArray(upgradeTreasuryCommitments),
			Nat.equal,
			natHash,
		);
		upgradeTreasuryCommitments := [];
		processedDonationBlocks := TrieMap.fromEntries<Nat64, Bool>(
			Iter.map<Nat64, (Nat64, Bool)>(
				Iter.fromArray(upgradeProcessedDonationBlocks),
				func(blockIndex) { (blockIndex, true) },
			),
			Nat64.equal,
			nat64Hash,
		);
		// Backfill immutable vote snapshots for grants that were already in
		// #voting before Governance V2 was introduced. Their original voting
		// startTime is used so donations made later do not enter the electorate.
		for (grant in grants.getGrants().vals()) {
			if (grant.grantStatus == #voting) {
				let grantId = Int.abs(grant.grantId);
				if (grantVoteSnapshots.get(grantId) == null) {
					switch (grant.votingStatus) {
						case (?status) {
							let baseSnapshot = buildGrantVoteSnapshotAt(status.startTime);
							grantVoteSnapshots.put(
								grantId,
								{
									baseSnapshot with
									eligibleVoters = [];
									eligibleVoterCount = votingPowers.size();
									totalVotingPower = _accumulated_voting_power;
									legacyRawWeighting = true;
								},
							);
						};
						case null {};
					};
				};
			};
		};

		// On the first upgrade that introduces the replay index, seed it from
		// historical confirmed donations already retained in voting power history.
		for ((_, power) in votingPowers.entries()) {
			for (change in power.powerHistory.vals()) {
				if (change.source.isConfirmed) {
					processedDonationBlocks.put(change.source.blockIndex, true);
				};
			};
		};
		upgradeProcessedDonationBlocks := [];
		donations := TrieMap.fromEntries<Nat64, Donation>(
			Iter.fromArray(upgradeDonations),
			Nat64.equal,
			nat64Hash,
		);
		upgradeDonations := [];
	};

	public shared ({ caller }) func updateExchangeRates(currency : Types.Currency, rate : Nat64) : async Result.Result<Nat, Text> {
		if (Principal.isAnonymous(caller)) {
			#err("no permission for anonymous caller to set exchange rate");
		} else if (not canManageConcilMembers(caller)) {
			#err("Only controllers or council members can set exchange rates");
		} else if (rate == 0) {
			#err("Exchange rate must be greater than zero");
		} else {
			let currencyText = currencyToText(currency);
			donorExchangeRates.put(currencyText, rate);
			#ok(1);
		};
	};

	public query func getExchangeRates() : async [(Text, Nat64)] {
		Iter.toArray(donorExchangeRates.entries());
	};

	public query func getTotalDonations() : async Nat64 {
		return _accumulated_donations;
	};

	public query func getTotalVotingPower() : async Nat64 {
		return currentGovernancePower();
	};

	public shared ({ caller }) func addConcilMember(member : Principal) : async Result.Result<Nat, Text> {
		if (Principal.isAnonymous(caller)) {
			#err("Anonymous users cannot add council members");
		} else if (not canManageConcilMembers(caller)) {
			#err("Only controller or council members can add new members");
		} else if (Principal.isAnonymous(member)) {
			#err("Cannot add anonymous principal as council member");
		} else if (isConcilMemberInternal(member)) {
			#err("Principal is already a council member");
		} else {
			concilMembers.put(member, true);
			#ok(1);
		};
	};

	public shared ({ caller }) func removeConcilMember(member : Principal) : async Result.Result<Nat, Text> {
		if (Principal.isAnonymous(caller)) {
			#err("Anonymous users cannot remove council members");
		} else if (not canManageConcilMembers(caller)) {
			#err("Only controller or council members can remove members");
		} else if (not isConcilMemberInternal(member)) {
			#err("Principal is not a council member");
		} else {
			ignore concilMembers.remove(member);
			#ok(1);
		};
	};

	public query func getConcilMembers() : async [Principal] {
		Iter.toArray(concilMembers.keys());
	};

	public query func isConcilMember(member : Principal) : async Bool {
		isConcilMemberInternal(member);
	};

	//---------------------------------------
	// Donations
	//---------------------------------------
	public shared ({ caller }) func donate(amount : Nat64, currency : Types.Currency, blockIndex : Nat64) : async Result.Result<Nat, Text> {
		if (Principal.isAnonymous(caller)) {
			#err("no permission for anonymous caller to donate");
		} else if (currency != #ICP) {
			#err("This donation verification path currently supports ICP only");
		} else if (amount == 0) {
			#err("Donation amount must be greater than zero");
		} else if (Option.isSome(processedDonationBlocks.get(blockIndex))) {
			#err("This block index has already been processed");
		} else {
			let tempDonation : Donation = {
				donorId = caller;
				amount = amount;
				currency = currency;
				timestamp = Time.now();
				blockIndex = blockIndex;
				isConfirmed = false;
			};

			switch (donations.get(blockIndex)) {
				case null {
					donations.put(blockIndex, tempDonation);
					#ok(1);
				};
				case (?pending) {
					if (pending.donorId == caller) {
						donations.put(blockIndex, tempDonation);
						#ok(1);
					} else {
						// Do not let an unverified pending record permanently squat
						// a ledger index. The authenticated caller may replace it,
						// but confirmation still succeeds only if the ledger sender
						// matches this caller and destination/amount checks pass.
						donations.put(blockIndex, tempDonation);
						#ok(1);
					};
				};
			};
		};
	};

	public shared ({ caller }) func confirmDonation(blockIndex : Nat64) : async Result.Result<Nat, Text> {
		if (Principal.isAnonymous(caller)) {
			return #err("Anonymous users cannot confirm donations");
		};
		switch (donations.get(blockIndex)) {
			case null { return #err("Donation not found") };
			case (?tempDonation) {
				if (tempDonation.donorId != caller) {
					return #err("Only the recorded donor can confirm this donation");
				};
				if (tempDonation.isConfirmed) {
					return #err("Donation already confirmed");
				};
				if (tempDonation.currency != #ICP) {
					return #err("This donation verification path currently supports ICP only");
				};

				let queryResult = await ICPLedger.query_blocks({
					start = blockIndex;
					length = 1;
				});
				if (queryResult.blocks.size() == 0) {
					return #err("Ledger block not found");
				};

				switch (queryResult.blocks[0].transaction.operation) {
					case (?#Transfer(transfer)) {
						if (transfer.amount.e8s != tempDonation.amount) {
							return #err("Amount mismatch");
						};

						let expectedFrom = await ICPLedger.account_identifier({
							owner = caller;
							subaccount = null;
						});
						if (not Blob.equal(transfer.from, expectedFrom)) {
							return #err("Donation sender does not match caller");
						};

						let expectedTo = await ICPLedger.account_identifier({
							owner = Principal.fromActor(Defunds);
							subaccount = null;
						});
						if (not Blob.equal(transfer.to, expectedTo)) {
							return #err("Donation was not sent to the Defunds treasury");
						};

						let currencyText = currencyToText(tempDonation.currency);
						let rate : Nat64 = switch (donorExchangeRates.get(currencyText)) {
							case (null) 1;
							case (?configuredRate) configuredRate;
						};

						// Validate all Nat64 arithmetic before marking the ledger block as
						// processed. A rejected overflow must remain retryable after policy
						// or accounting remediation.
						let maxNat64 : Nat = 18_446_744_073_709_551_615;
						let contributionScoreNat =
							Nat64.toNat(tempDonation.amount) * Nat64.toNat(rate);
						let newAccumulatedDonationsNat =
							Nat64.toNat(_accumulated_donations) + Nat64.toNat(tempDonation.amount);
						let newAvailableFundsNat =
							Nat64.toNat(_avaliable_funds) + Nat64.toNat(tempDonation.amount);
						let newAccumulatedScoreNat =
							Nat64.toNat(_accumulated_voting_power) + contributionScoreNat;
						if (
							contributionScoreNat > maxNat64 or
							newAccumulatedDonationsNat > maxNat64 or
							newAvailableFundsNat > maxNat64 or
							newAccumulatedScoreNat > maxNat64
						) {
							return #err("Donation would overflow Main Fund accounting");
						};

						switch (votingPowers.get(tempDonation.donorId)) {
							case null {};
							case (?existingPower) {
								if (
									Nat64.toNat(existingPower.totalPower) + contributionScoreNat >
									maxNat64
								) {
									return #err("Donation would overflow contributor score");
								};
							};
						};

						// All external awaits and arithmetic validation are complete. Re-check
						// and atomically mark the ledger block before mutating contribution
						// state so concurrent confirmations cannot credit it twice.
						if (Option.isSome(processedDonationBlocks.get(blockIndex))) {
							donations.delete(blockIndex);
							return #err("This block index has already been processed");
						};
						processedDonationBlocks.put(blockIndex, true);

						// totalPower remains a normalized cumulative contribution score.
						// Actual governance power is sqrt(totalPower), snapshotted per grant.
						let contributionScore = Nat64.fromNat(contributionScoreNat);
						_accumulated_donations := Nat64.fromNat(newAccumulatedDonationsNat);
						_avaliable_funds := Nat64.fromNat(newAvailableFundsNat);
						_accumulated_voting_power := Nat64.fromNat(newAccumulatedScoreNat);

						let donation : Donation = {
							donorId = tempDonation.donorId;
							amount = tempDonation.amount;
							currency = tempDonation.currency;
							timestamp = tempDonation.timestamp;
							blockIndex = blockIndex;
							isConfirmed = true;
						};

						let powerChange : PowerChange = {
							amount = contributionScore;
							timestamp = Time.now();
							source = donation;
						};

						switch (votingPowers.get(tempDonation.donorId)) {
							case null {
								votingPowers.put(
									tempDonation.donorId,
									{
										userId = tempDonation.donorId;
										totalPower = contributionScore;
										powerHistory = [powerChange];
									},
								);
							};
							case (?existingPower) {
								let updatedHistory = Buffer.fromArray<PowerChange>(existingPower.powerHistory);
								updatedHistory.add(powerChange);
								votingPowers.put(
									tempDonation.donorId,
									{
										userId = tempDonation.donorId;
										totalPower = existingPower.totalPower + contributionScore;
										powerHistory = Buffer.toArray(updatedHistory);
									},
								);
							};
						};
						donations.delete(blockIndex);
						#ok(1);
					};
					case (_) { #err("Ledger block is not an ICP transfer") };
				};
			};
		};
	};

	public query ({ caller }) func getMyDonations() : async [Donation] {
		let allDonations = Buffer.Buffer<Donation>(0);

		// Get confirmed donations from voting power history
		switch (votingPowers.get(caller)) {
			case (null) {};
			case (?power) {
				for (powerChange in power.powerHistory.vals()) {
					allDonations.add(powerChange.source);
				};
			};
		};

		// Get pending donations
		for ((_, donation) in donations.entries()) {
			if (donation.donorId == caller) {
				allDonations.add({
					donorId = donation.donorId;
					amount = donation.amount;
					currency = donation.currency;
					timestamp = donation.timestamp;
					blockIndex = donation.blockIndex;
					isConfirmed = donation.isConfirmed;
				});
			};
		};

		return Buffer.toArray(allDonations);
	};
	//---------------------------------------
	// Grant
	//---------------------------------------

	public shared ({ caller }) func applyGrant(application : NewGrant) : async Result.Result<Nat, Text> {
		if (Principal.isAnonymous(caller)) {
			#err("no permission for anonymous caller to apply grant");
		} else {
			let maxAllowedAmount = (_accumulated_donations * Nat64.fromNat(maxAmountPercentage)) / 100;
			if (application.amount > maxAllowedAmount) {
				#err("Requested amount exceeds maximum allowed amount");
			} else {
				grants.apply(caller, application);
				#ok(1);
			};
		};
	};

	public query func getGrants(status : [GrantTypes.Status], page : Nat) : async [Grant] {
		let pageSize = DEFAULT_PAGE_SIZE;

		var filteredGrants : [Grant] = [];
		// Filter grants by status
		if (status.size() == 0) {
			filteredGrants := grants.getGrants();
		} else {
			let bufferGrants = Buffer.Buffer<Grant>(0);
			for (s in status.vals()) {
				let statusGrants = grants.getGrantsByStatus(s);
				bufferGrants.append(Buffer.fromArray(statusGrants));
				filteredGrants := Buffer.toArray(bufferGrants);
			};
		};

		// let filteredGrants = Array.sort<Grant>(
		//     Buffer.toArray(bufferGrants),
		//     func(a : Grant, b : Grant) : Order.Order {
		//         Int.compare(b.submitime, a.submitime);
		//     },
		// );

		// Calculate pagination
		let startIndex = page * pageSize;
		let endIndex = Nat.min(startIndex + pageSize, filteredGrants.size());

		if (startIndex >= filteredGrants.size()) {
			return [];
		};

		Iter.toArray(Array.slice<Grant>(filteredGrants, startIndex, endIndex - startIndex));
	};

	public query func getGrant(grantId : Nat) : async ?Grant {
		grants.getGrant(grantId);
	};

	public query ({ caller }) func getMyGrants() : async [Grant] {
		let allGrants = grants.getGrants();

		// Filter grants where recipient matches caller
		Array.filter<Grant>(
			allGrants,
			func(grant : Grant) : Bool {
				grant.applicant == caller;
			},
		);
	};

	public query func getAllGrants() : async [Grant] {
		let allGrants = grants.getGrants();
		allGrants;
	};

	public shared ({ caller }) func cancelGrant(grantId : Nat) : async Result.Result<Nat, Text> {
		if (Principal.isAnonymous(caller)) {
			#err("Anonymous users cannot cancel grants");
		} else {
			switch (grants.getGrant(grantId)) {
				case null { #err("Grant not found") };
				case (?grant) {
					if (grant.applicant != caller) {
						#err("Only grant owner can cancel");
					} else {
						if (grants.changeGrantStatus(grantId, #cancelled)) {
							#ok(1);
						} else {
							#err("Failed to cancel grant");
						};
					};
				};
			};
		};
	};

	// Query available voting power
	public query func getVotingPower(userId : Principal) : async ?VotingPower {
		votingPowers.get(userId);
	};

	public query func getDonorCredit(donor : Text) : async ?Nat {
		return donorCredits.get(Principal.fromText(donor));
	};

	public query func getGrantVotingSnapshot(grantId : Nat) : async ?{
		eligibleVoterCount : Nat;
		totalVotingPower : Nat64;
		createdAt : Int;
		minVotePercentage : Nat;
		minPowerPercentage : Nat;
		approvalPercentage : Nat;
		legacyRawWeighting : Bool;
	} {
		switch (grantVoteSnapshots.get(grantId)) {
			case null { null };
			case (?snapshot) {
				?{
					eligibleVoterCount = snapshot.eligibleVoterCount;
					totalVotingPower = snapshot.totalVotingPower;
					createdAt = snapshot.createdAt;
					minVotePercentage = snapshot.minVotePercentage;
					minPowerPercentage = snapshot.minPowerPercentage;
					approvalPercentage = snapshot.approvalPercentage;
					legacyRawWeighting = snapshot.legacyRawWeighting;
				};
			};
		};
	};

	private func readMainFundIcpTreasuryState() : async {
		balance : Nat64;
		reserved : Nat64;
		available : Nat64;
	} {
		let treasuryAccount = await ICPLedger.account_identifier({
			owner = Principal.fromActor(Defunds);
			subaccount = null;
		});
		let versionBeforeBalance = treasuryMutationVersion;
		let liveBalance = await ICPLedger.account_balance({ account = treasuryAccount });
		if (treasuryMutationVersion != versionBeforeBalance) {
			return await readMainFundIcpTreasuryState();
		};
		let reservedNat = committedIcpLiability();
		let maxNat64 : Nat = 18_446_744_073_709_551_615;
		let cappedReservedNat = Nat.min(reservedNat, maxNat64);
		let reserved = Nat64.fromNat(cappedReservedNat);
		let available = if (reserved >= liveBalance.e8s) {
			0
		} else {
			liveBalance.e8s - reserved
		};
		{
			balance = liveBalance.e8s;
			reserved = reserved;
			available = available;
		};
	};

	public shared func getMainFundIcpTreasuryState() : async {
		balance : Nat64;
		reserved : Nat64;
		available : Nat64;
	} {
		await readMainFundIcpTreasuryState();
	};

	public query func getGrantTreasuryCommitment(grantId : Nat) : async ?TreasuryCommitment {
		treasuryCommitments.get(grantId);
	};

	public query func getTreasuryCommitments() : async [TreasuryCommitment] {
		Iter.toArray(treasuryCommitments.vals());
	};

	public shared ({ caller }) func commitApprovedGrant(grantId : Nat) : async Result.Result<TreasuryCommitment, Text> {
		if (Principal.isAnonymous(caller)) {
			return #err("Anonymous users cannot commit grant funds");
		};
		switch (grants.getGrant(grantId)) {
			case null { #err("Grant not found") };
			case (?grant) {
				await tryCommitApprovedGrant(grant);
			};
		};
	};

	public shared ({ caller }) func startReview(grantId : Nat) : async Result.Result<Nat, Text> {
		if (Principal.isAnonymous(caller)) {
			#err("Anonymous users cannot start review");
		} else if (Option.isNull(concilMembers.get(caller))) {
			#err("Only council members can start review");
		} else {
			if (grants.startReview(grantId)) {
				#ok(1);
			} else {
				#err("Failed to start review for grant");
			};
		};
	};

	// Update startGrantVoting with concilMember check
	public shared ({ caller }) func startGrantVoting(grantId : Nat) : async Result.Result<Nat, Text> {
		if (Principal.isAnonymous(caller)) {
			#err("Anonymous users cannot start voting");
		} else if (not canManageConcilMembers(caller)) {
			#err("Only controllers or council members can start voting");
		} else {
			let snapshot = buildGrantVoteSnapshot();
			if (snapshot.eligibleVoterCount == 0 or snapshot.totalVotingPower == 0) {
				return #err("No eligible contributors are available for voting");
			};
			if (grants.startVoting(grantId)) {
				grantVoteSnapshots.put(grantId, snapshot);
				#ok(1);
			} else {
				#err("Failed to start voting for grant");
			};
		};
	};

	public shared ({ caller }) func rejectGrant(grantId : Nat) : async Result.Result<Nat, Text> {
		if (Principal.isAnonymous(caller)) {
			#err("Anonymous users cannot reject grants");
		} else if (Option.isNull(concilMembers.get(caller))) {
			#err("Only council members can reject grants");
		} else {
			if (grants.changeGrantStatus(grantId, #rejected)) {
				#ok(1);
			} else {
				#err("Failed to reject grant");
			};
		};
	};

	// Cast vote on a grant
	public shared ({ caller }) func voteOnGrant(grantId : Nat, voteType : GrantTypes.VoteType) : async Result.Result<Nat, Text> {
		if (Principal.isAnonymous(caller)) {
			return #err("Anonymous users cannot vote");
		};

		switch (grantVoteSnapshots.get(grantId)) {
			case null {
				#err("Voting snapshot not found; restart voting for this grant");
			};
			case (?snapshot) {
				switch (snapshotVotingPower(snapshot, caller)) {
					case null {
						#err("Only contributors eligible when voting started may vote");
					};
					case (?votePowerAmount) {
						if (votePowerAmount == 0) {
							#err("Insufficient voting power");
						} else {
							let voteResult = grants.vote(grantId, caller, votePowerAmount, voteType);
							if (voteResult) {
								#ok(1);
							} else {
								#err("Vote could not be recorded");
							};
						};
					};
				};
			};
		};
	};
	// Finalize voting for a grant
	public shared ({ caller }) func finalizeGrantVoting(grantId : Nat) : async Result.Result<Nat, Text> {
		if (Principal.isAnonymous(caller)) {
			#err("Anonymous users cannot finalize voting");
		} else {
			switch (grantVoteSnapshots.get(grantId)) {
				case null { #err("Voting snapshot not found for this grant") };
				case (?snapshot) {
					switch (grants.getGrant(grantId)) {
						case null { #err("Grant not found") };
						case (?grant) {
							switch (grant.votingStatus) {
								case null { #err("No voting status found") };
								case (?status) {
									let voterCount = status.votes.size();
									let eligibleVoterCount = if (snapshot.legacyRawWeighting) {
										votingPowers.size()
									} else {
										snapshot.eligibleVoterCount
									};
									let eligibleVotingPower = if (snapshot.legacyRawWeighting) {
										_accumulated_voting_power
									} else {
										snapshot.totalVotingPower
									};

									if (voterCount * 100 < eligibleVoterCount * snapshot.minVotePercentage) {
										return #err("Insufficient voter participation");
									};

									if (
										status.totalVotePower * 100 <
										eligibleVotingPower * Nat64.fromNat(snapshot.minPowerPercentage)
									) {
										return #err("Insufficient voting power participation");
									};

									if (grants.finalizeVoting(grantId, snapshot.approvalPercentage)) {
										switch (grants.getGrant(grantId)) {
											case (?finalGrant) {
												if (finalGrant.grantStatus == #approved) {
													ignore await tryCommitApprovedGrant(finalGrant);
												};
											};
											case null {};
										};
										#ok(1);
									} else {
										#err("Failed to finalize voting");
									};
								};
							};
						};
					};
				};
			};
		};
	};

	public shared ({ caller }) func claimGrant(grantId : Nat) : async Result.Result<Nat64, Text> {
		if (Principal.isAnonymous(caller)) {
			return #err("Anonymous users cannot claim grants");
		};

		switch (grants.getGrant(grantId)) {
			case null { #err("Grant not found") };
			case (?grant) {
				if (grant.applicant != caller) {
					return #err("Only grant applicant can claim");
				};

				// A completed payout is idempotent even after the Grant has moved
				// from #approved to #released. This lets callers recover the ledger
				// receipt after a client timeout or lost response.
				switch (treasuryCommitments.get(grantId)) {
					case (?existing) {
						switch (existing.status) {
							case (#paid(blockIndex)) { return #ok(blockIndex) };
							case (_) {};
						};
					};
					case null {};
				};

				if (grant.grantStatus != #approved) {
					return #err("Grant must be approved to claim");
				};

				let commitment = switch (treasuryCommitments.get(grantId)) {
					case (?existing) {
						switch (existing.status) {
							case (#awaitingFunding) {
								switch (await tryCommitApprovedGrant(grant)) {
									case (#err(message)) { return #err(message) };
									case (#ok(updated)) { updated };
								};
							};
							case (_) { existing };
						};
					};
					case null {
						switch (await tryCommitApprovedGrant(grant)) {
							case (#err(message)) { return #err(message) };
							case (#ok(created)) { created };
						};
					};
				};

				switch (commitment.status) {
					case (#awaitingFunding) {
						return #err("Grant is approved but awaiting treasury funding");
					};
					case (#paid(blockIndex)) {
						return #ok(blockIndex);
					};
					case (#committed) {};
					case (#paying(_)) {};
					case (#reconciliationRequired(_)) {
						return #err("Payout requires ledger reconciliation before retry");
					};
				};

				switch (grant.currency) {
					case (#ICP) {
						if (not isValidIcpAccountIdentifier(grant.recipient)) {
							return #err("Invalid ICP recipient account identifier");
						};
						let payoutCreatedAt = switch (beginOrResumeIcpPayout(grantId)) {
							case (#ok(timestamp)) { timestamp };
							case (#err(message)) {
								if (Text.startsWith(message, #text("PAID:"))) {
									switch (treasuryCommitments.get(grantId)) {
										case (?paidCommitment) {
											switch (paidCommitment.status) {
												case (#paid(blockIndex)) { return #ok(blockIndex) };
												case (_) {};
											};
										};
										case null {};
									};
								};
								return #err(message);
							};
						};

						let transferArgs : ICPTypes.TransferArgs = {
							memo = Nat64.fromNat(grantId);
							amount = { e8s = grant.amount };
							fee = { e8s = ICP_FEE };
							from_subaccount = null;
							to = Blob.fromArray(Hex.decode(grant.recipient));
							created_at_time = ?{ timestamp_nanos = payoutCreatedAt };
						};

						try {
							let transferResult = await ICPLedger.transfer(transferArgs);
							switch (transferResult) {
								case (#Ok(blockIndex)) {
									if (not ensureGrantReleased(grantId)) {
										return #err("Transfer succeeded but grant status could not be reconciled");
									};
									markPaid(grantId, blockIndex);
									if (_avaliable_funds >= grant.amount) {
										_avaliable_funds -= grant.amount;
									};
									#ok(blockIndex);
								};
								case (#Err(#TxDuplicate({ duplicate_of }))) {
									if (not ensureGrantReleased(grantId)) {
										return #err("Transfer already succeeded but grant status could not be reconciled");
									};
									markPaid(grantId, duplicate_of);
									#ok(duplicate_of);
								};
								case (#Err(#InsufficientFunds(_))) {
									resetPayoutToCommitted(grantId, payoutCreatedAt);
									#err("Treasury ledger balance is insufficient; commitment remains reserved");
								};
								case (#Err(#BadFee(_))) {
									resetPayoutToCommitted(grantId, payoutCreatedAt);
									#err("Ledger fee changed; payout can be retried after fee configuration is updated");
								};
								case (#Err(#TxCreatedInFuture)) {
									resetPayoutToCommitted(grantId, payoutCreatedAt);
									#err("Ledger rejected payout timestamp as future; payout can be retried");
								};
								case (#Err(#TxTooOld(_))) {
									requirePayoutReconciliation(grantId, payoutCreatedAt);
									#err("Payout attempt is outside the ledger deduplication window and requires reconciliation");
								};
							};
						} catch (_) {
							requirePayoutReconciliation(grantId, payoutCreatedAt);
							#err("Payout result is uncertain; ledger reconciliation is required before retry");
						};
					};
					case (_) {
						#err("This currency is not yet enabled for committed Main Fund payout");
					};
				};
			};
		};
	};

	public shared ({ caller }) func reconcileIcpGrantPayout(
		grantId : Nat,
		paidBlockIndex : ?Nat64,
	) : async Result.Result<TreasuryCommitment, Text> {
		if (Principal.isAnonymous(caller)) {
			return #err("Anonymous users cannot reconcile payouts");
		};
		if (not canManageConcilMembers(caller)) {
			return #err("Only controllers or council members can reconcile payouts");
		};

		switch (treasuryCommitments.get(grantId)) {
			case null { #err("Treasury commitment not found") };
			case (?existing) {
				switch (existing.status) {
					case (#reconciliationRequired({ createdAt })) {
						switch (paidBlockIndex) {
							case (?blockIndex) {
								if (not ensureGrantReleased(grantId)) {
									return #err("Could not reconcile grant status to released");
								};
								markPaid(grantId, blockIndex);
							};
							case null {
								// Reconciliation is a privileged explicit decision that
								// the old attempt did not settle. Return it to committed
								// only if the same reconciliation attempt is still current.
								switch (treasuryCommitments.get(grantId)) {
									case (?current) {
										switch (current.status) {
											case (#reconciliationRequired({ createdAt = currentCreatedAt })) {
												if (currentCreatedAt == createdAt) {
													treasuryCommitments.put(
														grantId,
														{
															current with
															status = #committed;
															updatedAt = Time.now();
														},
													);
													bumpTreasuryVersion();
												};
											};
											case (_) {};
										};
									};
									case null {};
								};
							};
						};
						switch (treasuryCommitments.get(grantId)) {
							case (?updated) { #ok(updated) };
							case null { #err("Treasury commitment disappeared during reconciliation") };
						};
					};
					case (_) {
						#err("Payout is not awaiting reconciliation");
					};
				};
			};
		};
	};

	// Get voting status for a grant
	public query func getGrantVotingStatus(grantId : Nat) : async ?GrantTypes.VotingStatus {
		switch (grants.getGrant(grantId)) {
			case null { null };
			case (?grant) { grant.votingStatus };
		};
	};

	public shared ({ caller }) func addGrantComment(grantId : Nat, content : Text) : async Result.Result<Nat, Text> {
		if (Principal.isAnonymous(caller)) {
			#err("Anonymous users cannot comment");
		} else {
			let comment : GrantTypes.Comment = {
				authorId = caller;
				content = content;
				timestamp = Time.now();
			};

			if (grants.addComment(grantId, comment)) {
				#ok(1);
			} else {
				#err("Failed to add comment");
			};
		};
	};

	public query func getGrantComments(grantId : Nat) : async [GrantTypes.Comment] {
		switch (grants.getGrant(grantId)) {
			case null { [] };
			case (?grant) { grant.comments };
		};
	};

	//============================================================================================================
	// Group Management
	//============================================================================================================
	public shared ({ caller }) func createGroup(name : Text, description : Text, isPublic : Bool, currency : Types.Currency) : async Result.Result<GroupTypes.GroupFund, Text> {
		if (Principal.isAnonymous(caller)) {
			#err("Anonymous users cannot create groups");
		} else {
			switch (votingPowers.get(caller)) {
				case (null) {
					#err("User must have voting power to create groups");
				};
				case (?power) {
					if (power.totalPower == 0) {
						#err("Insufficient voting power to create groups");
					} else {
						let r = groups.createGroupFund(caller, name, description, isPublic, currency);
						#ok(r);
					};
				};
			};
		};
	};

	public shared ({ caller }) func addGroupMember(groupId : Nat, memberName : Text, memberPrincipal : Principal, votingPower : Nat) : async Result.Result<(), Text> {
		if (Principal.isAnonymous(caller)) {
			#err("Anonymous users cannot manage members");
		} else {
			switch (groups.getGroup(groupId)) {
				case null { #err("Group not found") };
				case (?group) {
					if (group.creator != caller) {
						#err("Only the fund creator can manage members");
					} else if (groups.hasActiveProposals(groupId)) {
						#err("Voting membership is frozen while a proposal is active");
					} else if (Principal.isAnonymous(memberPrincipal)) {
						#err("Cannot add anonymous principal as a fund member");
					} else {
						let member : GroupTypes.Member = {
							name = memberName;
							principal = memberPrincipal;
							votingPower = votingPower;
						};
						groups.addMember(groupId, member);
					};
				};
			};
		};
	};

	public shared ({ caller }) func removeGroupMember(groupId : Nat, memberPrincipal : Principal) : async Result.Result<(), Text> {
		if (Principal.isAnonymous(caller)) {
			#err("Anonymous users cannot manage members");
		} else {
			switch (groups.getGroup(groupId)) {
				case null { #err("Group not found") };
				case (?group) {
					if (group.creator != caller) {
						#err("Only the fund creator can manage members");
					} else if (memberPrincipal == group.creator) {
						#err("The fund creator cannot be removed");
					} else if (groups.hasActiveProposals(groupId)) {
						#err("Voting membership is frozen while a proposal is active");
					} else {
						groups.removeMember(groupId, memberPrincipal);
					};
				};
			};
		};
	};

	public shared ({ caller }) func updateGroup(groupId : Nat, name : Text, description : Text, isPublic : Bool) : async Result.Result<(), Text> {
		if (Principal.isAnonymous(caller)) {
			#err("Anonymous users cannot update groups");
		} else {
			groups.updateGroup(groupId, caller, name, description, isPublic);
		};
	};

	public shared ({ caller }) func updateGroupMemberVotingPower(groupId : Nat, memberPrincipal : Principal, votingPower : Nat) : async Result.Result<(), Text> {
		if (Principal.isAnonymous(caller)) {
			#err("Anonymous users cannot manage members");
		} else {
			switch (groups.getGroup(groupId)) {
				case null { #err("Group not found") };
				case (?group) {
					if (group.creator != caller) {
						#err("Only the fund creator can manage voting power");
					} else if (groups.hasActiveProposals(groupId)) {
						#err("Voting power is frozen while a proposal is active");
					} else if (memberPrincipal == group.creator and votingPower == 0) {
						#err("The fund creator must retain voting power");
					} else {
						groups.updateMemberVotingPower(groupId, memberPrincipal, votingPower);
					};
				};
			};
		};
	};

	public shared ({ caller }) func updateGroupMemberName(groupId : Nat, memberPrincipal : Principal, memberName : Text) : async Result.Result<(), Text> {
		if (Principal.isAnonymous(caller)) {
			#err("Anonymous users cannot manage members");
		} else {
			switch (groups.getGroup(groupId)) {
				case null { #err("Group not found") };
				case (?group) {
					if (group.creator != caller) {
						#err("Only the fund creator can manage member names");
					} else {
						groups.updateMemberName(groupId, memberPrincipal, memberName);
					};
				};
			};
		};
	};

	private func canReadGroup(caller : Principal, group : GroupTypes.GroupFund) : Bool {
		group.isPublic or (
			not Principal.isAnonymous(caller) and
			(group.creator == caller or groups.isMember(group.members, caller))
		)
	};

	// Group query methods. Public funds are inspectable by everyone; private
	// funds are visible only to their members.
	public query ({ caller }) func getGroup(groupId : Nat) : async ?GroupTypes.GroupFund {
		switch (groups.getGroup(groupId)) {
			case null { null };
			case (?group) {
				if (canReadGroup(caller, group)) { ?group } else { null };
			};
		};
	};

	public query ({ caller }) func getAllGroups() : async [GroupTypes.GroupFund] {
		Array.filter<GroupTypes.GroupFund>(
			groups.getAllGroups(),
			func(group : GroupTypes.GroupFund) : Bool { canReadGroup(caller, group) },
		);
	};

	public query func getPublicGroups() : async [GroupTypes.GroupFund] {
		groups.getPublicGroups();
	};

	public query ({ caller }) func getMyGroups() : async [GroupTypes.GroupFund] {
		if (Principal.isAnonymous(caller)) {
			[];
		} else {
			groups.getUserGroups(caller);
		};
	};

	// Proposal methods
	public shared ({ caller }) func createGroupProposal(groupId : Nat, title : Text, description : Text, recipient : Principal, amount : Nat) : async Result.Result<GroupTypes.GroupProposal, Text> {
		if (Principal.isAnonymous(caller)) {
			#err("Anonymous users cannot create proposals");
		} else {
			groups.createGroupProposal(caller, groupId, title, description, recipient, amount);
		};
	};

	public shared ({ caller }) func cancelGroupProposal(groupId : Nat, proposalId : Nat) : async Result.Result<(), Text> {
		if (Principal.isAnonymous(caller)) {
			#err("Anonymous users cannot close proposals");
		} else {
			groups.cancelGroupProposal(caller, groupId, proposalId);
		};
	};

	public shared ({ caller }) func voteOnProposal(groupId : Nat, proposalId : Nat, voteYes : Bool) : async Result.Result<(), Text> {
		if (Principal.isAnonymous(caller)) {
			#err("Anonymous users cannot vote");
		} else {
			await groups.vote(caller, groupId, proposalId, voteYes);
		};
	};

	public query ({ caller }) func getProposal(proposalId : Nat) : async ?GroupTypes.GroupProposal {
		switch (groups.getProposal(proposalId)) {
			case null { null };
			case (?proposal) {
				switch (groups.getGroup(proposal.groupId)) {
					case null { null };
					case (?group) {
						if (canReadGroup(caller, group)) { ?proposal } else { null };
					};
				};
			};
		};
	};

	public query ({ caller }) func getGroupProposals(groupId : Nat) : async [GroupTypes.GroupProposal] {
		switch (groups.getGroup(groupId)) {
			case null { [] };
			case (?group) {
				if (canReadGroup(caller, group)) {
					groups.getGroupProposals(groupId)
				} else {
					[]
				};
			};
		};
	};

	public query ({ caller }) func getAllProposals() : async [GroupTypes.GroupProposal] {
		Array.filter<GroupTypes.GroupProposal>(
			groups.getAllProposals(),
			func(proposal : GroupTypes.GroupProposal) : Bool {
				switch (groups.getGroup(proposal.groupId)) {
					case null { false };
					case (?group) { canReadGroup(caller, group) };
				};
			},
		);
	};

	public shared ({ caller }) func joinGroup(groupId : Nat) : async Result.Result<(), Text> {
		if (Principal.isAnonymous(caller)) {
			#err("Anonymous users cannot join groups");
		} else {
			groups.joinGroupFund(caller, groupId);
		};
	};

	//============================================================================================================
	// AI Agent Fund Management
	//============================================================================================================

	public shared ({ caller }) func createAIAgentFund(
		name : Text,
		description : Text,
		isPublic : Bool,
		strategy : GroupTypes.AIStrategy,
		riskTolerance : Nat,
		maxAllocationPct : Nat,
		autoApproveThreshold : Nat,
	) : async Result.Result<GroupTypes.AIAgentFund, Text> {
		if (Principal.isAnonymous(caller)) {
			return #err("Anonymous users cannot create AI Agent Funds");
		};
		if (riskTolerance < 1 or riskTolerance > 100) {
			return #err("riskTolerance must be between 1 and 100");
		};
		if (maxAllocationPct < 1 or maxAllocationPct > 100) {
			return #err("maxAllocationPct must be between 1 and 100");
		};
		if (autoApproveThreshold > 100) {
			return #err("autoApproveThreshold must be between 0 and 100");
		};
		let config : GroupTypes.AIAgentConfig = {
			strategy = strategy;
			riskTolerance = riskTolerance;
			maxAllocationPct = maxAllocationPct;
			autoApproveThreshold = autoApproveThreshold;
			enabled = true;
		};
		let aiFund = groups.createAIAgentFund(caller, name, description, isPublic, config);
		#ok(aiFund);
	};

	public shared ({ caller }) func setAIAgentConfig(
		groupId : Nat,
		strategy : GroupTypes.AIStrategy,
		riskTolerance : Nat,
		maxAllocationPct : Nat,
		autoApproveThreshold : Nat,
		enabled : Bool,
	) : async Result.Result<(), Text> {
		if (Principal.isAnonymous(caller)) {
			return #err("Anonymous users cannot update AI Agent configuration");
		};
		if (riskTolerance < 1 or riskTolerance > 100) {
			return #err("riskTolerance must be between 1 and 100");
		};
		if (maxAllocationPct < 1 or maxAllocationPct > 100) {
			return #err("maxAllocationPct must be between 1 and 100");
		};
		if (autoApproveThreshold > 100) {
			return #err("autoApproveThreshold must be between 0 and 100");
		};
		let config : GroupTypes.AIAgentConfig = {
			strategy = strategy;
			riskTolerance = riskTolerance;
			maxAllocationPct = maxAllocationPct;
			autoApproveThreshold = autoApproveThreshold;
			enabled = enabled;
		};
		groups.setAIAgentConfig(groupId, caller, config);
	};

	public shared ({ caller }) func runAIEvaluation(groupId : Nat) : async Result.Result<[GroupTypes.AIProposalEvaluation], Text> {
		if (Principal.isAnonymous(caller)) {
			return #err("Anonymous users cannot run AI evaluations");
		};
		groups.evaluateProposals(groupId, caller);
	};

	public query ({ caller }) func getAIAgentFund(groupId : Nat) : async ?GroupTypes.AIAgentFund {
		switch (groups.getAIAgentFund(groupId)) {
			case null { null };
			case (?fund) {
				if (canReadGroup(caller, fund.groupFund)) { ?fund } else { null };
			};
		};
	};

	public query ({ caller }) func getAllAIAgentFunds() : async [GroupTypes.AIAgentFund] {
		Array.filter<GroupTypes.AIAgentFund>(
			groups.getAllAIAgentFunds(),
			func(fund : GroupTypes.AIAgentFund) : Bool {
				canReadGroup(caller, fund.groupFund)
			},
		);
	};

	public query func getPublicAIAgentFunds() : async [GroupTypes.AIAgentFund] {
		groups.getPublicAIAgentFunds();
	};

	public query ({ caller }) func getMyAIAgentFunds() : async [GroupTypes.AIAgentFund] {
		if (Principal.isAnonymous(caller)) {
			[];
		} else {
			groups.getUserAIAgentFunds(caller);
		};
	};


	
};
