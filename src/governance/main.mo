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

    // Group storage
    transient var groups = HashMap.HashMap<Nat, Types.Group>(10, Nat.equal, natHash);
    var groupCounter : Nat = 0;

    // Group-scoped storage (key format: "groupId:itemId")
    transient var groupMembers = HashMap.HashMap<Text, Types.GroupMember>(10, Text.equal, Text.hash);
    transient var assets = HashMap.HashMap<Nat, Types.Asset>(10, Nat.equal, natHash);
    transient var rules = HashMap.HashMap<Nat, Types.Rule>(10, Nat.equal, natHash);
    transient var proposals = HashMap.HashMap<Nat, Types.Proposal>(10, Nat.equal, natHash);
    transient var votes = HashMap.HashMap<Nat, [Types.Vote]>(10, Nat.equal, natHash);
    transient var authorizations = HashMap.HashMap<Nat, Types.Authorization>(10, Nat.equal, natHash);

    var assetCounter : Nat = 0;
    var ruleCounter : Nat = 0;
    var proposalCounter : Nat = 0;

    // ========= Helpers =========

    func makeGroupMemberKey(groupId : Nat, principal : Principal) : Text {
        Nat.toText(groupId) # ":" # Principal.toText(principal);
    };

    func hasRole(roles : [Types.Role], r : Types.Role) : Bool {
        Array.find<Types.Role>(roles, func(x) { x == r }) != null;
    };

    func requireGroupRole(p : Principal, groupId : Nat, r : Types.Role) : Result.Result<Types.GroupMember, Text> {
        let key = makeGroupMemberKey(groupId, p);
        switch (groupMembers.get(key)) {
            case (?m) {
                if (not m.active) return #err("Member inactive");
                if (hasRole(m.roles, r)) #ok(m) else #err("Missing role");
            };
            case null #err("Not a member of this group");
        };
    };

    func groupExists(groupId : Nat) : Bool {
        switch (groups.get(groupId)) {
            case (?g) g.active;
            case null false;
        };
    };

    // ========= Group Management =========

    public shared (msg) func createGroup(
        name : Text,
        description : Text,
    ) : async Result.Result<Nat, Text> {
        groupCounter += 1;
        groups.put(
            groupCounter,
            {
                groupId = groupCounter;
                name = name;
                description = description;
                createdBy = msg.caller;
                createdAt = Time.now();
                active = true;
            },
        );
        // Add creator as admin
        let key = makeGroupMemberKey(groupCounter, msg.caller);
        groupMembers.put(
            key,
            {
                groupId = groupCounter;
                principal = msg.caller;
                roles = [#admin];
                active = true;
                joinedAt = Time.now();
            },
        );
        #ok(groupCounter);
    };

    public query func getGroup(groupId : Nat) : async ?Types.Group {
        groups.get(groupId);
    };

    public query func listGroups() : async [Types.Group] {
        var result : [Types.Group] = [];
        for ((_, group) in groups.entries()) {
            if (group.active) {
                result := Array.append(result, [group]);
            };
        };
        result;
    };

    // ========= Admin =========

    public shared (msg) func addMember(
        groupId : Nat,
        principal : Principal,
        roles : [Types.Role],
    ) : async Result.Result<(), Text> {
        if (not groupExists(groupId)) return #err("Group not found");
        
        switch (requireGroupRole(msg.caller, groupId, #admin)) {
            case (#err(e)) return #err(e);
            case (#ok(_)) {};
        };
        
        let key = makeGroupMemberKey(groupId, principal);
        groupMembers.put(
            key,
            {
                groupId = groupId;
                principal = principal;
                roles = roles;
                active = true;
                joinedAt = Time.now();
            },
        );
        #ok(());
    };

    public query func getGroupMembers(groupId : Nat) : async [Types.GroupMember] {
        var result : [Types.GroupMember] = [];
        for ((_, member) in groupMembers.entries()) {
            if (member.groupId == groupId and member.active) {
                result := Array.append(result, [member]);
            };
        };
        result;
    };

    // ========= Asset =========

    public shared (msg) func registerAsset(
        groupId : Nat,
        category : Types.AssetCategory, // #native or #external
        assetType : Types.AssetType,
        description : Text,
        canisterId : ?Text,
        tokenIdentifier : ?Text,
        constraints : ?Text,
    ) : async Result.Result<Nat, Text> {
        if (not groupExists(groupId)) return #err("Group not found");
        
        switch (requireGroupRole(msg.caller, groupId, #admin)) {
            case (#err(e)) return #err(e);
            case (#ok(_)) {};
        };
        assetCounter += 1;
        assets.put(
            assetCounter,
            {
                assetId = assetCounter;
                groupId = groupId;
                category = category;
                assetType = assetType;
                description = description;
                canisterId = canisterId;
                tokenIdentifier = tokenIdentifier;
                constraints = constraints;
                createdAt = Time.now();
            },
        );
        #ok(assetCounter);
    };

    public query func getGroupAssets(groupId : Nat) : async [Types.Asset] {
        var result : [Types.Asset] = [];
        for ((_, asset) in assets.entries()) {
            if (asset.groupId == groupId) {
                result := Array.append(result, [asset]);
            };
        };
        result;
    };

    // ========= Rule =========

    public shared (msg) func setRule(
        groupId : Nat,
        assetId : ?Nat,
        threshold : Nat,
        quorum : Nat,
        timelock : ?Nat,
    ) : async Result.Result<Nat, Text> {
        if (not groupExists(groupId)) return #err("Group not found");
        
        switch (requireGroupRole(msg.caller, groupId, #admin)) {
            case (#err(e)) return #err(e);
            case (#ok(_)) {};
        };
        ruleCounter += 1;
        rules.put(
            ruleCounter,
            {
                ruleId = ruleCounter;
                groupId = groupId;
                assetId = assetId;
                threshold = threshold;
                quorum = quorum;
                timelock = timelock;
                version = ruleCounter;
            },
        );
        #ok(ruleCounter);
    };

    public query func getGroupRules(groupId : Nat) : async [Types.Rule] {
        var result : [Types.Rule] = [];
        for ((_, rule) in rules.entries()) {
            if (rule.groupId == groupId) {
                result := Array.append(result, [rule]);
            };
        };
        result;
    };

    // ========= Proposal =========

    public shared (msg) func createProposal(
        groupId : Nat,
        assetId : Nat,
        amount : Nat,
        purpose : Text,
        payee : Text,
        evidenceHash : ?Text,
        ruleId : Nat,
    ) : async Result.Result<Nat, Text> {
        if (not groupExists(groupId)) return #err("Group not found");
        
        switch (requireGroupRole(msg.caller, groupId, #proposer)) {
            case (#err(e)) return #err(e);
            case (#ok(_)) {};
        };
        
        // Verify asset belongs to the group
        switch (assets.get(assetId)) {
            case (?asset) {
                if (asset.groupId != groupId) return #err("Asset not in this group");
            };
            case null return #err("Invalid asset");
        };
        
        // Verify rule belongs to the group
        switch (rules.get(ruleId)) {
            case (?rule) {
                if (rule.groupId != groupId) return #err("Rule not in this group");
            };
            case null return #err("Invalid rule");
        };

        proposalCounter += 1;
        proposals.put(
            proposalCounter,
            {
                proposalId = proposalCounter;
                groupId = groupId;
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

    public query func getGroupProposals(groupId : Nat) : async [Types.Proposal] {
        var result : [Types.Proposal] = [];
        for ((_, proposal) in proposals.entries()) {
            if (proposal.groupId == groupId) {
                result := Array.append(result, [proposal]);
            };
        };
        result;
    };

    // ========= Voting =========

    public shared (msg) func vote(
        proposalId : Nat,
        approve : Bool,
    ) : async Result.Result<(), Text> {
        let p = proposals.get(proposalId);
        if (p == null) return #err("Proposal not found");

        switch (p) {
            case (?proposal) {
                // Verify caller is a voter in the proposal's group
                switch (requireGroupRole(msg.caller, proposal.groupId, #voter)) {
                    case (#err(e)) return #err(e);
                    case (#ok(_)) {};
                };
                
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

    // 按组列出 Proposal 审计
    public query func listGroupProposalsAudit(
        groupId : Nat,
        from : Nat,
        limit : Nat,
    ) : async [Types.ProposalAudit] {
        var result : [Types.ProposalAudit] = [];
        var i = from;
        var count = 0;

        label scanLoop while (count < limit and i <= proposalCounter) {
            let p = proposals.get(i);
            if (p != null) {
                switch (p) {
                    case (?proposal) {
                        if (proposal.groupId == groupId) {
                            let vs = switch (votes.get(i)) {
                                case (?v) v;
                                case null [];
                            };
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

    // 成员参与记录（不泄露投票倾向）- 现在需要指定组
    public query func auditMember(
        groupId : Nat,
        principal : Principal
    ) : async [Nat] {
        var result : [Nat] = [];

        for ((id, vs) in votes.entries()) {
            // Check if this proposal belongs to the group
            switch (proposals.get(id)) {
                case (?proposal) {
                    if (proposal.groupId == groupId and 
                        Array.find<Types.Vote>(vs, func(v) { v.voter == principal }) != null) {
                        result := Array.append(result, [id]);
                    };
                };
                case null {};
            };
        };

        result;
    };

    // 系统概览（审计报告用）
    public query func auditSystemInfo() : async {
        totalGroups : Nat;
        totalMembers : Nat;
        totalAssets : Nat;
        totalProposals : Nat;
        rulesVersion : Nat;
    } {
        {
            totalGroups = groups.size();
            totalMembers = groupMembers.size();
            totalAssets = assets.size();
            totalProposals = proposalCounter;
            rulesVersion = ruleCounter;
        };
    };

    // 组概览
    public query func auditGroupInfo(groupId : Nat) : async ?{
        group : Types.Group;
        totalMembers : Nat;
        totalAssets : Nat;
        totalProposals : Nat;
        totalRules : Nat;
    } {
        switch (groups.get(groupId)) {
            case (?group) {
                var memberCount = 0;
                var assetCount = 0;
                var proposalCount = 0;
                var ruleCount = 0;

                for ((_, member) in groupMembers.entries()) {
                    if (member.groupId == groupId and member.active) {
                        memberCount += 1;
                    };
                };

                for ((_, asset) in assets.entries()) {
                    if (asset.groupId == groupId) {
                        assetCount += 1;
                    };
                };

                for ((_, proposal) in proposals.entries()) {
                    if (proposal.groupId == groupId) {
                        proposalCount += 1;
                    };
                };

                for ((_, rule) in rules.entries()) {
                    if (rule.groupId == groupId) {
                        ruleCount += 1;
                    };
                };

                ?{
                    group = group;
                    totalMembers = memberCount;
                    totalAssets = assetCount;
                    totalProposals = proposalCount;
                    totalRules = ruleCount;
                };
            };
            case null null;
        };
    };

};
