module {
    public type Member = {
        name : Text;
        principal : Principal;
        votingPower : Nat;
    };

    public type GroupFund = {
        id : Nat;
        name : Text;
        description : Text;
        creator : Principal;
        isPublic : Bool;
        members : [Member];
        balance : Nat;
        proposals : [Nat];
        createdAt : Int;
        account : [Nat8]; // <-- Added for group subaccount
    };

    public type GroupProposal = {
        id : Nat;
        groupId : Nat;
        title : Text;
        description : Text;
        recipient : Principal;
        amount : Nat;
        yesVotes : [Principal];
        noVotes : [Principal];
        status : { #active; #accepted; #rejected; #executed };
        createdAt : Int;
    };

};
