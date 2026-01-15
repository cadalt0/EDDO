// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {BaseRule} from "../core/BaseRule.sol";
import {IRule} from "../interfaces/IRule.sol";
import {IContext} from "../interfaces/IContext.sol";

/**
 * @title VelocityRule
 * @notice Rule that enforces transfer velocity limits
 * @dev Limits the amount an address can transfer within a time window
 */
contract VelocityRule is BaseRule {
    struct VelocityLimit {
        uint256 maxAmount;      // Maximum amount in window
        uint256 windowSize;     // Time window in seconds
        uint256 windowStart;    // Start of current window
        uint256 transferred;    // Amount transferred in current window
    }

    mapping(address => VelocityLimit) public limits;
    
    uint256 public defaultMaxAmount;
    uint256 public defaultWindowSize;
    
    address public admin;

    event VelocityLimitSet(address indexed account, uint256 maxAmount, uint256 windowSize);
    event DefaultsUpdated(uint256 maxAmount, uint256 windowSize);

    modifier onlyAdmin() {
        require(msg.sender == admin, "VelocityRule: caller is not admin");
        _;
    }

    constructor(uint256 defaultMaxAmount_, uint256 defaultWindowSize_) BaseRule(
        keccak256("VELOCITY_RULE"),
        "Velocity Limit Check",
        1
    ) {
        defaultMaxAmount = defaultMaxAmount_;
        defaultWindowSize = defaultWindowSize_;
        admin = msg.sender;
    }

    /// @inheritdoc IRule
    function evaluate(IContext context) external view override returns (RuleResult memory) {
        // Skip for minting
        if (context.operationType() == IContext.OperationType.MINT) {
            return _pass();
        }

        address actor = context.actor();
        uint256 amount = context.amount();

        VelocityLimit memory limit = limits[actor];
        
        // Use defaults if not set
        if (limit.maxAmount == 0) {
            limit.maxAmount = defaultMaxAmount;
            limit.windowSize = defaultWindowSize;
        }

        // Check if we need to reset window
        if (block.timestamp >= limit.windowStart + limit.windowSize) {
            // New window, amount is OK if less than max
            if (amount > limit.maxAmount) {
                return _fail("Transfer exceeds velocity limit");
            }
        } else {
            // Within current window
            if (limit.transferred + amount > limit.maxAmount) {
                return _fail("Transfer would exceed velocity limit for current window");
            }
        }

        return _pass();
    }

    /**
     * @notice Set velocity limit for an address
     * @param account The address to set limit for
     * @param maxAmount Maximum amount per window
     * @param windowSize Time window in seconds
     */
    function setVelocityLimit(
        address account,
        uint256 maxAmount,
        uint256 windowSize
    ) external onlyAdmin {
        require(account != address(0), "VelocityRule: invalid address");
        require(maxAmount > 0, "VelocityRule: invalid max amount");
        require(windowSize > 0, "VelocityRule: invalid window size");

        limits[account] = VelocityLimit({
            maxAmount: maxAmount,
            windowSize: windowSize,
            windowStart: block.timestamp,
            transferred: 0
        });

        emit VelocityLimitSet(account, maxAmount, windowSize);
    }

    /**
     * @notice Update default limits
     * @param maxAmount Default maximum amount
     * @param windowSize Default window size
     */
    function setDefaults(uint256 maxAmount, uint256 windowSize) external onlyAdmin {
        require(maxAmount > 0, "VelocityRule: invalid max amount");
        require(windowSize > 0, "VelocityRule: invalid window size");

        defaultMaxAmount = maxAmount;
        defaultWindowSize = windowSize;

        emit DefaultsUpdated(maxAmount, windowSize);
    }

    /**
     * @notice Record a transfer (called after successful transfer)
     * @param account The account that transferred
     * @param amount The amount transferred
     */
    function recordTransfer(address account, uint256 amount) external {
        VelocityLimit storage limit = limits[account];
        
        // Initialize if needed
        if (limit.maxAmount == 0) {
            limit.maxAmount = defaultMaxAmount;
            limit.windowSize = defaultWindowSize;
            limit.windowStart = block.timestamp;
        }

        // Reset window if needed
        if (block.timestamp >= limit.windowStart + limit.windowSize) {
            limit.windowStart = block.timestamp;
            limit.transferred = amount;
        } else {
            limit.transferred += amount;
        }
    }

    /**
     * @notice Get remaining amount in current window
     * @param account The address to check
     */
    function getRemainingAmount(address account) external view returns (uint256) {
        VelocityLimit memory limit = limits[account];
        
        if (limit.maxAmount == 0) {
            return defaultMaxAmount;
        }

        if (block.timestamp >= limit.windowStart + limit.windowSize) {
            return limit.maxAmount;
        }

        if (limit.transferred >= limit.maxAmount) {
            return 0;
        }

        return limit.maxAmount - limit.transferred;
    }
}
