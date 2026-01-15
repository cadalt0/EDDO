# EDDO

OpenZeppelin-style smart contract library for Real World Assets (RWA), where asset behavior is controlled by configurable rules instead of hardcoded logic, and where every rule, state, and proof is transparently visible onchain.

## Overview

An infrastructure-layer RWA developer toolkit that abstracts compliance, identity, and verification logic into a configurable rules engine, enabling faster, safer, and more transparent tokenization without reinventing contracts.

## Features

- **Configurable Rules Engine**: Define compliance and business logic as composable, reusable rules
- **Identity Resolution**: Pluggable identity providers (EAS, allow-lists, oracles, custom integrations)
- **Policy Management**: Versioned policies with staging, timelocks, and transparent activation
- **Multi-Asset Support**: ERC20, ERC721, ERC1155, ERC4626 adapters with rules integration
- **Governance**: Role-based access control, circuit breakers, and timelock execution
- **Transparent by Design**: All rule evaluations, policy changes, and attestations are logged onchain
- **Framework Agnostic**: Works with Hardhat, Foundry, Truffle, Brownie—no build system lock-in

## Architecture

```
┌─────────────────────────────────────────────────────────┐
│                   RWA Asset Adapters                     │
│         (ERC20, ERC721, ERC1155, ERC4626)               │
└──────────────────────┬──────────────────────────────────┘
                       │
                       ▼
┌─────────────────────────────────────────────────────────┐
│                    Rules Engine                          │
│   • Evaluate rules against context                       │
│   • Short-circuit, ALL, or ANY modes                     │
│   • Emit transparent results                             │
└──────────────────────┬──────────────────────────────────┘
                       │
        ┌──────────────┼──────────────┐
        ▼              ▼              ▼
┌──────────────┐ ┌────────────┐ ┌───────────────┐
│   Rule Set   │ │  Identity  │ │    Policy     │
│              │ │  Resolver  │ │   Registry    │
│ • KYC Tier   │ │            │ │               │
│ • Blacklist  │ │ • EAS      │ │ • Versioned   │
│ • Lockups    │ │ • Allow    │ │ • Staged      │
│ • Velocity   │ │   Lists    │ │ • Timelock    │
│ • Supply Cap │ │ • Oracles  │ │               │
└──────────────┘ └────────────┘ └───────────────┘
```

## Directory Structure

```
contracts/
├── interfaces/           # Core interfaces
│   ├── IContext.sol
│   ├── IRule.sol
│   ├── IRulesEngine.sol
│   ├── IIdentityResolver.sol
│   ├── IPolicyRegistry.sol
│   └── IRWAAdapter.sol
│
├── core/                # Core implementations
│   ├── Context.sol
│   ├── BaseRule.sol
│   ├── RuleSet.sol
│   └── RulesEngine.sol
│
├── policy/              # Policy management
│   └── PolicyRegistry.sol
│
├── identity/            # Identity resolution
│   ├── AllowListResolver.sol
│   └── CompositeIdentityResolver.sol
│
├── adapters/            # Asset adapters
│   ├── RWA_ERC20.sol
│   ├── RWA_ERC721.sol
│   ├── RWA_ERC1155.sol (planned)
│   └── RWA_ERC4626.sol (planned)
│
├── governance/          # Governance and safety
│   ├── AccessControl.sol
│   ├── CircuitBreaker.sol
│   └── Timelock.sol
│
├── rules/               # Rule implementations
│   ├── KYCTierRule.sol
│   ├── JurisdictionRule.sol
│   ├── BlacklistRule.sol
│   ├── LockupRule.sol
│   ├── SupplyCapRule.sol
│   └── VelocityRule.sol
│
└── libraries/           # Utility libraries
    ├── BitOperations.sol
    ├── StringUtils.sol
    └── SafeMath.sol
```

## Core Components

### Rules Engine

The heart of the system. Evaluates a set of rules against a context (actor, counterparty, amount, operation type) and returns pass/fail with detailed reasoning.

**Evaluation Modes:**
- `ALL_MUST_PASS`: Every rule must pass
- `ANY_MUST_PASS`: At least one rule must pass
- `SHORT_CIRCUIT`: Stop on first failure (gas-efficient)

### Rules

Modular, composable compliance checks:

- **KYCTierRule**: Enforce minimum identity tiers
- **JurisdictionRule**: Allow/deny based on geography
- **BlacklistRule**: Block specific addresses
- **LockupRule**: Enforce token lockup periods
- **SupplyCapRule**: Limit total supply
- **VelocityRule**: Rate-limit transfers

### Identity Resolution

Pluggable identity providers behind a standard interface:

- **AllowListResolver**: Simple onchain allow-lists
- **CompositeIdentityResolver**: Combine multiple sources with AND/OR/QUORUM logic
- **Custom**: Integrate EAS, DIDs, oracles, or enterprise KYC APIs

### Policy Management

Versioned policies with transparent lifecycle:

1. **Register**: Create a new policy version
2. **Stage**: Prepare for activation (timelock starts)
3. **Activate**: Make policy active (after timelock)
4. **Deprecate**: Replace with newer version

All changes are logged onchain with full history.

## 📚 Complete Documentation

Start here based on your role:

- **Full docs index:** [DOCUMENTATION_SUMMARY.md](docs/DOCUMENTATION_SUMMARY.md)

### For Developers

- **[SETUP.md](docs/SETUP.md)** - Environment setup, installation, configuration (start here!)
- **[INTERFACES.md](docs/INTERFACES.md)** - Deep dive into all 6 core interfaces and how they connect
- **[CONTRACTS.md](docs/CONTRACTS.md)** - Complete reference for all 27 contracts
- **[API.md](docs/API.md)** - Function signatures, parameters, return values for every contract
- **[DEPLOYMENT.md](docs/DEPLOYMENT.md)** - Step-by-step deployment to testnet and mainnet

### For Architects & Product Teams

- **[ARCHITECTURE.md](docs/ARCHITECTURE.md)** - System design, layers, and principles
- **[RULES.md](docs/RULES.md)** - Detailed guide to all 6 compliance rules with real-world use cases
- **[EXAMPLES.md](docs/EXAMPLES.md)** - 5 real-world scenarios (bonds, PE fund, real estate, commodities, employee options)
- **[PROJECT_STRUCTURE.md](docs/PROJECT_STRUCTURE.md)** - Directory organization and contract relationships

### For Operations & Compliance

- **[CONFIGURATION.md](docs/CONFIGURATION.md)** - Role management, rule configuration, governance setup
- **[USAGE_GUIDE.md](docs/USAGE_GUIDE.md)** - Complete usage guide and testing

---

## Quick Start

### Option 1: 5-Minute Example

```javascript
const hre = require("hardhat");

async function main() {
  // Deploy all contracts
  const deployer = await hre.ethers.getSigner();
  
  // 1. Access control
  const AccessControl = await hre.ethers.getContractFactory("AccessControl");
  const acl = await AccessControl.deploy();
  
  // 2. Rules engine
  const RulesEngine = await hre.ethers.getContractFactory("RulesEngine");
  const engine = await RulesEngine.deploy(acl.address);
  
  // 3. Identity resolver
  const AllowListResolver = await hre.ethers.getContractFactory("AllowListResolver");
  const resolver = await AllowListResolver.deploy(acl.address);
  
  // 4. Rules
  const KYCTierRule = await hre.ethers.getContractFactory("KYCTierRule");
  const kycRule = await KYCTierRule.deploy(acl.address, resolver.address);
  
  // 5. RuleSet container
  const RuleSet = await hre.ethers.getContractFactory("RuleSet");
  const ruleset = await RuleSet.deploy(acl.address);
  await ruleset.addRule(kycRule.address, 0, true);
  
  // 6. Token
  const RWA_ERC20 = await hre.ethers.getContractFactory("RWA_ERC20");
  const token = await RWA_ERC20.deploy("RWA Token", "RWA", 0, acl.address, engine.address);
  
  // 7. Connect
  await engine.setRuleSet(0, ruleset.address);  // OperationType.TRANSFER
  
  // 8. Add user to whitelist
  await resolver.attestUser(deployer.address, 2, "US", 365);
  
  // 9. Transfer (rules checked automatically)
  await token.transfer("0x...", hre.ethers.utils.parseEther("100"));
  
  console.log("✓ Token deployed and transfer succeeded");
}

main();
```

### Option 2: Full Setup (See [DEPLOYMENT.md](docs/DEPLOYMENT.md))

```bash
# 1. Install
npm install

# 2. Compile
npx hardhat compile

# 3. Test locally
npx hardhat node

# 4. In another terminal:
npx hardhat run scripts/deploy-full.js --network localhost

# 5. Deploy to testnet
npx hardhat run scripts/deploy-full.js --network sepolia

# 6. Configure rules
npx hardhat run scripts/configure-rules.js --network sepolia
```

## What This Toolkit Does

### The Problem
Every RWA (Real World Asset) project needs to implement compliance rules from scratch:
- KYC (Know Your Customer) verification
- Blacklist/sanctions screening
- Jurisdiction restrictions
- Transfer lockups (vesting)
- Rate limiting (anti-wash-trading)
- Supply caps

This leads to:
- ❌ Duplicated code across projects
- ❌ Security vulnerabilities
- ❌ Auditing delays
- ❌ Time-to-market delays

### The Solution
A modular, production-ready **rules framework** where:
- ✅ Select from pre-built compliance rules
- ✅ Combine them as needed
- ✅ All rules are composable and upgradeable
- ✅ Transparent on-chain audit trail
- ✅ No redeploying the token to change rules

### How It Works

```
User initiates transfer (A → B, 1000 tokens)
              ↓
Token calls RulesEngine.evaluate(context)
              ↓
Engine checks each rule in priority order:
   1. Blacklist: Is A blocked? No ✓
   2. KYC: Does A have INTERMEDIATE tier? Yes ✓
   3. Jurisdiction: Is B in US? Yes ✓
   4. Velocity: Is 1000 within daily limit? Yes ✓
              ↓
All rules passed → Transfer executes
All events emitted for audit trail
```

### Real-World Examples

See [EXAMPLES.md](docs/EXAMPLES.md) for complete code examples:

1. **Public Bond Issuance** - Global, retail-accessible, rate-limited
2. **Private Equity Fund** - Accredited investors only, 3-year lockup
3. **Real Estate** - Property-specific rules, quarterly redemptions
4. **Commodity Trading** - High-volume, basic KYC, 24/7 trading
5. **Employee Stock Options** - Vesting schedules, competitor restrictions

## Rule Development

Create custom rules by extending `BaseRule`:

```solidity
import {BaseRule} from "../core/BaseRule.sol";
import {IContext} from "../interfaces/IContext.sol";

contract MyCustomRule is BaseRule {
    constructor() BaseRule("my-custom-rule") {}

    function evaluate(IContext context) 
        external 
        view 
        override 
        returns (RuleResult memory) 
    {
        // Your custom logic
        if (someCondition(context)) {
            return _pass();
        } else {
            return _fail("Reason this rule failed");
        }
    }
}
```

See [RULES.md](docs/RULES.md#rule-development-guide) for detailed guide with testing patterns.

## Security

- **Fail-Closed**: Rules default to blocking unless explicitly passed
- **Deterministic**: Pure functions, no side effects
- **Transparent**: All evaluations logged onchain
- **Upgradeable**: ERC-1967 proxy pattern for safe upgrades
- **Governed**: Timelock + multi-sig for critical operations
- **Circuit Breaker**: Emergency pause with transparent reasoning

## Testing

```bash
# Foundry
forge test

# Hardhat
npx hardhat test

# Coverage
forge coverage
```

## Gas Optimization

- Bitmap caching for rule results
- Short-circuit evaluation
- Minimal external calls
- L2-optimized (Arbitrum, Optimism, Polygon)

## Compliance

- **Audit-Friendly**: Clear, modular code with comprehensive tests
- **Regulator-Friendly**: Transparent event logs and forensic replay
- **No PII Onchain**: Only attestation IDs and hashes stored
- **Configurable**: Adapt to regional regulations (US, EU, UK, GCC)

## Roadmap

**MVP (Current)**
- ✅ Rules engine and core infrastructure
- ✅ ERC20 adapter
- ✅ Identity resolution (allow-lists, composite)
- ✅ Policy registry with versioning
- ✅ Core rules (KYC, jurisdiction, blacklist, lockup, supply cap, velocity)
- ✅ Governance (access control, circuit breaker, timelock)

**Phase 2**
- ERC721 and ERC1155 adapters
- ERC4626 vault adapter
- Additional rule types (trading windows, investor caps, NAV gating)
- Multi-attestor quorum and slashing
- Offchain TypeScript SDK

**Phase 3**
- Cross-chain policy sync
- Advanced oracle integrations
- Formal verification
- Enterprise integrations (Chainlink, Pyth, EAS)

## Contributing

Contributions welcome! Please:
1. Fork the repo
2. Create a feature branch
3. Add tests for new functionality
4. Submit a pull request

## License

MIT License

## Support

- GitHub Issues: [github.com/your-org/mantle-rwa-toolkit](https://github.com)
- Documentation: [docs.mantle-rwa.io](https://example.com)
- Discord: [discord.gg/mantle-rwa](https://discord.com)

## Acknowledgments

Built with inspiration from:
- OpenZeppelin Contracts
- Ethereum Attestation Service (EAS)
- Maple Finance
- Centrifuge

---

**⚠️ Disclaimer**: This is experimental software. Always audit thoroughly before production use.
