from pathlib import Path


def replace_once(text: str, old: str, new: str, label: str) -> str:
    count = text.count(old)
    if count != 1:
        raise RuntimeError(f"{label}: expected exactly one match, found {count}")
    return text.replace(old, new, 1)


group_path = Path("src/backend/group/lib.mo")
group = group_path.read_text()

group = replace_once(
    group,
    '''        public func isMember(members : [Member], caller : Principal) : Bool {
            for (member in members.vals()) {
                if (member.principal == caller) return true;
            };
            false;
        };

        public func joinGroupFund''',
    '''        public func isMember(members : [Member], caller : Principal) : Bool {
            for (member in members.vals()) {
                if (member.principal == caller) return true;
            };
            false;
        };

        private func containsPrincipal(principals : [Principal], target : Principal) : Bool {
            Array.find<Principal>(principals, func(p) { p == target }) != null
        };

        private func memberVotingPower(members : [Member], caller : Principal) : Nat {
            switch (Array.find<Member>(members, func(m) { m.principal == caller })) {
                case null { 0 };
                case (?member) { member.votingPower };
            }
        };

        // Count each principal once so historical duplicate memberships cannot
        // inflate the total power used by a proposal.
        private func totalMemberVotingPower(members : [Member]) : Nat {
            let seen = TrieMap.TrieMap<Principal, Bool>(Principal.equal, Principal.hash);
            var total : Nat = 0;
            for (member in members.vals()) {
                if (seen.get(member.principal) == null) {
                    seen.put(member.principal, true);
                    total += member.votingPower;
                };
            };
            total
        };

        private func votingPowerFor(members : [Member], voters : [Principal]) : Nat {
            let seen = TrieMap.TrieMap<Principal, Bool>(Principal.equal, Principal.hash);
            var total : Nat = 0;
            for (member in members.vals()) {
                if (
                    seen.get(member.principal) == null and
                    containsPrincipal(voters, member.principal)
                ) {
                    seen.put(member.principal, true);
                    total += member.votingPower;
                };
            };
            total
        };

        public func hasActiveProposals(groupId : Nat) : Bool {
            for (proposal in groupProposals.vals()) {
                if (proposal.groupId == groupId) {
                    switch (proposal.status) {
                        case (#active) { return true };
                        case (_) {};
                    };
                };
            };
            false
        };

        public func joinGroupFund''',
    "group helpers",
)

group = replace_once(
    group,
    '''                    if (not group.isPublic) {
                        #err("Group is private");
                    } else {
                        let member : Member = {
                            name = "";
                            principal = caller;
                            votingPower = 1;
                        };''',
    '''                    if (not group.isPublic) {
                        #err("Group is private");
                    } else if (isMember(group.members, caller)) {
                        #err("Already a group member");
                    } else {
                        // Public discovery does not grant permissionless governance.
                        // Self-joined users enter as observers with zero voting power.
                        let member : Member = {
                            name = "";
                            principal = caller;
                            votingPower = 0;
                        };''',
    "observer join",
)

group = replace_once(
    group,
    '''                case (?group) {
                    if (not isMember(group.members, caller)) {
                        #err("Not a group member");
                    } else {
                        let proposalId = nextProposalId;''',
    '''                case (?group) {
                    let votingPower = memberVotingPower(group.members, caller);
                    if (not isMember(group.members, caller)) {
                        #err("Not a group member");
                    } else if (votingPower == 0) {
                        #err("Member does not have governance voting power");
                    } else if (Text.size(title) == 0) {
                        #err("Proposal title is required");
                    } else if (amount == 0) {
                        #err("Proposal amount must be greater than zero");
                    } else {
                        let proposalId = nextProposalId;''',
    "proposal validation",
)

group = replace_once(
    group,
    '''                        groupProposals.put(proposalId, proposal);

                        nextProposalId += 1;''',
    '''                        groupProposals.put(proposalId, proposal);
                        groupFunds.put(
                            groupId,
                            { group with proposals = Array.append(group.proposals, [proposalId]) },
                        );

                        nextProposalId += 1;''',
    "proposal index",
)

old_vote = '''        public func vote(caller: Principal, groupId : Nat, proposalId : Nat, voteYes : Bool) : async Result.Result<(), Text> {
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
        };'''

new_vote = '''        public func vote(caller: Principal, groupId : Nat, proposalId : Nat, voteYes : Bool) : async Result.Result<(), Text> {
            switch (groupProposals.get(proposalId)) {
                case null { #err("Proposal not found") };
                case (?proposal) {
                    if (proposal.groupId != groupId) {
                        return #err("Proposal does not belong to this group");
                    };
                    switch (proposal.status) {
                        case (#active) {};
                        case (_) { return #err("Proposal is not active") };
                    };
                    switch (groupFunds.get(groupId)) {
                        case null { #err("Group not found") };
                        case (?group) {
                            let member = Array.find<Member>(group.members, func(m) { m.principal == caller });
                            switch (member) {
                                case null { #err("Not a group member") };
                                case (?memberInfo) {
                                    if (memberInfo.votingPower == 0) {
                                        return #err("Member does not have governance voting power");
                                    };
                                    if (
                                        containsPrincipal(proposal.yesVotes, caller) or
                                        containsPrincipal(proposal.noVotes, caller)
                                    ) {
                                        return #err("Member has already voted on this proposal");
                                    };

                                    let updatedProposal = if (voteYes) {
                                        {
                                            proposal with yesVotes = Array.append(proposal.yesVotes, [caller])
                                        };
                                    } else {
                                        {
                                            proposal with noVotes = Array.append(proposal.noVotes, [caller])
                                        };
                                    };

                                    let totalPower = totalMemberVotingPower(group.members);
                                    if (totalPower == 0) {
                                        return #err("Group has no voting power");
                                    };

                                    let yesPower = votingPowerFor(group.members, updatedProposal.yesVotes);
                                    let noPower = votingPowerFor(group.members, updatedProposal.noVotes);
                                    var finalProposal = updatedProposal;

                                    // Majority is calculated against total fund voting power,
                                    // not just votes already cast.
                                    if (yesPower * 2 > totalPower) {
                                        finalProposal := { updatedProposal with status = #accepted };
                                    } else if (noPower * 2 >= totalPower) {
                                        // At 50% No power, a >50% Yes majority is no longer reachable.
                                        finalProposal := { updatedProposal with status = #rejected };
                                    };

                                    groupProposals.put(proposalId, finalProposal);
                                    #ok();
                                };
                            };
                        };
                    };
                };
            };
        };'''

group = replace_once(group, old_vote, new_vote, "weighted vote")

group = replace_once(
    group,
    '''                            if (gf.creator != caller and not isMember(gf.members, caller)) {
                                return #err("Not authorised to run AI evaluation for this fund");
                            };''',
    '''                            if (gf.creator != caller and memberVotingPower(gf.members, caller) == 0) {
                                return #err("Not authorised to run AI evaluation for this fund");
                            };''',
    "AI observer permission",
)

group_path.write_text(group)

main_path = Path("src/backend/main.mo")
main = main_path.read_text()

main = replace_once(
    main,
    '''\tpublic shared ({ caller }) func addGroupMember(groupId : Nat, memberName : Text, memberPrincipal : Principal, votingPower : Nat) : async Result.Result<(), Text> {
\t\tif (Principal.isAnonymous(caller)) {
\t\t\t#err("Anonymous users cannot manage members");
\t\t} else {
\t\t\tlet member : GroupTypes.Member = {
\t\t\t\tname = memberName;
\t\t\t\tprincipal = memberPrincipal;
\t\t\t\tvotingPower = votingPower;
\t\t\t};
\t\t\tgroups.addMember(groupId, member);
\t\t};
\t};''',
    '''\tpublic shared ({ caller }) func addGroupMember(groupId : Nat, memberName : Text, memberPrincipal : Principal, votingPower : Nat) : async Result.Result<(), Text> {
\t\tif (Principal.isAnonymous(caller)) {
\t\t\t#err("Anonymous users cannot manage members");
\t\t} else {
\t\t\tswitch (groups.getGroup(groupId)) {
\t\t\t\tcase null { #err("Group not found") };
\t\t\t\tcase (?group) {
\t\t\t\t\tif (group.creator != caller) {
\t\t\t\t\t\t#err("Only the fund creator can manage members");
\t\t\t\t\t} else if (groups.hasActiveProposals(groupId)) {
\t\t\t\t\t\t#err("Voting membership is frozen while a proposal is active");
\t\t\t\t\t} else if (Principal.isAnonymous(memberPrincipal)) {
\t\t\t\t\t\t#err("Cannot add anonymous principal as a fund member");
\t\t\t\t\t} else {
\t\t\t\t\t\tlet member : GroupTypes.Member = {
\t\t\t\t\t\t\tname = memberName;
\t\t\t\t\t\t\tprincipal = memberPrincipal;
\t\t\t\t\t\t\tvotingPower = votingPower;
\t\t\t\t\t\t};
\t\t\t\t\t\tgroups.addMember(groupId, member);
\t\t\t\t\t};
\t\t\t\t};
\t\t\t};
\t\t};
\t};''',
    "main add member authorization",
)

main = replace_once(
    main,
    '''\tpublic shared ({ caller }) func removeGroupMember(groupId : Nat, memberPrincipal : Principal) : async Result.Result<(), Text> {
\t\tif (Principal.isAnonymous(caller)) {
\t\t\t#err("Anonymous users cannot manage members");
\t\t} else {
\t\t\tgroups.removeMember(groupId, memberPrincipal);
\t\t};
\t};''',
    '''\tpublic shared ({ caller }) func removeGroupMember(groupId : Nat, memberPrincipal : Principal) : async Result.Result<(), Text> {
\t\tif (Principal.isAnonymous(caller)) {
\t\t\t#err("Anonymous users cannot manage members");
\t\t} else {
\t\t\tswitch (groups.getGroup(groupId)) {
\t\t\t\tcase null { #err("Group not found") };
\t\t\t\tcase (?group) {
\t\t\t\t\tif (group.creator != caller) {
\t\t\t\t\t\t#err("Only the fund creator can manage members");
\t\t\t\t\t} else if (memberPrincipal == group.creator) {
\t\t\t\t\t\t#err("The fund creator cannot be removed");
\t\t\t\t\t} else if (groups.hasActiveProposals(groupId)) {
\t\t\t\t\t\t#err("Voting membership is frozen while a proposal is active");
\t\t\t\t\t} else {
\t\t\t\t\t\tgroups.removeMember(groupId, memberPrincipal);
\t\t\t\t\t};
\t\t\t\t};
\t\t\t};
\t\t};
\t};''',
    "main remove member authorization",
)

main = replace_once(
    main,
    '''\tpublic shared ({ caller }) func updateGroupMemberVotingPower(groupId : Nat, memberPrincipal : Principal, votingPower : Nat) : async Result.Result<(), Text> {
\t\tif (Principal.isAnonymous(caller)) {
\t\t\t#err("Anonymous users cannot manage members");
\t\t} else {
\t\t\tgroups.updateMemberVotingPower(groupId, memberPrincipal, votingPower);
\t\t};
\t};''',
    '''\tpublic shared ({ caller }) func updateGroupMemberVotingPower(groupId : Nat, memberPrincipal : Principal, votingPower : Nat) : async Result.Result<(), Text> {
\t\tif (Principal.isAnonymous(caller)) {
\t\t\t#err("Anonymous users cannot manage members");
\t\t} else {
\t\t\tswitch (groups.getGroup(groupId)) {
\t\t\t\tcase null { #err("Group not found") };
\t\t\t\tcase (?group) {
\t\t\t\t\tif (group.creator != caller) {
\t\t\t\t\t\t#err("Only the fund creator can manage voting power");
\t\t\t\t\t} else if (groups.hasActiveProposals(groupId)) {
\t\t\t\t\t\t#err("Voting power is frozen while a proposal is active");
\t\t\t\t\t} else if (memberPrincipal == group.creator and votingPower == 0) {
\t\t\t\t\t\t#err("The fund creator must retain voting power");
\t\t\t\t\t} else {
\t\t\t\t\t\tgroups.updateMemberVotingPower(groupId, memberPrincipal, votingPower);
\t\t\t\t\t};
\t\t\t\t};
\t\t\t};
\t\t};
\t};''',
    "main voting power authorization",
)

main = replace_once(
    main,
    '''\tpublic shared ({ caller }) func updateGroupMemberName(groupId : Nat, memberPrincipal : Principal, memberName : Text) : async Result.Result<(), Text> {
\t\tif (Principal.isAnonymous(caller)) {
\t\t\t#err("Anonymous users cannot manage members");
\t\t} else {
\t\t\tgroups.updateMemberName(groupId, memberPrincipal, memberName);
\t\t};
\t};''',
    '''\tpublic shared ({ caller }) func updateGroupMemberName(groupId : Nat, memberPrincipal : Principal, memberName : Text) : async Result.Result<(), Text> {
\t\tif (Principal.isAnonymous(caller)) {
\t\t\t#err("Anonymous users cannot manage members");
\t\t} else {
\t\t\tswitch (groups.getGroup(groupId)) {
\t\t\t\tcase null { #err("Group not found") };
\t\t\t\tcase (?group) {
\t\t\t\t\tif (group.creator != caller) {
\t\t\t\t\t\t#err("Only the fund creator can manage member names");
\t\t\t\t\t} else {
\t\t\t\t\t\tgroups.updateMemberName(groupId, memberPrincipal, memberName);
\t\t\t\t\t};
\t\t\t\t};
\t\t\t};
\t\t};
\t};''',
    "main member name authorization",
)

main = replace_once(
    main,
    '''\tpublic query ({ caller }) func getMyGroups() : async [GroupTypes.GroupFund] {
\t\tif (Principal.isAnonymous(caller)) {
\t\t\t[];
\t\t} else {
\t\t\tArray.filter<GroupTypes.GroupFund>(
\t\t\t\tgroups.getAllGroups(),
\t\t\t\tfunc(group : GroupTypes.GroupFund) : Bool {
\t\t\t\t\tgroup.creator == caller;
\t\t\t\t},
\t\t\t);
\t\t};
\t};''',
    '''\tpublic query ({ caller }) func getMyGroups() : async [GroupTypes.GroupFund] {
\t\tif (Principal.isAnonymous(caller)) {
\t\t\t[];
\t\t} else {
\t\t\tgroups.getUserGroups(caller);
\t\t};
\t};''',
    "getMyGroups membership semantics",
)

main_path.write_text(main)
print("Applied Defunds fund governance hardening successfully")
