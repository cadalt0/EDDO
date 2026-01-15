// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

/**
 * @title IIdentityResolver
 * @notice Interface for identity and attestation resolution
 * @dev Pluggable interface for various identity providers (EAS, allow-lists, oracles, etc.)
 */
interface IIdentityResolver {
    /**
     * @notice Identity tier levels
     */
    enum IdentityTier {
        NONE,           // No verification
        BASIC,          // Basic KYC
        INTERMEDIATE,   // Enhanced KYC
        ADVANCED,       // Full KYC/AML
        ACCREDITED      // Accredited investor
    }

    /**
     * @notice Attestation status
     * @param tier The identity tier
     * @param isValid Whether the attestation is currently valid
     * @param expiresAt Expiration timestamp (0 if never expires)
     * @param jurisdiction Jurisdiction code (ISO 3166-1 alpha-2)
     * @param attestationId Unique identifier for the attestation
     */
    struct AttestationStatus {
        IdentityTier tier;
        bool isValid;
        uint256 expiresAt;
        bytes2 jurisdiction;
        bytes32 attestationId;
    }

    /**
     * @notice Resolve the identity status for an address
     * @param subject The address to resolve
     * @return status The attestation status
     */
    function resolveIdentity(address subject) external view returns (AttestationStatus memory status);

    /**
     * @notice Check if an address has a minimum identity tier
     * @param subject The address to check
     * @param minTier The minimum required tier
     * @return hasMinimumTier Whether the subject meets the minimum tier
     */
    function hasMinimumTier(address subject, IdentityTier minTier) external view returns (bool);

    /**
     * @notice Check if an address is in a specific jurisdiction
     * @param subject The address to check
     * @param jurisdiction The jurisdiction code
     * @return inJurisdiction Whether the subject is in the jurisdiction
     */
    function isInJurisdiction(address subject, bytes2 jurisdiction) external view returns (bool);

    /**
     * @notice Event emitted when an attestation is resolved
     */
    event AttestationResolved(
        address indexed subject,
        bytes32 indexed attestationId,
        IdentityTier tier,
        bool isValid
    );
}
