// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "eddo-rwa/contracts/adapters/RWA_ERC20.sol";

/**
 * @title MyRWAToken
 * @notice Example RWA token using EDDO library
 */
contract MyRWAToken is RWA_ERC20 {
    constructor(
        string memory name_,
        string memory symbol_,
        uint8 decimals_,
        address rulesEngine_
    ) RWA_ERC20(name_, symbol_, decimals_, rulesEngine_) {}
}
