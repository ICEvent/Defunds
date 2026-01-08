# Unified Group Architecture

## Overview

The system now supports a **unified group architecture** that merges two distinct group types:

1. **Backend Groups (GroupFund)** - Native ICP/ICRC fund management
2. **Governance Groups** - External asset governance with voting and rules

## Architecture

### Three Group Types

1. **🔗 Unified Groups** - Have both native funds AND governance
   - Linked backend group + governance group
   - Full feature set: fund management + asset governance
   - Example: A DAO treasury managing both ICP donations and external grants

2. **💰 Backend-Only Groups** - Native funds without governance
   - Only fund management (proposals for ICP transfers)
   - No governance rules or external assets
   - Example: Simple shared wallet for a team

3. **⚖️ Governance-Only Groups** - External assets without native funds
   - Only governance features (rules, voting, authorizations)
   - No native ICP/ICRC balance
   - Example: Managing external grants or equipment

## Data Model

### Governance Group (Enhanced)
```motoko
public type Group = {
    groupId : Nat;
    name : Text;
    description : Text;
    createdBy : Principal;
    createdAt : Int;
    active : Bool;
    backendGroupId : ?Nat; // Optional link to backend group
};
```

### Backend Group (GroupFund)
```motoko
public type GroupFund = {
    id : Nat;
    name : Text;
    description : Text;
    creator : Principal;
    isPublic : Bool;
    members : [Member];
    balance : Nat;
    proposals : [Nat];
    createdAt : Int;
    account : [Nat8]; // Subaccount for funds
};
```

## Key Features

### Creating Unified Groups
Users can create groups with either or both capabilities:
- ✅ Native Funds Management (creates backend GroupFund)
- ✅ Governance & External Assets (creates governance Group)
- 🔗 Automatically links them if both are selected

### Linking Existing Groups
- Existing separate groups can be linked later
- `linkBackendGroup(governanceGroupId, backendGroupId)`
- Only group admins can create links

### Frontend Experience
- **UnifiedGroupManager** component shows all groups with visual indicators
- Groups display their capabilities with badges:
  - 💰 Native Funds
  - ⚖️ Governance
- Seamless switching between group types
- Context-aware UI (hides governance features for backend-only groups)

## API Functions

### Governance Canister

#### New/Updated Functions:
```motoko
// Create governance group with optional backend link
createGroup(name: Text, description: Text, backendGroupId: ?Nat) -> Result<Nat, Text>

// Link existing governance group to backend group
linkBackendGroup(groupId: Nat, backendGroupId: Nat) -> Result<(), Text>

// Existing group functions remain the same
getGroup(groupId: Nat) -> ?Group
listGroups() -> [Group]
// ... etc
```

### Backend Canister
```motoko
// Existing functions (unchanged)
createGroup(name: Text, description: Text, isPublic: Bool) -> Result<GroupFund, Text>
getGroup(groupId: Nat) -> ?GroupFund
getAllGroups() -> [GroupFund]
// ... etc
```

## Frontend API

### governance.js
```javascript
// Create governance group with optional backend link
createGroup(governanceActor, name, description, backendGroupId = null)

// Link existing groups
linkBackendGroup(governanceActor, groupId, backendGroupId)
```

### Components

#### UnifiedGroupManager.svelte
- Displays all groups (governance, backend, and unified)
- Create form with capability checkboxes
- Visual indicators for group types
- Automatic linking when creating unified groups

#### Updated governance/+page.svelte
- Uses UnifiedGroupManager instead of simple GroupSelector
- Shows appropriate features based on group type
- Gracefully handles backend-only groups

## Use Cases

### 1. DAO Treasury (Unified)
```
Create: ✅ Native Funds + ✅ Governance
- Receive ICP donations via backend group
- Governance proposals for external grants
- Voting on both fund transfers and asset usage
```

### 2. Team Wallet (Backend-Only)
```
Create: ✅ Native Funds only
- Simple shared ICP wallet
- Proposals for fund transfers
- No complex governance rules
```

### 3. Grant Management (Governance-Only)
```
Create: ✅ Governance only
- Manage external grant applications
- Voting rules and thresholds
- No native funds involved
```

### 4. Upgrading Groups
```
Start: Backend-only group (team wallet)
Later: Create governance group → Link them
Result: Unified group with both capabilities
```

## Benefits

1. **Flexibility** - Groups can have exactly the features they need
2. **Separation of Concerns** - Fund management and governance remain independent
3. **Gradual Adoption** - Start simple, add governance later
4. **Clear Architecture** - Each canister has a focused responsibility
5. **No Breaking Changes** - Existing groups continue to work

## Migration Path

### Existing Groups
- All existing backend groups remain functional
- All existing governance groups remain functional
- No data migration required

### Adding Links
1. Identify related backend and governance groups
2. Call `linkBackendGroup()` as admin
3. Groups now appear as unified in UI

## Development Notes

### File Changes
- `src/governance/types.mo` - Added `backendGroupId` field
- `src/governance/main.mo` - Added `linkBackendGroup()` function
- `src/frontend/src/lib/api/governance.js` - Updated API functions
- `src/frontend/src/lib/components/UnifiedGroupManager.svelte` - New component
- `src/frontend/src/routes/governance/+page.svelte` - Updated to use unified manager

### Testing Checklist
- [ ] Create backend-only group
- [ ] Create governance-only group
- [ ] Create unified group (both features)
- [ ] Link existing separate groups
- [ ] Verify fund management works
- [ ] Verify governance proposals work
- [ ] Test member management in both systems
- [ ] Verify UI shows correct badges and features

## Future Enhancements

1. **Auto-sync members** - Keep governance and backend members in sync
2. **Unified proposals** - Single proposal type that can affect both funds and governance
3. **Cross-group references** - Allow governance rules to reference fund balances
4. **Group templates** - Pre-configured group setups for common use cases
