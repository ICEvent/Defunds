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
					switch (grant.grantStatus) {
						case (#submitted) {
							let updatedGrant = {
								grant with
								grantStatus = #review;
							};
							grants.put(grantId, updatedGrant);
							true;
						};
						case (_) { false };
					};
				};
			};
		};

		// Initialize voting for a grant
		public func startVoting(grantId : Nat) : Bool {
			switch (grants.get(grantId)) {
				case null { false };
				case (?grant) {
					let canStart = switch (grant.grantStatus) {
						case (#submitted) { true };
						case (#review) { true };
						case (_) { false };
					};
					if (not canStart) {
						false
					} else {
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

		// Finalize against the immutable policy snapshot enforced by the backend.
		// Quorum and eligible voting power are checked before this function is called.
		public func finalizeVoting(grantId : Nat, approvalPercentage : Nat) : Bool {
			switch (grants.get(grantId)) {
				case null { false };
				case (?grant) {
					switch (grant.votingStatus) {
						case null { false };
						case (?status) {
							if (Time.now() <= status.endTime) {
								return false;
							};

							let participatingPower = status.approvalVotePower + status.rejectVotePower;
							if (participatingPower == 0) {
								let updatedGrant = { grant with grantStatus = #rejected };
								grants.put(grantId, updatedGrant);
								return true;
							};

							let approved = (
								status.approvalVotePower * 100 >
								participatingPower * Nat64.fromNat(approvalPercentage)
							);

							let updatedGrant = {
								grant with
								grantStatus = if (approved) { #approved } else { #rejected };
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
					let allowed = switch (grant.grantStatus, newStatus) {
						case (#submitted, #cancelled) { true };
						case (#submitted, #rejected) { true };
						case (#review, #cancelled) { true };
						case (#review, #rejected) { true };
						case (#voting, #cancelled) { true };
						case (#voting, #rejected) { true };
						case (#approved, #released) { true };
						case (_) { false };
					};
					if (not allowed) {
						false
					} else {
						let updatedGrant = {
							grant with
							grantStatus = newStatus;
						};
						grants.put(grantId, updatedGrant);
						true;
					};
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
