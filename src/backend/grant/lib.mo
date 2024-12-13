import Types "types";
import Buffer "mo:base/Buffer";
import Time "mo:base/Time";
import Principal "mo:base/Principal";
import TrieMap "mo:base/TrieMap";
import Hash "mo:base/Hash";
import Nat "mo:base/Nat";
import Iter "mo:base/Iter";
import Text "mo:base/Text";

module {
	type Grant = Types.Grant;
	type NewGrant = Types.NewGrant;
	type Status = Types.Status;
	type Vote = Types.Vote;
	type VoteType = Types.VoteType;
	type VotingStatus = Types.VotingStatus;

	public class Grants(stableId : Nat, stableGrants : [(Nat,Grant)]) {
		private var nextGrantId = stableId;

		// Add this custom hash function
		private func natHash(n: Nat) : Hash.Hash {
			Text.hash(Nat.toText(n))
		};

		// Update the TrieMap initialization
		var grants = TrieMap.TrieMap<Nat, Grant>(Nat.equal, natHash);
		grants := TrieMap.fromEntries<Nat, Grant>(Iter.fromArray(stableGrants), Nat.equal, natHash);


		public func toStable() : [(Nat,Grant)] {
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
			};
			
			grants.put(nextGrantId,newGrant);
			nextGrantId += 1;
		};

		public func getGrant(grantId: Nat) : ?Grant {
			grants.get(grantId);
		};

		public func getGrants() : [Grant] {
			Iter.toArray(grants.vals());    
		};     

		// Initialize voting for a grant
		public func startVoting(grantId: Nat) : Bool {
			switch(grants.get(grantId)) {
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
						grantStatus = #review;
					};
					grants.put(grantId, updatedGrant);
					true
				};
			};
		};

		// Cast a vote on a grant
		public func vote(grantId: Nat, voter: Principal, votePower: Nat, voteType: VoteType) : Bool {
			switch(grants.get(grantId)) {
				case null { false };
				case (?grant) {
					switch(grant.votingStatus) {
						case null { false };
						case (?status) {
							if (Time.now() > status.endTime) { return false };

							let newVote : Vote = {
								voterId = voter;
								grantId = grantId;
								voteType = voteType;
								votePower = votePower;
								timestamp = Time.now();
							};

							let newVotes = Buffer.fromArray<Vote>(status.votes);
							newVotes.add(newVote);

							let newApprovalPower = switch(voteType) {
								case (#approve) { status.approvalVotePower + votePower };
								case (#reject) { status.approvalVotePower };
							};

							let newRejectPower = switch(voteType) {
								case (#approve) { status.rejectVotePower };
								case (#reject) { status.rejectVotePower + votePower };
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
							true
						};
					};
				};
			};
		};

		// Check if voting has ended and finalize the grant status
		public func finalizeVoting(grantId: Nat) : Bool {
			switch(grants.get(grantId)) {
				case null { false };
				case (?grant) {
					switch(grant.votingStatus) {
						case null { false };
						case (?status) {
							if (Time.now() <= status.endTime) { return false };

							let newStatus = if (status.approvalVotePower > status.rejectVotePower) {
								#approved;
							} else {
								#rejected;
							};

							let updatedGrant = {
								grant with
								grantStatus = newStatus;
							};
							grants.put(grantId, updatedGrant);
							true
						};
					};
				};
			};
		};
	};
};