# EDDO - Usage Guide

Complete guide for deploying, configuring, and using EDDO.

## Table of Contents

1. [Installation](#installation)
2. [Quick Start](#quick-start)
3. [Core Concepts](#core-concepts)
4. [Deployment](#deployment)
5. [Configuration](#configuration)
6. [Rule Development](#rule-development)
7. [Identity Management](#identity-management)
8. [Policy Management](#policy-management)
9. [Asset Operations](#asset-operations)
10. [Governance](#governance)
11. [Testing](#testing)
12. [Production Checklist](#production-checklist)

## Installation

### Using Hardhat

```bash
npm install --save-dev hardhat
npm install --save-dev @nomicfoundation/hardhat-toolbox
npm install
```

### Using Foundry

```bash
forge install
forge build
```

Compile Contracts

```bash
# Hardhat
npx hardhat compile


```

## Core Concepts

### Rules Engine

The rules engine evaluates a set of compliance rules against every token operation. Rules are:

- **Deterministic**: Same input → same output
- **Composable**: Combine multiple rules
- **Prioritized**: Higher priority rules evaluated first
- **Mandatory/Optional**: Mandatory failures block operations

### Context

Every operation creates a `Context` containing:

```solidity
struct Context {
    OperationType operationType;  // TRANSFER, MINT, BURN, etc.
    address actor;                 // Who initiated
    address counterparty;          // Who receives/sends
    uint256 amount;                // How much
    address asset;                 // Which asset
    uint256 timestamp;             // When
}
```

### Rules

Rules evaluate contexts and return results:

```solidity
struct RuleResult {
    bool passed;       // Did the rule pass?
    string reason;     // Why did it fail?
    bytes32 ruleId;    // Which rule
}
```

## Deployment

### Step 1: Deploy Core Infrastructure

```solidity
// Deploy rule set
RuleSet ruleSet = new RuleSet();

// Deploy rules engine
RulesEngine engine = new RulesEngine(
    address(ruleSet),
    IRulesEngine.EvaluationMode.SHORT_CIRCUIT
);

// Deploy policy registry
PolicyRegistry policyRegistry = new PolicyRegistry();
```

### Step 2: Deploy Identity Resolution

```solidity
// Simple allow-list
AllowListResolver resolver = new AllowListResolver();

// Or composite with multiple sources
CompositeIdentityResolver composite = new CompositeIdentityResolver(
    CompositeIdentityResolver.ResolverMode.QUORUM,
    2  // require 2 out of N resolvers
);
```

### Step 3: Deploy Rules

```solidity
// KYC tier rule
KYCTierRule kycRule = new KYCTierRule(
    address(resolver),
    IIdentityResolver.IdentityTier.BASIC,
    IIdentityResolver.IdentityTier.BASIC,
    true  // check counterparty
);

// Add to rule set
ruleSet.addRule(kycRule, 100, true);  // priority 100, mandatory
```

### Step 4: Deploy Asset

```solidity
// Deploy RWA token
RWA_ERC20 token = new RWA_ERC20(
    "My RWA Token",
    "RWA",
    18,
    address(engine)
);
```

## Configuration

### Configure Rules

```solidity
// Add jurisdiction allowlist
JurisdictionRule jurisdictionRule = new JurisdictionRule(
    address(resolver),
    JurisdictionRule.ListType.ALLOWLIST
);

// Add allowed jurisdictions
jurisdictionRule.addJurisdiction("US");
jurisdictionRule.addJurisdiction("UK");
jurisdictionRule.addJurisdiction("SG");

// Add to rule set
ruleSet.addRule(jurisdictionRule, 90, true);
```

### Configure Identity

```solidity
// Add address to allow-list
resolver.setAttestation(
    userAddress,
    IIdentityResolver.IdentityTier.BASIC,
    "US",  // jurisdiction
    0      // no expiry
);

// Batch add
address[] memory users = [user1, user2, user3];
IIdentityResolver.IdentityTier[] memory tiers = [BASIC, BASIC, ADVANCED];
bytes2[] memory jurisdictions = ["US", "UK", "SG"];
uint256[] memory expiries = [0, 0, 0];

resolver.batchSetAttestations(users, tiers, jurisdictions, expiries);
```

### Configure Blacklist

```solidity
BlacklistRule blacklistRule = new BlacklistRule();
ruleSet.addRule(blacklistRule, 200, true);  // highest priority

// Add address to blacklist
blacklistRule.addToBlacklist(
    badActor,
    block.timestamp + 365 days,  // expires in 1 year
    "Suspicious activity detected"
);
```

### Configure Lockups

```solidity
LockupRule lockupRule = new LockupRule();
ruleSet.addRule(lockupRule, 80, true);

// Lock tokens for an address
lockupRule.setLockup(
    vestingAccount,
    block.timestamp + 180 days,  // locked for 6 months
    1000000 * 10**18,             // amount locked
    "Vesting schedule"
);
```

## Rule Development

### Creating a Custom Rule

```solidity
// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {BaseRule} from "../core/BaseRule.sol";
import {IContext} from "../interfaces/IContext.sol";

contract TradingHoursRule is BaseRule {
    uint256 public marketOpenHour = 9;   // 9 AM
    uint256 public marketCloseHour = 17; // 5 PM

    constructor() BaseRule(
        keccak256("TRADING_HOURS_RULE"),
        "Trading Hours Check",
        1
    ) {}

    function evaluate(IContext context) 
        external 
        view 
        override 
        returns (RuleResult memory) 
    {
        // Skip for minting
        if (context.operationType() == IContext.OperationType.MINT) {
            return _pass();
        }

        // Get current hour (UTC)
        uint256 hour = (block.timestamp / 3600) % 24;

        // Check if within trading hours
        if (hour < marketOpenHour || hour >= marketCloseHour) {
            return _fail("Trading outside market hours");
        }

        return _pass();
    }

    function setTradingHours(uint256 open, uint256 close) external {
        require(open < 24 && close < 24, "Invalid hours");
        require(open < close, "Open must be before close");
        marketOpenHour = open;
        marketCloseHour = close;
    }
}
```

### Adding Rule to Engine

```solidity
TradingHoursRule tradingHours = new TradingHoursRule();
ruleSet.addRule(tradingHours, 70, false);  // optional rule
```

## Identity Management

### Attestation Lifecycle

```solidity
// 1. Create attestation
resolver.setAttestation(user, BASIC, "US", 0);

// 2. Check attestation
AttestationStatus memory status = resolver.resolveIdentity(user);
require(status.isValid, "Invalid attestation");

// 3. Revoke attestation
resolver.revokeAttestation(user);

// 4. Update attestation (upgrade tier)
resolver.setAttestation(user, ADVANCED, "US", 0);
```

### Using Composite Resolver

```solidity
CompositeIdentityResolver composite = new CompositeIdentityResolver(
    CompositeIdentityResolver.ResolverMode.QUORUM,
    2  // require 2 attestations
);

// Add resolvers
composite.addResolver(address(easResolver), 1);
composite.addResolver(address(allowListResolver), 1);
composite.addResolver(address(oracleResolver), 1);

// Now requires 2 out of 3 to pass
```

## Policy Management

### Registering a Policy

```solidity
// Compute policy hash
bytes32 ruleSetHash = keccak256(abi.encode(
    address(ruleSet),
    block.timestamp
));

// Register policy
uint256 version = policyRegistry.registerPolicy(
    ruleSetHash,
    "Q1 2026 Compliance Policy"
);
```

### Staging and Activating

```solidity
// Stage policy (starts 24h timelock)
policyRegistry.stagePolicy(version);

// Wait 24 hours...

// Activate policy
policyRegistry.activatePolicy(version);
// Previous policy automatically deprecated
```

### Querying Policies

```solidity
// Get active version
uint256 active = policyRegistry.getActiveVersion();

// Get policy details
PolicyMetadata memory policy = policyRegistry.getPolicyMetadata(active);
console.log("Version:", policy.version);
console.log("Status:", uint(policy.status));
console.log("Description:", policy.description);
```

## Asset Operations

### Minting

```solidity
// Ensure recipient has attestation
resolver.setAttestation(recipient, BASIC, "US", 0);

// Mint (rules checked automatically)
token.mint(recipient, 1000 * 10**18);
```

### Transferring

```solidity
// Transfer (rules enforced)
token.transfer(recipient, 100 * 10**18);

// If rules pass: transfer succeeds
// If rules fail: reverts with reason
```

### Burning

```solidity
// Burn own tokens
token.burn(100 * 10**18);

// Burn from another address (with allowance)
token.approve(burner, 100 * 10**18);
token.burnFrom(holder, 100 * 10**18);
```

### Pausing

```solidity
// Pause all operations
token.pause();

// Unpause
token.unpause();
```

## Governance

### Access Control

```solidity
AccessControl ac = new AccessControl();

// Grant roles
ac.grantRole(ac.POLICY_MANAGER_ROLE(), policyManager);
ac.grantRole(ac.RULE_MANAGER_ROLE(), ruleManager);
ac.grantRole(ac.MINTER_ROLE(), minter);

// Revoke roles
ac.revokeRole(ac.MINTER_ROLE(), oldMinter);

// Check roles
bool hasRole = ac.hasRole(ac.ADMIN_ROLE(), address);
```

### Circuit Breaker

```solidity
CircuitBreaker breaker = new CircuitBreaker(guardian);

// Open circuit (emergency stop)
breaker.openCircuit("Security incident detected");

// Enable safe mode (limited ops)
breaker.enableSafeMode("Investigating anomaly");

// Close circuit (resume)
// (must wait cooldown period)
breaker.closeCircuit();
```

### Timelock Operations

```solidity
Timelock timelock = new Timelock(admin, 2 days);

// Queue transaction
bytes32 txHash = timelock.queueTransaction(
    target,
    0,
    "updateMaxSupply(uint256)",
    abi.encode(newMaxSupply),
    block.timestamp + 2 days
);

// Wait 2 days...

// Execute transaction
timelock.executeTransaction(
    target,
    0,
    "updateMaxSupply(uint256)",
    abi.encode(newMaxSupply),
    eta
);
```

## Testing

### Unit Test Example

```javascript
const { expect } = require("chai");

describe("RWA_ERC20", function () {
  let token, engine, ruleSet, resolver;
  let owner, user1, user2;

  beforeEach(async function () {
    [owner, user1, user2] = await ethers.getSigners();
    
    // Deploy components
    ruleSet = await RuleSet.deploy();
    engine = await RulesEngine.deploy(ruleSet.address, 2);
    resolver = await AllowListResolver.deploy();
    
    // Deploy token
    token = await RWA_ERC20.deploy("Test", "TST", 18, engine.address);
    
    // Setup attestations
    await resolver.setAttestation(user1.address, 1, "US", 0);
  });

  it("Should allow transfer with valid attestation", async function () {
    await token.mint(user1.address, 1000);
    await resolver.setAttestation(user2.address, 1, "US", 0);
    
    await expect(
      token.connect(user1).transfer(user2.address, 100)
    ).to.not.be.reverted;
  });

  it("Should block transfer without attestation", async function () {
    await token.mint(user1.address, 1000);
    
    await expect(
      token.connect(user1).transfer(user2.address, 100)
    ).to.be.revertedWith("Actor does not meet minimum KYC tier");
  });
});
```
