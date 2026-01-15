// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

/**
 * @title StringUtils
 * @notice String manipulation utilities
 * @dev Provides helpers for string operations in rules
 */
library StringUtils {
    /**
     * @notice Convert bytes32 to string
     * @param data The bytes32 data
     * @return result The string representation
     */
    function bytes32ToString(bytes32 data) internal pure returns (string memory result) {
        bytes memory bytesArray = new bytes(32);
        for (uint256 i = 0; i < 32; i++) {
            bytesArray[i] = data[i];
        }
        return string(bytesArray);
    }

    /**
     * @notice Convert address to string
     * @param addr The address
     * @return result The string representation
     */
    function addressToString(address addr) internal pure returns (string memory result) {
        bytes32 value = bytes32(uint256(uint160(addr)));
        bytes memory alphabet = "0123456789abcdef";
        bytes memory str = new bytes(42);
        
        str[0] = "0";
        str[1] = "x";
        
        for (uint256 i = 0; i < 20; i++) {
            str[2 + i * 2] = alphabet[uint8(value[i + 12] >> 4)];
            str[3 + i * 2] = alphabet[uint8(value[i + 12] & 0x0f)];
        }
        
        return string(str);
    }

    /**
     * @notice Convert uint256 to string
     * @param value The uint256 value
     * @return result The string representation
     */
    function uintToString(uint256 value) internal pure returns (string memory result) {
        if (value == 0) {
            return "0";
        }
        
        uint256 temp = value;
        uint256 digits;
        
        while (temp != 0) {
            digits++;
            temp /= 10;
        }
        
        bytes memory buffer = new bytes(digits);
        
        while (value != 0) {
            digits -= 1;
            buffer[digits] = bytes1(uint8(48 + uint256(value % 10)));
            value /= 10;
        }
        
        return string(buffer);
    }

    /**
     * @notice Concatenate two strings
     * @param a First string
     * @param b Second string
     * @return result Concatenated string
     */
    function concat(string memory a, string memory b) internal pure returns (string memory result) {
        return string(abi.encodePacked(a, b));
    }

    /**
     * @notice Check if two strings are equal
     * @param a First string
     * @param b Second string
     * @return isEqual Whether the strings are equal
     */
    function equal(string memory a, string memory b) internal pure returns (bool isEqual) {
        return keccak256(bytes(a)) == keccak256(bytes(b));
    }

    /**
     * @notice Get string length
     * @param s The string
     * @return length The length
     */
    function length(string memory s) internal pure returns (uint256) {
        return bytes(s).length;
    }
}
