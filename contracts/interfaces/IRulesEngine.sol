// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {IContext} from "./IContext.sol";
import {IRule} from "./IRule.sol";

/**
 * @title IRulesEngine
 * @notice Core rules evaluation engine interface
 * @dev Evaluates a set of rules against a context with configurable precedence
 */
interface IRulesEngine {
    /**
     * @notice Evaluation mode for rule sets
     */
    enum EvaluationMode {
        ALL_MUST_PASS,      // All rules must pass
        ANY_MUST_PASS,      // At least one rule must pass
        SHORT_CIRCUIT       // Stop on first failure
    }

    /**
     * @notice Complete evaluation result
     * @param passed Whether all required rules passed
     * @param failedRule The ID of the first failed rule (if any)
     * @param reason The reason for failure (if any)
     * @param evaluatedRules Number of rules evaluated
     */
    struct EvaluationResult {
        bool passed;
        bytes32 failedRule;
        string reason;
        uint256 evaluatedRules;
    }

    /**
     * @notice Evaluate all rules for a given context
     * @param context The evaluation context
     * @return result The complete evaluation result
     */
    function evaluate(IContext context) external view returns (EvaluationResult memory result);

    /**
     * @notice Get the active rule set version
     */
    function activeRuleSetVersion() external view returns (uint256);

    /**
     * @notice Get the evaluation mode
     */
    function evaluationMode() external view returns (EvaluationMode);

    /**
     * @notice Event emitted when rules are evaluated
     * @param context The context address
     * @param passed Whether evaluation passed
     * @param failedRule The failed rule ID (if any)
     * @param ruleSetVersion The rule set version used
     */
    event RulesEvaluated(
        address indexed context,
        bool passed,
        bytes32 failedRule,
        uint256 ruleSetVersion
    );
}
