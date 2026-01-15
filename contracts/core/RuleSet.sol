// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {IRule} from "../interfaces/IRule.sol";
import {IContext} from "../interfaces/IContext.sol";

/**
 * @title RuleSet
 * @notice Container for a set of rules with evaluation configuration
 * @dev Manages rule precedence and evaluation settings
 */
contract RuleSet {
    /**
     * @notice Rule configuration
     * @param rule The rule contract
     * @param enabled Whether the rule is active
     * @param priority Higher priority rules are evaluated first
     * @param mandatory If true, failure blocks the entire operation
     */
    struct RuleConfig {
        IRule rule;
        bool enabled;
        uint256 priority;
        bool mandatory;
    }

    // Rule storage
    RuleConfig[] private _rules;
    
    // Rule ID to index mapping (for O(1) lookups)
    mapping(bytes32 => uint256) private _ruleIndex;
    
    // Has rule been added
    mapping(bytes32 => bool) private _hasRule;

    /**
     * @notice Add a rule to the set
     * @param rule The rule to add
     * @param priority The rule priority
     * @param mandatory Whether the rule is mandatory
     */
    function addRule(IRule rule, uint256 priority, bool mandatory) external {
        bytes32 id = rule.ruleId();
        require(!_hasRule[id], "RuleSet: rule already exists");

        _rules.push(RuleConfig({
            rule: rule,
            enabled: true,
            priority: priority,
            mandatory: mandatory
        }));

        _ruleIndex[id] = _rules.length - 1;
        _hasRule[id] = true;
    }

    /**
     * @notice Enable or disable a rule
     * @param ruleId The rule ID
     * @param enabled Whether to enable the rule
     */
    function setRuleEnabled(bytes32 ruleId, bool enabled) external {
        require(_hasRule[ruleId], "RuleSet: rule not found");
        _rules[_ruleIndex[ruleId]].enabled = enabled;
    }

    /**
     * @notice Update rule priority
     * @param ruleId The rule ID
     * @param priority The new priority
     */
    function setRulePriority(bytes32 ruleId, uint256 priority) external {
        require(_hasRule[ruleId], "RuleSet: rule not found");
        _rules[_ruleIndex[ruleId]].priority = priority;
    }

    /**
     * @notice Get all active rules sorted by priority
     * @return rules Array of active rule configurations
     */
    function getActiveRules() external view returns (RuleConfig[] memory rules) {
        // Count active rules
        uint256 activeCount = 0;
        for (uint256 i = 0; i < _rules.length; i++) {
            if (_rules[i].enabled) {
                activeCount++;
            }
        }

        // Collect active rules
        rules = new RuleConfig[](activeCount);
        uint256 index = 0;
        for (uint256 i = 0; i < _rules.length; i++) {
            if (_rules[i].enabled) {
                rules[index] = _rules[i];
                index++;
            }
        }

        // Sort by priority (bubble sort for simplicity, optimize later)
        for (uint256 i = 0; i < rules.length; i++) {
            for (uint256 j = i + 1; j < rules.length; j++) {
                if (rules[j].priority > rules[i].priority) {
                    RuleConfig memory temp = rules[i];
                    rules[i] = rules[j];
                    rules[j] = temp;
                }
            }
        }

        return rules;
    }

    /**
     * @notice Get rule configuration by ID
     * @param ruleId The rule ID
     * @return config The rule configuration
     */
    function getRuleConfig(bytes32 ruleId) external view returns (RuleConfig memory config) {
        require(_hasRule[ruleId], "RuleSet: rule not found");
        return _rules[_ruleIndex[ruleId]];
    }

    /**
     * @notice Get total number of rules
     * @return count The rule count
     */
    function getRuleCount() external view returns (uint256 count) {
        return _rules.length;
    }

    /**
     * @notice Check if a rule exists
     * @param ruleId The rule ID
     * @return exists Whether the rule exists
     */
    function hasRule(bytes32 ruleId) external view returns (bool exists) {
        return _hasRule[ruleId];
    }
}
