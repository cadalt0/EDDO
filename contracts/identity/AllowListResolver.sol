// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {IIdentityResolver} from "../interfaces/IIdentityResolver.sol";

/**
 * @title AllowListResolver
 * @notice Simple allow-list based identity resolver
 * @dev Maintains onchain lists of addresses with identity tiers and jurisdictions
 */
contract AllowListResolver is IIdentityResolver {
    // Address attestation storage
    mapping(address => AttestationStatus) private _attestations;

    // Admin control
    address public admin;

    // Events
    event AttestationSet(
        address indexed subject,
        IdentityTier tier,
        bytes2 jurisdiction,
        uint256 expiresAt
    );
    event AttestationRevoked(address indexed subject);

    modifier onlyAdmin() {
        require(msg.sender == admin, "AllowListResolver: caller is not admin");
        _;
    }

    constructor() {
        admin = msg.sender;
    }

    /// @inheritdoc IIdentityResolver
    function resolveIdentity(address subject) external view override returns (AttestationStatus memory status) {
        status = _attestations[subject];
        
        // Check expiration
        if (status.expiresAt > 0 && block.timestamp >= status.expiresAt) {
            status.isValid = false;
        }

        return status;
    }

    /// @inheritdoc IIdentityResolver
    function hasMinimumTier(address subject, IdentityTier minTier) external view override returns (bool) {
        AttestationStatus memory status = _attestations[subject];
        
        // Check validity and expiration
        if (!status.isValid) return false;
        if (status.expiresAt > 0 && block.timestamp >= status.expiresAt) return false;
        
        // Check tier level
        return uint8(status.tier) >= uint8(minTier);
    }

    /// @inheritdoc IIdentityResolver
    function isInJurisdiction(address subject, bytes2 jurisdiction) external view override returns (bool) {
        AttestationStatus memory status = _attestations[subject];
        
        // Check validity and expiration
        if (!status.isValid) return false;
        if (status.expiresAt > 0 && block.timestamp >= status.expiresAt) return false;
        
        return status.jurisdiction == jurisdiction;
    }

    /**
     * @notice Set attestation for an address
     * @param subject The address to attest
     * @param tier The identity tier
     * @param jurisdiction The jurisdiction code
     * @param expiresAt Expiration timestamp (0 for never)
     */
    function setAttestation(
        address subject,
        IdentityTier tier,
        bytes2 jurisdiction,
        uint256 expiresAt
    ) external onlyAdmin {
        require(subject != address(0), "AllowListResolver: invalid subject");
        
        bytes32 attestationId = keccak256(abi.encodePacked(subject, tier, jurisdiction, block.timestamp));
        
        _attestations[subject] = AttestationStatus({
            tier: tier,
            isValid: true,
            expiresAt: expiresAt,
            jurisdiction: jurisdiction,
            attestationId: attestationId
        });

        emit AttestationSet(subject, tier, jurisdiction, expiresAt);
    }

    /**
     * @notice Batch set attestations
     * @param subjects Array of addresses
     * @param tiers Array of identity tiers
     * @param jurisdictions Array of jurisdiction codes
     * @param expirations Array of expiration timestamps
     */
    function batchSetAttestations(
        address[] calldata subjects,
        IdentityTier[] calldata tiers,
        bytes2[] calldata jurisdictions,
        uint256[] calldata expirations
    ) external onlyAdmin {
        require(
            subjects.length == tiers.length &&
            subjects.length == jurisdictions.length &&
            subjects.length == expirations.length,
            "AllowListResolver: length mismatch"
        );

        for (uint256 i = 0; i < subjects.length; i++) {
            bytes32 attestationId = keccak256(
                abi.encodePacked(subjects[i], tiers[i], jurisdictions[i], block.timestamp)
            );
            
            _attestations[subjects[i]] = AttestationStatus({
                tier: tiers[i],
                isValid: true,
                expiresAt: expirations[i],
                jurisdiction: jurisdictions[i],
                attestationId: attestationId
            });

            emit AttestationSet(subjects[i], tiers[i], jurisdictions[i], expirations[i]);
        }
    }

    /**
     * @notice Revoke an attestation
     * @param subject The address to revoke
     */
    function revokeAttestation(address subject) external onlyAdmin {
        _attestations[subject].isValid = false;
        emit AttestationRevoked(subject);
    }

    /**
     * @notice Transfer admin role
     * @param newAdmin The new admin address
     */
    function transferAdmin(address newAdmin) external onlyAdmin {
        require(newAdmin != address(0), "AllowListResolver: invalid admin");
        admin = newAdmin;
    }
}
