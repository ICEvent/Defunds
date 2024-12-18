import Types "types";
import Buffer "mo:base/Buffer";
import Time "mo:base/Time";
import Principal "mo:base/Principal";
import TrieMap "mo:base/TrieMap";
import Hash "mo:base/Hash";
import Nat "mo:base/Nat";
import Nat64 "mo:base/Nat64";
import Iter "mo:base/Iter";
import Text "mo:base/Text";
import Array "mo:base/Array";

module {
	type Grant = Types.Grant;
	type NewGrant = Types.NewGrant;
	type Status = Types.Status;
	type Vote = Types.Vote;
	type VoteType = Types.VoteType;
	type VotingStatus = Types.VotingStatus;

	public class Grants(stableId : Nat, stableGrants : [(Nat, Grant)]) {
		private var nextGrantId = stableId;

		// Add this custom hash function
		private func natHash(n : Nat) : Hash.Hash {
			Text.hash(Nat.toText(n));
		};

		// Update the TrieMap initialization
		var grants = TrieMap.TrieMap<Nat, Grant>(Nat.equal, natHash);
		grants := TrieMap.fromEntries<Nat, Grant>(Iter.fromArray(stableGrants), Nat.equal, natHash);

		public func toStable() : [(Nat, Grant)] {
			Iter.toArray(grants.entries());
		};

		public func getNextGrantId() : Nat {
			nextGrantId;
		};

		public func apply(applicant : Principal, grant : NewGrant) {
			let newGrant : Grant = {
				grantId = nextGrantId;
				submitime = Time.now();
				title = grant.title;
				description = grant.description;
				recipient = grant.recipient;
				applicant = applicant;
				amount = grant.amount;
				currency = grant.currency;
				grantStatus = #submitted;
				category = grant.category;
				proofs = grant.proofs;
				votingStatus = null;
				comments = [];
			};

			grants.put(nextGrantId, newGrant);
			nextGrantId += 1;
		};

		public func getGrant(grantId : Nat) : ?Grant {
			grants.get(grantId);
		};

		public func getGrants() : [Grant] {
			Iter.toArray(grants.vals());
		};

		public func getGrantsByStatus(status : Status) : [Grant] {
			let allGrants = Iter.toArray(grants.vals());

			Array.filter<Grant>(
				allGrants,
				func(grant : Grant) : Bool {
					switch (grant.grantStatus, status) {
						case (#review, #review) { true };
						case (#submitted, #submitted) { true };
						case (#voting, #voting) { true };
						case (#approved, #approved) { true };
						case (#rejected, #rejected) { true };
						case (#cancelled, #cancelled) { true };
						case (#expired, #expired) { true };
						case _ { false };
					};
				},
			);
		};

		public func startReview(grantId : Nat) : Bool {
			switch (grants.get(grantId)) {
				case null { false };
				case (?grant) {
					let updatedGrant = {
						grant with
						grantStatus = #review;
					};
					grants.put(grantId, updatedGrant);
					true;
				};
			};
		};

		// Initialize voting for a grant
		public func startVoting(grantId : Nat) : Bool {
			switch (grants.get(grantId)) {
				case null { false };
				case (?grant) {
					let votingStatus : VotingStatus = {
						totalVotePower = 0;
						approvalVotePower = 0;
						rejectVotePower = 0;
						votes = [];
						startTime = Time.now();
						endTime = Time.now() + 7 * 24 * 60 * 60 * 1_000_000_000; // 7 days in nanoseconds
					};

					let updatedGrant = {
						grant with
						votingStatus = ?votingStatus;
						grantStatus = #voting;
					};
					grants.put(grantId, updatedGrant);
					true;
				};
			};
		};

		// Cast a vote on a grant
		public func vote(grantId : Nat, voter : Principal, votePower : Nat64, voteType : VoteType) : Bool {
			switch (grants.get(grantId)) {
				case null { false };
				case (?grant) {
					switch (grant.votingStatus) {
						case null { false };
						case (?status) {
							// Check if voting has ended
							if (Time.now() > status.endTime) { return false };
							// Check if the voter has already voted
							let hasVoted = Array.find<Vote>(
								status.votes,
								func(vote : Vote) : Bool {
									vote.voterId == voter;
								},
							);
							switch (hasVoted) {
								case (?_) { return false };
								case null {
									// Check if the voter has enough voting power
									let newVote : Vote = {
										voterId = voter;
										grantId = grantId;
										voteType = voteType;
										votePower = votePower;
										timestamp = Time.now();
									};

									let newVotes = Buffer.fromArray<Vote>(status.votes);
									newVotes.add(newVote);

									let newApprovalPower = switch (voteType) {
										case (#approve) {
											status.approvalVotePower + votePower;
										};
										case (#reject) {
											status.approvalVotePower;
										};
									};

									let newRejectPower = switch (voteType) {
										case (#approve) {
											status.rejectVotePower;
										};
										case (#reject) {
											status.rejectVotePower + votePower;
										};
									};

									let newStatus : VotingStatus = {
										totalVotePower = status.totalVotePower + votePower;
										approvalVotePower = newApprovalPower;
										rejectVotePower = newRejectPower;
										votes = Buffer.toArray(newVotes);
										startTime = status.startTime;
										endTime = status.endTime;
									};

									let updatedGrant = {
										grant with
										votingStatus = ?newStatus;
									};
									grants.put(grantId, updatedGrant);
									true;
								};
							};
						};
					};
				};
			};
		};

		public func calculateMinVotes(grantAmount : Nat64, totalFund : Nat64, totalDonors : Nat64) : Nat64 {
			let ratio = grantAmount / totalFund;
			let minVotes = (ratio * totalDonors) + 1;
			minVotes;
		};
		public func calculateMinVotingPower(grantAmount : Nat64, totalFund : Nat64, totalVotingPower : Nat64) : Nat64 {
			let ratio = grantAmount / totalFund;
			let minPower = (ratio * totalVotingPower) + 1;
			minPower;
		};
		// Check if voting has ended and finalize the grant status
		public func finalizeVoting(grantId : Nat, totalFund : Nat64, totalDonors : Nat64, totalVotingPower : Nat64) : Bool {
			switch (grants.get(grantId)) {
				case null { false };
				case (?grant) {
					switch (grant.votingStatus) {
						case null { false };
						case (?status) {
							//check if voting has ended
							if (Time.now() <= status.endTime) { return false };

							//check minimal requirement: votes and voting power
							let totalVotes = status.votes.size();
							let totalPower = status.approvalVotePower + status.rejectVotePower;
							let requiredVotes = calculateMinVotes(grant.amount, totalFund, totalDonors);
							let requiredPower = calculateMinVotingPower(grant.amount, totalFund, totalVotingPower);

							if (Nat64.fromNat(totalVotes) < requiredVotes or totalPower < requiredPower) {
								let updatedGrant = {
									grant with
									grantStatus = #rejected
								};
								grants.put(grantId, updatedGrant);
								return true;
							};

							//check if the grant is approved or rejected
							let newStatus = if (status.approvalVotePower > status.rejectVotePower) {
								#approved;
							} else {
								#rejected;
							};

							let updatedGrant = {
								grant with
								grantStatus = newStatus
							};
							grants.put(grantId, updatedGrant);
							true;

						};
					};
				};
			};
		};

		public func changeGrantStatus(grantId : Nat, newStatus : Status) : Bool {
			switch (grants.get(grantId)) {
				case null { false };
				case (?grant) {
					let updatedGrant = {
						grant with
						grantStatus = newStatus;
					};
					grants.put(grantId, updatedGrant);
					true;
				};
			};
		};
		public func addComment(grantId : Nat, comment : Types.Comment) : Bool {
			switch (grants.get(grantId)) {
				case null { false };
				case (?grant) {
					let newComments = Buffer.fromArray<Types.Comment>(grant.comments);
					newComments.add(comment);

					let updatedGrant = {
						grant with
						comments = Buffer.toArray(newComments);
					};
					grants.put(grantId, updatedGrant);
					true;
				};
			};
		};

		public func getComments(grantId : Nat) : [Types.Comment] {
			switch (grants.get(grantId)) {
				case null { [] };
				case (?grant) { grant.comments };
			};
		};
	};

};
