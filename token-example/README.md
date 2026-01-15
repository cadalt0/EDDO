# EDDO Token Example

This is a complete example project showing how to use the **EDDO** library to create and deploy an RWA token with compliance rules.

```
Deploying with account: 0xb585f8e096e17dFB1f0B20FA0F9eC9Da4b2646A3
Account balance: 7512559960154900000

1️⃣  Deploying AllowListResolver...
   ✅ AllowListResolver deployed to: 0x4da824cd7E0531e6804445395089c188Bc83628F

2️⃣  Deploying Rules...
   ✅ KYCTierRule deployed to: 0x754968771a65035Bd52A8652524ed53ef4229583
   ✅ BlacklistRule deployed to: 0x1304E616080d278102a0905588f1B7f833c5eF21
   ✅ VelocityRule deployed to: 0xfCda835d27212c9fbaa2CF996beB822d39Cc95Ef

3️⃣  Deploying RuleSet...
   ✅ RuleSet deployed to: 0x82fbAe078Ec9949C149F68b04f8fF4f7436bC752

4️⃣  Deploying RulesEngine...
   ✅ RulesEngine deployed to: 0x9687E6C29ceC8C25472150300dcC59b2E11D2383

5️⃣  Deploying MyRWAToken...
   ✅ MyRWAToken deployed to: 0x1cBac1E1A76038e41d1bf5a61e973bDa12F02425

6️⃣  Configuring system...
   ✅ Added BlacklistRule to RuleSet
   ✅ Added KYCTierRule to RuleSet
   ✅ Added VelocityRule to RuleSet
   ⚙️  Temporarily disabled KYC rule for bootstrap mint
   ✅ Whitelisted deployer with INTERMEDIATE tier
   ✅ Minted 1,000,000 tokens to deployer
   ✅ Re-enabled KYC rule

✨ Deployment Complete!
```

## What This Does

Creates a token with built-in compliance:
- ✅ KYC verification (must be whitelisted)
- ✅ Blacklist checking
- ✅ Velocity limits (rate limiting)
- ✅ All rules evaluated automatically on every transfer

## Quick Start

### 1. Install Dependencies

```bash
npm install
```

This installs:
- `eddo-rwa` - The EDDO smart contract library
- `hardhat` - Ethereum development environment
- Required tooling

### 2. Start Local Blockchain (Terminal 1)

```bash
npx hardhat node
```

Keep this running in a separate terminal.

### 3. Deploy (Terminal 2)

```bash
npm run deploy:local
```

This deploys:
1. AccessControl (governance)
2. AllowListResolver (KYC/identity)
3. Rules (KYC, Blacklist, Velocity)
4. RuleSet (rule container)
5. RulesEngine (orchestrator)
6. MyRWAToken (your token)

### 4. What You Get

After deployment, you'll have a fully functional RWA token at the displayed address with:
- 1,000,000 tokens minted to deployer
- Deployer whitelisted with INTERMEDIATE KYC tier
- Rules automatically enforced on transfers

## Project Structure

```
token-example/
├── contracts/
│   └── MyRWAToken.sol          # Your token contract (extends EDDO)
├── scripts/
│   └── deploy.js               # Deployment script
├── hardhat.config.js           # Hardhat configuration
├── package.json                # Dependencies
└── README.md                   # This file
```

## Customization

### Change Token Details

Edit `scripts/deploy.js`:

```javascript
const token = await MyRWAToken.deploy(
  "My RWA Token",  // ← Change name
  "MRWA",          // ← Change symbol
  18,              // ← Change decimals
  await engine.getAddress()
);
```

### Add More Rules

Available rules from EDDO library:
- `KYCTierRule` - Identity verification tiers
- `BlacklistRule` - Block specific addresses
- `JurisdictionRule` - Geography restrictions
- `LockupRule` - Time-based locks (vesting)
- `SupplyCapRule` - Maximum supply limits
- `VelocityRule` - Rate limiting

Example - Add lockup rule:

```javascript
const LockupRule = await hre.ethers.getContractFactory("eddo-rwa/contracts/rules/LockupRule.sol:LockupRule");
const lockupRule = await LockupRule.deploy(await acl.getAddress());
await lockupRule.waitForDeployment();
await ruleset.addRule(await lockupRule.getAddress(), 3, true);
```

### Whitelist Users

After deployment, whitelist addresses:

```javascript
// In your script or via Hardhat console
await resolver.attestUser(
  "0x...",        // user address
  2,              // tier: 1=BASIC, 2=INTERMEDIATE, 3=ADVANCED
  "US",           // jurisdiction code
  31536000        // validity in seconds (1 year)
);
```

## Deploy to Testnet

### 1. Create `.env` file

```bash
SEPOLIA_RPC_URL=https://sepolia.infura.io/v3/YOUR_PROJECT_ID
PRIVATE_KEY=your_private_key_here
```

### 2. Deploy

```bash
npm run deploy:sepolia
```

## Testing Transfers

After deployment, test that rules work:

```javascript
// This should work (deployer is whitelisted)
await token.transfer(recipientAddress, ethers.parseEther("100"));

// This should fail (recipient not whitelisted)
// Need to whitelist recipient first via resolver.attestUser()
```

## Common Operations

### Check Token Balance

```javascript
const balance = await token.balanceOf(address);
console.log("Balance:", ethers.formatEther(balance));
```

### Whitelist New User

```javascript
await resolver.attestUser(userAddress, 1, "US", 365 * 24 * 60 * 60);
```

### Add to Blacklist

```javascript
await blacklistRule.addToBlacklist(address, 0); // 0 = permanent
```

### Set Velocity Limit

```javascript
await velocityRule.setVelocityLimit(ethers.parseEther("10000")); // Max per period
await velocityRule.setPeriod(86400); // 1 day in seconds
```

## Need Help?

- Main EDDO Docs: https://github.com/cadalt0/EDDO
- EDDO npm: https://www.npmjs.com/package/eddo-rwa
- Hardhat Docs: https://hardhat.org/docs
