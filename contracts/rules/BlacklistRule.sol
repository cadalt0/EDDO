// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {BaseRule} from "../core/BaseRule.sol";
import {IRule} from "../interfaces/IRule.sol";
import {IContext} from "../interfaces/IContext.sol";

/**
 * @title BlacklistRule
 * @notice Rule that blocks specific addresses
 * @dev Maintains a blocklist of addresses with optional expiry
 */
contract BlacklistRule is BaseRule {
    struct BlacklistEntry {
        bool isBlacklisted;
        uint256 expiresAt;  // 0 = permanent
        string reason;
    }

    mapping(address => BlacklistEntry) public blacklist;
    uint256 public blacklistCount;

    address public admin;

    event AddressBlacklisted(address indexed account, uint256 expiresAt, string reason);
    event AddressUnblacklisted(address indexed account);

    modifier onlyAdmin() {
        require(msg.sender == admin, "BlacklistRule: caller is not admin");
        _;
    }

    constructor() BaseRule(
        keccak256("BLACKLIST_RULE"),
        "Blacklist Check",
        1
    ) {
        admin = msg.sender;
    }

    /// @inheritdoc IRule
    function evaluate(IContext context) external view override returns (RuleResult memory) {
        address actor = context.actor();
        address counterparty = context.counterparty();

        // Check actor
        if (_isBlacklisted(actor)) {
            return _fail(string(abi.encodePacked("Actor is blacklisted: ", blacklist[actor].reason)));
        }

        // Check counterparty
        if (counterparty != address(0) && _isBlacklisted(counterparty)) {
            return _fail(string(abi.encodePacked("Counterparty is blacklisted: ", blacklist[counterparty].reason)));
        }

        return _pass();
    }

    /**
     * @notice Check if address is currently blacklisted
     */
    function _isBlacklisted(address account) private view returns (bool) {
        BlacklistEntry memory entry = blacklist[account];
        
        if (!entry.isBlacklisted) {
            return false;
        }

        // Check expiry
        if (entry.expiresAt > 0 && block.timestamp >= entry.expiresAt) {
            return false;
        }

        return true;
    }

    /**
     * @notice Add address to blacklist
     * @param account The address to blacklist
     * @param expiresAt Expiration timestamp (0 for permanent)
     * @param reason Human-readable reason
     */
    function addToBlacklist(address account, uint256 expiresAt, string calldata reason) external onlyAdmin {
        require(account != address(0), "BlacklistRule: invalid address");
        require(!blacklist[account].isBlacklisted, "BlacklistRule: already blacklisted");

        blacklist[account] = BlacklistEntry({
            isBlacklisted: true,
            expiresAt: expiresAt,
            reason: reason
        });
        blacklistCount++;

        emit AddressBlacklisted(account, expiresAt, reason);
    }

    /**
     * @notice Remove address from blacklist
     * @param account The address to unblacklist
     */
    function removeFromBlacklist(address account) external onlyAdmin {
        require(blacklist[account].isBlacklisted, "BlacklistRule: not blacklisted");

        delete blacklist[account];
        blacklistCount--;

        emit AddressUnblacklisted(account);
    }

    /**
     * @notice Batch add addresses to blacklist
     * @param accounts Array of addresses
     * @param expirations Array of expiration timestamps
     * @param reasons Array of reasons
     */
    function batchAddToBlacklist(
        address[] calldata accounts,
        uint256[] calldata expirations,
        string[] calldata reasons
    ) external onlyAdmin {
        require(
            accounts.length == expirations.length && accounts.length == reasons.length,
            "BlacklistRule: length mismatch"
        );

        for (uint256 i = 0; i < accounts.length; i++) {
            if (!blacklist[accounts[i]].isBlacklisted && accounts[i] != address(0)) {
                blacklist[accounts[i]] = BlacklistEntry({
                    isBlacklisted: true,
                    expiresAt: expirations[i],
                    reason: reasons[i]
                });
                blacklistCount++;
                emit AddressBlacklisted(accounts[i], expirations[i], reasons[i]);
            }
        }
    }

    /**
     * @notice Check if address is blacklisted (public)
     */
    function isBlacklisted(address account) external view returns (bool) {
        return _isBlacklisted(account);
    }
}
