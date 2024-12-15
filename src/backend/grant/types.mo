import Text "mo:base/Text";
import Types "../types";

module {
	type Currency = Types.Currency;
	
	public type Status = {
		#submitted;
		#review;
		#voting;
		#approved;
		#rejected;
		#cancelled;
		#expired;
	};

	public type Grant = {
		grantId : Int;
		submitime : Int;
		title : Text;
		description : Text;
		recipient : Text; //address
		applicant : Principal;
		amount : Nat64;
		currency : Currency;
		grantStatus : Status;
		category : Text;
		proofs : [Text]; 
		votingStatus: ?VotingStatus;
	};
	public type NewGrant = {
		title : Text;
		description : Text;
		recipient : Text;
		amount : Nat64;
		currency : Currency;
		category : Text;
		proofs : [Text];

	};

	 public type VoteType = {
        #approve;
        #reject;
    };

    public type Vote = {
        voterId: Principal;
        grantId: Int;
        voteType: VoteType;
        votePower: Nat64;
        timestamp: Int;
    };

    public type VotingStatus = {
        totalVotePower: Nat64;
        approvalVotePower: Nat64;
        rejectVotePower: Nat64;
        votes: [Vote];
        startTime: Int;
        endTime: Int;
    };

   
};
