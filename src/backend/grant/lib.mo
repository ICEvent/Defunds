import Types "types";
import Buffer "mo:base/Buffer";
import Time "mo:base/Time";
import Principal "mo:base/Principal";

module {
	type Grant = Types.Grant;
	type NewGrant = Types.NewGrant;
    type Status = Types.Status;

	public class Grants(stableId : Nat, stableGrants : [Grant]) {
		private var nextGrantId = stableId;
		private var grants = Buffer.fromArray<Grant>(stableGrants);

		public func toStable() : [Grant] {
			Buffer.toArray(grants);
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
			nextGrantId += 1;
			grants.add(newGrant);
		};


        public func getGrants() : [Grant] {
            Buffer.toArray(grants);    
        }     

	};
};
