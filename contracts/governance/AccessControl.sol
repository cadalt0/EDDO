// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

/**
 * @title AccessControl
 * @notice Role-based access control with hierarchical roles
 * @dev Provides fine-grained permission management for RWA operations
 */
contract AccessControl {
    // Role definitions
    bytes32 public constant ADMIN_ROLE = keccak256("ADMIN_ROLE");
    bytes32 public constant POLICY_MANAGER_ROLE = keccak256("POLICY_MANAGER_ROLE");
    bytes32 public constant RULE_MANAGER_ROLE = keccak256("RULE_MANAGER_ROLE");
    bytes32 public constant IDENTITY_MANAGER_ROLE = keccak256("IDENTITY_MANAGER_ROLE");
    bytes32 public constant PAUSER_ROLE = keccak256("PAUSER_ROLE");
    bytes32 public constant MINTER_ROLE = keccak256("MINTER_ROLE");
    bytes32 public constant BURNER_ROLE = keccak256("BURNER_ROLE");

    // Role data
    struct RoleData {
        mapping(address => bool) members;
        bytes32 adminRole;
        uint256 memberCount;
    }

    mapping(bytes32 => RoleData) private _roles;

    // Events
    event RoleGranted(bytes32 indexed role, address indexed account, address indexed sender);
    event RoleRevoked(bytes32 indexed role, address indexed account, address indexed sender);
    event RoleAdminChanged(bytes32 indexed role, bytes32 indexed previousAdminRole, bytes32 indexed newAdminRole);

    /**
     * @notice Initialize access control
     */
    constructor() {
        _setupRole(ADMIN_ROLE, msg.sender);
        _setRoleAdmin(POLICY_MANAGER_ROLE, ADMIN_ROLE);
        _setRoleAdmin(RULE_MANAGER_ROLE, ADMIN_ROLE);
        _setRoleAdmin(IDENTITY_MANAGER_ROLE, ADMIN_ROLE);
        _setRoleAdmin(PAUSER_ROLE, ADMIN_ROLE);
        _setRoleAdmin(MINTER_ROLE, ADMIN_ROLE);
        _setRoleAdmin(BURNER_ROLE, ADMIN_ROLE);
    }

    /**
     * @notice Check if account has role
     * @param role The role to check
     * @param account The account to check
     */
    function hasRole(bytes32 role, address account) public view returns (bool) {
        return _roles[role].members[account];
    }

    /**
     * @notice Get the admin role for a role
     * @param role The role to check
     */
    function getRoleAdmin(bytes32 role) public view returns (bytes32) {
        return _roles[role].adminRole;
    }

    /**
     * @notice Get member count for a role
     * @param role The role to check
     */
    function getRoleMemberCount(bytes32 role) public view returns (uint256) {
        return _roles[role].memberCount;
    }

    /**
     * @notice Grant role to account
     * @param role The role to grant
     * @param account The account to grant to
     */
    function grantRole(bytes32 role, address account) public {
        require(hasRole(getRoleAdmin(role), msg.sender), "AccessControl: sender must be an admin");
        _grantRole(role, account);
    }

    /**
     * @notice Revoke role from account
     * @param role The role to revoke
     * @param account The account to revoke from
     */
    function revokeRole(bytes32 role, address account) public {
        require(hasRole(getRoleAdmin(role), msg.sender), "AccessControl: sender must be an admin");
        _revokeRole(role, account);
    }

    /**
     * @notice Renounce role
     * @param role The role to renounce
     * @param account The account renouncing (must be caller)
     */
    function renounceRole(bytes32 role, address account) public {
        require(account == msg.sender, "AccessControl: can only renounce roles for self");
        _revokeRole(role, account);
    }

    /**
     * @notice Internal function to setup role
     * @param role The role to setup
     * @param account The account to grant to
     */
    function _setupRole(bytes32 role, address account) internal {
        _grantRole(role, account);
    }

    /**
     * @notice Internal function to set role admin
     * @param role The role to set admin for
     * @param adminRole The admin role
     */
    function _setRoleAdmin(bytes32 role, bytes32 adminRole) internal {
        bytes32 previousAdminRole = getRoleAdmin(role);
        _roles[role].adminRole = adminRole;
        emit RoleAdminChanged(role, previousAdminRole, adminRole);
    }

    /**
     * @notice Internal function to grant role
     * @param role The role to grant
     * @param account The account to grant to
     */
    function _grantRole(bytes32 role, address account) private {
        if (!hasRole(role, account)) {
            _roles[role].members[account] = true;
            _roles[role].memberCount++;
            emit RoleGranted(role, account, msg.sender);
        }
    }

    /**
     * @notice Internal function to revoke role
     * @param role The role to revoke
     * @param account The account to revoke from
     */
    function _revokeRole(bytes32 role, address account) private {
        if (hasRole(role, account)) {
            _roles[role].members[account] = false;
            _roles[role].memberCount--;
            emit RoleRevoked(role, account, msg.sender);
        }
    }

    /**
     * @notice Modifier to check if caller has role
     * @param role The role to check
     */
    modifier onlyRole(bytes32 role) {
        require(hasRole(role, msg.sender), "AccessControl: insufficient permissions");
        _;
    }
}
