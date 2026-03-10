import Text "mo:base/Text";
import Nat "mo:base/Nat";
import Principal "mo:base/Principal";
import Result "mo:base/Result";
import Array "mo:base/Array";
import Iter "mo:base/Iter";
import Time "mo:base/Time";
import TrieMap "mo:base/TrieMap";
import Hash "mo:base/Hash";
import Blob "mo:base/Blob";
import Buffer "mo:base/Buffer";

import Types "types";

module {

    type GroupFund = Types.GroupFund;
    type GroupProposal = Types.GroupProposal;
    type Member = Types.Member;
    type AIAgentFund = Types.AIAgentFund;
    type AIAgentFundRecord = Types.AIAgentFundRecord;
    type AIAgentConfig = Types.AIAgentConfig;
    type AIProposalEvaluation = Types.AIProposalEvaluation;

    public class Groups(stableGroupId : Nat, stableGroups : [(Nat, GroupFund)], stableProposalId : Nat, stableProposals : [(Nat, GroupProposal)], mainActorPrincipal : Principal, stableAIAgentFunds : [(Nat, AIAgentFundRecord)]) {
        
        private var nextGroupId : Nat = stableGroupId;
        private var nextProposalId : Nat = stableProposalId;

        private func natHash(n : Nat) : Hash.Hash {
            Text.hash(Nat.toText(n));
        };

        var groupFunds : TrieMap.TrieMap<Nat, GroupFund> = TrieMap.TrieMap<Nat, GroupFund>(Nat.equal, natHash);
        groupFunds := TrieMap.fromEntries<Nat, GroupFund>(Iter.fromArray(stableGroups), Nat.equal, natHash);

        var groupProposals : TrieMap.TrieMap<Nat, GroupProposal> = TrieMap.TrieMap<Nat, GroupProposal>(Nat.equal, natHash);
        groupProposals := TrieMap.fromEntries<Nat, GroupProposal>(Iter.fromArray(stableProposals), Nat.equal, natHash);

        // AI Agent Fund storage: groupId -> AIAgentFundRecord (AI-specific fields only)
        var aiAgentFunds : TrieMap.TrieMap<Nat, AIAgentFundRecord> = TrieMap.TrieMap<Nat, AIAgentFundRecord>(Nat.equal, natHash);
        aiAgentFunds := TrieMap.fromEntries<Nat, AIAgentFundRecord>(Iter.fromArray(stableAIAgentFunds), Nat.equal, natHash);

        public func toStable() : [(Nat, GroupFund)] {
            Iter.toArray(groupFunds.entries());
        };

        public func getNextGroupId() : Nat {
            nextGroupId;
        };

        public func toStableProposals() : [(Nat, GroupProposal)] {
            Iter.toArray(groupProposals.entries());
        };

        public func getNextProposalId() : Nat {
            nextProposalId;
        };
        // Helper to generate subaccount for group
        public func mainActorGroupSubaccount(groupId : Nat) : [Nat8] {
            let subaccount = Array.init<Nat8>(32, 0);
            subaccount[0] := 1; // 0x01 for principal-based subaccount
            let principalBytes = Blob.toArray(Principal.toBlob(mainActorPrincipal));
            let groupIdBytes = Text.encodeUtf8(Nat.toText(groupId));
            let pLen = if (principalBytes.size() > 15) 15 else principalBytes.size();
            let gLen = if (groupIdBytes.size() > 16) 16 else groupIdBytes.size();
            for (i in Iter.range(0, pLen - 1)) {
                subaccount[i + 1] := principalBytes[i];
            };
            for (j in Iter.range(0, gLen - 1)) {
                subaccount[1 + pLen + j] := groupIdBytes[j];
            };
            Array.freeze(subaccount)
        };

        public func createGroupFund(caller: Principal, name : Text, description : Text,  isPublic : Bool ) : GroupFund {
            let groupId = nextGroupId;
            let member : Member = {
                name = "Owner";
                principal = caller;
                votingPower = 1;
            };
            let account = mainActorGroupSubaccount(groupId);
            let newGroup : GroupFund = {
                id = groupId;
                name = name;
                description = description;
                creator = caller;
                isPublic = isPublic;
                members = [member];
                balance = 0;
                proposals = [];
                createdAt = Time.now();
                account = account;
            };
            groupFunds.put(groupId, newGroup);
            nextGroupId += 1;
            newGroup;
        };
        // Helper to check if caller is a member
        public func isMember(members : [Member], caller : Principal) : Bool {
            for (member in members.vals()) {
                if (member.principal == caller) return true;
            };
            false;
        };

        public func joinGroupFund(caller: Principal, groupId : Nat) : Result.Result<(), Text> {
            switch (groupFunds.get(groupId)) {
                case null { #err("Group not found") };
                case (?group) {
                    if (not group.isPublic) {
                        #err("Group is private");
                    } else {
                        let member : Member = {
                            name = "";
                            principal = caller;
                            votingPower = 1;
                        };
                        let updatedMembers = Array.append(group.members, [member]);
                        let updatedGroup = {
                            group with members = updatedMembers
                        };
                        groupFunds.put(groupId, updatedGroup);
                        #ok();
                    };
                };
            };
        };

        public func createGroupProposal(caller: Principal, groupId : Nat, title : Text, description : Text, recipient : Principal, amount : Nat) : Result.Result<GroupProposal, Text> {
            switch (groupFunds.get(groupId)) {
                case null { #err("Group not found") };
                case (?group) {
                    if (not isMember(group.members, caller)) {
                        #err("Not a group member");
                    } else {
                        let proposalId = nextProposalId;
                        let proposal : GroupProposal = {
                            id = proposalId;
                            groupId = groupId;
                            title = title;
                            description = description;
                            recipient = recipient;
                            amount = amount;
                            yesVotes = [];
                            noVotes = [];
                            status = #active;
                            createdAt = Time.now();
                        };
                        groupProposals.put(proposalId, proposal);

                        nextProposalId += 1;
                        #ok(proposal);
                    };
                };
            };
        };

        public func vote(caller: Principal, groupId : Nat, proposalId : Nat, voteYes : Bool) : async Result.Result<(), Text> {
            switch (groupProposals.get(proposalId)) {
                case null { #err("Proposal not found") };
                case (?proposal) {
                    switch (groupFunds.get(groupId)) {
                        case null { #err("Group not found") };
                        case (?group) {
                            let isMember = Array.find<Member>(group.members, func(m) { m.principal == caller });
                            switch (isMember) {
                                case null { #err("Not a group member") };
                                case (?_) {
                                    let updatedProposal = if (voteYes) {
                                        {
                                            proposal with yesVotes = Array.append(proposal.yesVotes, [caller])
                                        };
                                    } else {
                                        {
                                            proposal with noVotes = Array.append(proposal.noVotes, [caller])
                                        };
                                    };

                                    // Check if proposal passes (>50% yes votes)
                                    let totalVotes = Array.size(updatedProposal.yesVotes) + Array.size(updatedProposal.noVotes);
                                    let yesVotes = Array.size(updatedProposal.yesVotes);

                                    if (yesVotes * 2 > totalVotes) {
                                        // Execute proposal
                                        let finalProposal = {
                                            updatedProposal with status = #accepted
                                        };
                                        groupProposals.put(proposalId, finalProposal);
                                        // Transfer funds logic here
                                    };

                                    #ok();
                                };
                            };
                        };
                    };
                };
            };
        };

        // Member management methods
        public func addMember(groupId : Nat, member : Member) : Result.Result<(), Text> {
            switch (groupFunds.get(groupId)) {
                case null { #err("Group not found") };
                case (?group) {
                    if (Array.find<Member>(group.members, func(m) { m.principal == member.principal }) != null) {
                        #err("Member already exists");
                    } else {
                        let updatedMembers = Array.append(group.members, [member]);
                        let updatedGroup = { group with members = updatedMembers };
                        groupFunds.put(groupId, updatedGroup);
                        #ok();
                    }
                }
            }
        };

        public func removeMember(groupId : Nat, principal : Principal) : Result.Result<(), Text> {
            switch (groupFunds.get(groupId)) {
                case null { #err("Group not found") };
                case (?group) {
                    let updatedMembers = Array.filter<Member>(group.members, func(m) { m.principal != principal });
                    if (Array.size(updatedMembers) == Array.size(group.members)) {
                        #err("Member not found");
                    } else {
                        let updatedGroup = { group with members = updatedMembers };
                        groupFunds.put(groupId, updatedGroup);
                        #ok();
                    }
                }
            }
        };

        public func updateMemberVotingPower(groupId : Nat, principal : Principal, votingPower : Nat) : Result.Result<(), Text> {
            switch (groupFunds.get(groupId)) {
                case null { #err("Group not found") };
                case (?group) {
                    var found = false;
                    let updatedMembers = Array.map<Member, Member>(group.members, func(m) {
                        if (m.principal == principal) {
                            found := true;
                            { m with votingPower = votingPower }
                        } else m
                    });
                    if (not found) {
                        #err("Member not found");
                    } else {
                        let updatedGroup = { group with members = updatedMembers };
                        groupFunds.put(groupId, updatedGroup);
                        #ok();
                    }
                }
            }
        };

        public func updateMemberName(groupId : Nat, principal : Principal, name : Text) : Result.Result<(), Text> {
            switch (groupFunds.get(groupId)) {
                case null { #err("Group not found") };
                case (?group) {
                    var found = false;
                    let updatedMembers = Array.map<Member, Member>(group.members, func(m) {
                        if (m.principal == principal) {
                            found := true;
                            { m with name = name }
                        } else m
                    });
                    if (not found) {
                        #err("Member not found");
                    } else {
                        let updatedGroup = { group with members = updatedMembers };
                        groupFunds.put(groupId, updatedGroup);
                        #ok();
                    }
                }
            }
        };

        // Query methods
        public func getGroup(groupId : Nat) : ?GroupFund {
            groupFunds.get(groupId)
        };

        public func getAllGroups() : [GroupFund] {
            Iter.toArray(Iter.map(groupFunds.vals(), func(g : GroupFund) : GroupFund { g }))
        };

        public func getPublicGroups() : [GroupFund] {
            let groups = Iter.toArray(groupFunds.vals());
            Array.filter<GroupFund>(groups, func(g) { g.isPublic })
        };

        public func getUserGroups(user : Principal) : [GroupFund] {
            let groups = Iter.toArray(groupFunds.vals());
            Array.filter<GroupFund>(groups, func(g) { isMember(g.members, user) })
        };

        public func getProposal(proposalId : Nat) : ?GroupProposal {
            groupProposals.get(proposalId)
        };

        public func getGroupProposals(groupId : Nat) : [GroupProposal] {
            let proposals = Iter.toArray(groupProposals.vals());
            Array.filter<GroupProposal>(proposals, func(p) { p.groupId == groupId })
        };

        public func getAllProposals() : [GroupProposal] {
            Iter.toArray(groupProposals.vals())
        };

        // ========= AI Agent Fund Methods =========

        // Maximum penalty percentage applied when a proposal exceeds the budget cap.
        private let AI_SCORE_PENALTY_PCT : Nat = 50;
        // Maximum bonus percentage applied when a proposal is well within budget.
        private let AI_SCORE_BONUS_PCT : Nat = 10;

        // Serialise AI Agent Fund records for canister upgrade persistence.
        public func toStableAIAgentFunds() : [(Nat, AIAgentFundRecord)] {
            Iter.toArray(aiAgentFunds.entries())
        };

        // Assemble the external AIAgentFund view by pairing the record with the
        // live GroupFund so callers always see up-to-date member and balance data.
        private func toAIAgentFundView(record : AIAgentFundRecord) : ?AIAgentFund {
            switch (groupFunds.get(record.groupId)) {
                case null null;
                case (?gf) {
                    ?{
                        groupFund = gf;
                        agentConfig = record.agentConfig;
                        evaluations = record.evaluations;
                        lastRunAt = record.lastRunAt;
                    }
                };
            }
        };

        // Create an AI Agent Fund: creates a regular GroupFund and registers an
        // AI agent record keyed on the same group ID.
        public func createAIAgentFund(caller : Principal, name : Text, description : Text, isPublic : Bool, config : AIAgentConfig) : AIAgentFund {
            let groupFund = createGroupFund(caller, name, description, isPublic);
            let record : AIAgentFundRecord = {
                groupId = groupFund.id;
                agentConfig = config;
                evaluations = [];
                lastRunAt = null;
            };
            aiAgentFunds.put(groupFund.id, record);
            {
                groupFund = groupFund;
                agentConfig = config;
                evaluations = [];
                lastRunAt = null;
            }
        };

        // Update the AI agent configuration for a fund (creator only).
        public func setAIAgentConfig(groupId : Nat, caller : Principal, config : AIAgentConfig) : Result.Result<(), Text> {
            switch (aiAgentFunds.get(groupId)) {
                case null { #err("AI Agent Fund not found") };
                case (?record) {
                    switch (groupFunds.get(groupId)) {
                        case null { #err("Underlying group not found") };
                        case (?gf) {
                            if (gf.creator != caller) {
                                return #err("Only fund creator can update AI agent configuration");
                            };
                            let updated : AIAgentFundRecord = {
                                record with agentConfig = config
                            };
                            aiAgentFunds.put(groupId, updated);
                            #ok();
                        };
                    };
                };
            };
        };

        // Deterministic AI scoring heuristic based on proposal parameters and fund config.
        private func computeAIScore(proposal : GroupProposal, config : AIAgentConfig, groupBalance : Nat) : Nat {
            // Base score from risk tolerance
            var score : Nat = config.riskTolerance;

            // Penalise or reward proposals based on how they compare to the budget cap.
            let maxAllowed : Nat = if (groupBalance > 0) {
                (groupBalance * config.maxAllocationPct) / 100
            } else { 0 };

            if (proposal.amount > 0 and maxAllowed > 0) {
                if (proposal.amount > maxAllowed) {
                    // Exceeds budget cap: apply a percentage penalty to the score.
                    // The penalty scales linearly with the excess as a fraction of the
                    // total requested amount, capped at AI_SCORE_PENALTY_PCT (50 %).
                    // Multiplication precedes division to preserve integer precision
                    // (Motoko Nat does not support fractional division).
                    let excess = proposal.amount - maxAllowed;
                    let penalty = (score * excess * AI_SCORE_PENALTY_PCT) / (proposal.amount * 100);
                    if (penalty >= score) { score := 0 } else { score -= penalty };
                } else {
                    // Within budget: apply a percentage bonus proportional to remaining
                    // headroom, capped at AI_SCORE_BONUS_PCT (10 %) of the current score.
                    // Multiplication precedes division to preserve integer precision.
                    let headroom = maxAllowed - proposal.amount;
                    let bonus = (score * headroom * AI_SCORE_BONUS_PCT) / (maxAllowed * 100);
                    score += bonus;
                    if (score > 100) { score := 100 };
                };
            };

            // Strategy-specific adjustment
            score := switch (config.strategy) {
                case (#conservative) { if (score > 60) 60 else score };
                case (#balanced)     { score };
                case (#aggressive)   { let s = score + 10; if (s > 100) 100 else s };
                case (#custom)       { score };
            };

            score
        };

        // Run AI evaluation on all active proposals for a given AI Agent Fund.
        public func evaluateProposals(groupId : Nat, caller : Principal) : Result.Result<[AIProposalEvaluation], Text> {
            switch (aiAgentFunds.get(groupId)) {
                case null { #err("AI Agent Fund not found") };
                case (?record) {
                    switch (groupFunds.get(groupId)) {
                        case null { #err("Underlying group not found") };
                        case (?gf) {
                            if (gf.creator != caller and not isMember(gf.members, caller)) {
                                return #err("Not authorised to run AI evaluation for this fund");
                            };
                            if (not record.agentConfig.enabled) {
                                return #err("AI agent is disabled for this fund");
                            };

                            let activeProposals = Array.filter<GroupProposal>(
                                getGroupProposals(groupId),
                                func(p) {
                                    switch (p.status) { case (#active) true; case _ false }
                                }
                            );

                            let now = Time.now();
                            let evalsBuffer = Buffer.Buffer<AIProposalEvaluation>(activeProposals.size());

                            for (proposal in activeProposals.vals()) {
                                let score = computeAIScore(proposal, record.agentConfig, gf.balance);
                                let recommendation = if (score >= record.agentConfig.autoApproveThreshold) {
                                    #approve
                                } else if (score < 30) {
                                    #reject
                                } else {
                                    #review
                                };

                                let reasoning = switch (recommendation) {
                                    case (#approve) { "Proposal meets AI scoring criteria and is within fund allocation limits." };
                                    case (#reject)  { "Proposal score is below acceptable threshold based on current strategy." };
                                    case (#review)  { "Proposal requires human review; AI score is inconclusive." };
                                };

                                let eval : AIProposalEvaluation = {
                                    proposalId = proposal.id;
                                    score = score;
                                    recommendation = recommendation;
                                    reasoning = reasoning;
                                    evaluatedAt = now;
                                };
                                evalsBuffer.add(eval);
                            };

                            let newEvals = Buffer.toArray(evalsBuffer);

                            // Merge: keep old evaluations for proposals not in this batch.
                            let existingFiltered = Array.filter<AIProposalEvaluation>(
                                record.evaluations,
                                func(e) {
                                    Array.find<AIProposalEvaluation>(newEvals, func(n) { n.proposalId == e.proposalId }) == null
                                }
                            );
                            let mergedEvals = Array.append(existingFiltered, newEvals);

                            let updatedRecord : AIAgentFundRecord = {
                                record with
                                evaluations = mergedEvals;
                                lastRunAt = ?now;
                            };
                            aiAgentFunds.put(groupId, updatedRecord);
                            #ok(newEvals);
                        };
                    };
                };
            };
        };

        // Get AI Agent Fund view (includes live GroupFund data).
        public func getAIAgentFund(groupId : Nat) : ?AIAgentFund {
            switch (aiAgentFunds.get(groupId)) {
                case null null;
                case (?record) toAIAgentFundView(record);
            }
        };

        // List all AI Agent Funds.
        public func getAllAIAgentFunds() : [AIAgentFund] {
            let buf = Buffer.Buffer<AIAgentFund>(aiAgentFunds.size());
            for (record in aiAgentFunds.vals()) {
                switch (toAIAgentFundView(record)) {
                    case (?v) buf.add(v);
                    case null {};
                };
            };
            Buffer.toArray(buf)
        };

        // Get AI Agent Funds where the caller is a member.
        public func getUserAIAgentFunds(user : Principal) : [AIAgentFund] {
            let buf = Buffer.Buffer<AIAgentFund>(0);
            for (record in aiAgentFunds.vals()) {
                switch (toAIAgentFundView(record)) {
                    case (?v) {
                        if (isMember(v.groupFund.members, user)) buf.add(v);
                    };
                    case null {};
                };
            };
            Buffer.toArray(buf)
        };

        // Get public AI Agent Funds.
        public func getPublicAIAgentFunds() : [AIAgentFund] {
            let buf = Buffer.Buffer<AIAgentFund>(0);
            for (record in aiAgentFunds.vals()) {
                switch (toAIAgentFundView(record)) {
                    case (?v) {
                        if (v.groupFund.isPublic) buf.add(v);
                    };
                    case null {};
                };
            };
            Buffer.toArray(buf)
        };

    };
};
