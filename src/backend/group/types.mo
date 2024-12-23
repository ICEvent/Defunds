
type GroupFund = {
    id : Nat;
    name : Text;
    description : Text;
    creator : Principal;
    isPublic : Bool;
    members : [Principal];
    account: Text;
    balance : Nat;
    proposals : [Nat];
    createdAt : Int;
};

type GroupProposal = {
    id : Nat;
    groupId : Nat;
    title : Text;
    description : Text;
    recipient : Principal;
    amount : Nat;
    yesVotes : [Principal];
    noVotes : [Principal];
    status : {#active; #executed; #rejected};
    createdAt : Int;
};
