// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {BaseRule} from "../core/BaseRule.sol";
import {IRule} from "../interfaces/IRule.sol";
import {IContext} from "../interfaces/IContext.sol";
import {IIdentityResolver} from "../interfaces/IIdentityResolver.sol";

/**
 * @title KYCTierRule
 * @notice Rule that enforces minimum KYC tier requirements
 * @dev Checks both actor and counterparty against identity resolver
 */
contract KYCTierRule is BaseRule {
    IIdentityResolver public immutable identityResolver;
    IIdentityResolver.IdentityTier public immutable minActorTier;
    IIdentityResolver.IdentityTier public immutable minCounterpartyTier;
    bool public immutable checkCounterparty;

    constructor(
        address identityResolver_,
        IIdentityResolver.IdentityTier minActorTier_,
        IIdentityResolver.IdentityTier minCounterpartyTier_,
        bool checkCounterparty_
    ) BaseRule(
        keccak256("KYC_TIER_RULE"),
        "KYC Tier Check",
        1
    ) {
        identityResolver = IIdentityResolver(identityResolver_);
        minActorTier = minActorTier_;
        minCounterpartyTier = minCounterpartyTier_;
        checkCounterparty = checkCounterparty_;
    }

    /// @inheritdoc IRule
    function evaluate(IContext context) external view override returns (RuleResult memory) {
        address actor = context.actor();
        address counterparty = context.counterparty();

        // Check actor tier
        if (!identityResolver.hasMinimumTier(actor, minActorTier)) {
            return _fail("Actor does not meet minimum KYC tier");
        }

        // Check counterparty tier if enabled
        if (checkCounterparty && counterparty != address(0)) {
            if (!identityResolver.hasMinimumTier(counterparty, minCounterpartyTier)) {
                return _fail("Counterparty does not meet minimum KYC tier");
            }
        }

        return _pass();
    }
}
