// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

/**
 * @title Timelock
 * @notice Time-delayed execution for critical operations
 * @dev Provides transparent, delayed governance actions
 */
contract Timelock {
    uint256 public constant MINIMUM_DELAY = 2 days;
    uint256 public constant MAXIMUM_DELAY = 30 days;
    uint256 public constant GRACE_PERIOD = 14 days;

    address public admin;
    address public pendingAdmin;
    uint256 public delay;

    mapping(bytes32 => bool) public queuedTransactions;

    // Events
    event NewAdmin(address indexed newAdmin);
    event NewPendingAdmin(address indexed newPendingAdmin);
    event NewDelay(uint256 indexed newDelay);
    event QueueTransaction(
        bytes32 indexed txHash,
        address indexed target,
        uint256 value,
        string signature,
        bytes data,
        uint256 eta
    );
    event CancelTransaction(
        bytes32 indexed txHash,
        address indexed target,
        uint256 value,
        string signature,
        bytes data,
        uint256 eta
    );
    event ExecuteTransaction(
        bytes32 indexed txHash,
        address indexed target,
        uint256 value,
        string signature,
        bytes data,
        uint256 eta
    );

    modifier onlyAdmin() {
        require(msg.sender == admin, "Timelock: caller is not admin");
        _;
    }

    constructor(address admin_, uint256 delay_) {
        require(delay_ >= MINIMUM_DELAY, "Timelock: delay below minimum");
        require(delay_ <= MAXIMUM_DELAY, "Timelock: delay above maximum");

        admin = admin_;
        delay = delay_;
    }

    /**
     * @notice Queue a transaction
     * @param target Target contract address
     * @param value ETH value to send
     * @param signature Function signature
     * @param data Encoded function arguments
     * @param eta Estimated time of arrival (execution timestamp)
     */
    function queueTransaction(
        address target,
        uint256 value,
        string calldata signature,
        bytes calldata data,
        uint256 eta
    ) external onlyAdmin returns (bytes32) {
        require(eta >= block.timestamp + delay, "Timelock: ETA must satisfy delay");

        bytes32 txHash = keccak256(abi.encode(target, value, signature, data, eta));
        queuedTransactions[txHash] = true;

        emit QueueTransaction(txHash, target, value, signature, data, eta);
        return txHash;
    }

    /**
     * @notice Cancel a queued transaction
     * @param target Target contract address
     * @param value ETH value to send
     * @param signature Function signature
     * @param data Encoded function arguments
     * @param eta Estimated time of arrival
     */
    function cancelTransaction(
        address target,
        uint256 value,
        string calldata signature,
        bytes calldata data,
        uint256 eta
    ) external onlyAdmin {
        bytes32 txHash = keccak256(abi.encode(target, value, signature, data, eta));
        queuedTransactions[txHash] = false;

        emit CancelTransaction(txHash, target, value, signature, data, eta);
    }

    /**
     * @notice Execute a queued transaction
     * @param target Target contract address
     * @param value ETH value to send
     * @param signature Function signature
     * @param data Encoded function arguments
     * @param eta Estimated time of arrival
     */
    function executeTransaction(
        address target,
        uint256 value,
        string calldata signature,
        bytes calldata data,
        uint256 eta
    ) external payable onlyAdmin returns (bytes memory) {
        bytes32 txHash = keccak256(abi.encode(target, value, signature, data, eta));

        require(queuedTransactions[txHash], "Timelock: transaction not queued");
        require(block.timestamp >= eta, "Timelock: transaction not ready");
        require(block.timestamp <= eta + GRACE_PERIOD, "Timelock: transaction expired");

        queuedTransactions[txHash] = false;

        bytes memory callData;
        if (bytes(signature).length == 0) {
            callData = data;
        } else {
            callData = abi.encodePacked(bytes4(keccak256(bytes(signature))), data);
        }

        (bool success, bytes memory returnData) = target.call{value: value}(callData);
        require(success, "Timelock: transaction execution reverted");

        emit ExecuteTransaction(txHash, target, value, signature, data, eta);
        return returnData;
    }

    /**
     * @notice Set a new delay
     * @param delay_ New delay in seconds
     */
    function setDelay(uint256 delay_) external {
        require(msg.sender == address(this), "Timelock: call must come from Timelock");
        require(delay_ >= MINIMUM_DELAY, "Timelock: delay below minimum");
        require(delay_ <= MAXIMUM_DELAY, "Timelock: delay above maximum");

        delay = delay_;
        emit NewDelay(delay);
    }

    /**
     * @notice Accept admin role
     */
    function acceptAdmin() external {
        require(msg.sender == pendingAdmin, "Timelock: caller is not pending admin");
        admin = msg.sender;
        pendingAdmin = address(0);

        emit NewAdmin(admin);
    }

    /**
     * @notice Set pending admin
     * @param pendingAdmin_ New pending admin address
     */
    function setPendingAdmin(address pendingAdmin_) external {
        require(msg.sender == address(this), "Timelock: call must come from Timelock");
        pendingAdmin = pendingAdmin_;

        emit NewPendingAdmin(pendingAdmin);
    }

    receive() external payable {}
}
