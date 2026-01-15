// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

/**
 * @title SafeMath
 * @notice Safe math operations with overflow checks
 * @dev Provides checked arithmetic for critical calculations
 */
library SafeMath {
    /**
     * @notice Safe addition
     */
    function add(uint256 a, uint256 b) internal pure returns (uint256) {
        uint256 c = a + b;
        require(c >= a, "SafeMath: addition overflow");
        return c;
    }

    /**
     * @notice Safe subtraction
     */
    function sub(uint256 a, uint256 b) internal pure returns (uint256) {
        require(b <= a, "SafeMath: subtraction overflow");
        return a - b;
    }

    /**
     * @notice Safe multiplication
     */
    function mul(uint256 a, uint256 b) internal pure returns (uint256) {
        if (a == 0) return 0;
        uint256 c = a * b;
        require(c / a == b, "SafeMath: multiplication overflow");
        return c;
    }

    /**
     * @notice Safe division
     */
    function div(uint256 a, uint256 b) internal pure returns (uint256) {
        require(b > 0, "SafeMath: division by zero");
        return a / b;
    }

    /**
     * @notice Safe modulo
     */
    function mod(uint256 a, uint256 b) internal pure returns (uint256) {
        require(b > 0, "SafeMath: modulo by zero");
        return a % b;
    }

    /**
     * @notice Calculate percentage
     * @param amount The amount
     * @param basisPoints The percentage (in basis points, 10000 = 100%)
     */
    function percentage(uint256 amount, uint256 basisPoints) internal pure returns (uint256) {
        require(basisPoints <= 10000, "SafeMath: percentage > 100%");
        return mul(amount, basisPoints) / 10000;
    }

    /**
     * @notice Calculate average
     */
    function average(uint256 a, uint256 b) internal pure returns (uint256) {
        return (a & b) + (a ^ b) / 2;
    }

    /**
     * @notice Get minimum of two values
     */
    function min(uint256 a, uint256 b) internal pure returns (uint256) {
        return a < b ? a : b;
    }

    /**
     * @notice Get maximum of two values
     */
    function max(uint256 a, uint256 b) internal pure returns (uint256) {
        return a > b ? a : b;
    }
}
