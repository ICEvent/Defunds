import Time "mo:base/Time";
import Principal "mo:base/Principal";
import HashMap "mo:base/HashMap";
import Array "mo:base/Array";
import Text "mo:base/Text";
import Result "mo:base/Result";
import Nat "mo:base/Nat";
import Hash "mo:base/Hash";
import Nat32 "mo:base/Nat32";
import Int "mo:base/Int";

import Types "./types";

persistent actor Governance {

    // ========= Storage =========

    // Custom hash function for Nat
    func natHash(n : Nat) : Hash.Hash {
        Text.hash(Nat.toText(n));
    };

    transient var members = HashMap.HashMap<Principal, Types.Member>(10, Principal.equal, Principal.hash);
    transient var assets = HashMap.HashMap<Nat, Types.Asset>(10, Nat.equal, natHash);
    transient var rules = HashMap.HashMap<Nat, Types.Rule>(10, Nat.equal, natHash);
    transient var proposals = HashMap.HashMap<Nat, Types.Proposal>(10, Nat.equal, natHash);
    transient var votes = HashMap.HashMap<Nat, [Types.Vote]>(10, Nat.equal, natHash);
    transient var authorizations = HashMap.HashMap<Nat, Types.Authorization>(10, Nat.equal, natHash);

    var assetCounter : Nat = 0;
    var ruleCounter : Nat = 0;
    var proposalCounter : Nat = 0;

    // ========= Helpers =========

    func hasRole(m : Types.Member, r : Types.Role) : Bool {
        Array.find<Types.Role>(m.roles, func(x) { x == r }) != null;
    };

    func requireRole(p : Principal, r : Types.Role) : Result.Result<Types.Member, Text> {
        switch (members.get(p)) {
            case (?m) {
                if (not m.active) return #err("Member inactive");
                if (hasRole(m, r)) #ok(m) else #err("Missing role");
            };
            case null #err("Not a member");
        };
    };

    // ========= Admin =========

    public shared (msg) func addMember(
        principal : Principal,
        roles : [Types.Role],
    ) : async Result.Result<(), Text> {
        switch (requireRole(msg.caller, #admin)) {
            case (#err(e)) return #err(e);
            case (#ok(_)) {};
        };
        members.put(
            principal,
            {
                principal = principal;
                roles = roles;
                active = true;
                joinedAt = Time.now();
            },
        );
        #ok(());
    };

    // ========= Asset =========

    public shared (msg) func registerAsset(
        assetType : Types.AssetType,
        description : Text,
        constraints : ?Text,
    ) : async Result.Result<Nat, Text> {
        switch (requireRole(msg.caller, #admin)) {
            case (#err(e)) return #err(e);
            case (#ok(_)) {};
        };
        assetCounter += 1;
        assets.put(
            assetCounter,
            {
                assetId = assetCounter;
                assetType = assetType;
                description = description;
                constraints = constraints;
                createdAt = Time.now();
            },
        );
        #ok(assetCounter);
    };

    // ========= Rule =========

    public shared (msg) func setRule(
        assetId : ?Nat,
        threshold : Nat,
        quorum : Nat,
        timelock : ?Nat,
    ) : async Result.Result<Nat, Text> {
        switch (requireRole(msg.caller, #admin)) {
            case (#err(e)) return #err(e);
            case (#ok(_)) {};
        };
        ruleCounter += 1;
        rules.put(
            ruleCounter,
            {
                ruleId = ruleCounter;
                assetId = assetId;
                threshold = threshold;
                quorum = quorum;
                timelock = timelock;
                version = ruleCounter;
            },
        );
        #ok(ruleCounter);
    };

    // ========= Proposal =========

    public shared (msg) func createProposal(
        assetId : Nat,
        amount : Nat,
        purpose : Text,
        payee : Text,
        evidenceHash : ?Text,
        ruleId : Nat,
    ) : async Result.Result<Nat, Text> {
        switch (requireRole(msg.caller, #proposer)) {
            case (#err(e)) return #err(e);
            case (#ok(_)) {};
        };
        if (assets.get(assetId) == null) return #err("Invalid asset");
        if (rules.get(ruleId) == null) return #err("Invalid rule");

        proposalCounter += 1;
        proposals.put(
            proposalCounter,
            {
                proposalId = proposalCounter;
                assetId = assetId;
                amount = amount;
                purpose = purpose;
                payee = payee;
                evidenceHash = evidenceHash;
                ruleId = ruleId;
                status = #pending;
                createdBy = msg.caller;
                createdAt = Time.now();
            },
        );
        #ok(proposalCounter);
    };

    // ========= Voting =========

    public shared (msg) func vote(
        proposalId : Nat,
        approve : Bool,
    ) : async Result.Result<(), Text> {
        switch (requireRole(msg.caller, #voter)) {
            case (#err(e)) return #err(e);
            case (#ok(_)) {};
        };
        let p = proposals.get(proposalId);
        if (p == null) return #err("Proposal not found");

        switch (p) {
            case (?proposal) {
                if (proposal.status != #pending) return #err("Voting closed");

                let vs = switch (votes.get(proposalId)) {
                    case (?v) v;
                    case null [];
                };
                if (Array.find<Types.Vote>(vs, func(v) { v.voter == msg.caller }) != null) {
                    return #err("Already voted");
                };

                votes.put(proposalId, Array.append(vs, [{ voter = msg.caller; approve = approve; votedAt = Time.now() }]));

                #ok(());
            };
            case null return #err("Proposal not found");
        };
    };

    // ========= Authorization =========

    public shared (_msg) func generateAuthorization(
        proposalId : Nat
    ) : async Result.Result<Types.Authorization, Text> {
        let p = proposals.get(proposalId);
        if (p == null) return #err("Proposal not found");

        switch (p) {
            case (?proposal) {
                let vs = switch (votes.get(proposalId)) {
                    case (?v) v;
                    case null [];
                };

                let ruleOpt = rules.get(proposal.ruleId);
                if (ruleOpt == null) return #err("Rule not found");

                switch (ruleOpt) {
                    case (?rule) {
                        if (vs.size() < rule.quorum) return #err("Quorum not met");

                        let approvals = Array.filter<Types.Vote>(vs, func(v) { v.approve }).size();

                        if (approvals < rule.threshold) return #err("Threshold not met");

                        let now = Time.now();
                        switch (rule.timelock) {
                            case (?tl) {
                                if (now < proposal.createdAt + tl) {
                                    return #err("Timelock not passed");
                                };
                            };
                            case null {};
                        };

                        proposals.put(proposalId, { proposal with status = #executed });

                        let hashInput = proposal.purpose # Nat.toText(proposal.amount) # Int.toText(now);
                        let hash = Text.hash(hashInput);

                        let auth = {
                            proposalId = proposalId;
                            issuedAt = now;
                            hash = Nat32.toNat(hash) |> Nat.toText(_);
                        };

                        authorizations.put(proposalId, auth);
                        #ok(auth);
                    };
                    case null return #err("Rule not found");
                };
            };
            case null return #err("Proposal not found");
        };
    };
    // ========= AUDIT INTERFACES =========

    // 单个 Proposal 全量审计
    public query func auditProposal(
        proposalId : Nat
    ) : async ?Types.ProposalAudit {
        let p = proposals.get(proposalId);
        if (p == null) return null;

        switch (p) {
            case (?proposal) {
                let vs = switch (votes.get(proposalId)) {
                    case (?v) v;
                    case null [];
                };
                let r = rules.get(proposal.ruleId);
                let a = authorizations.get(proposalId);

                if (r == null) return null;

                switch (r) {
                    case (?rule) {
                        ?{
                            proposal = proposal;
                            votes = vs;
                            rule = rule;
                            authorization = a;
                        };
                    };
                    case null null;
                };
            };
            case null null;
        };
    };

    // 分页列出 Proposal（按 ID 顺序）
    public query func listProposalsAudit(
        from : Nat,
        limit : Nat,
    ) : async [Types.ProposalAudit] {
        var result : [Types.ProposalAudit] = [];
        var i = from;
        var count = 0;

        label scanLoop while (count < limit and i <= proposalCounter) {
            let p = proposals.get(i);
            if (p != null) {
                let vs = switch (votes.get(i)) {
                    case (?v) v;
                    case null [];
                };
                switch (p) {
                    case (?proposal) {
                        let r = rules.get(proposal.ruleId);
                        let a = authorizations.get(i);
                        switch (r) {
                            case (?rule) {
                                let audit = {
                                    proposal = proposal;
                                    votes = vs;
                                    rule = rule;
                                    authorization = a;
                                };
                                result := Array.append(result, [audit]);
                                count += 1;
                            };
                            case null {};
                        };
                    };
                    case null {};
                };
            };
            i += 1;
        };

        result;
    };

    // 按资产审计
    public query func auditAsset(
        assetId : Nat
    ) : async [Types.ProposalAudit] {
        var result : [Types.ProposalAudit] = [];

        for ((id, p) in proposals.entries()) {
            if (p.assetId == assetId) {
                let vs = switch (votes.get(id)) {
                    case (?v) v;
                    case null [];
                };
                let r = rules.get(p.ruleId);
                let a = authorizations.get(id);
                switch (r) {
                    case (?rule) {
                        let audit = {
                            proposal = p;
                            votes = vs;
                            rule = rule;
                            authorization = a;
                        };
                        result := Array.append(result, [audit]);
                    };
                    case null {};
                };
            };
        };

        result;
    };

    // 成员参与记录（不泄露投票倾向）
    public query func auditMember(
        principal : Principal
    ) : async [Nat] {
        var result : [Nat] = [];

        for ((id, vs) in votes.entries()) {
            if (Array.find<Types.Vote>(vs, func(v) { v.voter == principal }) != null) {
                result := Array.append(result, [id]);
            };
        };

        result;
    };

    // 系统概览（审计报告用）
    public query func auditSystemInfo() : async {
        totalMembers : Nat;
        totalAssets : Nat;
        totalProposals : Nat;
        rulesVersion : Nat;
    } {
        {
            totalMembers = members.size();
            totalAssets = assets.size();
            totalProposals = proposalCounter;
            rulesVersion = ruleCounter;
        };
    };

};
