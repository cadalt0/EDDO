# API Reference - EDDO

Complete function signatures, parameters, and return values for all contracts.

## Table of Contents

1. [AccessControl API](#accesscontrol-api)
2. [RulesEngine API](#rulesengine-api)
3. [RuleSet API](#ruleset-api)
4. [AllowListResolver API](#allowlistresolver-api)
5. [RWA_ERC20 API](#rwa_erc20-api)
6. [RWA_ERC721 API](#rwa_erc721-api)
7. [Policy Registry API](#policy-registry-api)
8. [CircuitBreaker API](#circuitbreaker-api)
9. [Timelock API](#timelock-api)
10. [Rules APIs](#rules-apis)

---

## AccessControl API

**Contract:** [contracts/governance/AccessControl.sol](../contracts/governance/AccessControl.sol)

### Role Constants

```solidity
bytes32 public constant DEFAULT_ADMIN_ROLE = 0x0000000000000000000000000000000000000000000000000000000000000000;
bytes32 public constant ADMIN_ROLE = keccak256("ADMIN");
bytes32 public constant POLICY_MANAGER_ROLE = keccak256("POLICY_MANAGER");
bytes32 public constant RULE_MANAGER_ROLE = keccak256("RULE_MANAGER");
bytes32 public constant IDENTITY_MANAGER_ROLE = keccak256("IDENTITY_MANAGER");
bytes32 public constant PAUSER_ROLE = keccak256("PAUSER");
bytes32 public constant MINTER_ROLE = keccak256("MINTER");
bytes32 public constant BURNER_ROLE = keccak256("BURNER");
```

### Functions

#### grantRole

```solidity
function grantRole(bytes32 role, address account) external onlyRole(DEFAULT_ADMIN_ROLE)
```

**Parameters:**
- `role` (bytes32): Role identifier (use constants above)
- `account` (address): Address to grant role to

**Emits:** `RoleGranted(role, account, msg.sender)`

**Example:**
```javascript
await accessControl.grantRole(RULE_MANAGER_ROLE, "0x...");
```

#### revokeRole

```solidity
function revokeRole(bytes32 role, address account) external onlyRole(DEFAULT_ADMIN_ROLE)
```

**Parameters:**
- `role` (bytes32): Role identifier
- `account` (address): Address to revoke role from

**Emits:** `RoleRevoked(role, account, msg.sender)`

#### hasRole

```solidity
function hasRole(bytes32 role, address account) external view returns (bool)
```

**Parameters:**
- `role` (bytes32): Role identifier
- `account` (address): Address to check

**Returns:**
- `bool`: True if account has role

**Example:**
```javascript
const isManager = await accessControl.hasRole(RULE_MANAGER_ROLE, address);
```

#### renounceRole

```solidity
function renounceRole(bytes32 role) external
```

**Parameters:**
- `role` (bytes32): Role to renounce

**Note:** User renounces their own role (not someone else's)

---

## RulesEngine API

**Contract:** [contracts/core/RulesEngine.sol](../contracts/core/RulesEngine.sol)

### Data Types

```solidity
enum EvaluationMode {
    SHORT_CIRCUIT,    // 0 - Stop on first failure
    ALL_MUST_PASS,    // 1 - All rules must pass
    ANY_MUST_PASS     // 2 - At least one must pass
}

struct RuleResult {
    bool passed;       // Did rule pass?
    string reason;     // Human-readable explanation
    string ruleId;     // Which rule evaluated this
}
```

### Functions

#### evaluate

```solidity
function evaluate(IContext context) external view returns (RuleResult memory)
```

**Parameters:**
- `context` (IContext): Transaction context

**Returns:**
- `RuleResult`: Pass/fail with reason

**Example:**
```javascript
const result = await rulesEngine.evaluate(contextAddress);
if (!result.passed) {
  console.log("Transfer blocked:", result.reason);
}
```

#### getRuleSet

```solidity
function getRuleSet(IContext.OperationType opType) external view returns (address)
```

**Parameters:**
- `opType` (IContext.OperationType): Operation type (0=TRANSFER, 1=MINT, etc.)

**Returns:**
- `address`: RuleSet contract address

#### setRuleSet

```solidity
function setRuleSet(IContext.OperationType opType, address ruleSet) 
    external 
    onlyRole(RULE_MANAGER_ROLE)
```

**Parameters:**
- `opType` (IContext.OperationType): Operation type
- `ruleSet` (address): New RuleSet address

**Emits:** `RuleSetUpdated(opType, ruleSet)`

#### setEvaluationMode

```solidity
function setEvaluationMode(EvaluationMode mode) 
    external 
    onlyRole(RULE_MANAGER_ROLE)
```

**Parameters:**
- `mode` (EvaluationMode): Evaluation strategy

---

## RuleSet API

**Contract:** [contracts/core/RuleSet.sol](../contracts/core/RuleSet.sol)

### Data Types

```solidity
struct RuleEntry {
    IRule rule;         // Rule contract
    uint8 priority;     // 0-255 (lower = evaluated first)
    bool mandatory;     // Must pass if true
    bool enabled;       // True if evaluates
}
```

### Functions

#### addRule

```solidity
function addRule(
    address rule,
    uint8 priority,
    bool mandatory
) external onlyRole(RULE_MANAGER_ROLE)
```

**Parameters:**
- `rule` (address): Rule contract address
- `priority` (uint8): Priority (0=highest)
- `mandatory` (bool): Must pass?

**Example:**
```javascript
await ruleSet.addRule(blacklistRule, 0, true);
```

#### removeRule

```solidity
function removeRule(address rule) external onlyRole(RULE_MANAGER_ROLE)
```

**Parameters:**
- `rule` (address): Rule to remove

#### enableRule

```solidity
function enableRule(address rule) external onlyRole(RULE_MANAGER_ROLE)
```

**Parameters:**
- `rule` (address): Rule to enable

#### disableRule

```solidity
function disableRule(address rule) external onlyRole(RULE_MANAGER_ROLE)
```

**Parameters:**
- `rule` (address): Rule to disable

#### getRules

```solidity
function getRules() external view returns (IRule[] memory)
```

**Returns:**
- `IRule[]`: Array of enabled rules in priority order

#### getRuleCount

```solidity
function getRuleCount() external view returns (uint256)
```

**Returns:**
- `uint256`: Number of rules (enabled or disabled)

---

## AllowListResolver API

**Contract:** [contracts/identity/AllowListResolver.sol](../contracts/identity/AllowListResolver.sol)

### Data Types

```solidity
enum IdentityTier {
    NONE,          // 0
    BASIC,         // 1
    INTERMEDIATE,  // 2
    ADVANCED,      // 3
    ACCREDITED     // 4
}

struct AttestationStatus {
    IdentityTier tier;      // KYC tier
    string jurisdiction;    // Country code
    uint256 expiresAt;     // Expiry timestamp
    bool verified;         // Currently valid?
}
```

### Functions

#### attestUser

```solidity
function attestUser(
    address subject,
    IdentityTier tier,
    string memory jurisdiction,
    uint256 daysValid
) external onlyRole(IDENTITY_MANAGER_ROLE)
```

**Parameters:**
- `subject` (address): User to attest
- `tier` (IdentityTier): KYC tier
- `jurisdiction` (string): Country code (e.g., "US")
- `daysValid` (uint256): Days until expiry

**Emits:** `UserAttested(subject, tier)`

**Example:**
```javascript
await resolver.attestUser(
  aliceAddress,
  2,      // INTERMEDIATE
  "US",
  365     // 1 year
);
```

#### revokeAttestation

```solidity
function revokeAttestation(address subject) 
    external 
    onlyRole(IDENTITY_MANAGER_ROLE)
```

**Parameters:**
- `subject` (address): User to revoke

**Emits:** `AttestationRevoked(subject)`

#### resolveIdentity

```solidity
function resolveIdentity(address subject) 
    external 
    view 
    returns (AttestationStatus memory)
```

**Parameters:**
- `subject` (address): User to query

**Returns:**
- `AttestationStatus`: Identity info

**Example:**
```javascript
const status = await resolver.resolveIdentity(aliceAddress);
console.log("Tier:", status.tier);
console.log("Verified:", status.verified);
```

#### updateTier

```solidity
function updateTier(address subject, IdentityTier newTier) 
    external 
    onlyRole(IDENTITY_MANAGER_ROLE)
```

**Parameters:**
- `subject` (address): User to update
- `newTier` (IdentityTier): New tier

---

## RWA_ERC20 API

**Contract:** [contracts/adapters/RWA_ERC20.sol](../contracts/adapters/RWA_ERC20.sol)

### Standard ERC20 Functions

#### transfer

```solidity
function transfer(address to, uint256 amount) external returns (bool)
```

**Checks:** RulesEngine.evaluate(context)

**Parameters:**
- `to` (address): Recipient
- `amount` (uint256): Amount to transfer

**Returns:** `bool` - True if successful

**Reverts If:**
- Rules not passed (with reason string)
- Insufficient balance
- Recipient is zero address

**Emits:** `Transfer(from, to, amount)`, `RuleCheckPassed(from, to, amount)`

#### transferFrom

```solidity
function transferFrom(
    address from,
    address to,
    uint256 amount
) external returns (bool)
```

**Checks:** RulesEngine.evaluate(context) and approve allowance

**Parameters:**
- `from` (address): Sender
- `to` (address): Recipient
- `amount` (uint256): Amount

**Returns:** `bool` - True if successful

#### approve

```solidity
function approve(address spender, uint256 amount) external returns (bool)
```

**Parameters:**
- `spender` (address): Address to approve
- `amount` (uint256): Amount

**Returns:** `bool` - True if successful

**Emits:** `Approval(owner, spender, amount)`

#### mint

```solidity
function mint(address to, uint256 amount) 
    external 
    onlyRole(MINTER_ROLE)
```

**Checks:** RulesEngine.evaluate(context) for MINT

**Parameters:**
- `to` (address): Recipient
- `amount` (uint256): Amount to mint

**Emits:** `Transfer(zero, to, amount)`, `RuleCheckPassed(...)`

#### burn

```solidity
function burn(uint256 amount) external
```

**Parameters:**
- `amount` (uint256): Amount to burn

**Emits:** `Transfer(caller, zero, amount)`

### View Functions

#### balanceOf

```solidity
function balanceOf(address account) external view returns (uint256)
```

**Parameters:**
- `account` (address): Account to query

**Returns:** `uint256` - Token balance

#### totalSupply

```solidity
function totalSupply() external view returns (uint256)
```

**Returns:** `uint256` - Total tokens in circulation

#### allowance

```solidity
function allowance(address owner, address spender) 
    external 
    view 
    returns (uint256)
```

**Returns:** `uint256` - Approved amount

#### getRulesEngine

```solidity
function getRulesEngine() external view returns (address)
```

**Returns:** `address` - Connected RulesEngine

### Admin Functions

#### setRulesEngine

```solidity
function setRulesEngine(address newEngine) 
    external 
    onlyRole(RULE_MANAGER_ROLE)
```

**Parameters:**
- `newEngine` (address): New RulesEngine address

**Emits:** `RulesEngineUpdated(newEngine)`

---

## RWA_ERC721 API

**Contract:** [contracts/adapters/RWA_ERC721.sol](../contracts/adapters/RWA_ERC721.sol)

### NFT Transfer Functions

#### transferFrom

```solidity
function transferFrom(
    address from,
    address to,
    uint256 tokenId
) external
```

**Checks:** RulesEngine for TRANSFER

**Parameters:**
- `from` (address): Current owner
- `to` (address): New owner
- `tokenId` (uint256): NFT ID

#### safeTransferFrom

```solidity
function safeTransferFrom(
    address from,
    address to,
    uint256 tokenId
) external
```

**Checks:** RulesEngine + safe receiver check

**Parameters:**
- `from` (address): Current owner
- `to` (address): New owner
- `tokenId` (uint256): NFT ID

### Minting Functions

#### mint

```solidity
function mint(address to, uint256 tokenId) 
    external 
    onlyRole(MINTER_ROLE)
```

**Checks:** RulesEngine for MINT

**Parameters:**
- `to` (address): Recipient
- `tokenId` (uint256): NFT ID

#### burn

```solidity
function burn(uint256 tokenId) 
    external 
    onlyRole(BURNER_ROLE)
```

**Parameters:**
- `tokenId` (uint256): NFT to burn

### View Functions

#### balanceOf

```solidity
function balanceOf(address owner) external view returns (uint256)
```

**Returns:** Number of NFTs owned

#### ownerOf

```solidity
function ownerOf(uint256 tokenId) external view returns (address)
```

**Returns:** Current owner of NFT

#### tokenURI

```solidity
function tokenURI(uint256 tokenId) external view returns (string memory)
```

**Returns:** Metadata URI for NFT

---

## Policy Registry API

**Contract:** [contracts/policy/PolicyRegistry.sol](../contracts/policy/PolicyRegistry.sol)

### Data Types

```solidity
enum PolicyStatus {
    DRAFT,      // 0
    STAGED,     // 1
    ACTIVE,     // 2
    DEPRECATED  // 3
}

struct Policy {
    uint256 version;
    address policyAddress;
    PolicyStatus status;
    uint256 stagedAt;
    uint256 activationTime;
}
```

### Functions

#### createPolicyDraft

```solidity
function createPolicyDraft(address policyAddress) 
    external 
    onlyRole(POLICY_MANAGER_ROLE) 
    returns (uint256 version)
```

**Parameters:**
- `policyAddress` (address): RuleSet or config address

**Returns:** `uint256` - New version number

**Emits:** `PolicyCreated(version, policyAddress)`

#### stagePolicy

```solidity
function stagePolicy(uint256 version, uint256 customDelay) 
    external 
    onlyRole(POLICY_MANAGER_ROLE)
```

**Parameters:**
- `version` (uint256): Policy version to stage
- `customDelay` (uint256): Activation delay (seconds)

**Default Delay:** 1 day (86400 seconds)

**Emits:** `PolicyStaged(version, activationTime)`

#### activatePolicy

```solidity
function activatePolicy(uint256 version) 
    external 
    onlyRole(POLICY_MANAGER_ROLE)
```

**Parameters:**
- `version` (uint256): Policy to activate

**Requires:**
- Current time >= activationTime
- Status is STAGED

**Emits:** `PolicyActivated(version)`

#### getCurrentPolicy

```solidity
function getCurrentPolicy() external view returns (uint256 version, address policyAddress)
```

**Returns:**
- `version`: Active policy version
- `policyAddress`: Active policy address

#### getPolicyStatus

```solidity
function getPolicyStatus(uint256 version) 
    external 
    view 
    returns (PolicyStatus)
```

**Returns:** Current status of policy

#### getPolicyCount

```solidity
function getPolicyCount() external view returns (uint256)
```

**Returns:** Total number of versions created

---

## CircuitBreaker API

**Contract:** [contracts/governance/CircuitBreaker.sol](../contracts/governance/CircuitBreaker.sol)

### Data Types

```solidity
enum CircuitBreakerState {
    CLOSED,      // 0 - Normal operation
    OPEN,        // 1 - Paused
    SAFE_MODE    // 2 - Limited operations
}

constant PAUSE_COOLDOWN = 1 hours
```

### Functions

#### pause

```solidity
function pause() external onlyRole(PAUSER_ROLE)
```

**Sets:** State to OPEN

**Requires:**
- 1+ hour since last pause attempt

**Emits:** `CircuitBreakerOpened()`

#### unpause

```solidity
function unpause() external onlyRole(DEFAULT_ADMIN_ROLE)
```

**Sets:** State to CLOSED

**Emits:** `CircuitBreakerClosed()`

#### setSafeMode

```solidity
function setSafeMode(bool enabled) 
    external 
    onlyRole(DEFAULT_ADMIN_ROLE)
```

**Parameters:**
- `enabled` (bool): Enable/disable safe mode

#### state

```solidity
function state() external view returns (CircuitBreakerState)
```

**Returns:** Current state

#### isClosed

```solidity
function isClosed() external view returns (bool)
```

**Returns:** True if CLOSED (normal operation)

#### isOpen

```solidity
function isOpen() external view returns (bool)
```

**Returns:** True if OPEN (paused)

---

## Timelock API

**Contract:** [contracts/governance/Timelock.sol](../contracts/governance/Timelock.sol)

### Constants

```solidity
uint256 public constant MINIMUM_DELAY = 2 days;
uint256 public constant MAXIMUM_DELAY = 30 days;
uint256 public constant GRACE_PERIOD = 14 days;
```

### Functions

#### queueTransaction

```solidity
function queueTransaction(
    address target,
    uint256 value,
    string memory signature,
    bytes memory data,
    uint256 eta
) external onlyRole(DEFAULT_ADMIN_ROLE)
```

**Parameters:**
- `target` (address): Contract to call
- `value` (uint256): ETH to send
- `signature` (string): Function signature
- `data` (bytes): Encoded parameters
- `eta` (uint256): Execution timestamp

**Requires:**
- eta >= now + MINIMUM_DELAY
- eta <= now + MAXIMUM_DELAY

**Returns:** Transaction hash

**Emits:** `QueuedTransaction(txHash, target, eta)`

**Example:**
```javascript
const delay = 2 * 24 * 60 * 60;  // 2 days
const eta = Math.floor(Date.now() / 1000) + delay;

const sig = "setMinimumTier(uint8,uint8)";
const data = ethers.utils.defaultAbiCoder.encode(
  ["uint8", "uint8"],
  [2, 4]
);

await timelock.queueTransaction(
  ruleAddress,
  0,
  sig,
  data,
  eta
);
```

#### executeTransaction

```solidity
function executeTransaction(
    address target,
    uint256 value,
    string memory signature,
    bytes memory data,
    uint256 eta
) external payable
```

**Requires:**
- Current time >= eta
- Current time <= eta + GRACE_PERIOD
- Transaction is queued

**Emits:** `ExecutedTransaction(txHash, target)`

#### cancelTransaction

```solidity
function cancelTransaction(
    address target,
    uint256 value,
    string memory signature,
    bytes memory data,
    uint256 eta
) external onlyRole(DEFAULT_ADMIN_ROLE)
```

**Removes:** Queued transaction

**Emits:** `CancelledTransaction(txHash)`

---

## Rules APIs

All rules follow the same interface:

```solidity
interface IRule {
    struct RuleResult {
        bool passed;
        string reason;
        string ruleId;
    }
    
    function evaluate(IContext context) 
        external 
        view 
        returns (RuleResult memory);
    
    function ruleId() external view returns (string memory);
}
```

### KYCTierRule

**Functions:**

```solidity
function setMinimumTier(uint8 actorTier, uint8 counterpartyTier) 
    external 
    onlyRole(RULE_MANAGER_ROLE)
```

```solidity
function setIdentityResolver(address resolver) 
    external 
    onlyRole(RULE_MANAGER_ROLE)
```

```solidity
function evaluate(IContext context) 
    external 
    view 
    returns (RuleResult memory)
```

### BlacklistRule

**Functions:**

```solidity
function addToBlacklist(
    address account,
    uint256 expiresAt,
    string memory reason
) external onlyRole(RULE_MANAGER_ROLE)
```

```solidity
function removeFromBlacklist(address account) 
    external 
    onlyRole(RULE_MANAGER_ROLE)
```

```solidity
function blacklist(address account) 
    external 
    view 
    returns (bool listed, uint256 expiresAt, string memory reason)
```

### JurisdictionRule

**Functions:**

```solidity
function setMode(uint8 mode) external onlyRole(RULE_MANAGER_ROLE)
```

```solidity
function addJurisdiction(string memory code) 
    external 
    onlyRole(RULE_MANAGER_ROLE)
```

```solidity
function removeJurisdiction(string memory code) 
    external 
    onlyRole(RULE_MANAGER_ROLE)
```

### LockupRule

**Functions:**

```solidity
function addLockup(
    address account,
    uint256 lockedUntil,
    uint256 amount,
    string memory reason
) external onlyRole(RULE_MANAGER_ROLE)
```

```solidity
function removeLockup(address account) 
    external 
    onlyRole(RULE_MANAGER_ROLE)
```

### SupplyCapRule

**Functions:**

```solidity
function setMaxSupply(uint256 max) 
    external 
    onlyRole(RULE_MANAGER_ROLE)
```

### VelocityRule

**Functions:**

```solidity
function setLimit(
    address account,
    uint256 maxAmount,
    uint256 windowDuration
) external onlyRole(RULE_MANAGER_ROLE)
```

---

## Common Patterns

### Encoding Function Data

```javascript
// For timelock queuing
const signature = "setMinimumTier(uint8,uint8)";
const data = ethers.utils.defaultAbiCoder.encode(
  ["uint8", "uint8"],
  [2, 4]
);
```

### Checking Roles

```javascript
const role = await contract.RULE_MANAGER_ROLE();
const hasRole = await accessControl.hasRole(role, userAddress);
```

### Creating Context

```javascript
const context = new ethers.Contract(
  contextAddress,
  [...],
  signer
);

// Or:
const context = await Context.deploy(
  actor,
  counterparty,
  amount,
  operationType
);
```

### Handling Errors

```javascript
try {
  await token.transfer(to, amount);
} catch (error) {
  if (error.reason) {
    console.log("Rule failed:", error.reason);
  } else {
    console.log("Transaction failed:", error);
  }
}
```

---

## Gas Usage Reference

Estimated gas per operation:

| Operation | Gas | Cost ($50/gwei) |
|-----------|-----|-----------------|
| transfer (1 rule) | 60,000 | $3 |
| transfer (3 rules) | 120,000 | $6 |
| mint | 80,000 | $4 |
| attestUser | 60,000 | $3 |
| addToBlacklist | 50,000 | $2.50 |
| setRuleSet | 40,000 | $2 |
| grantRole | 30,000 | $1.50 |
| pause | 25,000 | $1.25 |
| queueTransaction | 45,000 | $2.25 |
| executeTransaction | 50,000 | $2.50 |
