// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {BaseRule} from "../core/BaseRule.sol";
import {IRule} from "../interfaces/IRule.sol";
import {IContext} from "../interfaces/IContext.sol";
import {IIdentityResolver} from "../interfaces/IIdentityResolver.sol";

/**
 * @title JurisdictionRule
 * @notice Rule that enforces jurisdiction allowlist/denylist
 * @dev Checks actor and counterparty jurisdictions against configured lists
 */
contract JurisdictionRule is BaseRule {
    enum ListType {
        ALLOWLIST,  // Only listed jurisdictions allowed
        DENYLIST    // Listed jurisdictions blocked
    }

    IIdentityResolver public immutable identityResolver;
    ListType public immutable listType;

    // Jurisdiction storage
    mapping(bytes2 => bool) public jurisdictions;
    uint256 public jurisdictionCount;

    address public admin;

    event JurisdictionAdded(bytes2 indexed jurisdiction);
    event JurisdictionRemoved(bytes2 indexed jurisdiction);

    modifier onlyAdmin() {
        require(msg.sender == admin, "JurisdictionRule: caller is not admin");
        _;
    }

    constructor(
        address identityResolver_,
        ListType listType_
    ) BaseRule(
        keccak256("JURISDICTION_RULE"),
        "Jurisdiction Check",
        1
    ) {
        identityResolver = IIdentityResolver(identityResolver_);
        listType = listType_;
        admin = msg.sender;
    }

    /// @inheritdoc IRule
    function evaluate(IContext context) external view override returns (RuleResult memory) {
        address actor = context.actor();
        address counterparty = context.counterparty();

        // Check actor
        if (!_checkAddress(actor)) {
            return _fail("Actor jurisdiction not allowed");
        }

        // Check counterparty
        if (counterparty != address(0) && !_checkAddress(counterparty)) {
            return _fail("Counterparty jurisdiction not allowed");
        }

        return _pass();
    }

    /**
     * @notice Check if address passes jurisdiction check
     */
    function _checkAddress(address subject) private view returns (bool) {
        IIdentityResolver.AttestationStatus memory status = identityResolver.resolveIdentity(subject);
        
        if (!status.isValid) {
            return false;
        }

        bool inList = jurisdictions[status.jurisdiction];

        if (listType == ListType.ALLOWLIST) {
            return inList;
        } else {
            return !inList;
        }
    }

    /**
     * @notice Add jurisdiction to list
     * @param jurisdiction The jurisdiction code (ISO 3166-1 alpha-2)
     */
    function addJurisdiction(bytes2 jurisdiction) external onlyAdmin {
        require(jurisdiction != bytes2(0), "JurisdictionRule: invalid jurisdiction");
        require(!jurisdictions[jurisdiction], "JurisdictionRule: already added");

        jurisdictions[jurisdiction] = true;
        jurisdictionCount++;

        emit JurisdictionAdded(jurisdiction);
    }

    /**
     * @notice Remove jurisdiction from list
     * @param jurisdiction The jurisdiction code
     */
    function removeJurisdiction(bytes2 jurisdiction) external onlyAdmin {
        require(jurisdictions[jurisdiction], "JurisdictionRule: not in list");

        jurisdictions[jurisdiction] = false;
        jurisdictionCount--;

        emit JurisdictionRemoved(jurisdiction);
    }

    /**
     * @notice Batch add jurisdictions
     * @param jurisdictionList Array of jurisdiction codes
     */
    function batchAddJurisdictions(bytes2[] calldata jurisdictionList) external onlyAdmin {
        for (uint256 i = 0; i < jurisdictionList.length; i++) {
            if (!jurisdictions[jurisdictionList[i]] && jurisdictionList[i] != bytes2(0)) {
                jurisdictions[jurisdictionList[i]] = true;
                jurisdictionCount++;
                emit JurisdictionAdded(jurisdictionList[i]);
            }
        }
    }
}
