# Configuration Guide - EDDO

Complete guide to configuring governance, roles, rules, and operational settings.

## Table of Contents

1. [Configuration Overview](#configuration-overview)
2. [Role Management](#role-management)
3. [Rule Configuration](#rule-configuration)
4. [Identity Setup](#identity-setup)
5. [Circuit Breaker Setup](#circuit-breaker-setup)
6. [Timelock Setup](#timelock-setup)
7. [Policy Management](#policy-management)
8. [Multi-Sig Governance](#multi-sig-governance)
9. [Configuration Checklist](#configuration-checklist)

---

## Configuration Overview

**Configuration Layers:**
```
Level 1: Access Control (Who can do what?)
   └─→ Roles & Permissions

Level 2: Rules Engine (What rules apply?)
   └─→ Rule selection & parameters

Level 3: Identity (Who is verified?)
   └─→ KYC whitelists

Level 4: Governance (How are changes made?)
   └─→ Timelock delays & approvals

Level 5: Operations (What happens day-to-day?)
   └─→ Pausing, monitoring, emergency stops
```

**Typical Flow:**
```
1. Admin configures roles
   ↓
2. Rule managers set up rules
   ↓
3. Identity managers whitelist users
   ↓
4. Operations begin
   ↓
5. Need to change rules? → Governance process
```

---

## Role Management

### Understanding Roles

**7 Core Roles:**

| Role | Purpose | Permissions |
|------|---------|-------------|
| **ADMIN** | Super admin | Grant roles, pause, deploy |
| **POLICY_MANAGER** | Policy changes | Draft/stage/activate policies |
| **RULE_MANAGER** | Add/remove rules | Modify rule configurations |
| **IDENTITY_MANAGER** | KYC operations | Approve/deny users |
| **PAUSER** | Emergency control | Pause/unpause trading |
| **MINTER** | Token creation | Mint new tokens |
| **BURNER** | Token destruction | Burn tokens |

### Role Hierarchy

```
ADMIN (top level)
│
├─ POLICY_MANAGER     (modify policies)
├─ RULE_MANAGER       (modify rules)
├─ IDENTITY_MANAGER   (manage KYC)
├─ PAUSER             (emergency stop)
├─ MINTER             (create tokens)
└─ BURNER             (destroy tokens)

No single role below ADMIN can grant other roles
ADMIN must approve all role changes
```

### Granting Roles

**Step 1: Get Role Identifier**
```javascript
const accessControl = await ethers.getContractAt(
  "AccessControl",
  accessControlAddress
);

const RULE_MANAGER_ROLE = await accessControl.RULE_MANAGER_ROLE();
console.log("RULE_MANAGER_ROLE:", RULE_MANAGER_ROLE);
// Output: 0x5e9... (256-bit role identifier)
```

**Step 2: Grant Role**
```javascript
const tx = await accessControl.grantRole(
  RULE_MANAGER_ROLE,
  "0xRuleManagerAddress"
);

await tx.wait();
console.log("✓ Role granted");
```

**Step 3: Verify Role**
```javascript
const hasRole = await accessControl.hasRole(
  RULE_MANAGER_ROLE,
  "0xRuleManagerAddress"
);

console.log("User has role:", hasRole);
```

### Multi-Sig Configuration

**Using Gnosis Safe:**
```javascript
// Instead of:
await accessControl.grantRole(role, address);

// Use Safe transaction:
const data = accessControl.interface.encodeFunctionData(
  "grantRole",
  [role, address]
);

// Send to Safe for approval by multiple signers
```

**Why Multi-Sig?**
- No single person can change rules
- 2-of-3 (or n-of-m) approval required
- Transparent on-chain voting
- Audit trail of who approved what

### Example Configuration

**Team Structure:**
```javascript
// Founder: ADMIN (full control)
await accessControl.grantRole(DEFAULT_ADMIN_ROLE, "0xFounder");

// Compliance Officer: RULE_MANAGER + IDENTITY_MANAGER
await accessControl.grantRole(RULE_MANAGER_ROLE, "0xCompliance");
await accessControl.grantRole(IDENTITY_MANAGER_ROLE, "0xCompliance");

// Operations: PAUSER + MINTER
await accessControl.grantRole(PAUSER_ROLE, "0xOperations");
await accessControl.grantRole(MINTER_ROLE, "0xOperations");

// Finance: BURNER
await accessControl.grantRole(BURNER_ROLE, "0xFinance");

// Multi-Sig: ADMIN
await accessControl.grantRole(DEFAULT_ADMIN_ROLE, "0xGnosisSafe");
```

### Revoking Roles

```javascript
const tx = await accessControl.revokeRole(
  RULE_MANAGER_ROLE,
  "0xRuleManagerAddress"
);

await tx.wait();
console.log("✓ Role revoked");
```

**Note:** Only another account with that role can revoke it.

---

## Rule Configuration

### Basic Rule Setup

**Step 1: Deploy Rules**
```javascript
// Deploy KYCTierRule
const kycRule = await KYCTierRule.deploy(
  identityResolverAddress
);
await kycRule.deployed();

// Deploy BlacklistRule
const blacklistRule = await BlacklistRule.deploy();
await blacklistRule.deployed();
```

**Step 2: Create RuleSet**
```javascript
// Create container for rules
const ruleSet = await RuleSet.deploy();
await ruleSet.deployed();

// Add rules with priority
await ruleSet.addRule(
  kycRule.address,
  0,     // priority (lower = higher)
  true   // mandatory (must pass)
);

await ruleSet.addRule(
  blacklistRule.address,
  1,     // priority
  true   // mandatory
);
```

**Step 3: Connect to Engine**
```javascript
const rulesEngine = await ethers.getContractAt(
  "RulesEngine",
  rulesEngineAddress
);

// Set rules for TRANSFER operations
const TRANSFER_OP = 0;
const tx = await rulesEngine.setRuleSet(
  TRANSFER_OP,
  ruleSet.address
);

await tx.wait();
console.log("✓ RuleSet configured for TRANSFER");
```

### Rule-Specific Configuration

#### KYCTierRule Configuration

```javascript
const kycRule = await ethers.getContractAt(
  "KYCTierRule",
  kycRuleAddress
);

// Set minimum tier for sender and receiver
const INTERMEDIATE = 2;
const ACCREDITED = 4;

const tx = await kycRule.setMinimumTier(
  INTERMEDIATE,  // sender must be INTERMEDIATE+
  ACCREDITED     // receiver must be ACCREDITED
);

await tx.wait();
console.log("✓ KYC tiers configured");
```

#### BlacklistRule Configuration

```javascript
const blacklistRule = await ethers.getContractAt(
  "BlacklistRule",
  blacklistRuleAddress
);

// Permanently block an address
const tx1 = await blacklistRule.addToBlacklist(
  "0xSanctionedAddress",
  0,  // No expiry
  "OFAC SDN"
);

// Temporarily block for 30 days
const tx2 = await blacklistRule.addToBlacklist(
  "0xSuspiciousAddress",
  Math.floor(Date.now() / 1000) + 30 * 24 * 60 * 60,
  "Under investigation"
);

await Promise.all([tx1.wait(), tx2.wait()]);
console.log("✓ Blacklist entries added");
```

#### JurisdictionRule Configuration

```javascript
const jurisdictionRule = await ethers.getContractAt(
  "JurisdictionRule",
  jurisdictionRuleAddress
);

// Set to ALLOWLIST mode (only these countries)
const ALLOWLIST = 0;
const tx1 = await jurisdictionRule.setMode(ALLOWLIST);

// Add allowed countries
const countries = ["US", "GB", "DE", "FR", "SG", "JP"];

for (const country of countries) {
  const tx = await jurisdictionRule.addJurisdiction(country);
  await tx.wait();
  console.log(`✓ Added ${country}`);
}
```

#### LockupRule Configuration

```javascript
const lockupRule = await ethers.getContractAt(
  "LockupRule",
  lockupRuleAddress
);

// Full lockup: all tokens locked for 1 year
const lockUntil = Math.floor(Date.now() / 1000) + 365 * 24 * 60 * 60;

const tx = await lockupRule.addLockup(
  "0xFounderAddress",
  lockUntil,
  0,  // 0 = all tokens locked
  "Founder vesting"
);

await tx.wait();
console.log("✓ Lockup configured");
```

#### VelocityRule Configuration

```javascript
const velocityRule = await ethers.getContractAt(
  "VelocityRule",
  velocityRuleAddress
);

// Basic users: 10k per day
const basicLimit = ethers.utils.parseEther("10000");
const tx1 = await velocityRule.setLimit(
  "0xBasicUser",
  basicLimit,
  24 * 60 * 60  // 1 day
);

// Advanced users: 1M per day
const advancedLimit = ethers.utils.parseEther("1000000");
const tx2 = await velocityRule.setLimit(
  "0xAdvancedUser",
  advancedLimit,
  24 * 60 * 60
);

await Promise.all([tx1.wait(), tx2.wait()]);
console.log("✓ Velocity limits configured");
```

#### SupplyCapRule Configuration

```javascript
const supplyCapRule = await ethers.getContractAt(
  "SupplyCapRule",
  supplyCapRuleAddress
);

// Maximum 1 million tokens
const maxSupply = ethers.utils.parseEther("1000000");
const tx = await supplyCapRule.setMaxSupply(maxSupply);

await tx.wait();
console.log("✓ Supply cap configured");
```

### Dynamic Rule Management

**Enable/Disable Rules (No Removal):**
```javascript
const ruleSet = await ethers.getContractAt(
  "RuleSet",
  ruleSetAddress
);

// Disable without removing (useful for testing)
const tx1 = await ruleSet.disableRule(kycRule.address);
await tx1.wait();
console.log("✓ KYC rule disabled");

// Later: Re-enable
const tx2 = await ruleSet.enableRule(kycRule.address);
await tx2.wait();
console.log("✓ KYC rule re-enabled");
```

---

## Identity Setup

### AllowListResolver Configuration

**Step 1: Connect to Resolver**
```javascript
const resolver = await ethers.getContractAt(
  "AllowListResolver",
  resolverAddress
);
```

**Step 2: Attest Users (Add to Whitelist)**
```javascript
// Tier levels:
// 0 = NONE
// 1 = BASIC
// 2 = INTERMEDIATE
// 3 = ADVANCED
// 4 = ACCREDITED

const users = [
  {
    address: "0xAlice",
    tier: 2,  // INTERMEDIATE
    jurisdiction: "US",
    days: 365
  },
  {
    address: "0xBob",
    tier: 4,  // ACCREDITED
    jurisdiction: "UK",
    days: 365
  },
  {
    address: "0xCarol",
    tier: 1,  // BASIC
    jurisdiction: "SG",
    days: 180
  }
];

for (const user of users) {
  const tx = await resolver.attestUser(
    user.address,
    user.tier,
    user.jurisdiction,
    user.days
  );
  
  await tx.wait();
  console.log(`✓ Attested ${user.address}`);
}
```

**Step 3: Verify Attestations**
```javascript
// Check user identity
const alice = await resolver.resolveIdentity("0xAlice");

console.log("Alice identity:");
console.log("  Tier:", alice.tier);          // 2 = INTERMEDIATE
console.log("  Jurisdiction:", alice.jurisdiction);  // US
console.log("  Expires at:", new Date(alice.expiresAt * 1000));
console.log("  Verified:", alice.verified);  // true
```

**Step 4: Update Attestations**
```javascript
// Promote user to higher tier
const tx = await resolver.attestUser(
  "0xAlice",
  4,  // Upgrade to ACCREDITED
  "US",
  365
);

await tx.wait();
console.log("✓ Alice upgraded to ACCREDITED");
```

**Step 5: Revoke Attestations**
```javascript
// Remove user from whitelist
const tx = await resolver.revokeAttestation("0xAlice");
await tx.wait();
console.log("✓ Alice revoked");
```

### CompositeIdentityResolver Configuration (Optional)

**For Multiple Identity Sources:**

```javascript
const compositeResolver = await ethers.getContractAt(
  "CompositeIdentityResolver",
  compositeResolverAddress
);

// Configure with 2-of-3 sources
const sources = [
  allowListResolverAddress,
  easAttestationAddress,      // Ethereum Attestation Service
  oracleAddress               // Custom oracle
];

const ANY = 0;          // At least one source confirms
const ALL = 1;          // All sources confirm
const QUORUM = 2;       // N out of M confirm

// Use QUORUM: 2 out of 3 must confirm
const tx = await compositeResolver.configure(
  sources,
  QUORUM,
  2  // 2 out of 3
);

await tx.wait();
console.log("✓ Composite resolver configured");
```

---

## Circuit Breaker Setup

### Emergency Pause Configuration

```javascript
const circuitBreaker = await ethers.getContractAt(
  "CircuitBreaker",
  circuitBreakerAddress
);

// Check current state
const state = await circuitBreaker.state();
console.log("Circuit breaker state:", state);
// 0 = CLOSED (normal)
// 1 = OPEN (paused)
// 2 = SAFE_MODE (limited operations)
```

### Pausing Operations

**Emergency Pause:**
```javascript
// Only PAUSER role can call this
const tx = await circuitBreaker.pause();
await tx.wait();

console.log("✓ Circuit breaker PAUSED");
console.log("  All transfers blocked");
console.log("  Emergency investigation mode");
```

**Resume Operations:**
```javascript
// Only ADMIN can unpause
const tx = await circuitBreaker.unpause();
await tx.wait();

console.log("✓ Circuit breaker RESUMED");
console.log("  Transfers allowed again");
```

### Cooldown Period Configuration

```javascript
// Check cooldown configuration
const cooldown = await circuitBreaker.PAUSE_COOLDOWN();
console.log("Pause cooldown:", cooldown, "seconds");
// Output: 3600 (1 hour)

// Cooldown prevents rapid pause/unpause cycles
// If paused, can't pause again for 1 hour
```

---

## Timelock Setup

### Delayed Execution for Critical Changes

**Workflow:**
```
1. Admin queues action (with delay)
   ↓ (Wait required time)
2. Anyone can execute after delay
   ↓
3. Action executes on-chain
```

### Queue a Rule Change

```javascript
const timelock = await ethers.getContractAt(
  "Timelock",
  timelockAddress
);

// Want to: Change KYC tier requirement
// Create transaction proposal
const target = kycRuleAddress;
const signature = "setMinimumTier(uint8,uint8)";
const params = ethers.utils.defaultAbiCoder.encode(
  ["uint8", "uint8"],
  [2, 4]  // New tiers: INTERMEDIATE sender, ACCREDITED receiver
);

const delay = 2 * 24 * 60 * 60;  // 2 days
const eta = Math.floor(Date.now() / 1000) + delay;

// Queue the transaction
const tx = await timelock.queueTransaction(
  target,
  0,  // value (no ETH)
  signature,
  params,
  eta
);

await tx.wait();
console.log("✓ Transaction queued");
console.log("  Execution time:", new Date(eta * 1000));
console.log("  Waiting period: 2 days");

// Save for later
const txHash = ethers.utils.solidityKeccak256(
  ["address", "uint256", "string", "bytes", "uint256"],
  [target, 0, signature, params, eta]
);
console.log("  Transaction hash:", txHash);
```

### Execute After Delay

```javascript
// After waiting period passes...
const tx = await timelock.executeTransaction(
  target,
  0,
  signature,
  params,
  eta
);

await tx.wait();
console.log("✓ Transaction executed");
console.log("  Rule change now active");
```

### Cancel if Needed

```javascript
// Before execution, can cancel
const tx = await timelock.cancelTransaction(
  target,
  0,
  signature,
  params,
  eta
);

await tx.wait();
console.log("✓ Transaction cancelled");
```

### Grace Period

```javascript
// After eta, have 14 days to execute
const GRACE_PERIOD = 14 * 24 * 60 * 60;  // 14 days

// If you miss this window, must requeue
console.log("Grace period:", GRACE_PERIOD, "seconds");
```

---

## Policy Management

### Create Versioned Policy

```javascript
const policyRegistry = await ethers.getContractAt(
  "PolicyRegistry",
  policyRegistryAddress
);

// Step 1: Create new RuleSet (new version)
const newRuleSet = await RuleSet.deploy();
await newRuleSet.deployed();

// Add rules to new version
await newRuleSet.addRule(newKycRule.address, 0, true);
await newRuleSet.addRule(newBlacklistRule.address, 1, true);

// Step 2: Create policy draft
const txDraft = await policyRegistry.createPolicyDraft(
  newRuleSet.address
);
await txDraft.wait();

const policies = await policyRegistry.getPolicies();
const version = policies.length - 1;

console.log(`✓ Policy v${version} created (DRAFT)`);
```

### Stage Policy for Activation

```javascript
// Stage with 24-hour activation delay
const delay = 24 * 60 * 60;  // 24 hours
const activationTime = Math.floor(Date.now() / 1000) + delay;

const txStage = await policyRegistry.stagePolicy(
  version,
  delay
);

await txStage.wait();
console.log(`✓ Policy v${version} staged`);
console.log(`  Activation time: ${new Date(activationTime * 1000)}`);
console.log(`  Waiting period: 24 hours`);
```

### Activate Policy

```javascript
// After 24 hours...
const txActivate = await policyRegistry.activatePolicy(version);
await txActivate.wait();

console.log(`✓ Policy v${version} activated`);
console.log(`  Old policy marked DEPRECATED`);
console.log(`  New policy now ACTIVE`);

// Verify current policy
const current = await policyRegistry.getCurrentPolicy();
console.log(`  Current policy: v${current.version}`);
```

### Policy Lifecycle Tracking

```javascript
// Check all policy versions
const policyCount = await policyRegistry.getPolioryCount();

for (let i = 1; i <= policyCount; i++) {
  const policy = await policyRegistry.getPolicyStatus(i);
  console.log(`Policy v${i}:`);
  console.log(`  Status: ${["DRAFT", "STAGED", "ACTIVE", "DEPRECATED"][policy]}`);
}
```

---

## Multi-Sig Governance

### Gnosis Safe Integration

**Setup:**
```bash
# Create Gnosis Safe
https://app.safe.global/

# Add signers (e.g., 3 team members)
# Set threshold to 2-of-3

# Add Safe address as ADMIN
```

**Grant Role via Safe:**
```javascript
// Step 1: Create transaction data
const data = accessControl.interface.encodeFunctionData(
  "grantRole",
  [RULE_MANAGER_ROLE, "0xNewManager"]
);

// Step 2: Send to Safe
// Safe address creates proposal
// Signers review and vote
// 2 signers approve → executed

// Step 3: Verify on-chain
const hasRole = await accessControl.hasRole(
  RULE_MANAGER_ROLE,
  "0xNewManager"
);
```

### Multi-Sig Best Practices

**Required Signatures:**
```
Critical actions (>$1M impact):    3-of-5
Important actions (>$100k):        2-of-3
Standard operations (<$100k):      1-of-2
```

**Signers:**
```
Recommended: Not all employees
- Founder
- CFO
- External advisor
- Lawyer
- Auditor
```

**Transparency:**
```
All transactions visible on-chain
✓ Date and time
✓ Who proposed
✓ Who approved
✓ What changed
```

---

## Configuration Checklist

### Initial Setup
- [ ] Deploy all contracts
- [ ] Configure AccessControl with multi-sig
- [ ] Set up Timelock with delays
- [ ] Configure CircuitBreaker
- [ ] Deploy RulesEngine with empty RuleSets

### Rules Configuration
- [ ] Deploy KYCTierRule and set tiers
- [ ] Deploy BlacklistRule and add OFAC list
- [ ] Deploy JurisdictionRule and add countries
- [ ] Deploy LockupRule (if needed)
- [ ] Deploy VelocityRule with limits
- [ ] Deploy SupplyCapRule with cap

### Identity Setup
- [ ] Deploy AllowListResolver
- [ ] Add initial whitelist of users
- [ ] Test identity resolution
- [ ] Set up tier levels

### Token Configuration
- [ ] Deploy RWA_ERC20
- [ ] Connect to RulesEngine
- [ ] Set initial supply (if fixed)
- [ ] Grant MINTER role

### Governance Configuration
- [ ] Connect Gnosis Safe to multi-sig role
- [ ] Test role-based access control
- [ ] Test Timelock with dummy transaction
- [ ] Document emergency procedures

### Testing
- [ ] Test complete rule pipeline
- [ ] Test emergency pause
- [ ] Test role revocation
- [ ] Test policy activation
- [ ] Load test with multiple transactions

### Monitoring
- [ ] Set up event monitoring
- [ ] Configure alerts for rule failures
- [ ] Track role changes
- [ ] Monitor gas usage

### Documentation
- [ ] Document all role assignments
- [ ] Record rule configurations
- [ ] Save deployment addresses
- [ ] Create runbooks for common operations

---

## Quick Reference: Common Operations

### Add New User
```javascript
const resolver = await ethers.getContractAt("AllowListResolver", resolverAddress);
await resolver.attestUser(userAddress, tier, jurisdiction, days);
```

### Block User
```javascript
const blacklist = await ethers.getContractAt("BlacklistRule", blacklistAddress);
await blacklist.addToBlacklist(userAddress, 0, "reason");
```

### Pause Trading
```javascript
const breaker = await ethers.getContractAt("CircuitBreaker", breakerAddress);
await breaker.pause();
```

### Change Rule
```javascript
// Queue with timelock
await timelock.queueTransaction(target, 0, sig, params, eta);
// Wait 2 days
await timelock.executeTransaction(target, 0, sig, params, eta);
```

### Grant Role
```javascript
const ac = await ethers.getContractAt("AccessControl", acAddress);
await ac.grantRole(RULE_MANAGER_ROLE, address);
```
