import Types "types";
import Buffer "mo:base/Buffer";
import Time "mo:base/Time";
import Principal "mo:base/Principal";
import TrieMap "mo:base/TrieMap";
import Hash "mo:base/Hash";
import Nat "mo:base/Nat";
import Iter "mo:base/Iter";

module {
	type Grant = Types.Grant;
	type NewGrant = Types.NewGrant;
    type Status = Types.Status;

	public class Grants(stableId : Nat, stableGrants : [(Nat,Grant)]) {
		private var nextGrantId = stableId;
		// private var grants = Buffer.fromArray<Grant>(stableGrants);
		var grants = TrieMap.TrieMap<Nat, Grant>(Nat.equal, Hash.hash);
        grants := TrieMap.fromEntries<Nat, Grant>(Iter.fromArray(stableGrants), Nat.equal, Hash.hash);


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
				grantType = grant.grantType;
				reference = grant.reference;
			};
			
			grants.put(nextGrantId,newGrant);
			nextGrantId += 1;
		};

		public func getGrant(grantId: Nat) : ?Grant {
			grants.get(grantId);
		};

        public func getGrants() : [Grant] {
            Iter.toArray(grants.vals());    
        }     

	};
};
