# Contracts Reference - EDDO

Complete reference for all 27 contracts, organized by module, with explanations and usage patterns.

## Table of Contents

1. [Overview](#overview)
2. [Interfaces (6)](#interfaces-6-files)
3. [Core Engine (4)](#core-engine-4-files)
4. [Policy Management (1)](#policy-management-1-file)
5. [Identity Resolution (2)](#identity-resolution-2-files)
6. [Asset Adapters (2)](#asset-adapters-2-files)
7. [Governance (3)](#governance-3-files)
8. [Compliance Rules (6)](#compliance-rules-6-files)
9. [Utility Libraries (3)](#utility-libraries-3-files)
10. [Total Statistics](#total-statistics)

---

## Overview

**27 Total Contracts** organized into 8 logical modules:

```
Interfaces (6)           ← Define all contracts APIs
    ↓
Core Engine (4)          ← Rules evaluation & context
    ↓
↙ ↓ ↘
Adapters (2)  Rules (6)  Identity (2)  Policy (1)  Governance (3)  Libraries (3)
```

Each contract is independently testable, auditable, and can be upgraded or replaced without affecting others.

---

## INTERFACES (6 files)

All contracts implement these interfaces for pluggability and consistency.

### 1. IContext.sol
**Purpose:** Define transaction evaluation context

```solidity
interface IContext {
    enum OperationType {
        TRANSFER,    // transfer() operation
        MINT,        // mint() operation  
        BURN,        // burn() operation
        APPROVE,     // approve() operation
        CUSTOM       // Custom operation
    }
    
    function actor() external view returns (address);
    function counterparty() external view returns (address);
    function amount() external view returns (uint256);
    function operationType() external view returns (OperationType);
    function timestamp() external view returns (uint256);
}
```

**When Used:** Every rule evaluation requires a context. Created fresh for each transaction.

**Example Creation:**
```solidity
IContext context = new Context(
    msg.sender,      // actor (who initiates)
    to,              // counterparty (who receives)
    amount,          // transfer amount
    IContext.OperationType.TRANSFER
);
```

---

### 2. IRule.sol
**Purpose:** Define rule interface all compliance rules implement

```solidity
interface IRule {
    struct RuleResult {
        bool passed;       // true = allow, false = block
        string reason;     // Human-readable explanation
        string ruleId;     // Rule identifier
    }
    
    function evaluate(IContext context) external view returns (RuleResult memory);
    function ruleId() external view returns (string memory);
}
```

**When Used:** Rules engine calls this interface to evaluate compliance.

**Key Property:** Every rule is pure (no state mutations) - same input always gives same output.

---

### 3. IRulesEngine.sol
**Purpose:** Define rules evaluation orchestration interface

```solidity
interface IRulesEngine {
    enum EvaluationMode {
        SHORT_CIRCUIT,   // Stop on first failure (most common)
        ALL_MUST_PASS,   // Every rule must pass
        ANY_MUST_PASS    // At least one must pass
    }
    
    function evaluate(IContext context) external view returns (RuleResult memory);
    function getRuleSet(IContext.OperationType opType) external view returns (address);
    function setRuleSet(IContext.OperationType opType, address ruleSet) external;
}
```

**When Used:** Tokens call this to check if transaction should be allowed.

**Modes Explained:**
- **SHORT_CIRCUIT**: Stops on first failure (efficient, recommended)
- **ALL_MUST_PASS**: All rules must pass (strictest)
- **ANY_MUST_PASS**: Any rule can approve (most permissive, rare)

---

### 4. IIdentityResolver.sol
**Purpose:** Define identity attestation interface

```solidity
interface IIdentityResolver {
    enum IdentityTier {
        NONE,          // Not verified
        BASIC,         // Basic KYC
        INTERMEDIATE,  // Financial info included
        ADVANCED,      // Pre-accredited checks
        ACCREDITED     // Full accredited investor
    }
    
    struct AttestationStatus {
        IdentityTier tier;      // Current tier
        string jurisdiction;    // Country (e.g., "US", "SG")
        uint256 expiresAt;     // Expiry timestamp
        bool verified;         // Currently valid
    }
    
    function resolveIdentity(address subject) 
        external view returns (AttestationStatus memory);
}
```

**When Used:** Rules call this to check user's KYC status.

**Tier Progression:** NONE → BASIC → INTERMEDIATE → ADVANCED → ACCREDITED

---

### 5. IPolicyRegistry.sol
**Purpose:** Define policy versioning interface

```solidity
interface IPolicyRegistry {
    enum PolicyStatus {
        DRAFT,       // Being edited
        STAGED,      // Ready for activation (waiting period)
        ACTIVE,      // Currently enforced
        DEPRECATED   // Superseded
    }
    
    function getCurrentPolicy() external view returns (uint256 version, address address);
    function getPolicyStatus(uint256 version) external view returns (PolicyStatus);
    function stagePolicy(uint256 version, uint256 activationDelay) external;
    function activatePolicy(uint256 version) external;
}
```

**When Used:** Governance to manage policy versions with transparency.

**Workflow:** DRAFT → STAGED (+ delay) → ACTIVE

---

### 6. IRWAAdapter.sol
**Purpose:** Define asset adapter interface

```solidity
interface IRWAAdapter {
    function getRulesEngine() external view returns (address);
    function setRulesEngine(address newEngine) external;
    function checkRules(
        address actor,
        address counterparty,
        uint256 amount,
        IContext.OperationType opType
    ) external view returns (bool passed, string memory reason);
}
```

**When Used:** Common interface for all asset adapters (ERC20, ERC721, etc.)

**Key Concept:** Different token standards, but same rules checking mechanism.

---

## CORE ENGINE (4 files)

The heart of the system - evaluates rules against transactions.

### 7. Context.sol
**Location:** [contracts/core/Context.sol](../contracts/core/Context.sol)

**Purpose:** Immutable snapshot of a transaction

**Key Variables:**
```solidity
address public immutable actor;           // Who initiated
address public immutable counterparty;    // Who receives
uint256 public immutable amount;          // How much
OperationType public immutable operationType;  // What operation
uint256 public immutable timestamp;       // When
```

**Why Immutable?**
- Rules can safely read without locking
- Gas savings (immutable uses less gas)
- Prevents mutations mid-evaluation

**Usage:**
```solidity
// Created in token transfer function
Context ctx = new Context(
    msg.sender, to, amount, OperationType.TRANSFER
);

// Rules read it
(bool allowed, string reason) = rulesEngine.evaluate(ctx);
```

**Important:** Once created, cannot be modified. This ensures rules see consistent data.

---

### 8. BaseRule.sol
**Location:** [contracts/core/BaseRule.sol](../contracts/core/BaseRule.sol)

**Purpose:** Abstract base class for all rules

**Key Methods:**
```solidity
abstract contract BaseRule is IRule {
    string public ruleId;
    
    // Helper: Return pass result
    function _pass() internal view returns (RuleResult memory) {
        return RuleResult({passed: true, reason: "Rule passed", ruleId: ruleId});
    }
    
    // Helper: Return fail result
    function _fail(string memory reason) internal view returns (RuleResult memory) {
        return RuleResult({passed: false, reason: reason, ruleId: ruleId});
    }
    
    // Subclass implements this
    function evaluate(IContext context) external view virtual returns (RuleResult memory);
}
```

**Why Abstract?**
- Provides standard `_pass()` and `_fail()` helpers
- Ensures all rules return correct structure
- Reduces code duplication across 6 rules

**Usage Pattern:**
```solidity
contract MyRule is BaseRule {
    constructor() BaseRule("my-rule-id") {}
    
    function evaluate(IContext context) external view override returns (RuleResult memory) {
        if (checkCondition(context)) {
            return _pass();  // Helper method
        }
        return _fail("Condition failed");  // Helper method
    }
}
```

---

### 9. RuleSet.sol
**Location:** [contracts/core/RuleSet.sol](../contracts/core/RuleSet.sol)

**Purpose:** Container for rules with priority and flags

**Key Structures:**
```solidity
contract RuleSet is IRuleSet {
    struct RuleEntry {
        IRule rule;           // The rule contract
        uint8 priority;       // 0-255, lower = higher priority
        bool mandatory;       // true = must pass, false = optional
        bool enabled;         // true = evaluated, false = skipped
    }
    
    RuleEntry[] public rules;
    mapping(address => bool) public ruleExists;
}
```

**Operations:**
```solidity
// Add rule
addRule(ruleAddress, priority=1, mandatory=true);

// Enable/disable without removing
enableRule(ruleAddress);
disableRule(ruleAddress);

// Get ordered rules for evaluation
getRules() returns (IRule[]);
```

**Priority System:**
```
Priority 0 (highest) → Evaluated first
Priority 1          → Evaluated second
Priority 255 (lowest) → Evaluated last
```

**Why Priorities?**
- Expensive checks last (short-circuit saves gas)
- Critical checks first (fail fast)

**Example:**
```solidity
// This ruleset evaluates in order:
ruleset.addRule(blacklistRule, 0, true);    // Check first (cheap)
ruleset.addRule(kycRule, 1, true);          // Check second (moderate)
ruleset.addRule(velocityRule, 2, true);     // Check last (expensive)
```

---

### 10. RulesEngine.sol
**Location:** [contracts/core/RulesEngine.sol](../contracts/core/RulesEngine.sol)

**Purpose:** Evaluates ruleset for a transaction

**Key Concept:**
```solidity
contract RulesEngine is IRulesEngine {
    // Different rules for different operation types
    mapping(IContext.OperationType => address) public ruleSets;
    
    // Evaluate context against the ruleset for that operation
    function evaluate(IContext context) external view returns (RuleResult memory) {
        address ruleSetAddr = ruleSets[context.operationType()];
        // ... evaluate all rules in that set
    }
}
```

**Evaluation Flow:**
```
1. Create Context (who, what, when, amount)
2. Call rulesEngine.evaluate(context)
3. Engine looks up ruleset for operation type
4. Engine loops through rules (SHORT_CIRCUIT mode):
   - Evaluates each rule with context
   - If any fails: returns FAIL immediately
   - If all pass: returns PASS
5. Caller checks result.passed
```

**Configuration:**
```solidity
// Set rules for different operations
rulesEngine.setRuleSet(
    IContext.OperationType.TRANSFER,
    transferRulesetAddress
);

rulesEngine.setRuleSet(
    IContext.OperationType.MINT,
    mintRulesetAddress  // Different rules for minting
);
```

**Important:** Different operations can have different rule requirements.

---

## POLICY MANAGEMENT (1 file)

Manages policy versioning with staged activation.

### 11. PolicyRegistry.sol
**Location:** [contracts/policy/PolicyRegistry.sol](../contracts/policy/PolicyRegistry.sol)

**Purpose:** Versioned policy management with transparent activation

**Key Concept:**
```solidity
contract PolicyRegistry is IPolicyRegistry {
    struct Policy {
        uint256 version;       // v1, v2, v3...
        address policyAddress; // Rule set or configuration address
        PolicyStatus status;   // DRAFT, STAGED, ACTIVE, DEPRECATED
        uint256 stagedAt;      // When staging started
        uint256 activationTime; // When it can be activated
    }
    
    uint256 public currentPolicyVersion;
    mapping(uint256 => Policy) public policies;
}
```

**Lifecycle:**
```
1. Admin creates draft: createPolicyDraft(newRules)
   Status: DRAFT

2. Admin stages it: stagePolicy(version, 1 days)
   Status: STAGED
   System waits 1 day

3. Anyone can activate: activatePolicy(version)
   Status: ACTIVE (replaces old version)
   Old version: DEPRECATED

4. Repeat for v3, v4...
```

**Why Staged Activation?**
- Stakeholders see changes coming (24h+ notice)
- Can exit position before rules change
- Transparent governance on-chain
- Audit trail of all policy versions

**Usage:**
```solidity
// Day 1: Draft new policy with stricter KYC
uint256 v2 = policyRegistry.createPolicyDraft(newRulesetAddress);

// Day 1: Announce activation in 24 hours
policyRegistry.stagePolicy(v2, 1 days);

// Day 2: After delay, activate
policyRegistry.activatePolicy(v2);
```

---

## IDENTITY RESOLUTION (2 files)

Resolve user identity and KYC status.

### 12. AllowListResolver.sol
**Location:** [contracts/identity/AllowListResolver.sol](../contracts/identity/AllowListResolver.sol)

**Purpose:** Simple onchain KYC whitelist

**Data Structure:**
```solidity
contract AllowListResolver is IIdentityResolver {
    mapping(address => AttestationStatus) public identities;
    
    struct AttestationStatus {
        IdentityTier tier;      // NONE → BASIC → INTERMEDIATE → ADVANCED → ACCREDITED
        string jurisdiction;    // "US", "SG", "UK", etc.
        uint256 expiresAt;     // When KYC expires
        bool verified;         // Currently valid
    }
}
```

**Operations:**
```solidity
// Admin adds user to whitelist
attestUser(
    address user,
    IdentityTier.INTERMEDIATE,
    "US",
    365  // Valid for 365 days
);

// Anyone queries identity (on-chain)
AttestationStatus memory status = resolver.resolveIdentity(user);
```

**Key Features:**
- **Onchain**: All data stored on blockchain (transparent)
- **Expiring**: KYC can expire automatically
- **Queryable**: Rules can check tier instantly
- **Updateable**: Admin can change tier or jurisdiction

**Example Use Case:**
```solidity
// Only allow accredited investors in US to transfer
attestUser(address(alice), IdentityTier.ACCREDITED, "US", 365);

// Alice can now transfer (passes KYCTierRule)
alice.transfer(bob, 1000);
```

---

### 13. CompositeIdentityResolver.sol
**Location:** [contracts/identity/CompositeIdentityResolver.sol](../contracts/identity/CompositeIdentityResolver.sol)

**Purpose:** Combine multiple identity sources (AND/OR/QUORUM)

**Why Composite?**
- Single point of failure = risky
- Multiple sources = more robust
- Example: Cross-check AllowList + EAS + Oracle

**Combination Modes:**
```solidity
enum CombinationMode {
    ANY,     // At least one source confirms ✓
    ALL,     // All sources must confirm ✓
    QUORUM   // N out of M sources confirm ✓
}
```

**Usage Example:**
```solidity
// 2 out of 3 sources must confirm identity
resolver.configure(
    [allowListAddress, easAddress, oracleAddress],
    CombinationMode.QUORUM,
    quorumRequired=2
);

// Resolves with highest tier found among valid sources
status = resolver.resolveIdentity(alice);
```

**Typical Configurations:**
- **ANY**: Quick (first valid source wins)
- **ALL**: Strictest (all must confirm)
- **QUORUM(2/3)**: Balanced (majority consensus)

---

## ASSET ADAPTERS (2 files)

Different token standards with rules integration.

### 14. RWA_ERC20.sol
**Location:** [contracts/adapters/RWA_ERC20.sol](../contracts/adapters/RWA_ERC20.sol)

**Purpose:** ERC20 token with integrated rules enforcement

**Inheritance:**
```solidity
contract RWA_ERC20 is IRWAAdapter, ERC20, AccessControl {
    IRulesEngine private _rulesEngine;
}
```

**Transfer Hook:**
```solidity
function transfer(address to, uint256 amount) 
    public 
    override 
    returns (bool) 
{
    // Check rules BEFORE transfer
    _checkRules(msg.sender, to, amount, OperationType.TRANSFER);
    
    // If rules pass, do actual transfer
    return super.transfer(to, amount);
}
```

**Rules Checking:**
```solidity
function _checkRules(
    address from,
    address to,
    uint256 amount,
    IContext.OperationType opType
) internal view {
    // Create immutable context
    IContext context = new Context(from, to, amount, opType);
    
    // Evaluate rules
    IRule.RuleResult memory result = _rulesEngine.evaluate(context);
    
    // Require pass
    require(result.passed, result.reason);
    
    // Log event
    emit RuleCheckPassed(from, to, amount);
}
```

**Standard ERC20 Methods:**
- `transfer(to, amount)` - Standard transfer
- `transferFrom(from, to, amount)` - Approved transfer
- `approve(spender, amount)` - Give spending approval
- `mint(to, amount)` - Create tokens
- `burn(amount)` - Destroy tokens

**All these check rules before executing.**

**Governance Integration:**
```solidity
// Only RULE_MANAGER can change rules
function setRulesEngine(address newEngine) 
    external 
    onlyRole(RULE_MANAGER_ROLE) 
{
    _rulesEngine = IRulesEngine(newEngine);
}
```

---

### 15. RWA_ERC721.sol
**Location:** [contracts/adapters/RWA_ERC721.sol](../contracts/adapters/RWA_ERC721.sol)

**Purpose:** ERC721 (NFT) with rules enforcement

**Key Difference from ERC20:**
- Tokens are indivisible (amount always = 1)
- Transfer by token ID, not amount

**Transfer Hook:**
```solidity
function safeTransferFrom(
    address from,
    address to,
    uint256 tokenId
) 
    public 
    override 
{
    // Check rules before NFT transfer
    _checkRules(from, to, 1, OperationType.TRANSFER);  // amount=1
    
    // Execute transfer
    super.safeTransferFrom(from, to, tokenId);
}
```

**Use Cases:**
- **Real Estate Deed**: Each NFT = property deed
- **Securities**: Each NFT = certificate
- **Collectibles**: Each NFT = unique asset

**Rules Enforce:**
- Seller must be KYC'd
- Buyer must be in allowed jurisdiction
- Property can't be in blacklist
- etc.

---

## GOVERNANCE (3 files)

Access control, emergency stops, and time-delayed execution.

### 16. AccessControl.sol
**Location:** [contracts/governance/AccessControl.sol](../contracts/governance/AccessControl.sol)

**Purpose:** Role-based permission system

**Built-in Roles:**
```solidity
bytes32 public constant ADMIN_ROLE = keccak256("ADMIN");
bytes32 public constant POLICY_MANAGER_ROLE = keccak256("POLICY_MANAGER");
bytes32 public constant RULE_MANAGER_ROLE = keccak256("RULE_MANAGER");
bytes32 public constant IDENTITY_MANAGER_ROLE = keccak256("IDENTITY_MANAGER");
bytes32 public constant PAUSER_ROLE = keccak256("PAUSER");
bytes32 public constant MINTER_ROLE = keccak256("MINTER");
bytes32 public constant BURNER_ROLE = keccak256("BURNER");
```

**Role Hierarchy:**
```
ADMIN (super admin)
├── POLICY_MANAGER (change rules/policies)
├── RULE_MANAGER (add/remove rules)
├── IDENTITY_MANAGER (manage KYC)
├── PAUSER (emergency pause)
├── MINTER (create tokens)
└── BURNER (destroy tokens)
```

**Usage:**
```solidity
// Grant role
grantRole(MINTER_ROLE, aliceAddress);

// Check role
require(hasRole(MINTER_ROLE, msg.sender), "Not minter");

// Enforce in function
function mint(address to, uint256 amount) 
    external 
    onlyRole(MINTER_ROLE) 
{
    _mint(to, amount);
}
```

**Key Benefits:**
- Fine-grained permissions
- Non-custodial (address controls own role)
- Auditable (events for all changes)
- Standard (OpenZeppelin AccessControl)

---

### 17. CircuitBreaker.sol
**Location:** [contracts/governance/CircuitBreaker.sol](../contracts/governance/CircuitBreaker.sol)

**Purpose:** Emergency pause mechanism

**Three States:**
```solidity
enum CircuitBreakerState {
    CLOSED,       // Normal operation (no pause)
    OPEN,         // Paused (no transfers allowed)
    SAFE_MODE     // Limited operation (certain functions allowed)
}
```

**Triggers:**
```solidity
// Anyone with PAUSER role can pause
function pause() external onlyRole(PAUSER_ROLE) {
    state = CircuitBreakerState.OPEN;
}

// Admin can resume
function unpause() external onlyRole(ADMIN_ROLE) {
    state = CircuitBreakerState.CLOSED;
}
```

**Usage in Token:**
```solidity
function transfer(address to, uint256 amount) 
    public 
    override 
    returns (bool) 
{
    require(circuitBreaker.isClosed(), "Circuit breaker open");
    // Continue with transfer...
}
```

**Cooldown Period:**
```solidity
// Can't pause more than once per 1 hour
uint256 public constant PAUSE_COOLDOWN = 1 hours;
uint256 lastPauseTime;

function pause() external onlyRole(PAUSER_ROLE) {
    require(
        block.timestamp > lastPauseTime + PAUSE_COOLDOWN,
        "Pause cooldown active"
    );
    // Pause...
}
```

**Real-World Scenario:**
```
1. 2:00 PM: Detect suspicious activity
2. 2:00 PM: Pauser calls pause()
3. 2:00 PM: All transfers blocked
4. 2:30 PM: Investigate issue
5. 2:31 PM: Call unpause() when safe
6. 2:31 PM: Transfers resume
```

---

### 18. Timelock.sol
**Location:** [contracts/governance/Timelock.sol](../contracts/governance/Timelock.sol)

**Purpose:** Time-delayed execution for critical changes

**Concept:**
```
Admin wants to change rules
     ↓
Queue action (with parameters)
     ↓
Wait N days (2-30 days)
     ↓
Execute action (or cancel if needed)
```

**Key Structs:**
```solidity
struct TimelockTransaction {
    address target;         // Contract to call
    uint256 value;         // ETH to send
    string signature;      // Function signature
    bytes data;            // Function arguments
    uint256 eta;           // Execution time
    bool executed;         // Has it executed?
}
```

**Operations:**
```solidity
// 1. Queue action (2 day delay)
bytes32 txHash = queueTransaction(
    ruleSetAddress,
    0,
    "addRule(address,uint8,bool)",
    abi.encode(newRuleAddress, 1, true),
    eta = block.timestamp + 2 days
);

// 2. Wait 2 days...
// Block.timestamp increases

// 3. Execute
executeTransaction(target, value, signature, data, eta);

// OR cancel if needed
cancelTransaction(target, value, signature, data, eta);
```

**Grace Period:**
```solidity
// Can execute for 14 days after eta
require(
    block.timestamp >= eta,
    "Not yet"
);
require(
    block.timestamp <= eta + 14 days,
    "Grace period expired"
);
```

**Real-World Example:**
```
Day 1: Change minimum KYC tier from BASIC → INTERMEDIATE
   - Queue: queueTransaction(ruleSet, 0, "updateMinTier(uint8)", ...)
   - Event: QueuedTransaction(txHash, 2 days from now)
   - Community sees notification

Day 2: (1 day passes, still can't execute)

Day 3: 2 days passed, ready to activate
   - Execute: executeTransaction(...)
   - Event: ExecutedTransaction(txHash)
   - New rule active immediately
```

**Why Time-Delayed?**
- Stakeholders see changes coming
- Honest: Rules don't change secretly
- Safe: Can cancel if there's a bug
- Accountable: Every change is on-chain

---

## COMPLIANCE RULES (6 files)

Specific compliance rules that can be combined.

### 19. KYCTierRule.sol
**Location:** [contracts/rules/KYCTierRule.sol](../contracts/rules/KYCTierRule.sol)

**Purpose:** Require minimum KYC tier for transfers

**Configuration:**
```solidity
contract KYCTierRule is BaseRule {
    IIdentityResolver public identityResolver;
    IdentityTier public minimumTierActor;      // For sender
    IdentityTier public minimumTierCounterparty; // For receiver
}
```

**Evaluation:**
```solidity
function evaluate(IContext context) external view returns (RuleResult memory) {
    // Check actor (sender)
    AttestationStatus memory actorStatus = identityResolver.resolveIdentity(context.actor());
    if (actorStatus.tier < minimumTierActor) {
        return _fail("Actor tier too low");
    }
    
    // Check counterparty (receiver)
    AttestationStatus memory counterStatus = identityResolver.resolveIdentity(context.counterparty());
    if (counterStatus.tier < minimumTierCounterparty) {
        return _fail("Counterparty tier too low");
    }
    
    return _pass();
}
```

**Setup Example:**
```solidity
// Only intermediate+ can send, accredited only can receive
kycRule.setMinimumTier(
    IdentityTier.INTERMEDIATE,  // sender
    IdentityTier.ACCREDITED     // receiver
);

// Alice (INTERMEDIATE) can't send to Bob (BASIC)
// → Rule fails: "Counterparty tier too low"
```

---

### 20. BlacklistRule.sol
**Location:** [contracts/rules/BlacklistRule.sol](../contracts/rules/BlacklistRule.sol)

**Purpose:** Block specific addresses with optional expiry

**Data Structure:**
```solidity
struct BlacklistEntry {
    bool listed;           // Is blacklisted?
    uint256 expiresAt;    // When expires (0 = never)
    string reason;        // Why (e.g., "Sanctions violation")
}

mapping(address => BlacklistEntry) public blacklist;
```

**Evaluation:**
```solidity
function evaluate(IContext context) external view returns (RuleResult memory) {
    BlacklistEntry memory entry = blacklist[context.actor()];
    
    if (!entry.listed) {
        return _pass();  // Not blacklisted
    }
    
    // Check if expired
    if (block.timestamp > entry.expiresAt && entry.expiresAt != 0) {
        return _pass();  // Expired, treat as not blacklisted
    }
    
    return _fail(entry.reason);  // Blocked: reason is explanation
}
```

**Admin Operations:**
```solidity
// Block an address permanently
addToBlacklist(sanctionedAddress, 0, "OFAC sanctions list");

// Block for 30 days
addToBlacklist(
    suspiciousAddress,
    block.timestamp + 30 days,
    "Fraud investigation"
);

// Remove from blacklist
removeFromBlacklist(exAddress);
```

**Real Scenarios:**
```
Situation: OFAC sanctions violation detected
→ addToBlacklist(address, 0, "OFAC SDN")
→ Transfer always fails for this address

Situation: Fraud investigation
→ addToBlacklist(address, now + 30 days, "Investigation")
→ After 30 days, automatically allows transfers
→ No need to manually whitelist

Situation: Investigation cleared
→ removeFromBlacklist(address)
→ Can transfer immediately
```

---

### 21. JurisdictionRule.sol
**Location:** [contracts/rules/JurisdictionRule.sol](../contracts/rules/JurisdictionRule.sol)

**Purpose:** Restrict transfers by geography (country)

**Configuration:**
```solidity
enum JurisdictionMode {
    ALLOWLIST,  // Only these countries allowed
    DENYLIST    // These countries blocked
}

mapping(string => bool) jurisdictions;  // "US" → true, "KP" → false
JurisdictionMode mode;  // Which mode?
```

**Evaluation:**
```solidity
function evaluate(IContext context) external view returns (RuleResult memory) {
    string memory actorJurisdiction = identityResolver.resolveIdentity(context.actor()).jurisdiction;
    string memory counterJurisdiction = identityResolver.resolveIdentity(context.counterparty()).jurisdiction;
    
    bool actorAllowed = checkJurisdiction(actorJurisdiction);
    bool counterAllowed = checkJurisdiction(counterJurisdiction);
    
    if (!actorAllowed || !counterAllowed) {
        return _fail("Jurisdiction not allowed");
    }
    
    return _pass();
}
```

**Setup Examples:**

**Scenario 1: US-Only (ALLOWLIST)**
```solidity
rule.setMode(JurisdictionMode.ALLOWLIST);
rule.addJurisdiction("US");  // Only US allowed

// Alice (UK) can't transfer
// → Rule fails: "Jurisdiction not allowed"
```

**Scenario 2: Sanctions Evasion (DENYLIST)**
```solidity
rule.setMode(JurisdictionMode.DENYLIST);
rule.addJurisdiction("KP");  // Block North Korea
rule.addJurisdiction("IR");  // Block Iran
rule.addJurisdiction("SY");  // Block Syria

// Everyone except OFAC countries can transfer
```

---

### 22. LockupRule.sol
**Location:** [contracts/rules/LockupRule.sol](../contracts/rules/LockupRule.sol)

**Purpose:** Time-based transfer restrictions (vesting)

**Data Structure:**
```solidity
struct Lockup {
    uint256 lockedUntil;  // Unix timestamp
    uint256 amount;       // 0 = all tokens locked, X = only X locked
    string reason;        // Why locked
}

mapping(address => Lockup) public lockups;
```

**Evaluation:**
```solidity
function evaluate(IContext context) external view returns (RuleResult memory) {
    Lockup memory lock = lockups[context.actor()];
    
    // Not locked
    if (lock.lockedUntil == 0 || block.timestamp > lock.lockedUntil) {
        return _pass();
    }
    
    // Partial lock (amount = specific amount locked)
    if (lock.amount > 0 && lock.amount < context.amount()) {
        // Can transfer but amount is less
        return _pass();
    }
    
    // Fully locked
    return _fail("Tokens locked until " + formatTime(lock.lockedUntil));
}
```

**Lockup Types:**

**Type 1: Full Lockup**
```solidity
// Alice's tokens locked until 2025
lockupRule.addLockup(alice, 2025-01-01, 0, "Token vesting");

// Alice has 1000 tokens
// alice.transfer(bob, 100)
// → Rule fails: "Tokens locked until 2025-01-01"
```

**Type 2: Partial Lockup**
```solidity
// Alice has 1000 tokens, 700 are locked until 2024
lockupRule.addLockup(alice, 2024-01-01, 700, "Founder lockup");

// alice.transfer(bob, 100)
// → Passes (100 < 700 locked)

// alice.transfer(bob, 500)
// → Fails (500 > 700 locked)
```

**Use Case: Token Vesting**
```
Employee receives 1000 tokens
- Day 1: All locked for 1 year
- Year 1: Can sell up to 750 (25% vested)
- Year 2: Can sell up to 500 (50% vested)
- Year 3: Can sell up to 250 (75% vested)
- Year 4: Can sell all (100% vested)

```

---

### 23. SupplyCapRule.sol
**Location:** [contracts/rules/SupplyCapRule.sol](../contracts/rules/SupplyCapRule.sol)

**Purpose:** Enforce maximum total supply

**Configuration:**
```solidity
uint256 public maxSupply;
IERC20 public token;
```

**Evaluation:**
```solidity
function evaluate(IContext context) external view returns (RuleResult memory) {
    // Only applies to minting
    if (context.operationType() != IContext.OperationType.MINT) {
        return _pass();
    }
    
    uint256 newTotal = token.totalSupply() + context.amount();
    
    if (newTotal > maxSupply) {
        return _fail("Exceeds supply cap");
    }
    
    return _pass();
}
```

**Setup:**
```solidity
// Maximum 1 million tokens ever
supplyCapRule.setMaxSupply(1_000_000e18);

// Try to mint 500,000 more when supply = 600,000
// 600,000 + 500,000 = 1,100,000 > 1,000,000
// → Rule fails: "Exceeds supply cap"
```

**Real Use Case:**
```
Bond Issuance: "We will issue exactly 1M bonds, no more"

setupRule.setMaxSupply(1_000_000e18);

// Mint 1M bonds → Passes
// Try to mint 1 more → Fails

Provides certainty:
- Investors know total supply fixed
- No dilution possible
- Value proposition clear
```

---

### 24. VelocityRule.sol
**Location:** [contracts/rules/VelocityRule.sol](../contracts/rules/VelocityRule.sol)

**Purpose:** Rate-limit transfers per address (prevent wash trading)

**Data Structure:**
```solidity
struct VelocityLimit {
    uint256 maxAmount;      // Max amount per window
    uint256 windowDuration; // Time period (e.g., 24 hours)
    uint256 windowStart;    // When current window started
    uint256 amountInWindow; // Already transferred this window
}

mapping(address => VelocityLimit) public limits;
```

**Evaluation:**
```solidity
function evaluate(IContext context) external view returns (RuleResult memory) {
    VelocityLimit memory limit = limits[context.actor()];
    
    uint256 amountInCurrentWindow = limit.amountInWindow;
    
    // Window expired? Reset
    if (block.timestamp > limit.windowStart + limit.windowDuration) {
        amountInCurrentWindow = 0;
    }
    
    uint256 newAmount = amountInCurrentWindow + context.amount();
    
    if (newAmount > limit.maxAmount) {
        return _fail("Exceeds daily transfer limit");
    }
    
    return _pass();
}
```

**Setup:**
```solidity
// Max 100k per day
velocityRule.setLimit(alice, 100_000e18, 1 days);

// Alice transfers 60k → Passes (60k < 100k)
// Alice transfers 50k → Fails (60k + 50k > 100k)

// Next day:
// Alice transfers 80k → Passes (window reset)
```

**Use Cases:**

**Preventing Wash Trading:**
```
Security token trading
→ Max 10% of holdings per day
→ Prevents manipulation
```

**Fraud Prevention:**
```
Large account suddenly trades lots
→ VelocityRule limits daily volume
→ Alert investigation team
```

---

## UTILITY LIBRARIES (3 files)

Shared functions for optimization and safety.

### 25. BitOperations.sol
**Location:** [contracts/libraries/BitOperations.sol](../contracts/libraries/BitOperations.sol)

**Purpose:** Bitmap helpers for gas-efficient rule state tracking

**Operations:**
```solidity
library BitOperations {
    // Set bit 3 to 1: 0b0000 → 0b1000
    function setBit(uint256 value, uint8 index) internal pure returns (uint256);
    
    // Clear bit 3: 0b1111 → 0b0111
    function clearBit(uint256 value, uint8 index) internal pure returns (uint256);
    
    // Check if bit 3 is set
    function isBitSet(uint256 value, uint8 index) internal pure returns (bool);
    
    // Count number of set bits
    function popCount(uint256 value) internal pure returns (uint8);
}
```

**Why?**
- Tracking which of 256 rules are enabled uses 1 uint256 instead of 256 bools
- Saves massive gas and storage

**Example:**
```solidity
// Instead of:
bool[] enabledRules = new bool[](256);  // 256 storage slots!

// Use:
uint256 enabledRules = 0;  // 1 storage slot

// Enable rule 5
enabledRules = BitOperations.setBit(enabledRules, 5);

// Check if rule 5 enabled
if (BitOperations.isBitSet(enabledRules, 5)) { ... }
```

---

### 26. StringUtils.sol
**Location:** [contracts/libraries/StringUtils.sol](../contracts/libraries/StringUtils.sol)

**Purpose:** Convert addresses, numbers, bytes to strings for error messages

**Functions:**
```solidity
library StringUtils {
    // Convert address to string
    function addressToString(address addr) internal pure returns (string memory);
    
    // Convert uint256 to string
    function uint256ToString(uint256 value) internal pure returns (string memory);
    
    // Convert bytes32 to hex string
    function bytes32ToHexString(bytes32 data) internal pure returns (string memory);
}
```

**Usage in Rules:**
```solidity
function evaluate(IContext context) external view returns (RuleResult memory) {
    if (!approved(context.actor())) {
        string memory actorStr = StringUtils.addressToString(context.actor());
        return _fail(string(abi.encodePacked("Not approved: ", actorStr)));
        // Result: "Not approved: 0x1234...5678"
    }
}
```

---

### 27. SafeMath.sol
**Location:** [contracts/libraries/SafeMath.sol](../contracts/libraries/SafeMath.sol)

**Purpose:** Safe arithmetic with overflow protection

**Operations:**
```solidity
library SafeMath {
    function add(uint256 a, uint256 b) internal pure returns (uint256);
    function sub(uint256 a, uint256 b) internal pure returns (uint256);
    function mul(uint256 a, uint256 b) internal pure returns (uint256);
    function div(uint256 a, uint256 b) internal pure returns (uint256);
    
    // Special: Convert basis points to percentage
    // 100 basis points = 1%
    // 10000 basis points = 100%
    function basisPointsToPercentage(uint256 amount, uint256 basisPoints) 
        internal 
        pure 
        returns (uint256);
}
```

**Example Usage:**
```solidity
// Calculate 2.5% fee on 1000 tokens
uint256 amount = 1000e18;
uint256 fee = SafeMath.basisPointsToPercentage(amount, 250);  // 250 basis points = 2.5%
// fee = 25e18 (2.5% of 1000)
```

---

## TOTAL STATISTICS

**Summary Table:**

| Category | Count | Purpose |
|----------|-------|---------|
| **Interfaces** | 6 | Define contract APIs |
| **Core Engine** | 4 | Evaluate rules |
| **Policy** | 1 | Version management |
| **Identity** | 2 | KYC resolution |
| **Adapters** | 2 | ERC20/ERC721 tokens |
| **Governance** | 3 | Access control, pause, timelock |
| **Rules** | 6 | KYC, blacklist, jurisdiction, lockup, supply, velocity |
| **Libraries** | 3 | Bitmap ops, strings, math |
| **TOTAL** | **27** | Complete RWA framework |

**Lines of Code:**
- Interfaces: ~100 lines
- Core Engine: ~300 lines
- Governance: ~500 lines
- Rules: ~800 lines
- Adapters: ~400 lines
- Libraries: ~300 lines
- **Total: ~2,400 lines of production Solidity**

**Key Characteristics:**
- ✅ Fully modular (27 independent contracts)
- ✅ Gas optimized (bit operations, immutables, short-circuit evaluation)
- ✅ Thoroughly documented (this file + SETUP.md + INTERFACES.md + API.md)
- ✅ Auditable (transparent events, clear logic)
- ✅ Production-ready (error handling, access control)
- ✅ Framework agnostic (works with Hardhat, Foundry, Truffle)
