import HashMap "mo:base/HashMap";
import Text "mo:base/Text";
import Nat "mo:base/Nat";
import Principal "mo:base/Principal";
import Result "mo:base/Result";
import Array "mo:base/Array";
import Iter "mo:base/Iter";
import Time "mo:base/Time";
import TrieMap "mo:base/TrieMap";
import Hash "mo:base/Hash";

import Types "types";

module {

    type GroupFund = Types.GroupFund;
    type GroupProposal = Types.GroupProposal;

    public class Groups(stableGroupId : Nat, stableGroups : [(Nat, GroupFund)], stableProposalId : Nat, stableProposals : [(Nat, GroupProposal)]) {
       
        private var nextGroupId = stableGroupId;
        private var nextProposalId = stableProposalId;

        private func natHash(n : Nat) : Hash.Hash {
            Text.hash(Nat.toText(n));
        };

        var groupFunds = TrieMap.TrieMap<Nat, GroupFund>(Nat.equal, natHash);
        groupFunds := TrieMap.fromEntries<Nat, GroupFund>(Iter.fromArray(stableGroups), Nat.equal, natHash);

        var groupProposals = TrieMap.TrieMap<Nat, GroupProposal>(Nat.equal, natHash);
        groupProposals := TrieMap.fromEntries<Nat, GroupProposal>(Iter.fromArray(stableProposals), Nat.equal, natHash);

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
        public  func createGroupFund(caller: Principal, name : Text, description : Text, account : Text, isPublic : Bool ) :  GroupFund {

            let groupId = nextGroupId;

            let newGroup : GroupFund = {
                id = groupId;
                name = name;
                description = description;
                creator = caller;
                isPublic = isPublic;
                members = [caller];
                account = account;
                balance = 0;
                proposals = [];
                createdAt = Time.now();
            };

            groupFunds.put(groupId, newGroup);
            nextGroupId += 1;
            newGroup;
        };
        private func isMember(members : [Principal], caller : Principal) : Bool {
            for (member in members.vals()) {
                if (member == caller) return true;
            };
            false;
        };
        public  func joinGroupFund(caller: Principal, groupId : Nat) :  Result.Result<(), Text> {
            switch (groupFunds.get(groupId)) {
                case null { #err("Group not found") };
                case (?group) {
                    if (not group.isPublic) {
                        #err("Group is private");
                    } else {
                        let updatedMembers = Array.append(group.members, [caller]);
                        let updatedGroup = {
                            group with members = updatedMembers
                        };
                        groupFunds.put(groupId, updatedGroup);
                        #ok();
                    };
                };
            };
        };

        public  func createGroupProposal(caller: Principal, groupId : Nat, title : Text, description : Text, recipient : Principal, amount : Nat) :  Result.Result<GroupProposal, Text> {
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
                            let isMember = Array.find<Principal>(group.members, func(p) { p == caller });
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
    };
};
