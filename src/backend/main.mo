import Types "types";
import Nat "mo:base/Nat";
import Int "mo:base/Int";
import Array "mo:base/Array";
import Text "mo:base/Text";
import Iter "mo:base/Iter";
import Time "mo:base/Time";
import Order "mo:base/Order";
import Buffer "mo:base/Buffer";
import Result "mo:base/Result";
import Nat64 "mo:base/Nat64";
import Option "mo:base/Option";
import Hash "mo:base/Hash";

import Principal "mo:base/Principal";
import TrieMap "mo:base/TrieMap";

import ICPTypes "./icptypes";
import GrantTypes "./grant/types";
import Grants "./grant";

actor {

	type Donation = Types.Donation;
	type VotingPower = Types.VotingPower;
	type PowerChange = Types.PowerChange;

	type Grant = GrantTypes.Grant;
	type NewGrant = GrantTypes.NewGrant;

	stable var _stable_grantId = 1; // Unique ID for each grant
	stable var _accumulated_donations : Nat64 = 0; // Accumulated donations
	stable var _avaliable_funds : Nat64 = 0; // Total Available donations
	stable var _accumulated_voting_power : Nat64 = 0; // Accumulated voting power

	stable var upgradeCredits : [(Principal, Nat)] = [];
	stable var upgradeExchangeRates : [(Text, Nat64)] = [];
	stable var _stable_grants : [(Nat, Grant)] = [];
	stable var upgradeDonations : [(Nat64, Donation)] = [];
	let nat64Hash = func(n : Nat64) : Hash.Hash {
		Text.hash(Nat64.toText(n));
	};

	var donations = TrieMap.TrieMap<Nat64, Donation>(Nat64.equal, nat64Hash);

	stable var upgradeConcilMembers : [Principal] = [];
	var concilMembers = TrieMap.TrieMap<Principal, Bool>(Principal.equal, Principal.hash);
	concilMembers := TrieMap.fromEntries<Principal, Bool>(Iter.map<Principal, (Principal, Bool)>(Iter.fromArray(upgradeConcilMembers), func(p) { (p, true) }), Principal.equal, Principal.hash);

	stable var DEFAULT_PAGE_SIZE = 50;

	let grants = Grants.Grants(_stable_grantId, _stable_grants);

	let ICPLedger : actor {
		query_blocks : shared query ICPTypes.GetBlocksArgs -> async ICPTypes.QueryBlocksResponse;
		transfer : shared ICPTypes.TransferArgs -> async ICPTypes.Result_6;
		account_balance : shared query ICPTypes.BinaryAccountBalanceArgs -> async ICPTypes.Tokens;

	} = actor "ryjl3-tyaaa-aaaaa-aaaba-cai";

	var donorCredits = TrieMap.TrieMap<Principal, Nat>(Principal.equal, Principal.hash);
	donorCredits := TrieMap.fromEntries<Principal, Nat>(Iter.fromArray(upgradeCredits), Principal.equal, Principal.hash);
	var donorExchangeRates = TrieMap.TrieMap<Text, Nat64>(Text.equal, Text.hash);
	donorExchangeRates := TrieMap.fromEntries<Text, Nat64>(Iter.fromArray(upgradeExchangeRates), Text.equal, Text.hash);

	// Add these state variables
	stable var upgradeVotingPowers : [(Principal, VotingPower)] = [];
	var votingPowers = TrieMap.TrieMap<Principal, VotingPower>(Principal.equal, Principal.hash);
	votingPowers := TrieMap.fromEntries<Principal, VotingPower>(Iter.fromArray(upgradeVotingPowers), Principal.equal, Principal.hash);

	private func currencyToText(currency : Types.Currency) : Text {
		switch (currency) {
			case (#ICP) { "ICP" };
			case (#ckBTC) { "ckBTC" };
			case (#ckETH) { "ckETH" };
			case (#ckUSDC) { "ckUSDC" };
		};
	};
	stable var minVotePercentage : Nat = 50; // 50% of total donors must vote
	stable var minPowerPercentage : Nat = 50; // 50% of total voting power required
	stable var maxAmountPercentage : Nat = 5; // 5% of total funds maximum
	public shared ({ caller }) func updateVotingPolicy(
		newMinVote : Nat,
		newMinPower : Nat,
		newMaxAmount : Nat,
	) : async Result.Result<Nat, Text> {
		if (Principal.isAnonymous(caller)) {
			#err("Anonymous users cannot update policy");
		} else if (Option.isNull(concilMembers.get(caller))) {
			#err("Only council members can update policy");
		} else {
			minVotePercentage := newMinVote;
			minPowerPercentage := newMinPower;
			maxAmountPercentage := newMaxAmount;
			#ok(1);
		};
	};

	public query func getVotingPolicy() : async (Nat, Nat, Nat) {
		(minVotePercentage, minPowerPercentage, maxAmountPercentage);
	};

	system func preupgrade() {
		upgradeCredits := Iter.toArray(donorCredits.entries());
		upgradeExchangeRates := Iter.toArray(donorExchangeRates.entries());
		upgradeDonations := Iter.toArray(donations.entries());

		_stable_grants := grants.toStable();
		_stable_grantId := grants.getNextGrantId();
		upgradeVotingPowers := Iter.toArray(votingPowers.entries());
		upgradeConcilMembers := Iter.toArray(Iter.map<(Principal, Bool), Principal>(concilMembers.entries(), func((p, _)) { p }));
	};

	system func postupgrade() {
		upgradeCredits := [];
		upgradeExchangeRates := [];
		upgradeVotingPowers := [];
		upgradeConcilMembers := [];
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
		return _accumulated_voting_power;
	};

	public shared ({ caller }) func addConcilMember(member : Principal) : async Result.Result<Nat, Text> {
		if (Principal.isAnonymous(caller)) {
			#err("Anonymous users cannot add council members");
		} else if (Option.isNull(concilMembers.get(caller))) {
			#err("Only controller or council members can add new members");
		} else {
			concilMembers.put(member, true);
			#ok(1);
		};
	};

	//---------------------------------------
	// Donations
	//---------------------------------------
	public shared ({ caller }) func donate(amount : Nat64, currency : Types.Currency, blockIndex : Nat64) : async Result.Result<Nat, Text> {
		if (Principal.isAnonymous(caller)) {
			#err("no permission for anonymous caller to donate");
		} else {
			switch (donations.get(blockIndex)) {
				case (?donation) {
					return #err("This block index has already been processed");
				};
				case null {
					let tempDonation : Donation = {
						donorId = caller;
						amount = amount;
						currency = currency;
						timestamp = Time.now();
						blockIndex = blockIndex;
						isConfirmed = false;
					};

					donations.put(blockIndex, tempDonation);
					return #ok(1);
				};
			};
		};
	};

	public shared ({ caller }) func confirmDonation(blockIndex : Nat64) : async Result.Result<Nat, Text> {
		switch (donations.get(blockIndex)) {
			case null { return #err("Donation not found") };
			case (?tempDonation) {
				if (tempDonation.isConfirmed) {
					return #err("Donation already confirmed");
				};

				let queryResult = await ICPLedger.query_blocks({
					start = blockIndex;
					length = 1;
				});

				switch (queryResult.blocks[0].transaction.operation) {
					case (? #Transfer(transfer)) {
						if (transfer.amount.e8s != tempDonation.amount) {
							return #err("Amount mismatch");
						};

						//TODO: verify owner
						// if (Principal.fromBlob(transfer.from) != caller) {
						// 	return #err("Caller does not match transaction sender");
						// };

						let currencyText = currencyToText(tempDonation.currency);
						let rate : Nat64 = switch (donorExchangeRates.get(currencyText)) {
							case (null) 1;
							case (?rate) rate;
						};

						let votePowerAmount : Nat64 = tempDonation.amount * rate;
						_accumulated_donations += tempDonation.amount;
						_avaliable_funds += tempDonation.amount;
						_accumulated_voting_power += votePowerAmount;

						let donation : Donation = {
							donorId = tempDonation.donorId;
							amount = tempDonation.amount;
							currency = tempDonation.currency;
							timestamp = tempDonation.timestamp;
							blockIndex = blockIndex;
							isConfirmed = true;
						};

						let powerChange : PowerChange = {
							amount = votePowerAmount;
							timestamp = Time.now();
							source = donation;
						};

						// Update voting power
						switch (votingPowers.get(tempDonation.donorId)) {
							case (null) {
								votingPowers.put(
									tempDonation.donorId,
									{
										userId = tempDonation.donorId;
										totalPower = votePowerAmount;
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
										totalPower = existingPower.totalPower + votePowerAmount;
										powerHistory = Buffer.toArray(updatedHistory);
									},
								);
							};
						};
						donations.delete(blockIndex);
						#ok(1);
					};
					case (_) { #err("Invalid transaction type") };

				};
			};
		};
	};
	
		public query ({ caller }) func getMyDonations() : async [Donation] {
			let allDonations = Buffer.Buffer<Donation>(0);
	
			// Get confirmed donations from voting power history
			switch (votingPowers.get(caller)) {
				case (null) { };
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
		} else if (Option.isNull(concilMembers.get(caller))) {
			#err("Only council members can start voting");
		} else {
			if (grants.startVoting(grantId)) {
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

		// First check and deduct voting power
		switch (votingPowers.get(caller)) {
			case (null) {
				return #err("User does not have voting power");
			};
			case (?power) {
				let votePowerAmount = power.totalPower;
				if (votePowerAmount == 0) {
					#err("Insufficient voting power");
				} else {
					let voteResult = grants.vote(grantId, caller, votePowerAmount, voteType);
					if (voteResult) {
						#ok(1);
					} else {
						#err("Insufficient voting power");
					};
				};

			};
		}

	};
	// Finalize voting for a grant
	public shared ({ caller }) func finalizeGrantVoting(grantId : Nat) : async Result.Result<Nat, Text> {
		if (Principal.isAnonymous(caller)) {
			#err("Anonymous users cannot finalize voting");
		} else {
			let totalFund = _accumulated_donations;
			let totalDonors = votingPowers.size();
			let totalVotingPower = _accumulated_voting_power;

			switch (grants.getGrant(grantId)) {
				case null { #err("Grant not found") };
				case (?grant) {
					switch (grant.votingStatus) {
						case null { #err("No voting status found") };
						case (?status) {
							let voterCount = status.votes.size();
							if (voterCount * 100 < totalDonors * minVotePercentage) {
								return #err("Insufficient voter participation");
							};

							if (status.totalVotePower * 100 < totalVotingPower * Nat64.fromNat(minPowerPercentage)) {
								return #err("Insufficient voting power participation");
							};

							if (grants.finalizeVoting(grantId, totalFund, Nat64.fromNat(totalDonors), totalVotingPower)) {
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

	public shared ({ caller }) func claimGrant(grantId : Nat) : async Result.Result<Nat64, Text> {
		if (Principal.isAnonymous(caller)) {
			#err("Anonymous users cannot claim grants");
		} else {
			switch (grants.getGrant(grantId)) {
				case null { #err("Grant not found") };
				case (?grant) {
					if (grant.applicant != caller) {
						#err("Only grant applicant can claim");
					} else if (grant.grantStatus != #approved) {
						#err("Grant must be approved to claim");
					} else {
						// Transfer funds to recipient
						let transferArgs : ICPTypes.TransferArgs = {
							memo = 0;
							amount = { e8s = grant.amount };
							fee = { e8s = 10_000 };
							from_subaccount = null;
							to = Text.encodeUtf8(grant.recipient);
							created_at_time = null;
						};

						try {
							let transferResult = await ICPLedger.transfer(transferArgs);
							switch (transferResult) {
								case (#Ok(blockIndex)) {
									ignore grants.changeGrantStatus(grantId, #released);
									_avaliable_funds -= grant.amount;
									#ok(blockIndex);
								};
								case (#Err(error)) {
									#err("Transfer failed");
								};
							};
						} catch (error) {
							#err("Transfer error");
						};
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
};
