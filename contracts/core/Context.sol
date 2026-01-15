// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {IContext} from "../interfaces/IContext.sol";

/**
 * @title Context
 * @notice Implementation of evaluation context for rule execution
 * @dev Immutable context created per transaction evaluation
 */
contract Context is IContext {
    OperationType private immutable _operationType;
    address private immutable _actor;
    address private immutable _counterparty;
    uint256 private immutable _amount;
    address private immutable _asset;
    uint256 private immutable _timestamp;

    // Metadata storage for additional context
    mapping(bytes32 => bytes) private _metadata;

    /**
     * @notice Create a new context
     * @param opType The operation type
     * @param actor_ The initiating actor
     * @param counterparty_ The counterparty
     * @param amount_ The amount
     * @param asset_ The asset address
     */
    constructor(
        OperationType opType,
        address actor_,
        address counterparty_,
        uint256 amount_,
        address asset_
    ) {
        _operationType = opType;
        _actor = actor_;
        _counterparty = counterparty_;
        _amount = amount_;
        _asset = asset_;
        _timestamp = block.timestamp;
    }

    /// @inheritdoc IContext
    function operationType() external view override returns (OperationType) {
        return _operationType;
    }

    /// @inheritdoc IContext
    function actor() external view override returns (address) {
        return _actor;
    }

    /// @inheritdoc IContext
    function counterparty() external view override returns (address) {
        return _counterparty;
    }

    /// @inheritdoc IContext
    function amount() external view override returns (uint256) {
        return _amount;
    }

    /// @inheritdoc IContext
    function asset() external view override returns (address) {
        return _asset;
    }

    /// @inheritdoc IContext
    function timestamp() external view override returns (uint256) {
        return _timestamp;
    }

    /// @inheritdoc IContext
    function metadata(bytes32 key) external view override returns (bytes memory) {
        return _metadata[key];
    }

    /**
     * @notice Set metadata (internal only, called during construction)
     * @param key The metadata key
     * @param value The metadata value
     */
    function _setMetadata(bytes32 key, bytes memory value) internal {
        _metadata[key] = value;
    }
}
