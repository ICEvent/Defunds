import Text "mo:base/Text";

module {

	//grant fund to recipients
	public type Status = {
		#submitted;
		#review;
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
		recipient : Principal;
		applicant : Principal;
		amount : Nat;
		currency : Text;
		grantStatus : Status;
		grantType : Text;
		reference : Text; //link to the support materials
	};
	public type NewGrant = {
		title : Text;
		description : Text;
		recipient : Principal;
		amount : Nat;
		currency : Text;
		grantType : Text;
		reference : Text;

	};
};
