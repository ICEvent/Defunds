# Simple Governance Architecture

## Overview

This is a simplified, unified governance architecture with **one group type** that can manage both **native assets** (ICP/ICRC tokens) and **external assets** (other assets requiring governance rules).

## Key Concepts

### Single Group Type
- All groups are governance groups
- Groups manage both native and external assets
- No separate "backend fund groups" vs "governance groups"

### Two Asset Categories

#### 1. Native Assets 💰
- ICP and ICRC tokens
- Managed through backend subaccounts
- Direct fund management (deposits, withdrawals, transfers)
- Examples: ICP, ckBTC, SNS tokens

#### 2. External Assets 🌐
- Assets outside the IC ecosystem
- Require governance rules and voting
- Proposals must be approved before execution
- Examples: Bank accounts, real estate, equipment

## Data Model

### Group
```motoko
type Group = {
    groupId : Nat;
    name : Text;
    description : Text;
    createdBy : Principal;
    createdAt : Int;
    active : Bool;
};
```

### Asset with Category
```motoko
type AssetCategory = {
    #native;    // ICP/ICRC tokens
    #external;  // Other assets
};

type AssetType = {
    #cash;
    #grant;
    #equipment;
    #other;
};

type Asset = {
    assetId : Nat;
    groupId : Nat;
    category : AssetCategory;  // NEW: native or external
    assetType : AssetType;
    description : Text;
    canisterId : ?Text;        // For native tokens
    tokenIdentifier : ?Text;   // For specific token types
    constraints : ?Text;
    createdAt : Int;
};
```

## API

### Create Group
```javascript
import * as governanceAPI from '$lib/api/governance';

// Simple group creation - no backend linking needed
const result = await governanceAPI.createGroup(
    governanceActor,
    "My DAO Group",
    "A group managing both native ICP and external assets"
);

if (result.ok !== undefined) {
    const groupId = result.ok;
    // Group created!
}
```

### Register Native Asset (ICP/ICRC)
```javascript
const result = await governanceAPI.registerAsset(
    governanceActor,
    groupId,
    { native: null },           // Asset category
    { cash: null },             // Asset type
    "ICP Treasury",             // Description
    "ryjl3-tyaaa-aaaaa-aaaba-cai",  // ICP Ledger canister ID
    null,                       // Token identifier (optional)
    "For project funding"       // Constraints (optional)
);
```

### Register External Asset
```javascript
const result = await governanceAPI.registerAsset(
    governanceActor,
    groupId,
    { external: null },         // Asset category
    { equipment: null },        // Asset type
    "Office Building",          // Description
    null,                       // No canister ID
    null,                       // No token identifier
    "Requires board approval"   // Constraints
);
```

## Use Cases

### Use Case 1: DAO Treasury Management
**Scenario:** A DAO needs to manage ICP treasury with governance

```javascript
// 1. Create group
const groupResult = await governanceAPI.createGroup(
    governanceActor,
    "DAO Treasury",
    "Main treasury for project funding"
);
const groupId = groupResult.ok;

// 2. Add native ICP asset
await governanceAPI.registerAsset(
    governanceActor,
    groupId,
    { native: null },
    { cash: null },
    "ICP Treasury",
    "ryjl3-tyaaa-aaaaa-aaaba-cai",
    null,
    null
);

// 3. Set governance rules
await governanceAPI.setRule(
    governanceActor,
    groupId,
    null,  // Applies to all assets
    3,     // 3 votes required
    5,     // 5 members must participate
    86400  // 24 hour timelock
);

// 4. Create proposal to spend ICP
await governanceAPI.createProposal(
    governanceActor,
    groupId,
    assetId,
    100_000_000,  // 1 ICP in e8s
    "Fund new developer",
    "recipient-principal",
    "evidence-hash",
    ruleId
);
```

### Use Case 2: Mixed Asset Management
**Scenario:** Manage both ICP tokens and external real estate

```javascript
// Same group manages both!
const groupId = 42;

// Native asset
await governanceAPI.registerAsset(
    governanceActor,
    groupId,
    { native: null },
    { cash: null },
    "ICP Operating Funds",
    "ryjl3-tyaaa-aaaaa-aaaba-cai",
    null,
    null
);

// External asset
await governanceAPI.registerAsset(
    governanceActor,
    groupId,
    { external: null },
    { equipment: null },
    "Office Space in SF",
    null,
    null,
    "Requires unanimous approval for sale"
);
```

## UI Components

### GroupManager.svelte
Simple component for group creation and selection:

```svelte
<GroupManager
    {governanceActor}
    on:groupSelected={handleGroupSelected}
/>
```

Features:
- Create new groups
- List all groups
- Select a group
- No complexity around "unified" vs "backend-only"

### Visual Indicators

Assets are displayed with category indicators:
- 💰 Native assets (ICP/ICRC)
- 🌐 External assets (governance-controlled)

## Migration from Old Architecture

If you were using the old unified groups system:

### Before (Unified Groups)
```javascript
// Had to create backend group AND governance group
const backendResult = await backend.createGroup(...);
const govResult = await governanceAPI.createGroup(..., backendResult.ok);

// Or use UnifiedGroupManager component
```

### After (Simple Governance)
```javascript
// Just create ONE group
const result = await governanceAPI.createGroup(
    governanceActor,
    name,
    description
);

// Then add assets with categories
await governanceAPI.registerAsset(
    governanceActor,
    groupId,
    { native: null },  // or { external: null }
    ...
);
```

## Backend Integration

For native assets, the governance canister can:
1. Query backend for group subaccount balances
2. Initiate transfers through backend after proposal approval
3. Track fund movements alongside governance records

The backend canister continues to handle actual ICP/ICRC transfers, while governance handles approval workflow.

## Benefits

✅ **Simpler mental model** - one group type, not three
✅ **Clear asset distinction** - native vs external, not group types
✅ **Easier onboarding** - users understand "what kind of asset" not "what kind of group"
✅ **Flexible** - same group can manage both native and external assets
✅ **Clean API** - no complex linking between systems
✅ **Future-proof** - easy to add new asset categories

## Summary

The new architecture is cleaner and more intuitive:
- **One group type** (governance groups)
- **Two asset categories** (native 💰 or external 🌐)
- **Simple creation flow** (no linking, no unification)
- **Clear purpose** (asset category tells you how it's managed)

This makes it easier for users to understand and for developers to maintain.
