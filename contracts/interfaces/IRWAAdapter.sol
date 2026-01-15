// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

/**
 * @title IRWAAdapter
 * @notice Base interface for RWA asset adapters
 * @dev Asset-specific wrappers that integrate rules engine with token standards
 */
interface IRWAAdapter {
    /**
     * @notice Get the rules engine address
     */
    function rulesEngine() external view returns (address);

    /**
     * @notice Get the underlying asset address
     */
    function asset() external view returns (address);

    /**
     * @notice Check if operations are currently paused
     */
    function paused() external view returns (bool);

    /**
     * @notice Event emitted when a rule check fails
     */
    event RuleCheckFailed(
        address indexed actor,
        address indexed counterparty,
        uint256 amount,
        bytes32 failedRule,
        string reason
    );

    /**
     * @notice Event emitted when a rule check passes
     */
    event RuleCheckPassed(
        address indexed actor,
        address indexed counterparty,
        uint256 amount,
        uint256 rulesEvaluated
    );
}
