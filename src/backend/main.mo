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

	stable var pendingAmount = 0; // Amount of pending donations
	stable var grantedAmount = 0; // Amount of granted donations
	stable var _stable_grantId = 1; // Unique ID for each grant
	stable var _accumulated_donations : Nat64 = 0; // Accumulated donations -- total voting power
	stable var _accumulated_voting_power : Nat64 = 0; // Accumulated voting power

	stable var upgradeCredits : [(Principal, Nat)] = [];
	stable var upgradeExchangeRates : [(Text, Nat64)] = [];
	stable var _stable_grants : [(Nat, Grant)] = [];

	stable var upgradeConcilMembers : [Principal] = [];
	var concilMembers = TrieMap.TrieMap<Principal, Bool>(Principal.equal, Principal.hash);
	concilMembers := TrieMap.fromEntries<Principal, Bool>(Iter.map<Principal, (Principal, Bool)>(Iter.fromArray(upgradeConcilMembers), func(p) { (p, true) }), Principal.equal, Principal.hash);

	stable var DEFAULT_PAGE_SIZE = 50;

	let grants = Grants.Grants(_stable_grantId, _stable_grants);

	let ICPLedger : actor {
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

	system func preupgrade() {
		upgradeCredits := Iter.toArray(donorCredits.entries());
		upgradeExchangeRates := Iter.toArray(donorExchangeRates.entries());
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
	public shared ({ caller }) func donate(amount : Nat64, currency : Types.Currency, txid : Text) : async Result.Result<Nat, Text> {
		if (Principal.isAnonymous(caller)) {
			#err("no permission for anonymous caller to donate");
		} else {
			let currencyText = currencyToText(currency);
			let rate : Nat64 = switch (donorExchangeRates.get(currencyText)) {
				case (null) 1;
				case (?rate) rate;
			};

			let votePowerAmount : Nat64 = amount * rate;
			//update global totoal voting power
			_accumulated_donations += amount;
			_accumulated_voting_power += votePowerAmount;

			//TODO: transfer to treasury

			let donation : Donation = {
				donorId = caller;
				amount = amount;
				currency = currency;
				timestamp = Time.now();
				txid = txid;
			};

			let powerChange : PowerChange = {
				amount = votePowerAmount;
				timestamp = Time.now();
				source = donation;
			};

			// Update voting power
			switch (votingPowers.get(caller)) {
				case (null) {
					let newVotingPower : VotingPower = {
						userId = caller;
						totalPower = votePowerAmount;
						powerHistory = [powerChange];
					};
					votingPowers.put(caller, newVotingPower);
				};
				case (?existingPower) {
					let updatedHistory = Buffer.fromArray<PowerChange>(existingPower.powerHistory);
					updatedHistory.add(powerChange);

					let updatedPower : VotingPower = {
						userId = caller;
						totalPower = existingPower.totalPower + votePowerAmount;
						powerHistory = Buffer.toArray(updatedHistory);
					};
					votingPowers.put(caller, updatedPower);
				};
			};

			#ok(1);
		};
	};

	public query ({ caller }) func getMyDonations() : async [Donation] {
		switch (votingPowers.get(caller)) {
			case (null) { [] };
			case (?power) {
				let myDonations = Buffer.Buffer<Donation>(0);
				for (powerChange in power.powerHistory.vals()) {

					myDonations.add(powerChange.source);

				};
				Buffer.toArray(myDonations);
			};
		};
	};

	//---------------------------------------
	// Grant
	//---------------------------------------

	public shared ({ caller }) func applyGrant(application : NewGrant) : async Result.Result<Nat, Text> {
		if (Principal.isAnonymous(caller)) {
			#err("no permission for anonymous caller to apply grant");
		} else {
			grants.apply(caller, application);
			#ok(1);
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
			//grantId : Nat, totalFund : Nat, totalDonors : Nat, totalVotingPower : Nat
			let totalFund = _accumulated_donations;
			let totalDonors = votingPowers.size();
			let totalVotingPower = _accumulated_voting_power;

			if (grants.finalizeVoting(grantId, totalFund, Nat64.fromNat(totalDonors), totalVotingPower)) {
				#ok(1);
			} else {
				#err("Failed to finalize voting");
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
