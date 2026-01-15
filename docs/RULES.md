# Rules Guide - EDDO

Comprehensive guide to all 6 built-in compliance rules and how to use them effectively.

## Table of Contents

1. [Rules Overview](#rules-overview)
2. [Rule 1: KYCTierRule](#rule-1-kyctierrule)
3. [Rule 2: BlacklistRule](#rule-2-blacklistrule)
4. [Rule 3: JurisdictionRule](#rule-3-jurisdictionrule)
5. [Rule 4: LockupRule](#rule-4-lockuprule)
6. [Rule 5: SupplyCapRule](#rule-5-supplycaprule)
7. [Rule 6: VelocityRule](#rule-6-velocityrule)
8. [Combining Rules](#combining-rules)
9. [Rule Development Guide](#rule-development-guide)

## Rules Overview

All 6 rules inherit from `BaseRule` and implement the `IRule` interface.

**Common Properties:**
- **Pure/View Only**: No state mutations (safe to call)
- **Deterministic**: Same input → Same output
- **Gas Efficient**: Optimized for on-chain evaluation
- **Composable**: Can combine multiple rules
- **Disableable**: Can be enabled/disabled without removal

**Quick Reference:**

| Rule | Purpose | Checks | Parameter |
|------|---------|--------|-----------|
| **KYCTierRule** | Verify identity | User tier vs minimum | `IdentityTier` |
| **BlacklistRule** | Block addresses | Address in list? | Addresses + expiry |
| **JurisdictionRule** | Geographic limits | Country allowed? | Country codes |
| **LockupRule** | Prevent transfers | Time not reached? | Timestamp |
| **SupplyCapRule** | Limit tokens | Total supply OK? | Max supply |
| **VelocityRule** | Rate limiting | Daily limit OK? | Amount + window |

---

## RULE 1: KYCTierRule

**File:** [contracts/rules/KYCTierRule.sol](../contracts/rules/KYCTierRule.sol)

### Purpose

Enforce minimum identity verification (KYC) levels for transaction participants.

### How It Works

```solidity
contract KYCTierRule is BaseRule {
    IIdentityResolver public identityResolver;
    IdentityTier public minimumTierActor;        // For sender
    IdentityTier public minimumTierCounterparty; // For receiver
}
```

The rule checks:
1. **Sender (actor)**: Must have at least `minimumTierActor`
2. **Receiver (counterparty)**: Must have at least `minimumTierCounterparty`

### Identity Tiers

From least to most verified:
```
NONE (0)           → Not verified
BASIC (1)          → Basic KYC (name, ID)
INTERMEDIATE (2)   → Financial info included
ADVANCED (3)       → Pre-accredited investor checks
ACCREDITED (4)     → Full accredited investor
```

### Configuration

**Step 1: Connect to Identity Resolver**
```solidity
kycRule.setIdentityResolver(allowListResolverAddress);
```

**Step 2: Set Minimum Tiers**
```solidity
// Require intermediate+ for sending
// Require accredited for receiving
kycRule.setMinimumTier(
    IdentityTier.INTERMEDIATE,  // sender minimum
    IdentityTier.ACCREDITED     // receiver minimum
);
```

### Evaluation Example

```
Transaction: Alice (INTERMEDIATE) → Bob (BASIC)

1. Check sender: Alice.tier (INTERMEDIATE) >= INTERMEDIATE? ✓ PASS
2. Check receiver: Bob.tier (BASIC) >= ACCREDITED? ✗ FAIL

Result: FAIL "Receiver KYC tier too low"
```

### Real-World Use Cases

**Case 1: Open to All**
```solidity
kycRule.setMinimumTier(
    IdentityTier.NONE,    // Anyone can send
    IdentityTier.NONE     // Anyone can receive
);
// Only requires being in the system
```

**Case 2: Qualified Investors**
```solidity
kycRule.setMinimumTier(
    IdentityTier.INTERMEDIATE,  // Investors
    IdentityTier.INTERMEDIATE   // Investors
);
// Both parties must pass financial background check
```

**Case 3: Accredited Only**
```solidity
kycRule.setMinimumTier(
    IdentityTier.ACCREDITED,    // Accredited only
    IdentityTier.ACCREDITED     // Accredited only
);
// Strictest: SEC accredited investor level
```

**Case 4: Asymmetric (Different for sender/receiver)**
```solidity
kycRule.setMinimumTier(
    IdentityTier.BASIC,         // Anyone can buy (send coins)
    IdentityTier.ADVANCED       // Seller must be qualified (receive coins)
);
// Scenario: Public can buy, only professionals can sell
```

### Interaction with Other Rules

**With BlacklistRule:**
```
KYCTierRule passes → USER IS VERIFIED
BlacklistRule passes → USER NOT SANCTIONED

Both must pass for transaction to succeed
```

**With VelocityRule:**
```
KYCTierRule passes → USER VERIFIED
VelocityRule passes → WITHIN DAILY LIMIT

Higher tier users could have higher daily limits
```

---

## RULE 2: BlacklistRule

**File:** [contracts/rules/BlacklistRule.sol](../contracts/rules/BlacklistRule.sol)

### Purpose

Block specific addresses from transferring tokens, optionally with expiry time.

### How It Works

```solidity
struct BlacklistEntry {
    bool listed;        // Is this address blacklisted?
    uint256 expiresAt;  // When it expires (0 = permanent)
    string reason;      // Why (e.g., "OFAC violation")
}

mapping(address => BlacklistEntry) public blacklist;
```

The rule checks:
1. **Is sender blacklisted?**
2. **If yes, has expiry passed?** (treat as not listed if expired)
3. **If yes and not expired, FAIL with reason**

### Configuration

**Add to Permanent Blacklist:**
```solidity
blacklistRule.addToBlacklist(
    sanctionedAddress,
    0,  // expiresAt = 0 (never expires)
    "OFAC SDN list"
);
```

**Add with Expiry (Temporary):**
```solidity
blacklistRule.addToBlacklist(
    suspiciousAddress,
    block.timestamp + 30 days,
    "Fraud investigation - under review"
);
```

**Remove from Blacklist:**
```solidity
blacklistRule.removeFromBlacklist(exAddress);
```

**Query Blacklist Status:**
```solidity
BlacklistEntry memory entry = blacklistRule.blacklist(someAddress);
require(!entry.listed, entry.reason);
```

### Evaluation Example

```
Blacklist state:
  0x1111 → listed=true, expiresAt=2025-12-31, reason="OFAC"
  0x2222 → listed=true, expiresAt=0 (permanent), reason="Fraud"
  0x3333 → listed=false

Transaction: 0x1111 → 0x9999

1. Check if 0x1111 blacklisted? → YES (listed=true)
2. Has expiry passed? → NO (current date < 2025-12-31)
3. Return FAIL "OFAC"

→ Transfer BLOCKED
```

### Expiry Benefits

**Permanent Blacklist:**
```solidity
// OFAC violation - permanent
addToBlacklist(sanctionedAddress, 0, "OFAC SDN");

// Can never be removed (unless explicitly called)
// Indicates: This person is permanently disqualified
```

**Temporary Blacklist:**
```solidity
// Fraud investigation - 30 day hold
addToBlacklist(suspiciousAddress, block.timestamp + 30 days, "Under investigation");

// After 30 days:
// - No whitelist action needed
// - Automatically allowed again
// - Rule still checked (not listed anymore)
```

### Real-World Scenarios

**Scenario 1: Sanctions Compliance**
```
Situation: User appears on OFAC SDN list

Action:
addToBlacklist(userAddress, 0, "OFAC SDN - Specially Designated National");

Result:
- User cannot transfer any tokens
- Permanent (no expiry)
- Stays on list until legal team removes them
```

**Scenario 2: Fraud Investigation**
```
Situation: Account shows signs of fraud

Action:
addToBlacklist(
    fraudAddress,
    block.timestamp + 30 days,
    "Account frozen pending investigation"
);

Timeline:
Day 0: Added to list, transfers blocked
Day 15: Investigation continues, still blocked
Day 30: Expiry reached, automatically whitelisted
Day 31: Can transfer again

OR if fraud confirmed on day 25:
addToBlacklist(fraudAddress, 0, "Confirmed fraud");  // Make permanent
```

**Scenario 3: Court Order**
```
Situation: Court orders account freeze

Action:
addToBlacklist(
    account,
    block.timestamp + 365 days,  // 1 year hold
    "Court order - Asset freeze"
);

After 1 year:
- Auto-expires
- Automatic restoration
- No need to call whitelist function
```

### Combined with VelocityRule

```
BlacklistRule: Is user sanctioned?
VelocityRule: Is user within daily limit?

Both must pass. Example:
- Alice not blacklisted ✓
- Alice within daily limit ✓
→ Transfer allowed

- Bob blacklisted ✗
→ Transfer blocked (even if within daily limit)
```

---

## RULE 3: JurisdictionRule

**File:** [contracts/rules/JurisdictionRule.sol](../contracts/rules/JurisdictionRule.sol)

### Purpose

Restrict transfers based on geographic location (country codes).

### How It Works

```solidity
enum JurisdictionMode {
    ALLOWLIST,   // Only listed countries allowed
    DENYLIST     // Listed countries blocked
}

mapping(string => bool) jurisdictions;  // "US" → true/false
JurisdictionMode mode;
```

The rule checks:
1. **Get actor's jurisdiction** from identity resolver
2. **Get counterparty's jurisdiction** from identity resolver
3. **Based on mode:**
   - ALLOWLIST: Both must be in allowed list
   - DENYLIST: Neither can be in blocked list

### Configuration

**ALLOWLIST Mode (Only US + EU):**
```solidity
jurisdictionRule.setMode(JurisdictionMode.ALLOWLIST);
jurisdictionRule.addJurisdiction("US");
jurisdictionRule.addJurisdiction("DE");
jurisdictionRule.addJurisdiction("FR");
jurisdictionRule.addJurisdiction("UK");

// Only users from these countries can transfer
// Alice (US) ↔ Bob (DE) → PASS
// Alice (US) ↔ Bob (SG) → FAIL
```

**DENYLIST Mode (Block Sanctioned Countries):**
```solidity
jurisdictionRule.setMode(JurisdictionMode.DENYLIST);

// Add countries on OFAC/UN sanction lists
jurisdictionRule.addJurisdiction("KP");  // North Korea
jurisdictionRule.addJurisdiction("IR");  // Iran
jurisdictionRule.addJurisdiction("SY");  // Syria
jurisdictionRule.addJurisdiction("CU");  // Cuba

// Everyone EXCEPT these countries can transfer
// Alice (US) ↔ Bob (UK) → PASS
// Alice (KP) ↔ Bob (US) → FAIL
```

**Remove Jurisdiction:**
```solidity
jurisdictionRule.removeJurisdiction("KP");
```

### Country Codes

Use ISO 3166-1 alpha-2 codes:

```
US = United States
GB = Great Britain
DE = Germany
FR = France
JP = Japan
SG = Singapore
KR = South Korea
IN = India
AU = Australia
CA = Canada

KP = North Korea (blocked)
IR = Iran (blocked)
SY = Syria (blocked)
CU = Cuba (blocked)
```

### Evaluation Examples

**Example 1: ALLOWLIST Mode**
```
Configuration:
mode = ALLOWLIST
allowed = ["US", "UK", "DE"]

Transaction: Alice (US) → Bob (US)
1. Actor jurisdiction: "US" in allowlist? ✓
2. Counterparty jurisdiction: "US" in allowlist? ✓
→ PASS

Transaction: Alice (SG) → Bob (US)
1. Actor jurisdiction: "SG" in allowlist? ✗
→ FAIL "Jurisdiction not allowed"
```

**Example 2: DENYLIST Mode**
```
Configuration:
mode = DENYLIST
blocked = ["KP", "IR", "SY"]

Transaction: Alice (US) → Bob (UK)
1. Actor in denylist? ✗
2. Counterparty in denylist? ✗
→ PASS

Transaction: Alice (IR) → Bob (US)
1. Actor in denylist? ✓
→ FAIL "Jurisdiction not allowed"
```

### Real-World Use Cases

**Case 1: US-Only Platform**
```solidity
// Only US-based users
jurisdictionRule.setMode(JurisdictionMode.ALLOWLIST);
jurisdictionRule.addJurisdiction("US");

// Ensures regulatory compliance for US-specific offering
```

**Case 2: Global Minus Sanctioned**
```solidity
// Available globally EXCEPT sanctioned countries
jurisdictionRule.setMode(JurisdictionMode.DENYLIST);
jurisdictionRule.addJurisdiction("KP");  // North Korea
jurisdictionRule.addJurisdiction("IR");  // Iran
jurisdictionRule.addJurisdiction("SY");  // Syria

// Maximum coverage minus compliance risk
```

**Case 3: EU Strict (ALLOWLIST)**
```solidity
// Only EU members
jurisdictionRule.setMode(JurisdictionMode.ALLOWLIST);
// Add all 27 EU countries
jurisdictionRule.addJurisdiction("AT");  // Austria
jurisdictionRule.addJurisdiction("BE");  // Belgium
// ... 25 more
jurisdictionRule.addJurisdiction("SE");  // Sweden
```

**Case 4: APAC Focus with Exclusions**
```solidity
// APAC countries minus high-risk
jurisdictionRule.setMode(JurisdictionMode.ALLOWLIST);
jurisdictionRule.addJurisdiction("SG");  // Singapore
jurisdictionRule.addJurisdiction("JP");  // Japan
jurisdictionRule.addJurisdiction("AU");  // Australia
jurisdictionRule.addJurisdiction("KR");  // South Korea
jurisdictionRule.addJurisdiction("HK");  // Hong Kong
```

### Interaction with Identity Resolver

The rule calls:
```solidity
identityResolver.resolveIdentity(address)
→ Returns AttestationStatus{
    tier: ...,
    jurisdiction: "US",  // ← Used by this rule
    expiresAt: ...,
    verified: ...
}
```

**Important:** Jurisdiction comes from identity resolver, not specified in transfer call.

---

## RULE 4: LockupRule

**File:** [contracts/rules/LockupRule.sol](../contracts/rules/LockupRule.sol)

### Purpose

Prevent transfers until a specific time (token vesting).

### How It Works

```solidity
struct Lockup {
    uint256 lockedUntil;  // Unix timestamp when unlock happens
    uint256 amount;       // 0 = all tokens locked, X = X tokens locked
    string reason;        // Why locked
}

mapping(address => Lockup) public lockups;
```

The rule checks:
1. **Does address have lockup?**
2. **If yes, has unlock time passed?**
3. **If no (locked), is transfer amount exceeding locked amount?**

### Two Lockup Types

**Type 1: Full Lockup (amount = 0)**
- Entire token balance is locked
- No transfers allowed until unlock time

**Type 2: Partial Lockup (amount > 0)**
- Only specified amount is locked
- Can transfer amounts below locked amount
- Cannot transfer more than locked amount

### Configuration

**Full Lockup (All Tokens Locked):**
```solidity
// Alice's 1000 tokens fully locked until 2025
lockupRule.addLockup(
    alice,
    block.timestamp + 365 days,
    0,  // amount = 0 means ALL locked
    "Founder vesting 1 year"
);

// alice.transfer(bob, 1)
// → FAIL: All tokens locked
```

**Partial Lockup (Some Tokens Locked):**
```solidity
// Alice has 1000 tokens, 600 are locked until 2024
lockupRule.addLockup(
    alice,
    block.timestamp + 180 days,
    600e18,  // 600 tokens are locked
    "Employee 6-month vesting"
);

// alice.transfer(bob, 300)
// → PASS (300 < 600 locked, so can transfer)

// alice.transfer(bob, 500)
// → FAIL (500 > 600 locked, so can't transfer this much)
```

**Remove Lockup:**
```solidity
// Unlock Alice
lockupRule.removeLockup(alice);

// Or just let time pass - after unlock time, automatically unlocked
```

### Evaluation Examples

**Example 1: Full Lockup Not Yet Expired**
```
Lockup: alice → lockedUntil=2025-06-01, amount=0
Current date: 2024-06-01
Transaction: alice.transfer(bob, 1)

1. Alice has lockup? → YES
2. Current time > lockedUntil? NO (2024 < 2025)
3. Amount=0 (full lock) → FAIL "Tokens locked until 2025-06-01"
```

**Example 2: Full Lockup Expired**
```
Lockup: alice → lockedUntil=2025-06-01, amount=0
Current date: 2025-07-01
Transaction: alice.transfer(bob, 1000)

1. Alice has lockup? → YES
2. Current time > lockedUntil? YES (2025-07 > 2025-06)
3. Unlock time passed → PASS
```

**Example 3: Partial Lockup**
```
Lockup: bob → lockedUntil=2025-01-01, amount=400e18
Bob has: 1000e18 total
Transaction: bob.transfer(alice, 500e18)

1. Bob has lockup? → YES
2. Current time > lockedUntil? NO
3. Transfer 500, locked 400 → 500 > 400 → FAIL "Cannot transfer locked amount"

Alternative transaction: bob.transfer(alice, 300e18)

1. Bob has lockup? → YES
2. Current time > lockedUntil? NO
3. Transfer 300, locked 400 → 300 < 400 → PASS
```

### Real-World Scenarios

**Scenario 1: Token Sale**
```
100 million tokens issued
- Founders: 20M with 4-year lockup
- Employees: 15M with 1-year lockup
- Public: 65M unlocked

Implementation:
addLockup(founderAddr, now + 4 years, 0, "Founder lockup");
addLockup(employeeAddr, now + 1 year, 0, "Employee lockup");
// Public addresses have no lockup
```

**Scenario 2: Vesting Schedule**
```
Employee gets 1000 tokens vesting quarterly

Setup:
- Year 1: 250 tokens unlock → 750 locked
- Year 2: 500 tokens unlock → 500 locked
- Year 3: 750 tokens unlock → 250 locked
- Year 4: 1000 tokens unlock → 0 locked

Implementation:
// Year 1-4 via Timelock
T+0: addLockup(employee, now + 1 yr, 750, "Vesting")
T+1yr: addLockup(employee, now + 2 yr, 500, "Vesting")
T+2yr: addLockup(employee, now + 3 yr, 250, "Vesting")
T+3yr: removeLockup(employee)
```

**Scenario 3: Cliff Lock**
```
Investor locked until Series B happens

addLockup(
    investorAddr,
    block.timestamp + 999999999,  // Far future
    0,
    "Locked until Series B"
);

// When Series B approved:
removeLockup(investorAddr);  // Unlock immediately
```

### Difference: Lockup vs Velocity Rule

| Rule | Prevents | Example |
|------|----------|---------|
| **LockupRule** | Transfers before date | "Can't sell until 2025" |
| **VelocityRule** | Transfers exceeding daily amount | "Max 100k per day" |

Both can be active:
- LockupRule: Time-based restriction
- VelocityRule: Rate-based restriction

---

## RULE 5: SupplyCapRule

**File:** [contracts/rules/SupplyCapRule.sol](../contracts/rules/SupplyCapRule.sol)

### Purpose

Enforce maximum total supply limit for token minting.

### How It Works

```solidity
contract SupplyCapRule is BaseRule {
    uint256 public maxSupply;
    IERC20 public token;
}
```

The rule checks:
1. **Is this a MINT operation?**
2. **If yes, would new total supply exceed cap?**
3. **If yes, FAIL**

### Configuration

**Set Maximum Supply:**
```solidity
// Token can never exceed 1 million
supplyCapRule.setMaxSupply(1_000_000e18);
```

**Update Cap:**
```solidity
// Change from 1M to 2M
supplyCapRule.setMaxSupply(2_000_000e18);
```

### Evaluation Examples

**Example 1: Mint Within Limit**
```
maxSupply = 1_000_000e18
currentSupply = 600_000e18
Transaction: mint(alice, 300_000e18)

1. Operation is MINT? → YES
2. New total = 600,000 + 300,000 = 900,000
3. 900,000 < 1,000,000? → YES → PASS
```

**Example 2: Mint Exceeding Limit**
```
maxSupply = 1_000_000e18
currentSupply = 900_000e18
Transaction: mint(alice, 200_000e18)

1. Operation is MINT? → YES
2. New total = 900,000 + 200,000 = 1,100,000
3. 1,100,000 < 1,000,000? → NO → FAIL "Exceeds supply cap"
```

**Example 3: Non-Mint Operations (Transfer)**
```
maxSupply = 1_000_000e18
Transaction: transfer(alice, bob, 100_000e18)

1. Operation is MINT? → NO
2. Not applicable (only checks mints) → PASS
```

### Real-World Use Cases

**Case 1: Tokenized Real Estate**
```
Limited property development

// Only 100 properties will be tokenized
supplyCapRule.setMaxSupply(100e18);

// 99 properties already tokenized
// Attempt to mint 100th property → PASS
// Attempt to mint 101st property → FAIL
```

**Case 2: Bond Issuance**
```
// Issuance of 1 million bonds, no more
supplyCapRule.setMaxSupply(1_000_000e18);

// Market certainty: Supply is fixed forever
// Prevents dilution
// Predictable value proposition
```

**Case 3: Equity Token**
```
// 10 million shares ever issued
supplyCapRule.setMaxSupply(10_000_000e18);

// Prevents uncontrolled dilution
// Protects existing shareholders
```

### Important: Only Applies to Minting

```solidity
// Only minting operations are checked
mint(address, amount)    → Checked (MINT operation)
burn(address, amount)    → Not checked
transfer(to, amount)     → Not checked
transferFrom(from, to, amount) → Not checked

// Reason: You can't exceed supply by burning or transferring
// Only minting creates new tokens
```

### Combined with Other Rules

**Supply Cap + Velocity Rule:**
```
SupplyCapRule: Can mint 1M total, only 100k per day
VelocityRule: Max 100k per day transfers

Different rules for minting vs transferring
```

**Supply Cap + KYCTierRule:**
```
SupplyCapRule: Maximum total cap
KYCTierRule: Only accredited can receive mints

Controls both quantity and eligibility
```

---

## RULE 6: VelocityRule

**File:** [contracts/rules/VelocityRule.sol](../contracts/rules/VelocityRule.sol)

### Purpose

Rate-limit transfers per address over time window (prevent wash trading, fraud).

### How It Works

```solidity
struct VelocityLimit {
    uint256 maxAmount;           // Max per window (e.g., 100k)
    uint256 windowDuration;      // Window length (e.g., 24 hours)
    uint256 windowStart;         // When window started
    uint256 amountInWindow;      // Already transferred this window
}

mapping(address => VelocityLimit) public limits;
```

The rule checks:
1. **How much has been transferred in current window?**
2. **Would this transfer exceed daily limit?**
3. **If yes, FAIL**

### Configuration

**Set Daily Limit:**
```solidity
// Alice can transfer max 100k per day
velocityRule.setLimit(
    alice,
    100_000e18,   // maxAmount
    1 days        // windowDuration
);
```

**Set Multiple Users:**
```solidity
// Basic users: 50k per day
velocityRule.setLimit(basicUser, 50_000e18, 1 days);

// Intermediate users: 500k per day
velocityRule.setLimit(intermediateUser, 500_000e18, 1 days);

// Advanced users: 5M per day
velocityRule.setLimit(advancedUser, 5_000_000e18, 1 days);
```

**Set Shorter Window (For Hourly Limits):**
```solidity
// Max 10k per hour
velocityRule.setLimit(user, 10_000e18, 1 hours);
```

**Update Limit:**
```solidity
// Increase limit to 150k per day
velocityRule.setLimit(alice, 150_000e18, 1 days);
```

### Evaluation Examples

**Example 1: Within Daily Limit**
```
Limit: maxAmount=100k, window=1 day
Window state: windowStart=TODAY, amountInWindow=30k
Current time: TODAY
Transaction: transfer(alice, bob, 40k)

1. Already transferred: 30k
2. This transfer: 40k
3. Total would be: 70k
4. Exceeds 100k? NO → PASS

Updated state: amountInWindow = 70k
```

**Example 2: Exceeds Daily Limit**
```
Limit: maxAmount=100k, window=1 day
Window state: amountInWindow=80k
Current time: SAME DAY
Transaction: transfer(alice, bob, 30k)

1. Already transferred: 80k
2. This transfer: 30k
3. Total would be: 110k
4. Exceeds 100k? YES → FAIL "Exceeds daily transfer limit"
```

**Example 3: Window Expires**
```
Limit: maxAmount=100k, window=1 day
Window state: windowStart=YESTERDAY, amountInWindow=100k
Current time: TODAY (>24 hours passed)
Transaction: transfer(alice, bob, 50k)

1. Has window expired? YES (TODAY > YESTERDAY + 1 day)
2. Reset amountInWindow = 0
3. New total = 0 + 50k = 50k
4. Exceeds 100k? NO → PASS

Updated state: amountInWindow = 50k, windowStart = TODAY
```

### Real-World Scenarios

**Scenario 1: Prevent Pump & Dump**
```
Security token
- Max 10% of holdings per day
- Prevents manipulation

Alice has 1000 tokens
- Can sell max 100 tokens per day
- Protects other shareholders
```

**Scenario 2: Fraud Detection**
```
Account suddenly tries to:
- Transfer 1M tokens per day
- Normal pattern: 100k per day

Rule blocks it immediately
Alert triggered for investigation
```

**Scenario 3: Tiered Limits Based on KYC Level**
```
// Different users, different limits

Rule 1: KYCTierRule
- Basic users must have BASIC tier
- Advanced users must have ADVANCED tier

Rule 2: VelocityRule
- Basic users: 10k per day
- Advanced users: 1M per day
- Accredited users: 10M per day

Combined: Tier + Speed limits
```

**Scenario 4: Anti-Wash-Trading**
```
Securities exchange rule:
- Max 5% of daily volume per holder
- Prevents artificial volume inflation

```

### Window Mechanics

**1-Hour Window Example:**
```
Timeline:
00:00 - Window starts, limit = 50k
00:15 - Alice transfers 30k ✓ (30k < 50k)
00:30 - Alice transfers 25k ✗ (30k + 25k > 50k)
01:01 - Window expires, counter resets
01:02 - Alice transfers 40k ✓ (new window, 40k < 50k)
```

**24-Hour Rolling Window:**
```
Timeline:
June 1, 10:00 - Window starts, limit = 100k per day
June 1, 12:00 - Transfer 60k ✓
June 1, 15:00 - Transfer 50k ✗ (60k + 50k > 100k)
June 2, 10:01 - Window expires, counter resets
June 2, 10:30 - Transfer 80k ✓ (new day)
```

### Combined with KYCTierRule

```solidity
// Tier-based limits: higher KYC = higher velocity

kycRule.setMinimumTier(IdentityTier.BASIC, IdentityTier.BASIC);

// Different velocity limits per tier
if (tier == IdentityTier.BASIC) {
    velocityRule.setLimit(user, 10_000e18, 1 days);    // $10k/day
}
if (tier == IdentityTier.INTERMEDIATE) {
    velocityRule.setLimit(user, 100_000e18, 1 days);   // $100k/day
}
if (tier == IdentityTier.ADVANCED) {
    velocityRule.setLimit(user, 1_000_000e18, 1 days); // $1M/day
}
```

---

## Combining Rules

Rules are most powerful when combined. Here's how.

### Rule Combination Strategy

**Short-Circuit Mode (Default):**
```solidity
rulesEngine.setEvaluationMode(EvaluationMode.SHORT_CIRCUIT);

// Evaluation order matters!
// Stops on FIRST failure

ruleset.addRule(blacklistRule, priority=0, mandatory=true);    // Cheapest
ruleset.addRule(kycRule, priority=1, mandatory=true);          // Moderate
ruleset.addRule(jurisdictionRule, priority=2, mandatory=true); // Moderate
ruleset.addRule(velocityRule, priority=3, mandatory=true);     // Most expensive
```

**Why order matters:**
- Blacklist: Single mapping lookup
- KYC: Calls identity resolver
- Jurisdiction: Calls identity resolver + comparison
- Velocity: Multiple lookups + tracking

**Gas savings:** If blacklisted, don't check expensive rules.

### Real-World Rule Combinations

**Combination 1: Accredited Investors Only (Secure)**
```solidity
ruleset.add(KYCTierRule);              // Only ACCREDITED tier
ruleset.add(BlacklistRule);            // Not blacklisted
ruleset.add(JurisdictionRule);         // US only
ruleset.add(VelocityRule);             // Max $5M per day

Result: Very restrictive, institutional-grade security
```

**Combination 2: Public Token (Inclusive)**
```solidity
ruleset.add(BlacklistRule);            // Not sanctioned
ruleset.add(VelocityRule);             // Rate limited

Result: Available to most people, basic compliance
```

**Combination 3: Real Estate Token (Mixed)**
```solidity
ruleset.add(KYCTierRule);              // INTERMEDIATE minimum
ruleset.add(JurisdictionRule);         // US-only
ruleset.add(LockupRule);               // 1-year lockup
ruleset.add(BlacklistRule);            // OFAC check

Result: Verified investors, geographic limits, long hold
```

**Combination 4: Security Token (Strict)**
```solidity
ruleset.add(KYCTierRule);              // ACCREDITED
ruleset.add(BlacklistRule);            // OFAC/sanctions
ruleset.add(JurisdictionRule);         // Approved countries
ruleset.add(VelocityRule);             // Anti-manipulation
ruleset.add(SupplyCapRule);            // Limited shares

Result: Regulatory-compliant security issuance
```

**Combination 5: Employee Stock Options (Time-Locked)**
```solidity
ruleset.add(KYCTierRule);              // Employees verified
ruleset.add(LockupRule);               // Vesting schedule
ruleset.add(VelocityRule);             // Can't dump all at once
ruleset.add(BlacklistRule);            // Prevent transfers to competitors

Result: Employee incentive with retention
```

### Rule Dependencies

**Rules that work together:**

```
KYCTierRule + VelocityRule
  → Higher tier users get higher daily limits

KYCTierRule + LockupRule
  → Higher tier users might have shorter lockups

JurisdictionRule + BlacklistRule
  → Block both sanctioned countries AND sanctioned addresses

SupplyCapRule + VelocityRule
  → Control minting rate AND transfer rate
```

---

## Rule Development Guide

### Creating Custom Rules

**Step 1: Inherit from BaseRule**
```solidity
import {IRule} from "../interfaces/IRule.sol";
import {BaseRule} from "../core/BaseRule.sol";
import {IContext} from "../interfaces/IContext.sol";

contract MyCustomRule is BaseRule {
    constructor() BaseRule("my-custom-rule") {}
}
```

**Step 2: Implement evaluate() Function**
```solidity
function evaluate(IContext context) external view override returns (RuleResult memory) {
    // Your custom logic
    
    if (someCondition) {
        return _pass();
    } else {
        return _fail("Reason this rule failed");
    }
}
```

**Step 3: Full Example**
```solidity
contract MinimumBalanceRule is BaseRule {
    uint256 public minimumBalance;
    IERC20 public token;

    constructor(uint256 _minBalance, address _token) BaseRule("min-balance") {
        minimumBalance = _minBalance;
        token = IERC20(_token);
    }

    function evaluate(IContext context) external view override returns (RuleResult memory) {
        uint256 balance = token.balanceOf(context.actor());
        
        if (balance < minimumBalance) {
            return _fail("Insufficient minimum balance");
        }
        
        return _pass();
    }
}
```

### Testing Rules

**Unit Test Template:**
```solidity
contract TestMyRule is Test {
    MyCustomRule rule;
    
    function setUp() public {
        rule = new MyCustomRule();
    }
    
    function testRulePasses() public {
        Context ctx = new Context(alice, bob, 1000, IContext.OperationType.TRANSFER);
        RuleResult memory result = rule.evaluate(ctx);
        assertTrue(result.passed);
    }
    
    function testRuleFails() public {
        Context ctx = new Context(mallory, bob, 1000, IContext.OperationType.TRANSFER);
        RuleResult memory result = rule.evaluate(ctx);
        assertFalse(result.passed);
        assertEq(result.reason, "Expected failure reason");
    }
}
```

### Best Practices

1. **View Only**: Never modify state in evaluate()
2. **Gas Efficient**: Minimize storage reads
3. **Fail Fast**: Return _fail() as soon as condition fails
4. **Clear Reason**: Explain why rule failed in error message
5. **No Dependencies**: Don't assume other rules ran first
6. **Handle Edge Cases**: Check for zero addresses, overflow, etc.

