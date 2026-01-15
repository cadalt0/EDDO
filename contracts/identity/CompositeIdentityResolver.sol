// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {IIdentityResolver} from "../interfaces/IIdentityResolver.sol";

/**
 * @title CompositeIdentityResolver
 * @notice Combines multiple identity resolvers with configurable logic
 * @dev Supports AND/OR logic across multiple identity sources
 */
contract CompositeIdentityResolver is IIdentityResolver {
    enum ResolverMode {
        ANY,        // At least one resolver must pass
        ALL,        // All resolvers must pass
        QUORUM      // Minimum N resolvers must pass
    }

    struct ResolverConfig {
        IIdentityResolver resolver;
        bool enabled;
        uint256 weight;
    }

    ResolverConfig[] public resolvers;
    ResolverMode public mode;
    uint256 public quorumThreshold;

    address public admin;

    event ResolverAdded(address indexed resolver, uint256 weight);
    event ResolverRemoved(address indexed resolver);
    event ResolverModeUpdated(ResolverMode newMode);

    modifier onlyAdmin() {
        require(msg.sender == admin, "CompositeIdentityResolver: caller is not admin");
        _;
    }

    constructor(ResolverMode mode_, uint256 quorumThreshold_) {
        admin = msg.sender;
        mode = mode_;
        quorumThreshold = quorumThreshold_;
    }

    /// @inheritdoc IIdentityResolver
    function resolveIdentity(address subject) external view override returns (AttestationStatus memory status) {
        if (resolvers.length == 0) {
            return AttestationStatus({
                tier: IdentityTier.NONE,
                isValid: false,
                expiresAt: 0,
                jurisdiction: bytes2(0),
                attestationId: bytes32(0)
            });
        }

        uint256 validCount = 0;
        uint256 totalWeight = 0;
        IdentityTier highestTier = IdentityTier.NONE;
        bytes2 firstJurisdiction;
        uint256 earliestExpiry = type(uint256).max;
        bytes32 firstAttestationId;

        for (uint256 i = 0; i < resolvers.length; i++) {
            if (!resolvers[i].enabled) continue;

            AttestationStatus memory result = resolvers[i].resolver.resolveIdentity(subject);
            
            if (result.isValid) {
                validCount++;
                totalWeight += resolvers[i].weight;
                
                // Track highest tier
                if (uint8(result.tier) > uint8(highestTier)) {
                    highestTier = result.tier;
                }
                
                // Track earliest expiration
                if (result.expiresAt > 0 && result.expiresAt < earliestExpiry) {
                    earliestExpiry = result.expiresAt;
                }
                
                // Use first jurisdiction
                if (firstJurisdiction == bytes2(0)) {
                    firstJurisdiction = result.jurisdiction;
                }
                
                // Use first attestation ID
                if (firstAttestationId == bytes32(0)) {
                    firstAttestationId = result.attestationId;
                }
            }

            // Early exit for ANY mode
            if (mode == ResolverMode.ANY && validCount > 0) {
                break;
            }
        }

        // Determine overall validity
        bool isValid = false;
        if (mode == ResolverMode.ANY) {
            isValid = validCount > 0;
        } else if (mode == ResolverMode.ALL) {
            isValid = validCount == _getEnabledResolverCount();
        } else if (mode == ResolverMode.QUORUM) {
            isValid = totalWeight >= quorumThreshold;
        }

        return AttestationStatus({
            tier: isValid ? highestTier : IdentityTier.NONE,
            isValid: isValid,
            expiresAt: earliestExpiry == type(uint256).max ? 0 : earliestExpiry,
            jurisdiction: firstJurisdiction,
            attestationId: firstAttestationId
        });
    }

    /// @inheritdoc IIdentityResolver
    function hasMinimumTier(address subject, IdentityTier minTier) external view override returns (bool) {
        AttestationStatus memory status = this.resolveIdentity(subject);
        return status.isValid && uint8(status.tier) >= uint8(minTier);
    }

    /// @inheritdoc IIdentityResolver
    function isInJurisdiction(address subject, bytes2 jurisdiction) external view override returns (bool) {
        AttestationStatus memory status = this.resolveIdentity(subject);
        return status.isValid && status.jurisdiction == jurisdiction;
    }

    /**
     * @notice Add a resolver to the composite
     * @param resolver The resolver address
     * @param weight The resolver weight (for quorum mode)
     */
    function addResolver(address resolver, uint256 weight) external onlyAdmin {
        require(resolver != address(0), "CompositeIdentityResolver: invalid resolver");
        
        resolvers.push(ResolverConfig({
            resolver: IIdentityResolver(resolver),
            enabled: true,
            weight: weight
        }));

        emit ResolverAdded(resolver, weight);
    }

    /**
     * @notice Remove a resolver
     * @param index The resolver index
     */
    function removeResolver(uint256 index) external onlyAdmin {
        require(index < resolvers.length, "CompositeIdentityResolver: invalid index");
        
        address resolver = address(resolvers[index].resolver);
        
        // Swap and pop
        resolvers[index] = resolvers[resolvers.length - 1];
        resolvers.pop();

        emit ResolverRemoved(resolver);
    }

    /**
     * @notice Enable or disable a resolver
     * @param index The resolver index
     * @param enabled Whether to enable the resolver
     */
    function setResolverEnabled(uint256 index, bool enabled) external onlyAdmin {
        require(index < resolvers.length, "CompositeIdentityResolver: invalid index");
        resolvers[index].enabled = enabled;
    }

    /**
     * @notice Update resolver mode
     * @param newMode The new resolver mode
     */
    function setResolverMode(ResolverMode newMode) external onlyAdmin {
        mode = newMode;
        emit ResolverModeUpdated(newMode);
    }

    /**
     * @notice Update quorum threshold
     * @param newThreshold The new threshold
     */
    function setQuorumThreshold(uint256 newThreshold) external onlyAdmin {
        quorumThreshold = newThreshold;
    }

    /**
     * @notice Get the number of enabled resolvers
     */
    function _getEnabledResolverCount() private view returns (uint256 count) {
        for (uint256 i = 0; i < resolvers.length; i++) {
            if (resolvers[i].enabled) count++;
        }
        return count;
    }

    /**
     * @notice Get resolver count
     */
    function getResolverCount() external view returns (uint256) {
        return resolvers.length;
    }
}
