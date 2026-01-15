// SPDX-License-Identifier: MIT
pragma solidity 0.8.20;

// Import EDDO contracts so Hardhat generates local artifacts for deployment.
import "eddo-rwa/contracts/governance/AccessControl.sol";
import "eddo-rwa/contracts/identity/AllowListResolver.sol";
import "eddo-rwa/contracts/rules/KYCTierRule.sol";
import "eddo-rwa/contracts/rules/BlacklistRule.sol";
import "eddo-rwa/contracts/rules/VelocityRule.sol";
import "eddo-rwa/contracts/core/RuleSet.sol";
import "eddo-rwa/contracts/core/RulesEngine.sol";
