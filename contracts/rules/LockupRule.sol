// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {BaseRule} from "../core/BaseRule.sol";
import {IRule} from "../interfaces/IRule.sol";
import {IContext} from "../interfaces/IContext.sol";

/**
 * @title LockupRule
 * @notice Rule that enforces token lockup periods
 * @dev Prevents transfers during lockup windows per address
 */
contract LockupRule is BaseRule {
    struct LockupPeriod {
        uint256 lockedUntil;
        uint256 amount;      // 0 = all tokens locked
        string reason;
    }

    mapping(address => LockupPeriod) public lockups;
    uint256 public lockupCount;

    address public admin;

    event LockupSet(address indexed account, uint256 lockedUntil, uint256 amount, string reason);
    event LockupRemoved(address indexed account);

    modifier onlyAdmin() {
        require(msg.sender == admin, "LockupRule: caller is not admin");
        _;
    }

    constructor() BaseRule(
        keccak256("LOCKUP_RULE"),
        "Lockup Period Check",
        1
    ) {
        admin = msg.sender;
    }

    /// @inheritdoc IRule
    function evaluate(IContext context) external view override returns (RuleResult memory) {
        address actor = context.actor();
        uint256 amount = context.amount();

        // Skip checks for minting
        if (context.operationType() == IContext.OperationType.MINT) {
            return _pass();
        }

        LockupPeriod memory lockup = lockups[actor];

        // Check if locked
        if (lockup.lockedUntil > 0 && block.timestamp < lockup.lockedUntil) {
            // Check if amount exceeds locked amount
            if (lockup.amount == 0 || amount > lockup.amount) {
                return _fail(string(abi.encodePacked("Tokens locked until ", _uint2str(lockup.lockedUntil))));
            }
        }

        return _pass();
    }

    /**
     * @notice Set lockup period for an address
     * @param account The address to lock
     * @param lockedUntil Timestamp until which tokens are locked
     * @param amount Amount of tokens locked (0 = all)
     * @param reason Human-readable reason
     */
    function setLockup(
        address account,
        uint256 lockedUntil,
        uint256 amount,
        string calldata reason
    ) external onlyAdmin {
        require(account != address(0), "LockupRule: invalid address");
        require(lockedUntil > block.timestamp, "LockupRule: lockup in past");

        bool isNew = lockups[account].lockedUntil == 0;

        lockups[account] = LockupPeriod({
            lockedUntil: lockedUntil,
            amount: amount,
            reason: reason
        });

        if (isNew) {
            lockupCount++;
        }

        emit LockupSet(account, lockedUntil, amount, reason);
    }

    /**
     * @notice Remove lockup period
     * @param account The address to unlock
     */
    function removeLockup(address account) external onlyAdmin {
        require(lockups[account].lockedUntil > 0, "LockupRule: no lockup");

        delete lockups[account];
        lockupCount--;

        emit LockupRemoved(account);
    }

    /**
     * @notice Batch set lockups
     * @param accounts Array of addresses
     * @param timestamps Array of lockup timestamps
     * @param amounts Array of locked amounts
     * @param reasons Array of reasons
     */
    function batchSetLockups(
        address[] calldata accounts,
        uint256[] calldata timestamps,
        uint256[] calldata amounts,
        string[] calldata reasons
    ) external onlyAdmin {
        require(
            accounts.length == timestamps.length &&
            accounts.length == amounts.length &&
            accounts.length == reasons.length,
            "LockupRule: length mismatch"
        );

        for (uint256 i = 0; i < accounts.length; i++) {
            if (accounts[i] != address(0) && timestamps[i] > block.timestamp) {
                bool isNew = lockups[accounts[i]].lockedUntil == 0;
                
                lockups[accounts[i]] = LockupPeriod({
                    lockedUntil: timestamps[i],
                    amount: amounts[i],
                    reason: reasons[i]
                });

                if (isNew) {
                    lockupCount++;
                }

                emit LockupSet(accounts[i], timestamps[i], amounts[i], reasons[i]);
            }
        }
    }

    /**
     * @notice Check if address is locked
     * @param account The address to check
     */
    function isLocked(address account) external view returns (bool) {
        LockupPeriod memory lockup = lockups[account];
        return lockup.lockedUntil > 0 && block.timestamp < lockup.lockedUntil;
    }

    /**
     * @notice Get time remaining in lockup
     * @param account The address to check
     */
    function getTimeRemaining(address account) external view returns (uint256) {
        LockupPeriod memory lockup = lockups[account];
        if (lockup.lockedUntil == 0 || block.timestamp >= lockup.lockedUntil) {
            return 0;
        }
        return lockup.lockedUntil - block.timestamp;
    }

    /**
     * @notice Convert uint to string (helper)
     */
    function _uint2str(uint256 _i) private pure returns (string memory) {
        if (_i == 0) {
            return "0";
        }
        uint256 j = _i;
        uint256 len;
        while (j != 0) {
            len++;
            j /= 10;
        }
        bytes memory bstr = new bytes(len);
        uint256 k = len;
        while (_i != 0) {
            k = k - 1;
            uint8 temp = (48 + uint8(_i - _i / 10 * 10));
            bytes1 b1 = bytes1(temp);
            bstr[k] = b1;
            _i /= 10;
        }
        return string(bstr);
    }
}
