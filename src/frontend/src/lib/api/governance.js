/**
 * Governance API Service
 * Provides functions to interact with the governance canister
 */

// ========= Group Management =========

/**
 * Create a new governance group
 * @param {Object} governanceActor - The governance canister actor
 * @param {string} name - Name of the group
 * @param {string} description - Description of the group
 * @returns {Promise<Object>} Result with group ID or error
 */
export async function createGroup(governanceActor, name, description) {
  try {
    const result = await governanceActor.createGroup(name, description);
    return result;
  } catch (error) {
    console.error('Error creating group:', error);
    return { err: error.message };
  }
}

/**
 * Get a specific group
 * @param {Object} governanceActor - The governance canister actor
 * @param {number} groupId - The group ID
 * @returns {Promise<Object|null>} Group object or null
 */
export async function getGroup(governanceActor, groupId) {
  try {
    const result = await governanceActor.getGroup(groupId);
    return result;
  } catch (error) {
    console.error('Error getting group:', error);
    return null;
  }
}

/**
 * List all groups
 * @param {Object} governanceActor - The governance canister actor
 * @returns {Promise<Array>} Array of groups
 */
export async function listGroups(governanceActor) {
  try {
    const result = await governanceActor.listGroups();
    return result;
  } catch (error) {
    console.error('Error listing groups:', error);
    return [];
  }
}

/**
 * Get members of a group
 * @param {Object} governanceActor - The governance canister actor
 * @param {number} groupId - The group ID
 * @returns {Promise<Array>} Array of group members
 */
export async function getGroupMembers(governanceActor, groupId) {
  try {
    const result = await governanceActor.getGroupMembers(groupId);
    return result;
  } catch (error) {
    console.error('Error getting group members:', error);
    return [];
  }
}

/**
 * Get group info for audit
 * @param {Object} governanceActor - The governance canister actor
 * @param {number} groupId - The group ID
 * @returns {Promise<Object|null>} Group info with stats
 */
export async function auditGroupInfo(governanceActor, groupId) {
  try {
    const result = await governanceActor.auditGroupInfo(groupId);
    return result;
  } catch (error) {
    console.error('Error getting group info:', error);
    return null;
  }
}

// ========= Member Management =========

/**
 * Add a member to a group
 * @param {Object} governanceActor - The governance canister actor
 * @param {number} groupId - The group ID
 * @param {string} principal - The principal ID of the member to add
 * @param {Array} roles - Array of roles to assign (e.g., ['admin', 'voter', 'proposer'])
 * @returns {Promise<Object>} Result object with ok or err
 */
export async function addMember(governanceActor, groupId, principal, roles) {
  try {
    const result = await governanceActor.addMember(groupId, principal, roles);
    return result;
  } catch (error) {
    console.error('Error adding member:', error);
    return { err: error.message };
  }
}

/**
 * Register an asset in a group
 * @param {Object} governanceActor - The governance canister actor
 * @param {number} groupId - The group ID
 * @param {Object} category - Asset category: { native: null } or { external: null }
 * @param {Object} assetType - The type of asset (e.g., { cash: null } or { grant: null })
 * @param {string} description - Description of the asset
 * @param {string|null} canisterId - Optional canister ID for native assets
 * @param {string|null} tokenIdentifier - Optional token identifier
 * @param {string|null} constraints - Optional constraints on the asset
 * @returns {Promise<Object>} Result with asset ID or error
 */
export async function registerAsset(governanceActor, groupId, category, assetType, description, canisterId = null, tokenIdentifier = null, constraints = null) {
  try {
    const canisterIdOpt = canisterId ? [canisterId] : [];
    const tokenIdentifierOpt = tokenIdentifier ? [tokenIdentifier] : [];
    const constraintsOpt = constraints ? [constraints] : [];
    const result = await governanceActor.registerAsset(groupId, category, assetType, description, canisterIdOpt, tokenIdentifierOpt, constraintsOpt);
    return result;
  } catch (error) {
    console.error('Error registering asset:', error);
    return { err: error.message };
  }
}

/**
 * Get assets for a group
 * @param {Object} governanceActor - The governance canister actor
 * @param {number} groupId - The group ID
 * @returns {Promise<Array>} Array of assets
 */
export async function getGroupAssets(governanceActor, groupId) {
  try {
    const result = await governanceActor.getGroupAssets(groupId);
    return result;
  } catch (error) {
    console.error('Error getting group assets:', error);
    return [];
  }
}

/**
 * Set a governance rule for a group
 * @param {Object} governanceActor - The governance canister actor
 * @param {number} groupId - The group ID
 * @param {number} assetId - Optional asset ID this rule applies to
 * @param {number} threshold - Minimum approvals needed
 * @param {number} quorum - Minimum votes required
 * @param {number} timelock - Optional timelock in nanoseconds
 * @returns {Promise<Object>} Result with rule ID or error
 */
export async function setRule(governanceActor, groupId, assetId = null, threshold, quorum, timelock = null) {
  try {
    const assetIdOpt = assetId !== null ? [assetId] : [];
    const timelockOpt = timelock !== null ? [timelock] : [];
    const result = await governanceActor.setRule(groupId, assetIdOpt, threshold, quorum, timelockOpt);
    return result;
  } catch (error) {
    console.error('Error setting rule:', error);
    return { err: error.message };
  }
}

/**
 * Get rules for a group
 * @param {Object} governanceActor - The governance canister actor
 * @param {number} groupId - The group ID
 * @returns {Promise<Array>} Array of rules
 */
export async function getGroupRules(governanceActor, groupId) {
  try {
    const result = await governanceActor.getGroupRules(groupId);
    return result;
  } catch (error) {
    console.error('Error getting group rules:', error);
    return [];
  }
}

/**
 * Create a proposal in a group
 * @param {Object} governanceActor - The governance canister actor
 * @param {number} groupId - The group ID
 * @param {number} assetId - The asset ID the proposal is for
 * @param {number} amount - The amount requested
 * @param {string} purpose - Purpose of the proposal
 * @param {string} payee - Who will receive the funds
 * @param {string} evidenceHash - Optional hash of supporting evidence
 * @param {number} ruleId - The rule ID to apply to this proposal
 * @returns {Promise<Object>} Result with proposal ID or error
 */
export async function createProposal(
  governanceActor,
  groupId,
  assetId,
  amount,
  purpose,
  payee,
  evidenceHash = null,
  ruleId
) {
  try {
    const evidenceHashOpt = evidenceHash ? [evidenceHash] : [];
    const result = await governanceActor.createProposal(
      groupId,
      assetId,
      amount,
      purpose,
      payee,
      evidenceHashOpt,
      ruleId
    );
    return result;
  } catch (error) {
    console.error('Error creating proposal:', error);
    return { err: error.message };
  }
}

/**
 * Get proposals for a group
 * @param {Object} governanceActor - The governance canister actor
 * @param {number} groupId - The group ID
 * @returns {Promise<Array>} Array of proposals
 */
export async function getGroupProposals(governanceActor, groupId) {
  try {
    const result = await governanceActor.getGroupProposals(groupId);
    return result;
  } catch (error) {
    console.error('Error getting group proposals:', error);
    return [];
  }
}

/**
 * Vote on a proposal
 * @param {Object} governanceActor - The governance canister actor
 * @param {number} proposalId - The proposal ID to vote on
 * @param {boolean} approve - true to approve, false to reject
 * @returns {Promise<Object>} Result object
 */
export async function vote(governanceActor, proposalId, approve) {
  try {
    const result = await governanceActor.vote(proposalId, approve);
    return result;
  } catch (error) {
    console.error('Error voting:', error);
    return { err: error.message };
  }
}

/**
 * Generate authorization for an approved proposal
 * @param {Object} governanceActor - The governance canister actor
 * @param {number} proposalId - The proposal ID to generate authorization for
 * @returns {Promise<Object>} Result with authorization object or error
 */
export async function generateAuthorization(governanceActor, proposalId) {
  try {
    const result = await governanceActor.generateAuthorization(proposalId);
    return result;
  } catch (error) {
    console.error('Error generating authorization:', error);
    return { err: error.message };
  }
}

/**
 * Audit a specific proposal
 * @param {Object} governanceActor - The governance canister actor
 * @param {number} proposalId - The proposal ID to audit
 * @returns {Promise<Object|null>} Proposal audit data or null
 */
export async function auditProposal(governanceActor, proposalId) {
  try {
    const result = await governanceActor.auditProposal(proposalId);
    return result;
  } catch (error) {
    console.error('Error auditing proposal:', error);
    return null;
  }
}

/**
 * List proposals with pagination
 * @param {Object} governanceActor - The governance canister actor
 * @param {number} from - Starting proposal ID
 * @param {number} limit - Number of proposals to fetch
 * @returns {Promise<Array>} Array of proposal audit data
 */
export async function listProposalsAudit(governanceActor, from = 1, limit = 10) {
  try {
    const result = await governanceActor.listProposalsAudit(from, limit);
    return result;
  } catch (error) {
    console.error('Error listing proposals:', error);
    return [];
  }
}

/**
 * List proposals for a group with pagination
 * @param {Object} governanceActor - The governance canister actor
 * @param {number} groupId - The group ID
 * @param {number} from - Starting proposal ID
 * @param {number} limit - Number of proposals to fetch
 * @returns {Promise<Array>} Array of proposal audit data
 */
export async function listGroupProposalsAudit(governanceActor, groupId, from = 1, limit = 10) {
  try {
    const result = await governanceActor.listGroupProposalsAudit(groupId, from, limit);
    return result;
  } catch (error) {
    console.error('Error listing group proposals:', error);
    return [];
  }
}

/**
 * Audit proposals for a specific asset
 * @param {Object} governanceActor - The governance canister actor
 * @param {number} assetId - The asset ID to audit
 * @returns {Promise<Array>} Array of proposal audit data for the asset
 */
export async function auditAsset(governanceActor, assetId) {
  try {
    const result = await governanceActor.auditAsset(assetId);
    return result;
  } catch (error) {
    console.error('Error auditing asset:', error);
    return [];
  }
}

/**
 * Audit member participation in a group
 * @param {Object} governanceActor - The governance canister actor
 * @param {number} groupId - The group ID
 * @param {string} principal - The principal ID to audit
 * @returns {Promise<Array>} Array of proposal IDs the member participated in
 */
export async function auditMember(governanceActor, groupId, principal) {
  try {
    const result = await governanceActor.auditMember(groupId, principal);
    return result;
  } catch (error) {
    console.error('Error auditing member:', error);
    return [];
  }
}

/**
 * Get system information
 * @param {Object} governanceActor - The governance canister actor
 * @returns {Promise<Object>} System info with totals and counters
 */
export async function auditSystemInfo(governanceActor) {
  try {
    const result = await governanceActor.auditSystemInfo();
    return result;
  } catch (error) {
    console.error('Error getting system info:', error);
    return {
      totalMembers: 0,
      totalAssets: 0,
      totalProposals: 0,
      rulesVersion: 0,
    };
  }
}
