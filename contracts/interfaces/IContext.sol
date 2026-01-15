// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

/**
 * @title IContext
 * @notice Context interface for rule evaluation
 * @dev Encapsulates all information needed to evaluate rules for a transaction
 */
interface IContext {
    /**
     * @notice Operation type being performed
     */
    enum OperationType {
        TRANSFER,
        MINT,
        BURN,
        APPROVE,
        DEPOSIT,
        WITHDRAW,
        REDEEM
    }

    /**
     * @notice Get the operation type
     */
    function operationType() external view returns (OperationType);

    /**
     * @notice Get the initiating actor
     */
    function actor() external view returns (address);

    /**
     * @notice Get the counterparty (recipient, spender, etc.)
     */
    function counterparty() external view returns (address);

    /**
     * @notice Get the amount involved in the operation
     */
    function amount() external view returns (uint256);

    /**
     * @notice Get the asset being operated on
     */
    function asset() external view returns (address);

    /**
     * @notice Get the timestamp of the operation
     */
    function timestamp() external view returns (uint256);

    /**
     * @notice Get arbitrary metadata for the operation
     */
    function metadata(bytes32 key) external view returns (bytes memory);
}
