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

    // ========= AI Agent Fund Types =========

    public type AIStrategy = {
        #conservative;  // Low risk, stable returns
        #balanced;      // Moderate risk/reward
        #aggressive;    // High risk, high reward
        #custom;        // User-defined parameters
    };

    public type AIAgentConfig = {
        strategy : AIStrategy;
        riskTolerance : Nat;     // 1–100 scale
        maxAllocationPct : Nat;  // Max % of fund per proposal (1–100)
        autoApproveThreshold : Nat; // AI score threshold to auto-approve (0–100)
        enabled : Bool;
    };

    public type AIProposalEvaluation = {
        proposalId : Nat;
        score : Nat;          // 0–100 AI score
        recommendation : { #approve; #reject; #review };
        reasoning : Text;
        evaluatedAt : Int;
    };

    // Internal storage record – stores only AI-specific fields to avoid
    // duplicating GroupFund data that already lives in the groupFunds map.
    public type AIAgentFundRecord = {
        groupId : Nat;
        agentConfig : AIAgentConfig;
        evaluations : [AIProposalEvaluation];
        lastRunAt : ?Int;
    };

    // External view type returned to callers – includes the live GroupFund.
    public type AIAgentFund = {
        groupFund : GroupFund;
        agentConfig : AIAgentConfig;
        evaluations : [AIProposalEvaluation];
        lastRunAt : ?Int;
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
