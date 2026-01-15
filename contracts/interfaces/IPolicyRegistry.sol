// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

/**
 * @title IPolicyRegistry
 * @notice Registry for versioned compliance policies
 * @dev Manages policy lifecycle with staging, activation, and transparent history
 */
interface IPolicyRegistry {
    /**
     * @notice Policy status
     */
    enum PolicyStatus {
        DRAFT,      // Policy created but not staged
        STAGED,     // Policy staged, waiting for timelock
        ACTIVE,     // Policy currently active
        DEPRECATED  // Policy replaced by newer version
    }

    /**
     * @notice Policy metadata
     * @param version Policy version number
     * @param status Current policy status
     * @param ruleSetHash Hash of the rule set
     * @param stagedAt Timestamp when staged (0 if not staged)
     * @param activatedAt Timestamp when activated (0 if not active)
     * @param deprecatedAt Timestamp when deprecated (0 if still active)
     * @param activationDelay Required delay between staging and activation
     * @param description Human-readable policy description
     */
    struct PolicyMetadata {
        uint256 version;
        PolicyStatus status;
        bytes32 ruleSetHash;
        uint256 stagedAt;
        uint256 activatedAt;
        uint256 deprecatedAt;
        uint256 activationDelay;
        string description;
    }

    /**
     * @notice Register a new policy version
     * @param ruleSetHash Hash of the rule set
     * @param description Human-readable description
     * @return version The new policy version number
     */
    function registerPolicy(
        bytes32 ruleSetHash,
        string calldata description
    ) external returns (uint256 version);

    /**
     * @notice Stage a policy for activation
     * @param version The policy version to stage
     */
    function stagePolicy(uint256 version) external;

    /**
     * @notice Activate a staged policy
     * @param version The policy version to activate
     */
    function activatePolicy(uint256 version) external;

    /**
     * @notice Get the currently active policy version
     * @return version The active policy version (0 if none)
     */
    function getActiveVersion() external view returns (uint256 version);

    /**
     * @notice Get policy metadata for a specific version
     * @param version The policy version
     * @return metadata The policy metadata
     */
    function getPolicyMetadata(uint256 version) external view returns (PolicyMetadata memory metadata);

    /**
     * @notice Get the total number of registered policies
     * @return count The policy count
     */
    function getPolicyCount() external view returns (uint256 count);

    /**
     * @notice Event emitted when a policy is registered
     */
    event PolicyRegistered(
        uint256 indexed version,
        bytes32 indexed ruleSetHash,
        string description
    );

    /**
     * @notice Event emitted when a policy is staged
     */
    event PolicyStaged(
        uint256 indexed version,
        uint256 activationTime
    );

    /**
     * @notice Event emitted when a policy is activated
     */
    event PolicyActivated(
        uint256 indexed version,
        uint256 indexed previousVersion
    );

    /**
     * @notice Event emitted when a policy is deprecated
     */
    event PolicyDeprecated(
        uint256 indexed version
    );
}
