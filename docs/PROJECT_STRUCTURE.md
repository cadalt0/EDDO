# Project Structure

## Complete Solidity Contract Library

```
contracts/
├── interfaces/                    # 6 interfaces
│   ├── IContext.sol              # Evaluation context interface
│   ├── IRule.sol                 # Base rule interface
│   ├── IRulesEngine.sol          # Rules engine interface
│   ├── IIdentityResolver.sol     # Identity resolution interface
│   ├── IPolicyRegistry.sol       # Policy management interface
│   └── IRWAAdapter.sol           # Asset adapter interface
│
├── core/                         # 4 core implementations
│   ├── Context.sol               # Context implementation
│   ├── BaseRule.sol              # Base rule abstract contract
│   ├── RuleSet.sol               # Rule set container
│   └── RulesEngine.sol           # Rules evaluation engine
│
├── policy/                       # 1 policy contract
│   └── PolicyRegistry.sol        # Versioned policy management
│
├── identity/                     # 2 identity resolvers
│   ├── AllowListResolver.sol     # Simple onchain allow-list
│   └── CompositeIdentityResolver.sol  # Multi-source resolver
│
├── adapters/                     # 2 asset adapters (+ 2 planned)
│   ├── RWA_ERC20.sol            # ERC20 with rules integration
│   ├── RWA_ERC721.sol           # ERC721 with rules integration
│   ├── RWA_ERC1155.sol          # [PLANNED] Multi-token
│   └── RWA_ERC4626.sol          # [PLANNED] Vault adapter
│
├── governance/                   # 3 governance contracts
│   ├── AccessControl.sol         # Role-based access control
│   ├── CircuitBreaker.sol        # Emergency pause mechanism
│   └── Timelock.sol              # Time-delayed execution
│
├── rules/                        # 6 rule implementations
│   ├── KYCTierRule.sol          # Identity tier enforcement
│   ├── JurisdictionRule.sol     # Geography-based rules
│   ├── BlacklistRule.sol        # Address blocking
│   ├── LockupRule.sol           # Time-based restrictions
│   ├── SupplyCapRule.sol        # Maximum supply limits
│   └── VelocityRule.sol         # Transfer rate limits
│
├── libraries/                    # 3 utility libraries
│   ├── BitOperations.sol         # Bitmap helpers
│   ├── StringUtils.sol           # String manipulation
│   └── SafeMath.sol              # Safe arithmetic
│
└── examples/                     # 1 example
    └── ExampleDeployment.sol     # Complete deployment example
```

## Documentation

```
docs/
├── ARCHITECTURE.md               # System architecture & design
└── USAGE_GUIDE.md               # Complete usage guide

README.md                         # Project overview
```
