# Architecture Documentation

## System Overview

EDDO is a modular, composable smart contract library for tokenizing Real World Assets (RWA) with configurable compliance and identity verification rules.

## Design Principles

1. **Modularity**: Every component is independent and replaceable
2. **Transparency**: All logic and state changes are logged onchain
3. **Fail-Closed**: Default to blocking unless explicitly allowed
4. **Framework Agnostic**: Works with any EVM build tool
5. **Gas-Efficient**: Optimized for L1 and L2 deployments
6. **Audit-Friendly**: Clear, well-documented code with comprehensive tests

## Core Architecture

### Layer 1: Interfaces

All components implement standard interfaces for maximum flexibility:

- `IContext`: Evaluation context (actor, counterparty, amount, operation)
- `IRule`: Rule evaluation interface
- `IRulesEngine`: Engine that evaluates rule sets
- `IIdentityResolver`: Identity and attestation resolution
- `IPolicyRegistry`: Policy versioning and lifecycle
- `IRWAAdapter`: Asset adapter integration

### Layer 2: Core Engine

**RulesEngine**
- Evaluates rules against a context
- Supports multiple evaluation modes (ALL, ANY, SHORT_CIRCUIT)
- Emits transparent evaluation results
- Gas-optimized with early exits

**RuleSet**
- Container for rules with priority and mandatory flags
- O(1) lookups via mapping
- Dynamic enable/disable
- Sorted evaluation by priority

**Context**
- Immutable evaluation context
- Contains all information needed for rule evaluation
- Created per transaction

### Layer 3: Rules

Rules are pure, deterministic evaluators that return pass/fail:

```solidity
function evaluate(IContext context) returns (RuleResult memory)
```

**Built-in Rules:**
- **KYCTierRule**: Minimum identity tier requirements
- **JurisdictionRule**: Geography-based allow/deny lists
- **BlacklistRule**: Address-level blocking with expiry
- **LockupRule**: Time-based transfer restrictions
- **SupplyCapRule**: Maximum supply enforcement
- **VelocityRule**: Rate limiting per address

**Rule Lifecycle:**
1. Deploy rule contract
2. Configure parameters
3. Add to RuleSet with priority
4. Engine evaluates during operations

### Layer 4: Identity Resolution

Identity resolvers implement `IIdentityResolver`:

```solidity
function resolveIdentity(address subject) returns (AttestationStatus memory)
```

**Built-in Resolvers:**
- **AllowListResolver**: Simple onchain lists
- **CompositeIdentityResolver**: Combine multiple sources with AND/OR/QUORUM

**Integration Points:**
- Ethereum Attestation Service (EAS)
- Decentralized Identifiers (DIDs)
- Oracle-based KYC providers
- Enterprise APIs via offchain workers

### Layer 5: Asset Adapters

Asset adapters wrap standard token contracts with rules enforcement:

**RWA_ERC20**
- Full ERC20 implementation
- Hooks on transfer, mint, burn, approve
- Creates Context and calls RulesEngine
- Reverts with detailed reason on failure

**RWA_ERC721**
- Full ERC721 implementation
- Per-token or per-address rules
- Supports safe transfers

**Future:**
- RWA_ERC1155 (multi-token)
- RWA_ERC4626 (vaults with NAV gating)

### Layer 6: Governance

**AccessControl**
- Role-based permissions (ADMIN, POLICY_MANAGER, RULE_MANAGER, etc.)
- Hierarchical role administration
- Granular permission assignment

**Timelock**
- Time-delayed execution for critical operations
- Configurable delay (2-30 days)
- Queue → Execute → Grace period
- Transparent cancellation

**CircuitBreaker**
- Emergency stop mechanism
- Three states: CLOSED (normal), OPEN (paused), SAFE_MODE (limited)
- Guardian + Admin control
- Cooldown period before reset
- Requires explicit reasoning

### Layer 7: Policy Management

**PolicyRegistry**
- Versioned policy storage
- Lifecycle: DRAFT → STAGED → ACTIVE → DEPRECATED
- Immutable history (all versions stored)
- Timelock-enforced activation
- Event logging for audits

**Policy Flow:**
```
1. Register policy (admin creates new version)
2. Stage policy (timelock starts)
3. Wait for activation delay
4. Activate policy (previous version deprecated)
5. Rules engine uses active policy
```

## Data Flow

### Transfer Operation

```
User calls token.transfer(to, amount)
    ↓
Adapter creates Context {
    operationType: TRANSFER
    actor: msg.sender
    counterparty: to
    amount: amount
    asset: address(this)
    timestamp: block.timestamp
}
    ↓
Adapter calls engine.evaluate(context)
    ↓
Engine gets active rules from RuleSet (sorted by priority)
    ↓
For each rule:
    Rule calls identityResolver.resolveIdentity(actor/counterparty)
    Rule evaluates logic
    Returns RuleResult { passed, reason, ruleId }
    ↓
    If failed and mandatory: stop, revert
    If failed and optional: record, continue
    If passed: continue
    ↓
Engine returns EvaluationResult {
    passed: bool
    failedRule: bytes32
    reason: string
    evaluatedRules: uint256
}
    ↓
If passed: proceed with transfer
If failed: revert with reason
    ↓
Emit events:
    - RulesEvaluated(context, passed, failedRule, version)
    - RuleCheckPassed/Failed(actor, counterparty, amount, ...)
    - Transfer(from, to, amount)
```

## Gas Optimization Strategies

1. **Short-Circuit Evaluation**: Stop on first mandatory failure
2. **Priority Ordering**: Evaluate cheap rules first
3. **Bitmap Caching**: Cache rule results in uint256
4. **Minimal Storage**: Use immutables and calldata where possible
5. **Batch Operations**: Process multiple items in one transaction
6. **L2 Deployment**: Optimized for Arbitrum, Optimism, Polygon

## Security Model

### Fail-Closed Design

- Default behavior: block unless explicitly allowed
- Missing attestation = fail
- Expired attestation = fail
- Resolver unavailable = fail (unless fallback configured)

### Deterministic Evaluation

- Pure functions (no state changes during evaluation)
- Same input always produces same output
- Enables offchain simulation and forensics

### Transparent Logging

All critical operations emit events:
- Rule evaluations (pass/fail, reason)
- Policy changes (register, stage, activate)
- Identity updates (attestations, revocations)
- Governance actions (role grants, timelock operations)

### Attack Vectors & Mitigations

| Attack | Mitigation |
|--------|-----------|
| Governance takeover | Multi-sig + Timelock + Role separation |
| Malicious rules | Admin-only rule addition + Timelock for activation |
| Identity spoofing | Cryptographic attestations (EIP-712, EAS) |
| Reentrancy | Checks-Effects-Interactions pattern |
| Frontrunning | Commit-reveal for sensitive ops |
| Gas griefing | Rule execution limits + Circuit breaker |

## Extensibility

### Adding New Rules

```solidity
contract MyRule is BaseRule {
    constructor(/* params */) BaseRule(
        keccak256("MY_RULE"),
        "My Rule Name",
        1
    ) {}

    function evaluate(IContext context) external view override 
        returns (RuleResult memory) 
    {
        // Custom logic
        if (/* condition */) {
            return _pass();
        } else {
            return _fail("Reason");
        }
    }
}
```

### Adding New Identity Resolvers

```solidity
contract MyResolver is IIdentityResolver {
    function resolveIdentity(address subject) external view override 
        returns (AttestationStatus memory) 
    {
        // Query external source
        // Return attestation status
    }
}
```

### Adding New Asset Types

```solidity
contract RWA_MyToken is IRWAAdapter {
    IRulesEngine public immutable rulesEngine;

    function myTokenOperation(/* params */) external {
        // Create context
        Context context = new Context(/* ... */);
        
        // Evaluate rules
        IRulesEngine.EvaluationResult memory result = 
            rulesEngine.evaluate(context);
        
        require(result.passed, result.reason);
        
        // Execute operation
    }
}
```

## Deployment Strategy

### MVP Deployment

1. Deploy core infrastructure:
   - RuleSet
   - RulesEngine
   - PolicyRegistry

2. Deploy identity resolution:
   - AllowListResolver
   - Configure initial identities

3. Deploy rules:
   - KYCTierRule
   - BlacklistRule
   - LockupRule
   - Add to RuleSet

4. Deploy governance:
   - AccessControl
   - Timelock
   - CircuitBreaker

5. Deploy asset:
   - RWA_ERC20
   - Configure roles
   - Test transfers

### Production Deployment

- Use multi-sig for all admin roles
- Configure appropriate timelocks (24-48h minimum)
- Set up monitoring and alerting
- Deploy to testnet first
- Comprehensive audit before mainnet
- Gradual rollout (limited users → full)

## Testing Strategy

1. **Unit Tests**: Test each component in isolation
2. **Integration Tests**: Test component interactions
3. **Scenario Tests**: Test realistic user flows
4. **Invariant Tests**: Test properties that must always hold
5. **Fuzzing**: Random input testing
6. **Gas Benchmarks**: Measure and optimize costs

## Upgrade Path

Contracts use ERC-1967 proxy pattern:
- Logic contracts are upgradeable
- Storage layout must be preserved
- Timelock-enforced upgrades
- Multi-sig approval required

## Future Enhancements

- Formal verification of critical paths
- Advanced oracle integrations (Chainlink, Pyth)
- Cross-chain policy synchronization
- Privacy-preserving identity (zk-SNARKs)
- Machine learning risk scoring
- Automated compliance reporting

---
