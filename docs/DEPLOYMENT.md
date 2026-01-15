# Deployment Guide - EDDO

Complete step-by-step guide to deploy EDDO to testnet and mainnet.

## Table of Contents

1. [Deployment Overview](#deployment-overview)
2. [Prerequisites](#prerequisites)
3. [Phase 1: Local Testing](#phase-1-local-testing)
4. [Phase 2: Testnet Deployment](#phase-2-testnet-deployment)
5. [Phase 3: Mainnet Deployment](#phase-3-mainnet-deployment)
6. [Deployment Verification](#deployment-verification)
7. [Post-Deployment Configuration](#post-deployment-configuration)
8. [Monitoring & Troubleshooting](#monitoring--troubleshooting)

---

## Deployment Overview

**Architecture:**
```
1. Deploy Infrastructure
   ├── AccessControl (roles management)
   ├── Timelock (delayed execution)
   └── CircuitBreaker (emergency pause)

2. Deploy Rules Engine
   ├── RulesEngine (main orchestrator)
   ├── Create empty RuleSets for each operation type
   └── Deploy individual rules

3. Deploy Identity Resolution
   ├── AllowListResolver (KYC storage)
   └── CompositeIdentityResolver (optional)

4. Deploy Assets
   ├── RWA_ERC20 (main token)
   └── RWA_ERC721 (NFT, optional)

5. Deploy Policy Management
   └── PolicyRegistry (versioning)

6. Connect Components
   ├── Token points to RulesEngine
   ├── Rules point to IdentityResolver
   └── All link to AccessControl
```

**Gas Estimates (Ethereum L1):**
```
AccessControl        ~100k gas (~$5)
Timelock            ~150k gas (~$7)
CircuitBreaker      ~80k gas (~$4)
RulesEngine         ~200k gas (~$10)
AllowListResolver   ~100k gas (~$5)
RWA_ERC20           ~250k gas (~$12)
Individual Rules    ~80k gas each (~$4 each x 6)

Total: ~1,500k gas (~$70 at $50 gwei)
```

**Time Estimate:**
- Local testing: 10 minutes
- Testnet deployment: 10-20 minutes (waiting for confirmations)
- Mainnet deployment: 30+ minutes (safety checks)
- Configuration: 20-30 minutes (setting rules, roles)

---

## Prerequisites

### 1. Development Environment

```bash
# Clone repository
git clone <your-repo>
cd mantle-rwa-toolkit

# Install dependencies
npm install

# Verify Hardhat
npx hardhat --version
# Expected: Hardhat [version]

# Compile contracts
npx hardhat compile
# Expected: Compiled 27 Solidity files successfully
```

### 2. Wallet & Accounts

**Create Deployer Account:**
```bash
# Generate new private key (or use existing)
node -e "console.log(require('crypto').randomBytes(32).toString('hex'))"
# Output: abc123def456...

# Save to .env
echo "PRIVATE_KEY=0xabc123def456..." >> .env
```

**Fund Testnet Wallet (Sepolia):**
1. Get Sepolia ETH from faucet: https://sepoliafaucet.com
2. Verify balance:
```bash
node scripts/check-balance.js --network sepolia
```

### 3. Network Configuration

**Update .env:**
```bash
# Testnets
SEPOLIA_RPC_URL=https://sepolia.infura.io/v3/YOUR_INFURA_KEY
MANTLE_TESTNET_RPC_URL=https://rpc.testnet.mantle.xyz

# Mainnets
MAINNET_RPC_URL=https://eth-mainnet.g.alchemy.com/v2/YOUR_ALCHEMY_KEY
MANTLE_MAINNET_RPC_URL=https://rpc.mantle.xyz

# API Keys for verification
ETHERSCAN_API_KEY=YOUR_ETHERSCAN_KEY
MANTLE_SCAN_API_KEY=YOUR_MANTLESCAN_KEY

# Deployer
PRIVATE_KEY=0x...
```

### 4. Verify Network Connectivity

```bash
# Test RPC connection
npx hardhat run scripts/test-rpc.js --network sepolia

# Expected output:
# Network: Sepolia
# Chain ID: 11155111
# Latest block: 4567890
```

---

## Phase 1: Local Testing

### Step 1: Start Local Blockchain

**Terminal 1:**
```bash
npx hardhat node
# Expected output:
# Started HTTP and WebSocket JSON-RPC server at http://127.0.0.1:8545
```

**Accounts created (with 10,000 ETH each):**
```
Account #0: 0x1111111111111111111111111111111111111111
Account #1: 0x2222222222222222222222222222222222222222
... (20 accounts total)
```

### Step 2: Deploy Locally

**Terminal 2:**
```bash
npx hardhat run scripts/deploy-full.js --network localhost

# Expected output:
# [1/8] Deploying AccessControl...
# [2/8] Deploying Timelock...
# [3/8] Deploying CircuitBreaker...
# [4/8] Deploying RulesEngine...
# [5/8] Deploying AllowListResolver...
# [6/8] Deploying RWA_ERC20...
# [7/8] Deploying Rules (6 contracts)...
# [8/8] Deployment complete!
#
# Deployment Summary:
# AccessControl: 0x1234...
# RulesEngine: 0x5678...
# RWA_ERC20: 0x9abc...
# ...
```

### Step 3: Run Tests Locally

```bash
npx hardhat test --network localhost

# Expected: All tests pass
# ✓ AccessControl tests (X tests)
# ✓ RulesEngine tests (X tests)
# ✓ RWA_ERC20 tests (X tests)
# ...
# X tests passed
```

### Step 4: Verify Local Deployment

```bash
# Check token balance
npx hardhat run scripts/check-balance.js --network localhost

# Output:
# Account 0 balance: 10000 tokens
```

### Step 5: Test Rules Locally

```bash
# Run rules integration test
npx hardhat run scripts/test-rules.js --network localhost

# Tests rules in order:
# 1. KYC Tier enforcement
# 2. Blacklist blocking
# 3. Jurisdiction limits
# 4. Lockup enforcement
# 5. Supply cap limits
# 6. Velocity limits
```

**⚠️ Fix any issues before testnet deployment.**

---

## Phase 2: Testnet Deployment

### Step 1: Deploy to Sepolia

```bash
# Set network
export HARDHAT_NETWORK=sepolia

# Run deployment
npx hardhat run scripts/deploy-full.js --network sepolia

# Expected wait times:
# - 3-5 seconds for each transaction
# - Total: 5-10 minutes for full deployment
```

**Output Example:**
```
[AccessControl] Deploying...
Transaction: 0x1234...
Waiting for confirmation...
✓ Confirmed at block 4567890
Address: 0xaaaa000000000000000000000000000000000001

[Timelock] Deploying...
Transaction: 0x5678...
...

=== DEPLOYMENT COMPLETE ===
AccessControl:     0xaaaa000000000000000000000000000000000001
Timelock:          0xaaaa000000000000000000000000000000000002
CircuitBreaker:    0xaaaa000000000000000000000000000000000003
RulesEngine:       0xaaaa000000000000000000000000000000000004
AllowListResolver: 0xaaaa000000000000000000000000000000000005
RWA_ERC20:         0xaaaa000000000000000000000000000000000006
KYCTierRule:       0xaaaa000000000000000000000000000000000007
...

Save these addresses to .env for configuration!
```

### Step 2: Verify on Block Explorer

**Sepolia Etherscan:**
```bash
# Check contract code
https://sepolia.etherscan.io/address/0xaaaa000000000000000000000000000000000001

# Should show:
# ✓ Contract source code verified
# ✓ Transactions list
# ✓ Read/Write functions
```

### Step 3: Verify Contracts (Optional)

```bash
# Verify AccessControl
npx hardhat verify --network sepolia 0xaaaa000000000000000000000000000000000001

# Expected:
# ✓ Successfully verified contract AccessControl
```

### Step 4: Configure Testnet Rules

Create `scripts/configure-testnet.js`:

```javascript
const hre = require("hardhat");

async function main() {
  // Load addresses from previous deployment
  const addresses = require("./deployments/sepolia.json");
  
  // Connect to deployed contracts
  const accessControl = await hre.ethers.getContractAt(
    "AccessControl",
    addresses.accessControl
  );
  const rulesEngine = await hre.ethers.getContractAt(
    "RulesEngine",
    addresses.rulesEngine
  );
  const kycRule = await hre.ethers.getContractAt(
    "KYCTierRule",
    addresses.kycRule
  );

  // Grant roles
  const IDENTITY_MANAGER = await accessControl.IDENTITY_MANAGER_ROLE();
  const tx1 = await accessControl.grantRole(
    IDENTITY_MANAGER,
    "0xYourIdentityManager"
  );
  await tx1.wait();
  console.log("✓ Granted IDENTITY_MANAGER role");

  // Set KYC rule requirement
  const tx2 = await kycRule.setMinimumTier(
    1, // BASIC
    1  // BASIC
  );
  await tx2.wait();
  console.log("✓ Set KYC minimum tier to BASIC");

  console.log("Testnet configuration complete!");
}

main();
```

Run configuration:
```bash
npx hardhat run scripts/configure-testnet.js --network sepolia
```

### Step 5: Test on Testnet

```bash
# Transfer tokens
npx hardhat run scripts/test-transfer.js --network sepolia

# Should output:
# Account A balance: 1000 tokens
# Transfer 100 tokens to Account B
# ✓ Transfer successful
# Account B balance: 100 tokens
```

---

## Phase 3: Mainnet Deployment

### ⚠️ Pre-Mainnet Checklist

- [ ] All tests pass locally
- [ ] Testnet deployment successful
- [ ] Rules tested and working
- [ ] All contracts verified on Sepolia
- [ ] Security audit completed
- [ ] Governance structure decided
- [ ] Mainnet RPC endpoint configured
- [ ] Mainnet gas prices checked
- [ ] Mainnet wallet funded (>10 ETH recommended)

### Step 1: Pre-Deployment Safety Check

```bash
# Final compilation check
npx hardhat compile

# Run full test suite
npx hardhat test

# Estimate mainnet gas costs
npx hardhat run scripts/estimate-gas.js
```

**Output should show:**
```
AccessControl: ~100k gas → $5-10
Timelock: ~150k gas → $7-15
...
Total: ~1.5M gas → $70-150 at current gas prices
```

### Step 2: Deploy to Mainnet

**IMPORTANT: Use Multi-Sig Wallet**
```bash
# Deploy with governance wallet (ideally Gnosis Safe)
npx hardhat run scripts/deploy-full.js --network mainnet

# Verify each transaction before signing
# Check gas prices before confirming
```

**Conservative Settings:**
- Gas limit: 300k per contract (buffer for fluctuation)
- Gas price: Use standard or lower (not fast)
- Batch deployments: 2-3 contracts per block

### Step 3: Record Deployment

Save to `deployments/mainnet.json`:
```json
{
  "network": "ethereum",
  "chainId": 1,
  "deployedAt": "2024-01-15T10:30:00Z",
  "deployer": "0x...",
  
  "contracts": {
    "accessControl": "0xaaaa...",
    "timelock": "0xbbbb...",
    "circuitBreaker": "0xcccc...",
    "rulesEngine": "0xdddd...",
    "allowListResolver": "0xeeee...",
    "rwaERC20": "0xffff...",
    
    "rules": {
      "kycTierRule": "0x1111...",
      "blacklistRule": "0x2222...",
      "jurisdictionRule": "0x3333...",
      "lockupRule": "0x4444...",
      "supplyCapRule": "0x5555...",
      "velocityRule": "0x6666..."
    }
  },
  
  "txHashes": [
    "0x...",
    "0x..."
  ],
  
  "gasUsed": {
    "accessControl": 98765,
    "total": 1234567
  }
}
```

### Step 4: Verify Mainnet Contracts

```bash
# Verify each contract on Etherscan
for contract in AccessControl Timelock CircuitBreaker RulesEngine ...; do
  npx hardhat verify --network mainnet \
    "0xAddress..." \
    --constructor-args scripts/args/$contract.js
done
```

---

## Deployment Verification

### Checklist After Deployment

```bash
# 1. Check contract exists
curl -s https://api.etherscan.io/api \
  ?module=account&action=getcode \
  &address=0x... \
  &apikey=$ETHERSCAN_API_KEY | jq .result

# 2. Check for events
npx hardhat run scripts/check-events.js --network mainnet

# 3. Verify functions callable
npx hardhat run scripts/verify-functions.js --network mainnet

# 4. Check role assignments
npx hardhat run scripts/verify-roles.js --network mainnet
```

### Expected Outputs

**Contract deployed:**
```
✓ Code found at 0x...
✓ Contract: AccessControl
✓ Verified: true
```

**Events logged:**
```
✓ RoleGranted(DEFAULT_ADMIN_ROLE, deployer, deployer)
✓ RoleGranted(RULE_MANAGER_ROLE, ruleManager, deployer)
```

---

## Post-Deployment Configuration

### Step 1: Initialize Identity List

```javascript
const allowListResolver = await ethers.getContractAt(
  "AllowListResolver",
  "0xaddress..."
);

// Add verified users to whitelist
const tx = await allowListResolver.attestUser(
  "0xalice...",
  2,  // IdentityTier.INTERMEDIATE
  "US",
  365 // Valid for 365 days
);
await tx.wait();
console.log("✓ User attested");
```

### Step 2: Configure Rules

```javascript
const kycRule = await ethers.getContractAt("KYCTierRule", "0x...");
const jurisdictionRule = await ethers.getContractAt("JurisdictionRule", "0x...");

// Set KYC requirement
await kycRule.setMinimumTier(2, 2);  // INTERMEDIATE

// Add jurisdiction restrictions
await jurisdictionRule.setMode(0);  // ALLOWLIST
await jurisdictionRule.addJurisdiction("US");
```

### Step 3: Connect Rules to Engine

```javascript
const rulesEngine = await ethers.getContractAt("RulesEngine", "0x...");
const ruleset = new RuleSet([kycRule, jurisdictionRule, ...]);

await rulesEngine.setRuleSet(
  0,  // OperationType.TRANSFER
  ruleset.address
);
```

### Step 4: Set Admin Roles

```javascript
const accessControl = await ethers.getContractAt("AccessControl", "0x...");

// Grant roles to management team
const RULE_MANAGER = await accessControl.RULE_MANAGER_ROLE();
const IDENTITY_MANAGER = await accessControl.IDENTITY_MANAGER_ROLE();

await accessControl.grantRole(RULE_MANAGER, "0xruleManager...");
await accessControl.grantRole(IDENTITY_MANAGER, "0xidentityManager...");
```

---

## Monitoring & Troubleshooting

### Common Issues

**Issue 1: "Insufficient balance for gas"**
```bash
# Add more funds to wallet
# Testnet: Use faucet
# Mainnet: Send ETH from exchange

# Check balance:
ethers.provider.getBalance(address)
```

**Issue 2: "Nonce too high"**
```bash
# Reset nonce
ethers.provider.getTransactionCount(address, "pending")
```

**Issue 3: "Contract already exists"**
```bash
# Use different deployer address
# Or deploy to different network
```

**Issue 4: "Gas limit exceeded"**
```bash
# Increase gas limit in deployment script
const tx = {
  ...params,
  gasLimit: 500000  // Increase from default
};
```

### Monitoring Transactions

```bash
# Monitor mainnet transaction
https://etherscan.io/tx/0x...

# Check for:
# ✓ Status: Success
# ✓ Gas Used < Gas Limit
# ✓ Block confirmation

# Monitor mempool
https://etherscan.io/txsPending
```

### Post-Deployment Checks

```bash
# Verify state after deployment
npx hardhat run scripts/post-deploy-verify.js --network mainnet

# Checks:
# 1. All contracts deployed ✓
# 2. All roles set ✓
# 3. Rules configured ✓
# 4. Identity resolver initialized ✓
# 5. Token minting works ✓
# 6. Transfers evaluated by rules ✓
```

### Gas Optimization Notes

**Deployment optimization:**
```
Lower gas (but slower):
- Use standard gas price
- Deploy in low-traffic times
- Space out transactions

Higher confidence (but more expensive):
- Use fast gas price
- Deploy during business hours
- Batch deploy when possible
```

**Operation optimization:**
```
After deployment, rules are evaluated on every transfer.
These are pure functions with minimal gas:

Short-circuit mode: Stop on first failure = saves gas
Expensive rules (velocity) should be last in priority
```

---

## Deployment Scripts Reference

### `scripts/deploy-full.js`
Complete deployment of all contracts

### `scripts/deploy-minimal.js`
Deploy only essential contracts (RulesEngine + RWA_ERC20)

### `scripts/configure-testnet.js`
Configure testnet with demo rules and users

### `scripts/configure-mainnet.js`
Production configuration with real rules

### `scripts/verify-deployment.js`
Verify all contracts deployed correctly

### `scripts/backup-deployment.js`
Save deployment info for records

---

## Mainnet Safety Checklist

- [ ] Code audit completed
- [ ] All tests passing
- [ ] Testnet deployment successful
- [ ] Contracts verified on testnet explorer
- [ ] Gas estimates reviewed
- [ ] Deployer wallet secured (hardware wallet preferred)
- [ ] Multi-sig governance considered
- [ ] Emergency procedures documented
- [ ] Monitoring/alerting configured
- [ ] Post-deployment verification plan ready

**Only deploy to mainnet after ALL checks are complete.**
