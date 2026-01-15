const hre = require("hardhat");

async function main() {
  console.log("🚀 Deploying EDDO-based RWA Token System...\n");

  const [deployer] = await hre.ethers.getSigners();
  console.log("Deploying with account:", deployer.address);
  console.log("Account balance:", (await hre.ethers.provider.getBalance(deployer.address)).toString());
  console.log("");

  const jurisdiction = hre.ethers.toUtf8Bytes("US");
  const ruleIds = {
    KYC: hre.ethers.keccak256(hre.ethers.toUtf8Bytes("KYC_TIER_RULE")),
    BLACKLIST: hre.ethers.keccak256(hre.ethers.toUtf8Bytes("BLACKLIST_RULE")),
    VELOCITY: hre.ethers.keccak256(hre.ethers.toUtf8Bytes("VELOCITY_RULE")),
  };

  // 1. Deploy AllowListResolver (Identity/KYC)
  console.log("1️⃣  Deploying AllowListResolver...");
  const AllowListResolver = await hre.ethers.getContractFactory("eddo-rwa/contracts/identity/AllowListResolver.sol:AllowListResolver");
  const resolver = await AllowListResolver.deploy();
  await resolver.waitForDeployment();
  console.log("   ✅ AllowListResolver deployed to:", await resolver.getAddress());
  console.log("");

  // 2. Deploy Rules
  console.log("2️⃣  Deploying Rules...");
  
  const KYCTierRule = await hre.ethers.getContractFactory("eddo-rwa/contracts/rules/KYCTierRule.sol:KYCTierRule");
  const kycRule = await KYCTierRule.deploy(
    await resolver.getAddress(), // identityResolver
    1, // minActorTier = BASIC
    1, // minCounterpartyTier = BASIC
    true // checkCounterparty
  );
  await kycRule.waitForDeployment();
  console.log("   ✅ KYCTierRule deployed to:", await kycRule.getAddress());

  const BlacklistRule = await hre.ethers.getContractFactory("eddo-rwa/contracts/rules/BlacklistRule.sol:BlacklistRule");
  const blacklistRule = await BlacklistRule.deploy();
  await blacklistRule.waitForDeployment();
  console.log("   ✅ BlacklistRule deployed to:", await blacklistRule.getAddress());

  const VelocityRule = await hre.ethers.getContractFactory("eddo-rwa/contracts/rules/VelocityRule.sol:VelocityRule");
  const velocityRule = await VelocityRule.deploy(
    hre.ethers.parseEther("100000"), // default max amount per window
    24 * 60 * 60 // window size = 1 day
  );
  await velocityRule.waitForDeployment();
  console.log("   ✅ VelocityRule deployed to:", await velocityRule.getAddress());
  console.log("");

  // 3. Deploy RuleSet
  console.log("3️⃣  Deploying RuleSet...");
  const RuleSet = await hre.ethers.getContractFactory("eddo-rwa/contracts/core/RuleSet.sol:RuleSet");
  const ruleset = await RuleSet.deploy();
  await ruleset.waitForDeployment();
  console.log("   ✅ RuleSet deployed to:", await ruleset.getAddress());
  console.log("");

  // 4. Deploy RulesEngine
  console.log("4️⃣  Deploying RulesEngine...");
  const RulesEngine = await hre.ethers.getContractFactory("eddo-rwa/contracts/core/RulesEngine.sol:RulesEngine");
  const engine = await RulesEngine.deploy(await ruleset.getAddress(), 2); // 2 = SHORT_CIRCUIT
  await engine.waitForDeployment();
  console.log("   ✅ RulesEngine deployed to:", await engine.getAddress());
  console.log("");

  // 5. Deploy Token
  console.log("5️⃣  Deploying MyRWAToken...");
  const MyRWAToken = await hre.ethers.getContractFactory("MyRWAToken");
  const token = await MyRWAToken.deploy(
    "My RWA Token",
    "MRWA",
    18,
    await engine.getAddress()
  );
  await token.waitForDeployment();
  console.log("   ✅ MyRWAToken deployed to:", await token.getAddress());
  console.log("");

  // 6. Configure Rules
  console.log("6️⃣  Configuring system...");
  
  // Add rules to ruleset
  let tx = await ruleset.addRule(await blacklistRule.getAddress(), 0, true);
  await tx.wait();
  console.log("   ✅ Added BlacklistRule to RuleSet");
  
  tx = await ruleset.addRule(await kycRule.getAddress(), 1, true);
  await tx.wait();
  console.log("   ✅ Added KYCTierRule to RuleSet");
  
  tx = await ruleset.addRule(await velocityRule.getAddress(), 2, true);
  await tx.wait();
  console.log("   ✅ Added VelocityRule to RuleSet");

  // Temporarily disable KYC for initial mint to avoid zero-address actor check
  tx = await ruleset.setRuleEnabled(ruleIds.KYC, false);
  await tx.wait();
  console.log("   ⚙️  Temporarily disabled KYC rule for bootstrap mint");

  // Whitelist deployer
  tx = await resolver.setAttestation(deployer.address, 2, jurisdiction, 365 * 24 * 60 * 60); // INTERMEDIATE tier
  await tx.wait();
  console.log("   ✅ Whitelisted deployer with INTERMEDIATE tier");

  // Mint initial tokens to deployer
  tx = await token.mint(deployer.address, hre.ethers.parseEther("1000000"));
  await tx.wait();
  console.log("   ✅ Minted 1,000,000 tokens to deployer");

  // Re-enable KYC rule after bootstrap
  tx = await ruleset.setRuleEnabled(ruleIds.KYC, true);
  await tx.wait();
  console.log("   ✅ Re-enabled KYC rule");
  console.log("");

  // 7. Summary
  console.log("✨ Deployment Complete!\n");
  console.log("📋 Contract Addresses:");
  console.log("━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━");
  console.log("AllowListResolver: ", await resolver.getAddress());
  console.log("KYCTierRule:       ", await kycRule.getAddress());
  console.log("BlacklistRule:     ", await blacklistRule.getAddress());
  console.log("VelocityRule:      ", await velocityRule.getAddress());
  console.log("RuleSet:           ", await ruleset.getAddress());
  console.log("RulesEngine:       ", await engine.getAddress());
  console.log("MyRWAToken:        ", await token.getAddress());
  console.log("━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━\n");

  console.log("🎯 Next Steps:");
  console.log("   1. Test a transfer: npx hardhat run scripts/test-transfer.js");
  console.log("   2. Whitelist more users via AllowListResolver");
  console.log("   3. Configure additional rules as needed\n");
}

main()
  .then(() => process.exit(0))
  .catch((error) => {
    console.error(error);
    process.exit(1);
  });
