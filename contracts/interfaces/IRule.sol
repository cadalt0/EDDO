// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {IContext} from "./IContext.sol";

/**
 * @title IRule
 * @notice Base interface for all rules
 * @dev Rules are pure, deterministic evaluators that return pass/fail with a reason
 */
interface IRule {
    /**
     * @notice Rule evaluation result
     * @param passed Whether the rule passed
     * @param reason Human-readable reason for the result (empty if passed)
     * @param ruleId Identifier of the rule
     */
    struct RuleResult {
        bool passed;
        string reason;
        bytes32 ruleId;
    }

    /**
     * @notice Evaluate the rule against a context
     * @param context The evaluation context
     * @return result The rule evaluation result
     */
    function evaluate(IContext context) external view returns (RuleResult memory result);

    /**
     * @notice Get the unique identifier for this rule
     */
    function ruleId() external view returns (bytes32);

    /**
     * @notice Get a human-readable name for this rule
     */
    function name() external view returns (string memory);

    /**
     * @notice Get the rule version
     */
    function version() external view returns (uint256);
}
