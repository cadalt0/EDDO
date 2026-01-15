# Setup Guide - EDDO

Complete step-by-step setup instructions for development, testing, and deployment.

## Table of Contents

1. [Prerequisites](#prerequisites)
2. [Installation](#installation)
3. [Configuration](#configuration)
4. [Verification](#verification)
5. [Development Environment](#development-environment)
6. [IDE Setup](#ide-setup)
7. [Troubleshooting](#troubleshooting)

## Prerequisites

### Required
- **Node.js**: v18.0.0 or higher
- **npm**: v9.0.0 or higher (comes with Node.js)
- **Git**: Latest version

### Optional (for advanced development)
- **Foundry**: For forge compilation/testing
- **Solhint**: For contract linting
- **Slither**: For static analysis

### System Requirements
- **Disk Space**: 1GB minimum
- **RAM**: 2GB minimum
- **OS**: Linux, macOS, or Windows (WSL2 recommended)

## Installation

### Step 1: Clone Repository

```bash
git clone https://github.com/your-org/mantle-rwa-toolkit.git
cd mantle-rwa-toolkit
```

### Step 2: Install Node Dependencies

```bash
npm install
```

This installs:
- `@nomicfoundation/hardhat-toolbox` - Hardhat plugin collection
- `@openzeppelin/contracts` - OpenZeppelin v5.0.0 base contracts
- `hardhat` - Ethereum development environment
- `ethers` - Ethereum library (v6.x)

### Step 3: Verify Installation

```bash
# Check versions
node --version          # Should be v18+
npm --version           # Should be v9+
npx hardhat --version   # Should show Hardhat version
```

### Step 4: Compile Contracts

```bash
npx hardhat compile
```

**Expected output:**
```
Compiled 27 Solidity files successfully (evm target: paris)
```

## Configuration

### Hardhat Configuration

File: `hardhat.config.js`

```javascript
module.exports = {
  solidity: {
    version: "0.8.20",
    settings: {
      optimizer: {
        enabled: true,
        runs: 200,
      },
      viaIR: true,
    },
  },
  networks: {
    hardhat: {
      chainId: 1337,
    },
    localhost: {
      url: "http://127.0.0.1:8545",
    },
    sepolia: {
      url: process.env.SEPOLIA_RPC_URL || "",
      accounts: process.env.PRIVATE_KEY ? [process.env.PRIVATE_KEY] : [],
    },
  },
};
```

**Key Settings Explained:**

- **solidity.version**: Uses Solidity 0.8.20 (stable, secure)
- **optimizer.enabled**: Reduces bytecode size and gas costs
- **optimizer.runs**: 200 = balanced between deployment and execution cost
- **viaIR**: Uses Intermediate Representation for better optimization
- **networks**: Define different blockchain networks for testing/deployment

### Foundry Configuration

File: `foundry.toml`

```toml
[profile.default]
src = "contracts"
out = "out"
libs = ["node_modules"]
solc = "0.8.20"
optimizer = true
optimizer_runs = 200
via_ir = true

[profile.test]
optimizer = false
```

**Key Settings Explained:**

- **src**: Location of Solidity contracts
- **libs**: External dependencies location
- **via_ir**: Same IR optimization as Hardhat
- **optimizer_runs**: Same balance as Hardhat

### Environment Variables

Create `.env` file in project root:

```bash
# Testnet RPC endpoints
SEPOLIA_RPC_URL=https://sepolia.infura.io/v3/YOUR_INFURA_KEY
MANTLE_TESTNET_RPC_URL=https://rpc.testnet.mantle.xyz

# Private keys (NEVER commit these)
PRIVATE_KEY=0x...

# Optional: API keys for verification
ETHERSCAN_API_KEY=YOUR_ETHERSCAN_KEY
```

**⚠️ SECURITY**: Never commit `.env` to Git. Use `.env.example` instead:

```bash
# .env.example (commit this)
SEPOLIA_RPC_URL=
MANTLE_TESTNET_RPC_URL=
PRIVATE_KEY=
ETHERSCAN_API_KEY=
```

### package.json Scripts

```json
{
  "scripts": {
    "compile": "hardhat compile",
    "test": "hardhat test",
    "test:gas": "REPORT_GAS=true hardhat test",
    "clean": "hardhat clean",
    "node": "hardhat node",
    "deploy:localhost": "hardhat run scripts/deploy.js --network localhost",
    "deploy:sepolia": "hardhat run scripts/deploy.js --network sepolia"
  }
}
```

**Usage:**
```bash
npm run compile      # Compile all contracts
npm run test         # Run test suite
npm run node         # Start local blockchain
npm run deploy:localhost  # Deploy to local network
```

## Verification

### 1. Compilation Check

```bash
npx hardhat compile
```

Expected: `Compiled 27 Solidity files successfully`

### 2. Version Verification

```bash
# Check Hardhat version
npx hardhat --version

# Check OpenZeppelin version
npm list @openzeppelin/contracts
# Should show: @openzeppelin/contracts@5.0.0

# Check Node version
node --version
# Should be v18.0.0 or higher
```

### 3. Test Run

```bash
npx hardhat test
```

Expected: Tests run and show results (if tests are written)

### 4. Local Network Test

```bash
# Terminal 1: Start local blockchain
npx hardhat node

# Terminal 2: Deploy to local blockchain
npx hardhat run scripts/deploy.js --network localhost
```

## Development Environment

### Visual Studio Code Setup

#### Recommended Extensions

1. **Solidity by Juan Blanco**
   - ID: `juanblanco.solidity`
   - Syntax highlighting, compilation, linting

2. **Hardhat for Visual Studio Code**
   - ID: `nomicfoundation.hardhat-solidity`
   - Better Hardhat integration, console.log support

3. **Error Lens**
   - ID: `usernamehhnhnhn.errorlens`
   - Display errors inline while editing

4. **Trailing Spaces**
   - ID: `shardulm94.trailing-spaces`
   - Keep code clean

#### VS Code Settings

Create/update `.vscode/settings.json`:

```json
{
  "[solidity]": {
    "editor.defaultFormatter": "juanblanco.solidity",
    "editor.formatOnSave": true,
    "editor.rulers": [80, 120]
  },
  "solidity.compileUsingRemoteVersion": "0.8.20",
  "solidity.remappings": [
    "@openzeppelin/contracts=node_modules/@openzeppelin/contracts"
  ],
  "editor.codeActionsOnSave": {
    "source.fixAll": "explicit"
  },
  "files.exclude": {
    "**/node_modules": true,
    "**/artifacts": true,
    "**/cache": true
  }
}
```

### Command Line Tools

#### Slither Static Analysis

```bash
# Install
pip install slither-analyzer

# Run analysis
slither contracts/
```

#### Solhint Linting

```bash
# Install
npm install --save-dev solhint

# Run
npx solhint contracts/**/*.sol
```

## IDE Setup

### Setting Up Hardhat Console Debugging

In `hardhat.config.js`, enable console.log:

```javascript
const { task } = require("hardhat/config");

// Allows console.log in contracts
require("hardhat-chai-matchers");
```

Then in test files:
```javascript
const { ethers } = require("hardhat");
console.log("Value:", value); // Prints to console
```

### Setting Up Network Switcher

Create `.vscode/launch.json` for debugging:

```json
{
  "version": "0.2.0",
  "configurations": [
    {
      "type": "node",
      "request": "launch",
      "name": "Hardhat Test",
      "program": "${workspaceFolder}/node_modules/.bin/hardhat",
      "args": ["test"],
      "console": "integratedTerminal"
    }
  ]
}
```

## Troubleshooting

### Issue: "Cannot find module '@openzeppelin/contracts'"

**Solution:**
```bash
rm -rf node_modules package-lock.json
npm install
npx hardhat compile
```

### Issue: "Solidity version mismatch"

**Solution:**
```bash
# Verify hardhat can download the compiler
npx hardhat compile --force
```

### Issue: "Unknown error during compilation"

**Solution:**
```bash
# Clean and recompile
npx hardhat clean
npx hardhat compile
```

### Issue: "Gas exceeds block limit" during testing

**Solution:** Disable optimizer temporarily:

In `hardhat.config.js`:
```javascript
solidity: {
  version: "0.8.20",
  settings: {
    optimizer: {
      enabled: false,  // Disable temporarily
    },
  },
},
```

### Issue: "Port 8545 already in use" when running local node

**Solution:**
```bash
# Kill process on port 8545
lsof -i :8545 | grep LISTEN | awk '{print $2}' | xargs kill -9

# Or use different port
npx hardhat node --port 8546
```

### Issue: "Private key not found" during deployment

**Solution:**
```bash
# Create .env file
cp .env.example .env

# Add your private key (starting with 0x)
echo "PRIVATE_KEY=0x..." >> .env

# Never commit .env!
```

### Issue: "Contract size exceeds 24KB"

**Solution:** This is a warning, not a blocking error:
1. Enable optimizer with higher runs (already enabled at runs=200)
2. Split contract into smaller contracts
3. Use proxy pattern for upgradeable contracts

## Next Steps

After successful setup:

1. Read [ARCHITECTURE.md](./ARCHITECTURE.md) to understand system design
2. Check [CONTRACTS.md](./CONTRACTS.md) for complete contract reference
3. Review [EXAMPLES.md](./EXAMPLES.md) for real-world usage patterns
4. Start with [DEPLOYMENT.md](./DEPLOYMENT.md) to deploy your first instance
5. Use [API.md](./API.md) for function signatures and parameter details

## Getting Help

- **Hardhat Docs**: https://hardhat.org/docs
- **OpenZeppelin Docs**: https://docs.openzeppelin.com/contracts/5.x/
- **Solidity Docs**: https://docs.soliditylang.org/
- **Project Issues**: GitHub Issues on project repository
