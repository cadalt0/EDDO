// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {BaseRule} from "../core/BaseRule.sol";
import {IRule} from "../interfaces/IRule.sol";
import {IContext} from "../interfaces/IContext.sol";

/**
 * @title SupplyCapRule
 * @notice Rule that enforces maximum supply caps
 * @dev Checks that minting doesn't exceed configured supply limits
 */
contract SupplyCapRule is BaseRule {
    uint256 public maxSupply;
    address public asset;
    address public admin;

    event MaxSupplyUpdated(uint256 newMaxSupply);

    modifier onlyAdmin() {
        require(msg.sender == admin, "SupplyCapRule: caller is not admin");
        _;
    }

    constructor(uint256 maxSupply_, address asset_) BaseRule(
        keccak256("SUPPLY_CAP_RULE"),
        "Supply Cap Check",
        1
    ) {
        maxSupply = maxSupply_;
        asset = asset_;
        admin = msg.sender;
    }

    /// @inheritdoc IRule
    function evaluate(IContext context) external view override returns (RuleResult memory) {
        // Only check on mint operations
        if (context.operationType() != IContext.OperationType.MINT) {
            return _pass();
        }

        // Get current total supply from asset
        (bool success, bytes memory data) = asset.staticcall(
            abi.encodeWithSignature("totalSupply()")
        );
        
        if (!success) {
            return _fail("Failed to query total supply");
        }

        uint256 currentSupply = abi.decode(data, (uint256));
        uint256 mintAmount = context.amount();

        if (currentSupply + mintAmount > maxSupply) {
            return _fail("Mint would exceed maximum supply");
        }

        return _pass();
    }

    /**
     * @notice Update maximum supply
     * @param newMaxSupply The new maximum supply
     */
    function setMaxSupply(uint256 newMaxSupply) external onlyAdmin {
        require(newMaxSupply > 0, "SupplyCapRule: invalid max supply");
        maxSupply = newMaxSupply;
        emit MaxSupplyUpdated(newMaxSupply);
    }
}
