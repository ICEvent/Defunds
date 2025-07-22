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
        account : Text;
        balance : Nat;
        proposals : [Nat];
        createdAt : Int;
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
