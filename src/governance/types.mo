module {
    public type Role = {
        #admin; // 规则 & 成员管理
        #proposer; // 发起资产使用请求
        #voter; // 对请求进行表决
        #observer; // 只读监督
    };
    public type Member = {
        principal : Principal;
        roles : [Role];
        active : Bool;
        joinedAt : Int;
    };
    public type AssetType = {
        #cash;
        #grant;
        #equipment;
        #other;
    };

    public type Asset = {
        assetId : Nat;
        assetType : AssetType;
        description : Text;
        constraints : ?Text; // 用途限制（人类可读）
        createdAt : Int;
    };

    public type Rule = {
        ruleId : Nat;
        assetId : ?Nat; // null = 全局规则
        threshold : Nat; // 赞成票数
        quorum : Nat; // 参与人数
        timelock : ?Nat; // 批准后等待期（秒）
        version : Nat;
    };
    public type ProposalStatus = {
        #pending;
        #approved;
        #rejected;
        #executed;
    };
    public type Proposal = {
        proposalId : Nat;
        assetId : Nat;
        amount : Nat;
        purpose : Text;
        payee : Text;
        evidenceHash : ?Text;

        ruleId : Nat;

        status : ProposalStatus;
        createdBy : Principal;
        createdAt : Int;
    };
    public type Vote = {
        voter : Principal;
        approve : Bool;
        votedAt : Int;
    };
    public type Authorization = {
        proposalId : Nat;
        issuedAt : Int;
        hash : Text; // hash(proposal + votes + timestamp)
    };

    public type ProposalAudit = {
        proposal : Proposal;
        votes : [Vote];
        rule : Rule;
        authorization : ?Authorization;
    };

};
