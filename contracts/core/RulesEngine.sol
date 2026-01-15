// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {IRulesEngine} from "../interfaces/IRulesEngine.sol";
import {IContext} from "../interfaces/IContext.sol";
import {IRule} from "../interfaces/IRule.sol";
import {RuleSet} from "./RuleSet.sol";

/**
 * @title RulesEngine
 * @notice Core rules evaluation engine
 * @dev Evaluates rules against contexts with configurable evaluation modes
 */
contract RulesEngine is IRulesEngine {
    RuleSet public ruleSet;
    EvaluationMode public override evaluationMode;
    uint256 public override activeRuleSetVersion;

    // Events
    event RuleSetUpdated(address indexed newRuleSet, uint256 version);
    event EvaluationModeUpdated(EvaluationMode newMode);

    /**
     * @notice Create a new rules engine
     * @param ruleSet_ The initial rule set
     * @param mode The evaluation mode
     */
    constructor(address ruleSet_, EvaluationMode mode) {
        ruleSet = RuleSet(ruleSet_);
        evaluationMode = mode;
        activeRuleSetVersion = 1;
    }

    /// @inheritdoc IRulesEngine
    function evaluate(IContext context) external view override returns (EvaluationResult memory result) {
        RuleSet.RuleConfig[] memory rules = ruleSet.getActiveRules();
        
        if (rules.length == 0) {
            return EvaluationResult({
                passed: true,
                failedRule: bytes32(0),
                reason: "",
                evaluatedRules: 0
            });
        }

        uint256 evaluated = 0;
        bool hasPassed = false;

        for (uint256 i = 0; i < rules.length; i++) {
            IRule.RuleResult memory ruleResult = rules[i].rule.evaluate(context);
            evaluated++;

            if (!ruleResult.passed) {
                // Rule failed
                if (rules[i].mandatory || evaluationMode == EvaluationMode.SHORT_CIRCUIT) {
                    // Stop immediately on mandatory rule failure or short-circuit mode
                    return EvaluationResult({
                        passed: false,
                        failedRule: ruleResult.ruleId,
                        reason: ruleResult.reason,
                        evaluatedRules: evaluated
                    });
                }

                if (evaluationMode == EvaluationMode.ALL_MUST_PASS) {
                    // Record first failure but continue evaluating
                    if (result.failedRule == bytes32(0)) {
                        result.failedRule = ruleResult.ruleId;
                        result.reason = ruleResult.reason;
                    }
                }
            } else {
                // Rule passed
                if (evaluationMode == EvaluationMode.ANY_MUST_PASS) {
                    hasPassed = true;
                    // Can short-circuit on first pass in ANY mode
                    return EvaluationResult({
                        passed: true,
                        failedRule: bytes32(0),
                        reason: "",
                        evaluatedRules: evaluated
                    });
                }
            }
        }

        // Final result determination
        if (evaluationMode == EvaluationMode.ANY_MUST_PASS) {
            result.passed = hasPassed;
            if (!hasPassed) {
                result.reason = "No rules passed";
            }
        } else if (evaluationMode == EvaluationMode.ALL_MUST_PASS) {
            result.passed = (result.failedRule == bytes32(0));
        } else {
            // SHORT_CIRCUIT - if we got here, all rules passed
            result.passed = true;
        }

        result.evaluatedRules = evaluated;
        return result;
    }

    /**
     * @notice Update the rule set
     * @param newRuleSet The new rule set address
     */
    function updateRuleSet(address newRuleSet) external {
        require(newRuleSet != address(0), "RulesEngine: invalid rule set");
        ruleSet = RuleSet(newRuleSet);
        activeRuleSetVersion++;
        emit RuleSetUpdated(newRuleSet, activeRuleSetVersion);
    }

    /**
     * @notice Update the evaluation mode
     * @param newMode The new evaluation mode
     */
    function updateEvaluationMode(EvaluationMode newMode) external {
        evaluationMode = newMode;
        emit EvaluationModeUpdated(newMode);
    }
}
