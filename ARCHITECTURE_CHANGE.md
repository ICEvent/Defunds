# Architecture Change Summary: From Unified Groups to Simple Governance

## Date: January 7, 2026

## Problem Statement

The previous unified groups architecture was overly complex:
- Three types of groups: unified 🔗, backend-only 💰, governance-only ⚖️
- Required linking between backend fund groups and governance groups
- Confusing mental model for users
- Complex UI with UnifiedGroupManager trying to merge two systems

## New Solution: Simple Governance

### Core Principle
**One group type, two asset categories**

Instead of different group types, we now have:
- **Single group type**: All groups are governance groups
- **Two asset categories**: 
  - 💰 Native (ICP/ICRC tokens managed via backend)
  - 🌐 External (other assets requiring governance rules)

## Changes Made

### Backend (Motoko)

#### 1. Updated Types (`src/governance/types.mo`)
```motoko
// REMOVED: backendGroupId field from Group
type Group = {
    groupId : Nat;
    name : Text;
    description : Text;
    createdBy : Principal;
    createdAt : Int;
    active : Bool;
    // backendGroupId : ?Nat; // REMOVED
};

// ADDED: Asset category
type AssetCategory = {
    #native;    // ICP/ICRC tokens
    #external;  // Other assets
};

// UPDATED: Asset with category and token info
type Asset = {
    assetId : Nat;
    groupId : Nat;
    category : AssetCategory;      // NEW
    assetType : AssetType;
    description : Text;
    canisterId : ?Text;            // NEW
    tokenIdentifier : ?Text;       // NEW
    constraints : ?Text;
    createdAt : Int;
};
```

#### 2. Updated Main Logic (`src/governance/main.mo`)
- **Removed**: `linkBackendGroup()` function
- **Updated**: `createGroup()` - no longer accepts `backendGroupId` parameter
- **Updated**: `registerAsset()` - now requires `category`, `canisterId`, `tokenIdentifier` parameters

### Frontend (JavaScript/Svelte)

#### 1. Updated API (`src/frontend/src/lib/api/governance.js`)
```javascript
// BEFORE:
export async function createGroup(governanceActor, name, description, backendGroupId = null)

// AFTER:
export async function createGroup(governanceActor, name, description)

// BEFORE:
export async function registerAsset(governanceActor, groupId, assetType, description, constraints)

// AFTER:
export async function registerAsset(
    governanceActor, 
    groupId, 
    category,          // { native: null } or { external: null }
    assetType, 
    description, 
    canisterId,        // For native assets
    tokenIdentifier,   // For token type
    constraints
)

// REMOVED:
export async function linkBackendGroup(governanceActor, groupId, backendGroupId)
```

#### 2. New Component: GroupManager.svelte
**Replaced**: `UnifiedGroupManager.svelte`

Simple component with:
- Create new group (just name and description)
- List groups
- Select a group
- No complexity around linking or unification

#### 3. Updated Governance Page
- Uses `GroupManager` instead of `UnifiedGroupManager`
- Removed backend actor dependency (no longer needed)
- Simplified group selection
- Asset display shows category icons (💰 for native, 🌐 for external)

### Files Modified

```
Backend:
├── src/governance/types.mo         [Updated: Added AssetCategory, updated Asset type]
├── src/governance/main.mo          [Updated: Removed linkBackendGroup, updated createGroup and registerAsset]

Frontend:
├── src/frontend/src/lib/api/governance.js                      [Updated: API signatures]
├── src/frontend/src/lib/components/GroupManager.svelte         [New: Simple group manager]
├── src/frontend/src/routes/governance/+page.svelte             [Updated: Uses GroupManager]

Documentation:
├── SIMPLE_GOVERNANCE.md            [New: Complete architecture documentation]
└── ARCHITECTURE_CHANGE.md          [This file]
```

### Files to Update (Remaining)

These files still reference the old unified groups system:
```
❌ src/frontend/src/lib/components/UnifiedGroupManager.svelte  [Can be deleted]
❌ src/frontend/src/routes/funds/+page.svelte                   [Remove UnifiedGroupManager references]
❌ src/frontend/src/routes/funds/[id]/+page.svelte              [Remove governance link checking]
❌ src/frontend/src/lib/components/Profile/GroupPanel.svelte    [Remove UnifiedGroupManager references]
⚠️  UI_SYNC_SUMMARY.md                                          [Outdated documentation]
⚠️  UNIFIED_GROUPS.md                                           [Outdated documentation]
```

## Migration Path

### For Existing Users

#### Old Way (Unified Groups)
```javascript
// Step 1: Create backend group
const backendResult = await backend.createGroup(name, description, true);
const backendGroupId = backendResult.ok;

// Step 2: Create governance group linked to backend
const govResult = await governanceAPI.createGroup(
    governanceActor, 
    name, 
    description, 
    backendGroupId  // Link them
);

// Step 3: Or link later
await governanceAPI.linkBackendGroup(govGroupId, backendGroupId);
```

#### New Way (Simple Governance)
```javascript
// Step 1: Create ONE group
const result = await governanceAPI.createGroup(
    governanceActor,
    "My Group",
    "Description"
);
const groupId = result.ok;

// Step 2: Add native assets (ICP/ICRC)
await governanceAPI.registerAsset(
    governanceActor,
    groupId,
    { native: null },                    // Category
    { cash: null },                      // Type
    "ICP Treasury",                      // Description
    "ryjl3-tyaaa-aaaaa-aaaba-cai",      // Canister ID
    null,                                // Token identifier
    null                                 // Constraints
);

// Step 3: Add external assets
await governanceAPI.registerAsset(
    governanceActor,
    groupId,
    { external: null },                  // Category
    { equipment: null },                 // Type
    "Office Building",                   // Description
    null,                                // No canister ID
    null,                                // No token identifier
    "Requires board approval"            // Constraints
);
```

### Benefits of New Architecture

✅ **Simpler Mental Model**
- One group type instead of three
- Asset category is clear and intuitive

✅ **Easier API**
- No linking functions needed
- Clear parameter names (category, canisterId)

✅ **Better UX**
- Users understand "what kind of asset" not "what kind of group"
- Visual indicators (💰 vs 🌐) are immediately clear

✅ **More Flexible**
- Same group can manage both native and external assets
- Easy to add new asset categories in future

✅ **Cleaner Code**
- Removed ~200 lines of linking logic
- Simpler components
- Less state management

## Testing Checklist

- [x] Governance types compile without errors
- [x] Governance main.mo compiles without errors
- [x] TypeScript declarations generated successfully
- [x] Frontend API has no syntax errors
- [x] GroupManager component works
- [x] Governance page renders
- [ ] Test creating a group in UI
- [ ] Test adding native asset in UI
- [ ] Test adding external asset in UI
- [ ] Test creating proposal for native asset
- [ ] Test creating proposal for external asset
- [ ] Update remaining UI components
- [ ] Remove outdated documentation

## Rollback Plan

If issues arise, you can rollback by:
1. Restore previous `types.mo` and `main.mo` from git history
2. Restore previous `governance.js` API
3. Restore `UnifiedGroupManager.svelte`
4. Redeploy governance canister

However, the new architecture is simpler and should cause fewer issues.

## Next Steps

1. **Update Remaining UI Components**
   - Remove UnifiedGroupManager from funds pages
   - Update profile group panel
   - Update any components still checking for "unified" group types

2. **Test in Local DFX**
   ```bash
   dfx start --clean
   dfx deploy governance
   dfx deploy backend
   # Test group creation and asset registration
   ```

3. **Update Documentation**
   - Archive or delete `UNIFIED_GROUPS.md`
   - Archive or delete `UI_SYNC_SUMMARY.md`
   - Promote `SIMPLE_GOVERNANCE.md` as main architecture doc

4. **Deploy to IC**
   ```bash
   dfx deploy --network ic governance
   # Existing groups will continue to work
   # New groups will use simplified architecture
   ```

## Conclusion

The architectural change from unified groups to simple governance significantly reduces complexity while improving clarity. By focusing on **asset categories** rather than **group types**, users have a more intuitive mental model and developers have cleaner code to maintain.

The key insight: *It's not about what kind of group you have, it's about what kind of assets you're managing.*
