// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

/**
 * @title CircuitBreaker
 * @notice Emergency pause and recovery mechanism
 * @dev Provides circuit breaker pattern for emergency stops with transparent reasoning
 */
contract CircuitBreaker {
    enum CircuitState {
        CLOSED,     // Normal operation
        OPEN,       // Paused
        SAFE_MODE   // Limited operations only
    }

    CircuitState public state;
    
    address public guardian;
    address public admin;
    
    // Cooldown period before circuit can be reset
    uint256 public constant COOLDOWN_PERIOD = 1 hours;
    uint256 public lastTripTime;
    
    // Reason for circuit trip
    string public tripReason;
    
    // Events
    event CircuitOpened(address indexed by, string reason, uint256 timestamp);
    event CircuitClosed(address indexed by, uint256 timestamp);
    event SafeModeEnabled(address indexed by, string reason, uint256 timestamp);
    event GuardianUpdated(address indexed oldGuardian, address indexed newGuardian);

    modifier onlyGuardianOrAdmin() {
        require(msg.sender == guardian || msg.sender == admin, "CircuitBreaker: unauthorized");
        _;
    }

    modifier onlyAdmin() {
        require(msg.sender == admin, "CircuitBreaker: caller is not admin");
        _;
    }

    modifier whenClosed() {
        require(state == CircuitState.CLOSED, "CircuitBreaker: circuit not closed");
        _;
    }

    modifier whenNotOpen() {
        require(state != CircuitState.OPEN, "CircuitBreaker: circuit is open");
        _;
    }

    constructor(address guardian_) {
        admin = msg.sender;
        guardian = guardian_;
        state = CircuitState.CLOSED;
    }

    /**
     * @notice Open the circuit (emergency stop)
     * @param reason Human-readable reason for stopping
     */
    function openCircuit(string calldata reason) external onlyGuardianOrAdmin {
        require(state != CircuitState.OPEN, "CircuitBreaker: already open");
        
        state = CircuitState.OPEN;
        lastTripTime = block.timestamp;
        tripReason = reason;
        
        emit CircuitOpened(msg.sender, reason, block.timestamp);
    }

    /**
     * @notice Close the circuit (resume normal operation)
     */
    function closeCircuit() external onlyAdmin {
        require(state != CircuitState.CLOSED, "CircuitBreaker: already closed");
        require(
            block.timestamp >= lastTripTime + COOLDOWN_PERIOD,
            "CircuitBreaker: cooldown period not passed"
        );
        
        state = CircuitState.CLOSED;
        tripReason = "";
        
        emit CircuitClosed(msg.sender, block.timestamp);
    }

    /**
     * @notice Enable safe mode (limited operations)
     * @param reason Human-readable reason
     */
    function enableSafeMode(string calldata reason) external onlyGuardianOrAdmin {
        require(state != CircuitState.SAFE_MODE, "CircuitBreaker: already in safe mode");
        
        state = CircuitState.SAFE_MODE;
        lastTripTime = block.timestamp;
        tripReason = reason;
        
        emit SafeModeEnabled(msg.sender, reason, block.timestamp);
    }

    /**
     * @notice Update guardian address
     * @param newGuardian The new guardian address
     */
    function updateGuardian(address newGuardian) external onlyAdmin {
        require(newGuardian != address(0), "CircuitBreaker: invalid guardian");
        
        address oldGuardian = guardian;
        guardian = newGuardian;
        
        emit GuardianUpdated(oldGuardian, newGuardian);
    }

    /**
     * @notice Check if circuit is in a safe state for operations
     * @param requireClosed If true, only CLOSED state is safe
     * @return isSafe Whether operations can proceed
     */
    function isSafeToOperate(bool requireClosed) external view returns (bool isSafe) {
        if (requireClosed) {
            return state == CircuitState.CLOSED;
        } else {
            return state != CircuitState.OPEN;
        }
    }

    /**
     * @notice Get circuit status
     */
    function getStatus() external view returns (
        CircuitState currentState,
        uint256 tripTime,
        string memory reason,
        bool canReset
    ) {
        currentState = state;
        tripTime = lastTripTime;
        reason = tripReason;
        canReset = (state != CircuitState.CLOSED) && 
                   (block.timestamp >= lastTripTime + COOLDOWN_PERIOD);
    }
}
