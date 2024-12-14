import Types "types";
import Nat "mo:base/Nat";
import Array "mo:base/Array";
import Text "mo:base/Text";
import Iter "mo:base/Iter";
import Time "mo:base/Time";
import Order "mo:base/Order";
import Buffer "mo:base/Buffer";
import Result "mo:base/Result";

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
	stable var _accumulated_donations = 0; // Accumulated donations -- total voting power

	stable var upgradeCredits : [(Principal, Nat)] = [];
	stable var upgradeExchangeRates : [(Text, Nat)] = [];
	stable var _stable_grants : [(Nat, Grant)] = [];

	stable var DEFAULT_PAGE_SIZE = 50;

	let grants = Grants.Grants(_stable_grantId, _stable_grants);

	let ICPLedger : actor {
		transfer : shared ICPTypes.TransferArgs -> async ICPTypes.Result_6;
		account_balance : shared query ICPTypes.BinaryAccountBalanceArgs -> async ICPTypes.Tokens;

	} = actor "ryjl3-tyaaa-aaaaa-aaaba-cai";

	var donorCredits = TrieMap.TrieMap<Principal, Nat>(Principal.equal, Principal.hash);
	donorCredits := TrieMap.fromEntries<Principal, Nat>(Iter.fromArray(upgradeCredits), Principal.equal, Principal.hash);
	var donorExchangeRates = TrieMap.TrieMap<Text, Nat>(Text.equal, Text.hash);
	donorExchangeRates := TrieMap.fromEntries<Text, Nat>(Iter.fromArray(upgradeExchangeRates), Text.equal, Text.hash);

	// Add these state variables
	stable var upgradeVotingPowers : [(Principal, VotingPower)] = [];
	var votingPowers = TrieMap.TrieMap<Principal, VotingPower>(Principal.equal, Principal.hash);

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
	};

	system func postupgrade() {
		upgradeCredits := [];
		upgradeExchangeRates := [];
		upgradeVotingPowers := [];
	};

	public shared ({ caller }) func updateExchangeRates(currency : Types.Currency, rate : Nat) : async Result.Result<Nat, Text> {
		if (Principal.isAnonymous(caller)) {
			#err("no permission for anonymous caller to set exchange rate");
		} else {
			let currencyText = currencyToText(currency);
			donorExchangeRates.put(currencyText, rate);
			#ok(1);
		};
	};

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
		let allGrants = grants.getGrants();

		// Filter grants by status
		let filteredGrants = Array.filter<Grant>(
			allGrants,
			func(grant : Grant) : Bool {
				if (status.size() == 0) {
					return true; // Return all if no status filter
				};
				for (s in status.vals()) {
					if (grant.grantStatus == s) {
						return true;
					};
				};
				false;
			},
		);

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

	// New function to collect voting power from donations
	public shared ({ caller }) func donate(amount : Nat, currency : Types.Currency, txid : Text) : async Result.Result<Nat, Text> {
		if (Principal.isAnonymous(caller)) {
			#err("no permission for anonymous caller to donate");
		} else {
			let currencyText = currencyToText(currency);
			let rate = switch (donorExchangeRates.get(currencyText)) {
				case (null) 0;
				case (?rate) rate;
			};

			let votePowerAmount = amount * rate;
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

	// Query available voting power
	public query func getVotingPower(userId : Principal) : async ?VotingPower {
		votingPowers.get(userId);
	};

	public query func getDonorCredit(donor : Text) : async ?Nat {
		return donorCredits.get(Principal.fromText(donor));
	};

	// Start voting period for a grant
	public shared ({ caller }) func startGrantVoting(grantId : Nat) : async Result.Result<Nat, Text> {
		if (Principal.isAnonymous(caller)) {
			#err("Anonymous users cannot start voting");
		} else {
			if (grants.startVoting(grantId)) {
				#ok(1);
			} else {
				#err("Failed to start voting for grant");
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
				let voteResult = grants.vote(grantId, caller, votePowerAmount, voteType);
				if (voteResult) {
					#ok(1);
				} else {
					#err("Insufficient voting power");
				};
			};
		}

	};
	// Finalize voting for a grant
	public shared ({ caller }) func finalizeGrantVoting(grantId : Nat) : async Result.Result<Nat, Text> {
		if (Principal.isAnonymous(caller)) {
			#err("Anonymous users cannot finalize voting");
		} else {
			if (grants.finalizeVoting(grantId)) {
				#ok(1);
			} else {
				#err("Failed to finalize voting");
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
