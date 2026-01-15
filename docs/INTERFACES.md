# Interfaces Reference - Mantle RWA Toolkit

Complete reference for all 6 core interfaces that define the contract architecture.

## Overview

The Mantle RWA Toolkit uses 6 core interfaces to define how contracts interact. Every contract either implements one of these interfaces or uses them to interact with other components.

**Interfaces at a Glance:**

| Interface | Location | Purpose |
|-----------|----------|---------|
| `IContext` | `interfaces/IContext.sol` | Transaction context snapshot |
| `IRule` | `interfaces/IRule.sol` | Rule evaluation contract |
| `IRulesEngine` | `interfaces/IRulesEngine.sol` | Rules evaluation orchestration |
| `IIdentityResolver` | `interfaces/IIdentityResolver.sol` | KYC/identity attestation |
| `IPolicyRegistry` | `interfaces/IPolicyRegistry.sol` | Versioned policy management |
| `IRWAAdapter` | `interfaces/IRWAAdapter.sol` | Asset adapter interface |

---

## 1. IContext

**File:** [contracts/interfaces/IContext.sol](../contracts/interfaces/IContext.sol)

**Purpose:** Defines an immutable snapshot of a transaction being evaluated.

### Why It Exists

When the rules engine evaluates if a transaction is allowed, it needs to know:
- Who is initiating the transfer? (actor)
- Who is receiving it? (counterparty)
- How much? (amount)
- What type of operation? (transfer, mint, burn, etc.)
- When? (timestamp)

`IContext` encapsulates all this information as an immutable object that rules can safely inspect.

### Interface Definition

```solidity
interface IContext {
    enum OperationType {
        TRANSFER,    // Normal transfer between users
        MINT,        // Minting new tokens
        BURN,        // Burning tokens
        APPROVE,     // Giving spending approval
        CUSTOM       // Custom operation
    }

    function actor() external view returns (address);
    function counterparty() external view returns (address);
    function amount() external view returns (uint256);
    function operationType() external view returns (OperationType);
    function timestamp() external view returns (uint256);
}
```

### Implementation: Context.sol

```solidity
contract Context is IContext {
    address public immutable actor;           // Transaction initiator
    address public immutable counterparty;    // Transaction recipient
    uint256 public immutable amount;          // Transfer amount
    OperationType public immutable operationType;  // Type of operation
    uint256 public immutable timestamp;       // Block timestamp

    constructor(
        address _actor,
        address _counterparty,
        uint256 _amount,
        OperationType _operationType
    ) {
        require(_actor != address(0), "Invalid actor");
        require(_counterparty != address(0), "Invalid counterparty");
        
        actor = _actor;
        counterparty = _counterparty;
        amount = _amount;
        operationType = _operationType;
        timestamp = block.timestamp;
    }
}
```

### Usage Example

```solidity
// In RWA_ERC20.sol before transfer
function _checkRules(
    address from,
    address to,
    uint256 value
) internal {
    IContext context = new Context(
        from,
        to,
        value,
        IContext.OperationType.TRANSFER
    );
    
    IRulesEngine.RuleResult memory result = rulesEngine.evaluate(context);
    require(result.passed, result.reason);
}
```

### Key Points

- **Immutable**: Once created, cannot be modified (saves gas)
- **Comprehensive**: Contains all data a rule might need
- **Type-Safe**: OperationType enum prevents invalid operation types
- **Timestamp**: Includes block.timestamp for time-based rules

---

## 2. IRule

**File:** [contracts/interfaces/IRule.sol](../contracts/interfaces/IRule.sol)

**Purpose:** Defines the interface that all compliance rules must implement.

### Why It Exists

Every compliance rule (KYC, blacklist, lockup, etc.) needs a consistent interface so the rules engine can:
1. Call the rule to evaluate a transaction
2. Get back a pass/fail result with explanation
3. Know which rule rejected the transaction

### Interface Definition

```solidity
interface IRule {
    struct RuleResult {
        bool passed;           // Did rule pass? true = allow, false = block
        string reason;         // Human-readable explanation
        string ruleId;         // Unique rule identifier
    }

    function evaluate(IContext context) external view returns (RuleResult memory);
    function ruleId() external view returns (string memory);
}
```

### Implementation: BaseRule.sol

All rules inherit from `BaseRule` which implements `IRule`:

```solidity
abstract contract BaseRule is IRule {
    string public ruleId;
    
    constructor(string memory _ruleId) {
        require(bytes(_ruleId).length > 0, "Invalid rule ID");
        ruleId = _ruleId;
    }

    // Helper to return pass result
    function _pass() internal view returns (RuleResult memory) {
        return RuleResult({
            passed: true,
            reason: "Rule passed",
            ruleId: ruleId
        });
    }

    // Helper to return fail result with reason
    function _fail(string memory reason) internal view returns (RuleResult memory) {
        return RuleResult({
            passed: false,
            reason: reason,
            ruleId: ruleId
        });
    }

    function evaluate(IContext context) external view virtual returns (RuleResult memory);
}
```

### Real Rule Example: BlacklistRule

```solidity
contract BlacklistRule is BaseRule {
    mapping(address => BlacklistEntry) public blacklist;

    struct BlacklistEntry {
        bool listed;
        uint256 expiresAt;
        string reason;
    }

    function evaluate(IContext context) external view returns (RuleResult memory) {
        BlacklistEntry memory entry = blacklist[context.actor()];
        
        if (!entry.listed) {
            return _pass();
        }
        
        // If expiry time passed, treat as unlisted
        if (block.timestamp > entry.expiresAt) {
            return _pass();
        }
        
        return _fail(entry.reason);
    }
}
```

### Usage Example

```solidity
// In RulesEngine
function evaluate(IContext context) returns (RuleResult memory) {
    RuleSet storage ruleset = ruleSets[context.operationType()];
    
    for (uint i = 0; i < ruleset.rules.length; i++) {
        IRule rule = ruleset.rules[i];
        IRule.RuleResult memory result = rule.evaluate(context);
        
        if (!result.passed) {
            return result;  // Short-circuit: stop on first failure
        }
    }
    
    return RuleResult({passed: true, reason: "All rules passed", ruleId: ""});
}
```

### Key Points

- **Deterministic**: Same inputs always produce same output
- **Cheap**: View function (read-only, no state changes)
- **Informative**: Returns reason for failure, not just true/false
- **Traceable**: Includes ruleId so logs show which rule blocked transaction

---

## 3. IRulesEngine

**File:** [contracts/interfaces/IRulesEngine.sol](../contracts/interfaces/IRulesEngine.sol)

**Purpose:** Orchestrates evaluation of multiple rules in sequence.

### Why It Exists

A single rule (e.g., "user must be on KYC list") is too restrictive. Real compliance needs multiple rules working together:
- **Rule 1**: User must pass KYC (tier must be ≥ INTERMEDIATE)
- **Rule 2**: User must not be blacklisted
- **Rule 3**: User's jurisdiction must be allowed
- **Rule 4**: Must not exceed daily transfer limits

The rules engine combines these with different strategies (all must pass, or just one, or short-circuit on first failure).

### Interface Definition

```solidity
interface IRulesEngine {
    enum EvaluationMode {
        SHORT_CIRCUIT,    // Stop on first failure
        ALL_MUST_PASS,    // All rules must pass
        ANY_MUST_PASS     // At least one must pass
    }

    struct RuleResult {
        bool passed;
        string reason;
        string ruleId;
    }

    function evaluate(IContext context) external view returns (RuleResult memory);
    function getRuleSet(IContext.OperationType opType) external view returns (address);
    function setRuleSet(IContext.OperationType opType, address ruleSet) external;
}
```

### Implementation: RulesEngine.sol

```solidity
contract RulesEngine is IRulesEngine {
    mapping(IContext.OperationType => address) public ruleSets;

    function evaluate(IContext context) external view returns (RuleResult memory) {
        address ruleSetAddr = ruleSets[context.operationType()];
        require(ruleSetAddr != address(0), "No rules configured");
        
        IRuleSet ruleset = IRuleSet(ruleSetAddr);
        IRule[] memory rules = ruleset.getRules();
        
        // SHORT_CIRCUIT: Stop on first failure (most common)
        for (uint i = 0; i < rules.length; i++) {
            IRule.RuleResult memory result = rules[i].evaluate(context);
            if (!result.passed) {
                return result;  // Exit immediately
            }
        }
        
        return RuleResult({passed: true, reason: "All rules passed", ruleId: ""});
    }

    function setRuleSet(IContext.OperationType opType, address ruleSet) external onlyAdmin {
        require(ruleSet != address(0), "Invalid ruleset");
        ruleSets[opType] = ruleSet;
        emit RuleSetUpdated(opType, ruleSet);
    }
}
```

### Evaluation Modes Explained

**SHORT_CIRCUIT** (default - most efficient):
```
Rule 1: KYC Check     → PASS ✓
Rule 2: Blacklist     → FAIL ✗ (STOP HERE, don't evaluate rules 3-4)
Rule 3: Jurisdiction  → (not evaluated)
Rule 4: Velocity      → (not evaluated)

Result: FAIL - returns immediately
```

**ALL_MUST_PASS** (traditional AND logic):
```
Rule 1: KYC Check     → PASS ✓
Rule 2: Blacklist     → PASS ✓
Rule 3: Jurisdiction  → FAIL ✗
Rule 4: Velocity      → PASS ✓

Result: FAIL - all must pass, one failed
```

**ANY_MUST_PASS** (OR logic - rarely used):
```
Rule 1: Partner A approved   → FAIL ✗
Rule 2: Partner B approved   → PASS ✓ (STOP, one passed)
Rule 3: Partner C approved   → (not evaluated)

Result: PASS - at least one passed
```

### Usage Example

```solidity
// In token transfer
function transfer(address to, uint256 amount) external returns (bool) {
    IContext context = new Context(
        msg.sender,
        to,
        amount,
        IContext.OperationType.TRANSFER
    );
    
    // This evaluates all configured rules for TRANSFER operations
    IRulesEngine.RuleResult memory result = rulesEngine.evaluate(context);
    require(result.passed, result.reason);
    
    // If we get here, all rules passed
    return _transfer(msg.sender, to, amount);
}
```

### Key Points

- **Flexible**: Supports SHORT_CIRCUIT (efficient), ALL_MUST_PASS (strict), ANY_MUST_PASS (permissive)
- **Operation-Specific**: Different rules for TRANSFER, MINT, BURN, etc.
- **Configurable**: Can change rules without redeploying token
- **Transparent**: Emits events so on-chain history is visible

---

## 4. IIdentityResolver

**File:** [contracts/interfaces/IIdentityResolver.sol](../contracts/interfaces/IIdentityResolver.sol)

**Purpose:** Resolves identity information (KYC tier, jurisdiction, expiry) for an address.

### Why It Exists

Compliance rules need to know:
- Is this user KYC'd?
- What tier? (basic, intermediate, advanced, accredited)
- What country are they in?
- Is their KYC still valid?

`IIdentityResolver` abstracts this - could be onchain list, EAS attestation, oracle, or external API.

### Interface Definition

```solidity
interface IIdentityResolver {
    enum IdentityTier {
        NONE,              // Not verified
        BASIC,             // Basic KYC (name + ID)
        INTERMEDIATE,      // Financial info included
        ADVANCED,          // Accredited investor checks
        ACCREDITED         // Full accredited investor
    }

    struct AttestationStatus {
        IdentityTier tier;           // Current KYC tier
        string jurisdiction;         // Country code (e.g., "US", "SG")
        uint256 expiresAt;          // When KYC expires
        bool verified;              // Is currently valid
    }

    function resolveIdentity(address subject) 
        external 
        view 
        returns (AttestationStatus memory);
}
```

### Implementation 1: AllowListResolver.sol

**Simple onchain whitelist:**

```solidity
contract AllowListResolver is IIdentityResolver {
    mapping(address => AttestationStatus) public identities;
    address public admin;

    function resolveIdentity(address subject) 
        external 
        view 
        returns (AttestationStatus memory) 
    {
        AttestationStatus memory status = identities[subject];
        
        // If expiry time passed, treat as unverified
        if (status.expiresAt < block.timestamp) {
            return AttestationStatus({
                tier: IdentityTier.NONE,
                jurisdiction: "",
                expiresAt: 0,
                verified: false
            });
        }
        
        return status;
    }

    // Admin adds a user to whitelist
    function attestUser(
        address subject,
        IdentityTier tier,
        string memory jurisdiction,
        uint256 expiryDays
    ) external onlyAdmin {
        identities[subject] = AttestationStatus({
            tier: tier,
            jurisdiction: jurisdiction,
            expiresAt: block.timestamp + (expiryDays * 1 days),
            verified: true
        });
        emit UserAttested(subject, tier);
    }
}
```

### Implementation 2: CompositeIdentityResolver.sol

**Combines multiple identity sources:**

```solidity
contract CompositeIdentityResolver is IIdentityResolver {
    enum CombinationMode {
        ANY,          // At least one source confirms identity
        ALL,          // All sources must confirm
        QUORUM        // N out of M sources must confirm
    }

    struct CompositeConfig {
        address[] sources;
        CombinationMode mode;
        uint8 quorumRequired;  // For QUORUM mode
    }

    function resolveIdentity(address subject) 
        external 
        view 
        returns (AttestationStatus memory) 
    {
        CompositeConfig memory config = configurations[subject];
        uint8 confirmedCount = 0;

        for (uint i = 0; i < config.sources.length; i++) {
            IIdentityResolver resolver = IIdentityResolver(config.sources[i]);
            AttestationStatus memory status = resolver.resolveIdentity(subject);
            
            if (status.verified) {
                confirmedCount++;
                if (config.mode == CombinationMode.ANY) {
                    return status;  // One confirmed, done
                }
            }
        }

        if (config.mode == CombinationMode.QUORUM) {
            if (confirmedCount >= config.quorumRequired) {
                // Return highest tier found
                return _getHighestTier(subject, config);
            }
        }

        return AttestationStatus({tier: IdentityTier.NONE, verified: false, ...});
    }
}
```

### Real-World Usage Example

```solidity
// In KYCTierRule
contract KYCTierRule is BaseRule {
    IIdentityResolver public identityResolver;
    IdentityTier public minimumTier;

    function evaluate(IContext context) external view returns (RuleResult memory) {
        AttestationStatus memory status = identityResolver.resolveIdentity(context.actor());
        
        if (!status.verified) {
            return _fail("User not KYC'd");
        }
        
        if (status.tier < minimumTier) {
            return _fail("User tier too low for this transfer");
        }
        
        return _pass();
    }
}
```

### Key Points

- **Pluggable**: Can swap identity sources without changing rules
- **Tier-Based**: Support multiple verification levels
- **Expiring**: KYC can expire automatically
- **Composable**: Can combine multiple sources (2FA-like approach for identity)

---

## 5. IPolicyRegistry

**File:** [contracts/interfaces/IPolicyRegistry.sol](../contracts/interfaces/IPolicyRegistry.sol)

**Purpose:** Manages versioned policies with staging and activation delays.

### Why It Exists

Compliance rules change:
- New jurisdiction added → Create new version
- Minimum KYC tier increased → New version
- Blacklist rules updated → New version

But you can't change rules mid-day without warning. `IPolicyRegistry` allows:
1. Draft a new policy version
2. Stage it with proposed changes visible onchain
3. Wait required time (e.g., 24 hours)
4. Activate it

This is transparent and gives stakeholders time to respond to rule changes.

### Interface Definition

```solidity
interface IPolicyRegistry {
    enum PolicyStatus {
        DRAFT,        // Being edited, not active
        STAGED,       // Proposed, waiting activation time
        ACTIVE,       // Currently enforced
        DEPRECATED    // Superseded by newer version
    }

    function getCurrentPolicy() external view returns (uint256 version, address policyAddress);
    function getPolicyStatus(uint256 version) external view returns (PolicyStatus);
    function stagePolicy(uint256 version, uint256 activationDelay) external;
    function activatePolicy(uint256 version) external;
}
```

### Implementation: PolicyRegistry.sol

```solidity
contract PolicyRegistry is IPolicyRegistry {
    struct Policy {
        uint256 version;
        address policyAddress;
        PolicyStatus status;
        uint256 stagedAt;
        uint256 activationTime;
    }

    mapping(uint256 => Policy) public policies;
    uint256 public currentPolicyVersion;
    uint256 public DEFAULT_ACTIVATION_DELAY = 1 days;

    // Create draft policy
    function createPolicyDraft(address policyAddress) 
        external 
        onlyAdmin 
        returns (uint256 version) 
    {
        version = currentPolicyVersion + 1;
        policies[version] = Policy({
            version: version,
            policyAddress: policyAddress,
            status: PolicyStatus.DRAFT,
            stagedAt: 0,
            activationTime: 0
        });
        emit PolicyCreated(version, policyAddress);
    }

    // Stage policy for activation
    function stagePolicy(uint256 version, uint256 customDelay) 
        external 
        onlyAdmin 
    {
        Policy storage policy = policies[version];
        require(policy.status == PolicyStatus.DRAFT, "Must be draft");
        
        policy.status = PolicyStatus.STAGED;
        policy.stagedAt = block.timestamp;
        policy.activationTime = block.timestamp + customDelay;
        
        emit PolicyStaged(version, policy.activationTime);
    }

    // Activate policy (only after activation time)
    function activatePolicy(uint256 version) 
        external 
        onlyAdmin 
    {
        Policy storage policy = policies[version];
        require(policy.status == PolicyStatus.STAGED, "Must be staged");
        require(block.timestamp >= policy.activationTime, "Activation time not reached");
        
        // Deprecate old policy
        policies[currentPolicyVersion].status = PolicyStatus.DEPRECATED;
        
        // Activate new policy
        policy.status = PolicyStatus.ACTIVE;
        currentPolicyVersion = version;
        
        emit PolicyActivated(version);
    }
}
```

### Policy Lifecycle Diagram

```
DRAFT
  ↓
[Admin calls stagePolicy(version, 1 day)]
  ↓
STAGED (waiting period begins)
  ↓
[24 hours pass]
  ↓
[Admin calls activatePolicy(version)]
  ↓
ACTIVE (enforced)
  ↓
[New policy created → activated]
  ↓
DEPRECATED (old policy no longer used)
```

### Usage Example

```solidity
// Day 1: Create draft with new KYC requirements
uint256 v2 = policyRegistry.createPolicyDraft(newPolicyAddress);

// Day 1: Announce activation for tomorrow
policyRegistry.stagePolicy(v2, 1 days);

// Day 2: Activate (after 24 hour delay)
policyRegistry.activatePolicy(v2);
```

### Key Points

- **Non-Harming**: Draft/staged versions don't affect current operations
- **Auditable**: Every version change is logged onchain
- **Staged**: Requires waiting period before activation
- **Reversible**: Can't go back to old policy, but can create new v3 quickly

---

## 6. IRWAAdapter

**File:** [contracts/interfaces/IRWAAdapter.sol](../contracts/interfaces/IRWAAdapter.sol)

**Purpose:** Base interface for all asset adapters (ERC20, ERC721, etc.).

### Why It Exists

Different token standards (ERC20, ERC721, ERC1155) have different transfer mechanisms. But they should all:
- Integrate with the rules engine
- Emit consistent events
- Support the same governance

`IRWAAdapter` defines this common interface so governance and rules work identically across all token types.

### Interface Definition

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

### Implementation 1: RWA_ERC20.sol

**ERC20 token with rules integration:**

```solidity
contract RWA_ERC20 is IRWAAdapter, ERC20 {
    IRulesEngine private _rulesEngine;

    function getRulesEngine() external view returns (address) {
        return address(_rulesEngine);
    }

    function setRulesEngine(address newEngine) external onlyAdmin {
        require(newEngine != address(0), "Invalid engine");
        _rulesEngine = IRulesEngine(newEngine);
        emit RulesEngineUpdated(newEngine);
    }

    function transfer(address to, uint256 amount) 
        public 
        override 
        returns (bool) 
    {
        _checkRules(msg.sender, to, amount, IContext.OperationType.TRANSFER);
        return super.transfer(to, amount);
    }

    function _checkRules(
        address from,
        address to,
        uint256 amount,
        IContext.OperationType opType
    ) internal view {
        IContext context = new Context(from, to, amount, opType);
        IRule.RuleResult memory result = _rulesEngine.evaluate(context);
        
        require(result.passed, result.reason);
        emit RuleCheckPassed(from, to, amount);
    }
}
```

### Implementation 2: RWA_ERC721.sol

**ERC721 with rules (tokens are indivisible):**

```solidity
contract RWA_ERC721 is IRWAAdapter, ERC721 {
    IRulesEngine private _rulesEngine;

    function safeTransferFrom(
        address from,
        address to,
        uint256 tokenId
    ) public override {
        _checkRules(from, to, 1, IContext.OperationType.TRANSFER);
        super.safeTransferFrom(from, to, tokenId);
    }

    function _checkRules(
        address from,
        address to,
        uint256 amount,
        IContext.OperationType opType
    ) internal view {
        IContext context = new Context(from, to, amount, opType);
        IRule.RuleResult memory result = _rulesEngine.evaluate(context);
        
        require(result.passed, result.reason);
        emit RuleCheckPassed(from, to, amount);
    }
}
```

### Key Points

- **Consistent Interface**: All adapters follow same pattern
- **Swappable**: Can change rules engine without redeploying token
- **Transparent**: Emits events for all rule checks
- **Extensible**: New adapters (ERC1155, ERC4626) inherit this

---

## Summary

| Interface | Purpose | Key Method |
|-----------|---------|-----------|
| **IContext** | Transaction snapshot | Read context data |
| **IRule** | Rule evaluation | `evaluate(context)` returns pass/fail |
| **IRulesEngine** | Combine rules | `evaluate(context)` evaluates ruleset |
| **IIdentityResolver** | Verify identity | `resolveIdentity(address)` returns tier |
| **IPolicyRegistry** | Version policies | Manage policy lifecycle |
| **IRWAAdapter** | Asset integration | Connect token to rules engine |

All interfaces work together to create a **pluggable, configurable, transparent compliance framework** for RWA tokens.
