// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {IPolicyRegistry} from "../interfaces/IPolicyRegistry.sol";

/**
 * @title PolicyRegistry
 * @notice Registry for versioned compliance policies with staging and activation
 * @dev Manages policy lifecycle with timelock-based activation
 */
contract PolicyRegistry is IPolicyRegistry {
    // Default activation delay (24 hours)
    uint256 public constant DEFAULT_ACTIVATION_DELAY = 24 hours;

    // Policy storage
    mapping(uint256 => PolicyMetadata) private _policies;
    uint256 private _policyCount;
    uint256 private _activeVersion;

    // Access control
    address public admin;
    address public pendingAdmin;

    // Modifiers
    modifier onlyAdmin() {
        require(msg.sender == admin, "PolicyRegistry: caller is not admin");
        _;
    }

    /**
     * @notice Create a new policy registry
     */
    constructor() {
        admin = msg.sender;
    }

    /// @inheritdoc IPolicyRegistry
    function registerPolicy(
        bytes32 ruleSetHash,
        string calldata description
    ) external override onlyAdmin returns (uint256 version) {
        require(ruleSetHash != bytes32(0), "PolicyRegistry: invalid rule set hash");

        _policyCount++;
        version = _policyCount;

        _policies[version] = PolicyMetadata({
            version: version,
            status: PolicyStatus.DRAFT,
            ruleSetHash: ruleSetHash,
            stagedAt: 0,
            activatedAt: 0,
            deprecatedAt: 0,
            activationDelay: DEFAULT_ACTIVATION_DELAY,
            description: description
        });

        emit PolicyRegistered(version, ruleSetHash, description);
        return version;
    }

    /// @inheritdoc IPolicyRegistry
    function stagePolicy(uint256 version) external override onlyAdmin {
        require(version > 0 && version <= _policyCount, "PolicyRegistry: invalid version");
        PolicyMetadata storage policy = _policies[version];
        require(policy.status == PolicyStatus.DRAFT, "PolicyRegistry: policy not in draft");

        policy.status = PolicyStatus.STAGED;
        policy.stagedAt = block.timestamp;

        emit PolicyStaged(version, block.timestamp + policy.activationDelay);
    }

    /// @inheritdoc IPolicyRegistry
    function activatePolicy(uint256 version) external override onlyAdmin {
        require(version > 0 && version <= _policyCount, "PolicyRegistry: invalid version");
        PolicyMetadata storage policy = _policies[version];
        require(policy.status == PolicyStatus.STAGED, "PolicyRegistry: policy not staged");
        require(
            block.timestamp >= policy.stagedAt + policy.activationDelay,
            "PolicyRegistry: activation delay not passed"
        );

        uint256 previousVersion = _activeVersion;

        // Deprecate previous policy if exists
        if (previousVersion > 0) {
            _policies[previousVersion].status = PolicyStatus.DEPRECATED;
            _policies[previousVersion].deprecatedAt = block.timestamp;
            emit PolicyDeprecated(previousVersion);
        }

        // Activate new policy
        policy.status = PolicyStatus.ACTIVE;
        policy.activatedAt = block.timestamp;
        _activeVersion = version;

        emit PolicyActivated(version, previousVersion);
    }

    /// @inheritdoc IPolicyRegistry
    function getActiveVersion() external view override returns (uint256 version) {
        return _activeVersion;
    }

    /// @inheritdoc IPolicyRegistry
    function getPolicyMetadata(uint256 version) external view override returns (PolicyMetadata memory metadata) {
        require(version > 0 && version <= _policyCount, "PolicyRegistry: invalid version");
        return _policies[version];
    }

    /// @inheritdoc IPolicyRegistry
    function getPolicyCount() external view override returns (uint256 count) {
        return _policyCount;
    }

    /**
     * @notice Set custom activation delay for a policy
     * @param version The policy version
     * @param delay The activation delay in seconds
     */
    function setActivationDelay(uint256 version, uint256 delay) external onlyAdmin {
        require(version > 0 && version <= _policyCount, "PolicyRegistry: invalid version");
        require(_policies[version].status == PolicyStatus.DRAFT, "PolicyRegistry: policy not in draft");
        require(delay >= 1 hours, "PolicyRegistry: delay too short");

        _policies[version].activationDelay = delay;
    }

    /**
     * @notice Transfer admin role to a new address
     * @param newAdmin The new admin address
     */
    function transferAdmin(address newAdmin) external onlyAdmin {
        require(newAdmin != address(0), "PolicyRegistry: invalid admin");
        pendingAdmin = newAdmin;
    }

    /**
     * @notice Accept admin role transfer
     */
    function acceptAdmin() external {
        require(msg.sender == pendingAdmin, "PolicyRegistry: caller is not pending admin");
        admin = pendingAdmin;
        pendingAdmin = address(0);
    }

    /**
     * @notice Emergency cancel a staged policy
     * @param version The policy version to cancel
     */
    function cancelStaging(uint256 version) external onlyAdmin {
        require(version > 0 && version <= _policyCount, "PolicyRegistry: invalid version");
        PolicyMetadata storage policy = _policies[version];
        require(policy.status == PolicyStatus.STAGED, "PolicyRegistry: policy not staged");

        policy.status = PolicyStatus.DRAFT;
        policy.stagedAt = 0;
    }
}
