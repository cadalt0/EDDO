// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

/**
 * @title BitOperations
 * @notice Gas-efficient bitmap operations for rule caching
 * @dev Provides bitmap helpers for tracking rule evaluations
 */
library BitOperations {
    /**
     * @notice Set a bit in a bitmap
     * @param bitmap The bitmap to modify
     * @param index The bit index to set
     * @return newBitmap The modified bitmap
     */
    function setBit(uint256 bitmap, uint256 index) internal pure returns (uint256 newBitmap) {
        require(index < 256, "BitOperations: index out of bounds");
        return bitmap | (1 << index);
    }

    /**
     * @notice Clear a bit in a bitmap
     * @param bitmap The bitmap to modify
     * @param index The bit index to clear
     * @return newBitmap The modified bitmap
     */
    function clearBit(uint256 bitmap, uint256 index) internal pure returns (uint256 newBitmap) {
        require(index < 256, "BitOperations: index out of bounds");
        return bitmap & ~(1 << index);
    }

    /**
     * @notice Check if a bit is set
     * @param bitmap The bitmap to check
     * @param index The bit index to check
     * @return isSet Whether the bit is set
     */
    function isBitSet(uint256 bitmap, uint256 index) internal pure returns (bool isSet) {
        require(index < 256, "BitOperations: index out of bounds");
        return (bitmap & (1 << index)) != 0;
    }

    /**
     * @notice Toggle a bit
     * @param bitmap The bitmap to modify
     * @param index The bit index to toggle
     * @return newBitmap The modified bitmap
     */
    function toggleBit(uint256 bitmap, uint256 index) internal pure returns (uint256 newBitmap) {
        require(index < 256, "BitOperations: index out of bounds");
        return bitmap ^ (1 << index);
    }

    /**
     * @notice Count set bits (population count)
     * @param bitmap The bitmap to count
     * @return count Number of set bits
     */
    function popCount(uint256 bitmap) internal pure returns (uint256 count) {
        // Brian Kernighan's algorithm
        while (bitmap != 0) {
            bitmap &= bitmap - 1;
            count++;
        }
        return count;
    }

    /**
     * @notice Find the index of the first set bit
     * @param bitmap The bitmap to search
     * @return index The index of the first set bit (255 if none)
     */
    function firstSetBit(uint256 bitmap) internal pure returns (uint256 index) {
        if (bitmap == 0) return 255;
        
        index = 0;
        while ((bitmap & 1) == 0) {
            bitmap >>= 1;
            index++;
        }
        return index;
    }
}
