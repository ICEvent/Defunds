/**
 * Governance API Service
 * Provides functions to interact with the governance canister
 */

/**
 * Add a member to the governance system
 * @param {Object} governanceActor - The governance canister actor
 * @param {string} principal - The principal ID of the member to add
 * @param {Array} roles - Array of roles to assign (e.g., ['admin', 'voter', 'proposer'])
 * @returns {Promise<Object>} Result object with ok or err
 */
export async function addMember(governanceActor, principal, roles) {
  try {
    const result = await governanceActor.addMember(principal, roles);
    return result;
  } catch (error) {
    console.error('Error adding member:', error);
    return { err: error.message };
  }
}

/**
 * Register an asset in the governance system
 * @param {Object} governanceActor - The governance canister actor
 * @param {Object} assetType - The type of asset (e.g., { treasury: null } or { grant: null })
 * @param {string} description - Description of the asset
 * @param {string} constraints - Optional constraints on the asset
 * @returns {Promise<Object>} Result with asset ID or error
 */
export async function registerAsset(governanceActor, assetType, description, constraints = null) {
  try {
    const constraintsOpt = constraints ? [constraints] : [];
    const result = await governanceActor.registerAsset(assetType, description, constraintsOpt);
    return result;
  } catch (error) {
    console.error('Error registering asset:', error);
    return { err: error.message };
  }
}

/**
 * Set a governance rule
 * @param {Object} governanceActor - The governance canister actor
 * @param {number} assetId - Optional asset ID this rule applies to
 * @param {number} threshold - Minimum approvals needed
 * @param {number} quorum - Minimum votes required
 * @param {number} timelock - Optional timelock in nanoseconds
 * @returns {Promise<Object>} Result with rule ID or error
 */
export async function setRule(governanceActor, assetId = null, threshold, quorum, timelock = null) {
  try {
    const assetIdOpt = assetId !== null ? [assetId] : [];
    const timelockOpt = timelock !== null ? [timelock] : [];
    const result = await governanceActor.setRule(assetIdOpt, threshold, quorum, timelockOpt);
    return result;
  } catch (error) {
    console.error('Error setting rule:', error);
    return { err: error.message };
  }
}

/**
 * Create a proposal
 * @param {Object} governanceActor - The governance canister actor
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
 * Audit member participation
 * @param {Object} governanceActor - The governance canister actor
 * @param {string} principal - The principal ID to audit
 * @returns {Promise<Array>} Array of proposal IDs the member participated in
 */
export async function auditMember(governanceActor, principal) {
  try {
    const result = await governanceActor.auditMember(principal);
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
