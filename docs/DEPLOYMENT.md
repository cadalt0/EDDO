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



## Prerequisites

### 1. Development Environment

```bash
# Clone repository
git clone...
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

**Fund Testnet Wallet 

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
