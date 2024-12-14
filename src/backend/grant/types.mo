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
		amount : Nat;
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
		amount : Nat;
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
        votePower: Nat;
        timestamp: Int;
    };

    public type VotingStatus = {
        totalVotePower: Nat;
        approvalVotePower: Nat;
        rejectVotePower: Nat;
        votes: [Vote];
        startTime: Int;
        endTime: Int;
    };

   
};
