# Examples & Scenarios - EDDO

Real-world examples showing how to implement different RWA use cases.

## Table of Contents

1. [Example 1: Public Bond Issuance](#example-1-public-bond-issuance)
2. [Example 2: Private Equity Fund](#example-2-private-equity-fund)
3. [Example 3: Real Estate Tokenization](#example-3-real-estate-tokenization)
4. [Example 4: Commodity Trading](#example-4-commodity-trading)
5. [Example 5: Employee Stock Options](#example-5-employee-stock-options)
6. [Common Patterns](#common-patterns)

---

## Example 1: Public Bond Issuance

**Scenario:** Issue $100M bonds with public access, accredited investor secondary market

### Requirements

- **Qualification:** Must pass basic KYC
- **Geography:** Available globally except sanctions countries
- **Trading:** Limited transfers (no high-volume speculation)
- **Maturity:** Fixed issuance of 100M bonds

### Implementation

**Step 1: Deploy Infrastructure**
```javascript
const hre = require("hardhat");

async function deployBonds() {
  const deployer = await hre.ethers.getSigner();
  
  // 1. Access control
  const AccessControl = await hre.ethers.getContractFactory("AccessControl");
  const acl = await AccessControl.deploy();
  await acl.deployed();
  console.log("AccessControl:", acl.address);
  
  // 2. Rules engine
  const RulesEngine = await hre.ethers.getContractFactory("RulesEngine");
  const engine = await RulesEngine.deploy(acl.address);
  await engine.deployed();
  console.log("RulesEngine:", engine.address);
  
  // 3. Identity resolver (KYC)
  const AllowListResolver = await hre.ethers.getContractFactory("AllowListResolver");
  const resolver = await AllowListResolver.deploy(acl.address);
  await resolver.deployed();
  console.log("AllowListResolver:", resolver.address);
  
  // 4. Rules for bond trading
  
  // KYC: Must be BASIC+
  const KYCTierRule = await hre.ethers.getContractFactory("KYCTierRule");
  const kycRule = await KYCTierRule.deploy(acl.address, resolver.address);
  await kycRule.deployed();
  
  // Blacklist: No sanctions
  const BlacklistRule = await hre.ethers.getContractFactory("BlacklistRule");
  const blacklistRule = await BlacklistRule.deploy(acl.address);
  await blacklistRule.deployed();
  
  // Jurisdiction: Global except sanctions
  const JurisdictionRule = await hre.ethers.getContractFactory("JurisdictionRule");
  const jurisdictionRule = await JurisdictionRule.deploy(acl.address, resolver.address);
  await jurisdictionRule.deployed();
  
  // Velocity: Max $1M per day (prevent speculation)
  const VelocityRule = await hre.ethers.getContractFactory("VelocityRule");
  const velocityRule = await VelocityRule.deploy(acl.address);
  await velocityRule.deployed();
  
  // Supply cap: 100M bonds total
  const SupplyCapRule = await hre.ethers.getContractFactory("SupplyCapRule");
  const supplyCapRule = await SupplyCapRule.deploy(acl.address);
  await supplyCapRule.deployed();
  
  // 5. Create ruleset
  const RuleSet = await hre.ethers.getContractFactory("RuleSet");
  const ruleset = await RuleSet.deploy(acl.address);
  await ruleset.deployed();
  
  // Add rules in priority order (cheap first)
  await ruleset.addRule(blacklistRule.address, 0, true);    // Fastest
  await ruleset.addRule(jurisdictionRule.address, 1, true);
  await ruleset.addRule(kycRule.address, 2, true);
  await ruleset.addRule(velocityRule.address, 3, true);    // Slowest (tracking)
  await ruleset.addRule(supplyCapRule.address, 4, true);
  
  // 6. Bond token
  const BondToken = await hre.ethers.getContractFactory("RWA_ERC20");
  const bond = await BondToken.deploy(
    "100M Bond 2025",          // name
    "BON25",                   // symbol
    ethers.utils.parseEther("100000000"),  // initial supply (mint later)
    acl.address,
    engine.address
  );
  await bond.deployed();
  console.log("Bond Token:", bond.address);
  
  // 7. Connect everything
  const TRANSFER = 0;  // OperationType.TRANSFER
  await engine.setRuleSet(TRANSFER, ruleset.address);
  
  // Mint rules for new bond issuance
  const mintRuleset = await RuleSet.deploy(acl.address);
  const MINT = 1;
  await engine.setRuleSet(MINT, mintRuleset.address);
  await mintRuleset.addRule(supplyCapRule.address, 0, true);
  
  return {
    acl: acl.address,
    engine: engine.address,
    resolver: resolver.address,
    kycRule: kycRule.address,
    blacklistRule: blacklistRule.address,
    jurisdictionRule: jurisdictionRule.address,
    velocityRule: velocityRule.address,
    supplyCapRule: supplyCapRule.address,
    bond: bond.address
  };
}

deployBonds();
```

**Step 2: Initialize KYC Whitelist**
```javascript
async function initializeKYC(addresses) {
  const resolver = await ethers.getContractAt(
    "AllowListResolver",
    addresses.resolver
  );
  
  const users = [
    { addr: "0xAlice", tier: 1, country: "US", days: 365 },
    { addr: "0xBob", tier: 1, country: "UK", days: 365 },
    { addr: "0xCarol", tier: 1, country: "SG", days: 365 },
  ];
  
  for (const user of users) {
    await resolver.attestUser(user.addr, user.tier, user.country, user.days);
    console.log(`✓ Whitelisted ${user.addr} (${user.country})`);
  }
}
```

**Step 3: Configure Rules**
```javascript
async function configureRules(addresses) {
  // KYC: BASIC tier minimum
  const kycRule = await ethers.getContractAt("KYCTierRule", addresses.kycRule);
  await kycRule.setMinimumTier(1, 1);  // BASIC
  
  // Blacklist: Add OFAC countries
  const blacklist = await ethers.getContractAt("BlacklistRule", addresses.blacklistRule);
  await blacklist.addToBlacklist(
    "0x0000000000000000000000000000000000000001",
    0,
    "Sanctioned address"
  );
  
  // Jurisdiction: ALLOWLIST mode - Global
  const jurisdiction = await ethers.getContractAt(
    "JurisdictionRule",
    addresses.jurisdictionRule
  );
  await jurisdiction.setMode(0);  // ALLOWLIST
  // Add all countries except sanctions
  const countries = ["US", "UK", "DE", "FR", "JP", "SG", "AU", "CA", ...];
  for (const country of countries) {
    await jurisdiction.addJurisdiction(country);
  }
  
  // Supply cap: 100M bonds
  const supplyCap = await ethers.getContractAt("SupplyCapRule", addresses.supplyCapRule);
  await supplyCap.setMaxSupply(ethers.utils.parseEther("100000000"));
  
  // Velocity: $1M per day (assuming 1 token = $1)
  const velocity = await ethers.getContractAt("VelocityRule", addresses.velocityRule);
  await velocity.setLimit(
    "0xPublicTrader",
    ethers.utils.parseEther("1000000"),  // $1M
    24 * 60 * 60                         // 1 day
  );
}
```

**Step 4: Mint Initial Bonds**
```javascript
async function mintBonds(addresses, amount) {
  const bond = await ethers.getContractAt("RWA_ERC20", addresses.bond);
  
  // Mint initial bonds to treasury
  const tx = await bond.mint(
    "0xTreasuryAddress",
    ethers.utils.parseEther(amount)
  );
  
  await tx.wait();
  console.log(`✓ Minted ${amount} bonds`);
}
```

**Step 5: Enable Trading**
```javascript
async function enableTrading(addresses) {
  const bond = await ethers.getContractAt("RWA_ERC20", addresses.bond);
  
  // Alice buys 1000 bonds
  await bond.transfer("0xAlice", ethers.utils.parseEther("1000"));
  
  // Alice (US) sells 500 bonds to Bob (UK)
  const tx = await bond
    .connect(await ethers.getSigner("0xAlice"))
    .transfer("0xBob", ethers.utils.parseEther("500"));
  
  // Rules check:
  // 1. Alice not blacklisted? ✓
  // 2. Alice in allowed jurisdiction (US)? ✓
  // 3. Alice has BASIC KYC? ✓
  // 4. 500 < $1M daily limit? ✓
  // → Transfer allowed
  
  console.log("✓ Transfer successful");
}
```

**Real-World Usage:**
- Retail + institutional investors
- High liquidity
- Transparent rules
- Compliant with global regulations

---

## Example 2: Private Equity Fund

**Scenario:** $50M private equity fund with accredited investors only, lockup periods

### Requirements

- **Qualification:** Must be ACCREDITED investor
- **Lockup:** 3-year hold minimum
- **Velocity:** None (long-term holding expected)
- **Geography:** US only

### Implementation

```javascript
async function deployPEFund() {
  // ... (deployment same as bonds)
  
  // Rules:
  // 1. KYC: ACCREDITED only
  const kycRule = await KYCTierRule.deploy(acl, resolver);
  await kycRule.setMinimumTier(4, 4);  // ACCREDITED
  
  // 2. Jurisdiction: US only
  const jurisdictionRule = await JurisdictionRule.deploy(acl, resolver);
  await jurisdictionRule.setMode(0);  // ALLOWLIST
  await jurisdictionRule.addJurisdiction("US");
  
  // 3. Lockup: 3 years
  const lockupRule = await LockupRule.deploy(acl);
  const unlockTime = Math.floor(Date.now() / 1000) + 3 * 365 * 24 * 60 * 60;
  
  // Configure lockup for each investor after initial allocation
  await lockupRule.addLockup(
    "0xInvestor1",
    unlockTime,
    0,  // All tokens locked
    "PE fund 3-year lockup"
  );
  
  // 4. Supply cap: 50M shares
  const supplyCapRule = await SupplyCapRule.deploy(acl);
  await supplyCapRule.setMaxSupply(ethers.utils.parseEther("50000000"));
  
  // Create ruleset
  const ruleset = await RuleSet.deploy(acl);
  await ruleset.addRule(kycRule.address, 0, true);
  await ruleset.addRule(jurisdictionRule.address, 1, true);
  await ruleset.addRule(lockupRule.address, 2, true);
  await ruleset.addRule(supplyCapRule.address, 3, true);
  
  // Token
  const peToken = await RWA_ERC20.deploy("PE Fund Token", "PEF", 0, acl, engine);
  await engine.setRuleSet(0, ruleset.address);  // TRANSFER
  
  return {
    token: peToken.address,
    lockupRule: lockupRule.address,
    // ...
  };
}
```

**Key Differences from Bonds:**
- Stricter qualification (ACCREDITED only)
- Lockup prevents early exit
- No velocity (no daily trading limits)
- Single jurisdiction (US)
- Private transfer (select accredited only)

---

## Example 3: Real Estate Tokenization

**Scenario:** Tokenize commercial real estate with property-specific rules

### Requirements

- **Properties:** Multiple real estate assets
- **NAV:** Token value tied to property valuation
- **Transfers:** Restricted (institutional only)
- **Redemption:** Quarterly at NAV

### Implementation

```javascript
async function deployRealEstateFund() {
  // ... deployment ...
  
  // Special rule: Property-specific hold
  // Can't hold more than 10% of property
  
  // Another rule: Quarterly redemption window
  // Only allow transfers during redemption week
  
  // Blacklist rule with property-specific restrictions
  const blacklistRule = await BlacklistRule.deploy(acl);
  
  // Add property restrictions
  // If default on one property, block transfers
  const properties = ["PROP001", "PROP002", "PROP003"];
  
  // Identity resolver for institutional verification
  const resolver = await AllowListResolver.deploy(acl);
  
  // Attest institutional investors only
  await resolver.attestUser(
    "0xVanguard",
    4,  // ACCREDITED (institutional level)
    "US",
    365
  );
  
  // Multi-property support
  // Deploy multiple ERC721 tokens for deed ownership
  const propertyDeeds = [];
  for (let i = 0; i < properties.length; i++) {
    const deed = await RWA_ERC721.deploy(
      `Property ${i} Deed`,
      `DEED${i}`,
      acl,
      engine
    );
    propertyDeeds.push(deed.address);
  }
  
  // Each deed has same rules:
  // - Must be institutional
  // - Cannot exceed 10% ownership
  // - Only transfer during redemption window
  
  return {
    propertyDeeds: propertyDeeds,
    // ...
  };
}
```

---

## Example 4: Commodity Trading

**Scenario:** Tokenized gold spot trading with daily volume limits

### Requirements

- **Commodity:** Gold backing each token (1 token = 1 oz)
- **Trading:** 24/7, high velocity
- **Limits:** 1000 oz per transaction
- **Verification:** Basic KYC only

### Implementation

```javascript
async function deployGoldToken() {
  // ... deployment ...
  
  // Rules:
  
  // 1. KYC: BASIC tier
  const kycRule = await KYCTierRule.deploy(acl, resolver);
  await kycRule.setMinimumTier(1, 1);  // BASIC
  
  // 2. Blacklist: Basic sanctions check
  const blacklistRule = await BlacklistRule.deploy(acl);
  
  // 3. Supply: Pegged to physical gold reserves
  const supplyCapRule = await SupplyCapRule.deploy(acl);
  // Check actual gold holdings
  const goldOunces = 1_000_000;  // 1M oz in vault
  await supplyCapRule.setMaxSupply(ethers.utils.parseEther(goldOunces.toString()));
  
  // 4. Velocity: Per-transaction limit (not daily)
  // 1000 oz max per transfer
  const velocityRule = await VelocityRule.deploy(acl);
  await velocityRule.setLimit(
    "0xTrader",
    ethers.utils.parseEther("1000"),  // 1000 oz
    60 * 60  // Per 1 hour (rolling hourly limit)
  );
  
  // 5. Jurisdiction: Global except sanctions
  const jurisdictionRule = await JurisdictionRule.deploy(acl, resolver);
  await jurisdictionRule.setMode(0);  // ALLOWLIST global
  
  const ruleset = await RuleSet.deploy(acl);
  await ruleset.addRule(blacklistRule.address, 0, true);     // Cheapest
  await ruleset.addRule(kycRule.address, 1, true);
  await ruleset.addRule(jurisdictionRule.address, 2, true);
  await ruleset.addRule(velocityRule.address, 3, true);      // Most expensive
  await ruleset.addRule(supplyCapRule.address, 4, true);
  
  const goldToken = await RWA_ERC20.deploy(
    "Gold Spot Token",
    "GOLD",
    0,
    acl,
    engine
  );
  
  await engine.setRuleSet(0, ruleset.address);  // TRANSFER
  
  return {
    token: goldToken.address,
    // ...
  };
}
```

**High-Frequency Trading Considerations:**
- Velocity limit per hour (rolling)
- No lockup (commodity trading is fluid)
- Basic KYC (retail-accessible)
- High supply ceiling (pegged to reserves)

---

## Example 5: Employee Stock Options

**Scenario:** Company issues employee stock options with vesting

### Requirements

- **Eligible:** Employees only
- **Vesting:** 4-year vest, 1-year cliff
- **Exercise:** Quarterly exercise windows
- **Exercise Price:** Fixed at grant

### Implementation

```javascript
async function deployEmployeeOptions() {
  // ... deployment ...
  
  // Rules:
  
  // 1. Identity: Employee verification
  const resolver = await AllowListResolver.deploy(acl);
  
  // Add all employees
  const employees = [
    { addr: "0xEmployee1", tier: 2, country: "US" },
    { addr: "0xEmployee2", tier: 2, country: "US" },
    // ...
  ];
  
  for (const emp of employees) {
    await resolver.attestUser(emp.addr, emp.tier, emp.country, 365);
  }
  
  // 2. KYC: Employees only
  const kycRule = await KYCTierRule.deploy(acl, resolver);
  await kycRule.setMinimumTier(2, 2);  // INTERMEDIATE (employee)
  
  // 3. Lockup: Vesting schedule
  const lockupRule = await LockupRule.deploy(acl);
  
  // Year 1: Cliff (all locked)
  const cliffDate = Math.floor(Date.now() / 1000) + 365 * 24 * 60 * 60;
  await lockupRule.addLockup(
    "0xEmployee1",
    cliffDate,
    ethers.utils.parseEther("1000"),  // 1000 shares
    "1-year cliff"
  );
  
  // After year 1: 25% vested, 75% locked
  // Update at year 1:
  // await lockupRule.addLockup(emp, year2Date, 750, "Vesting continues");
  
  // 4. Blacklist: Prevent transfers to competitors
  const blacklistRule = await BlacklistRule.deploy(acl);
  // Add competitor addresses
  const competitors = ["0xCompetitor1", "0xCompetitor2"];
  for (const comp of competitors) {
    await blacklistRule.addToBlacklist(comp, 0, "Competitor restriction");
  }
  
  // 5. Supply cap: Total options granted
  const supplyCapRule = await SupplyCapRule.deploy(acl);
  await supplyCapRule.setMaxSupply(ethers.utils.parseEther("10000000"));  // 10M options
  
  const ruleset = await RuleSet.deploy(acl);
  await ruleset.addRule(blacklistRule.address, 0, true);
  await ruleset.addRule(kycRule.address, 1, true);
  await ruleset.addRule(lockupRule.address, 2, true);
  await ruleset.addRule(supplyCapRule.address, 3, true);
  
  const optionsToken = await RWA_ERC20.deploy(
    "Company Stock Options",
    "OPTN",
    0,
    acl,
    engine
  );
  
  await engine.setRuleSet(0, ruleset.address);  // TRANSFER
  
  return {
    token: optionsToken.address,
    lockupRule: lockupRule.address,
    // ...
  };
}
```

**Vesting Timeline Automation:**
```javascript
async function updateVestingSchedule(lockupRule, employee, year) {
  const vestingSchedule = [
    { year: 0, locked: 1000, desc: "1-year cliff" },
    { year: 1, locked: 750, desc: "25% vested" },
    { year: 2, locked: 500, desc: "50% vested" },
    { year: 3, locked: 250, desc: "75% vested" },
    { year: 4, locked: 0, desc: "100% vested" }
  ];
  
  const schedule = vestingSchedule[year];
  const vestDate = Math.floor(Date.now() / 1000) + year * 365 * 24 * 60 * 60;
  
  if (schedule.locked > 0) {
    await lockupRule.addLockup(
      employee,
      vestDate,
      ethers.utils.parseEther(schedule.locked.toString()),
      schedule.desc
    );
  } else {
    await lockupRule.removeLockup(employee);
  }
}
```

---

## Common Patterns

### Pattern 1: Tiered Compliance

```javascript
// Different rules based on user tier

if (tier === BASIC) {
  // Minimal rules: Just KYC check
  rules = [kycRule];
  limits = { velocity: "50k/day" };
}

if (tier === INTERMEDIATE) {
  // Standard: KYC + blacklist + jurisdiction
  rules = [kycRule, blacklistRule, jurisdictionRule];
  limits = { velocity: "500k/day" };
}

if (tier === ACCREDITED) {
  // Permissive: Just accreditation check
  rules = [kycRule];  // Skip velocity
  limits = { velocity: "unlimited" };
}
```

### Pattern 2: Time-Based Access

```javascript
// Different rules at different times

// Mint window: 9 AM - 5 PM ET
function isMintWindow() {
  const now = new Date();
  const hours = now.getHours();
  return hours >= 9 && hours < 17;
}

// Redemption window: Last week of quarter
function isRedemptionWindow() {
  const now = new Date();
  const month = now.getMonth();
  const day = now.getDate();
  
  // Months: 2 (Mar), 5 (Jun), 8 (Sep), 11 (Dec)
  const quarterEndMonths = [2, 5, 8, 11];
  return quarterEndMonths.includes(month) && day > 21;
}
```

### Pattern 3: Rate-Limiting Based on Action

```javascript
// Different velocity limits for different operations

// Mints: Slow (1M per day)
velocityRule.setLimit(minter, "1000000", 1 days);

// Burns: Unrestricted (treasury operations)
// (don't add to ruleset)

// Transfers: Medium (100k per day)
velocityRule.setLimit(trader, "100000", 1 days);

// Redemptions: Controlled (quarterly)
// (separate redemption window enforcement)
```

### Pattern 4: Multi-Asset Management

```javascript
// One rules engine, multiple tokens

const engine = await RulesEngine.deploy();

// Bond token
const bondToken = await RWA_ERC20.deploy(..., engine);
await engine.setRuleSet(TRANSFER, bondRuleset);

// Real estate token
const reToken = await RWA_ERC20.deploy(..., engine);
await engine.setRuleSet(TRANSFER, reRuleset);

// Gold token
const goldToken = await RWA_ERC20.deploy(..., engine);
await engine.setRuleSet(TRANSFER, goldRuleset);

// Each asset has different rules,
// but same engine coordinates them
```

### Pattern 5: Emergency Procedures

```javascript
// When issue discovered:

// 1. Pause all operations
await circuitBreaker.pause();

// 2. Investigate (blockchain immutable logs show everything)

// 3. If fraud: Blacklist actors
await blacklistRule.addToBlacklist(fraudAddress, 0, "Fraud confirmed");

// 4. Resume
await circuitBreaker.unpause();

// Or if critical:
// 5. Activate governance to pause permanently
await policyRegistry.createPolicyDraft(frozenRuleset);
await policyRegistry.stagePolicy(version, 0);  // No delay
await policyRegistry.activatePolicy(version);   // Immediate freeze
```

These examples show the framework's flexibility for different RWA use cases.
