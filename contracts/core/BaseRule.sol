// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {IRule} from "../interfaces/IRule.sol";

/**
 * @title BaseRule
 * @notice Abstract base implementation for rules
 * @dev Provides common functionality for all rule implementations
 */
abstract contract BaseRule is IRule {
    bytes32 private immutable _ruleId;
    string private _name;
    uint256 private immutable _version;

    /**
     * @notice Create a new rule
     * @param ruleId_ Unique identifier for the rule
     * @param name_ Human-readable name
     * @param version_ Rule version
     */
    constructor(bytes32 ruleId_, string memory name_, uint256 version_) {
        _ruleId = ruleId_;
        _name = name_;
        _version = version_;
    }

    /// @inheritdoc IRule
    function ruleId() external view override returns (bytes32) {
        return _ruleId;
    }

    /// @inheritdoc IRule
    function name() external view override returns (string memory) {
        return _name;
    }

    /// @inheritdoc IRule
    function version() external view override returns (uint256) {
        return _version;
    }

    /**
     * @notice Helper to create a passing result
     */
    function _pass() internal view returns (RuleResult memory) {
        return RuleResult({
            passed: true,
            reason: "",
            ruleId: _ruleId
        });
    }

    /**
     * @notice Helper to create a failing result
     * @param reason The failure reason
     */
    function _fail(string memory reason) internal view returns (RuleResult memory) {
        return RuleResult({
            passed: false,
            reason: reason,
            ruleId: _ruleId
        });
    }
}
