// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";

contract MyGovernanceToken is ERC20 {
    constructor(uint256 initialSupply) ERC20("UpSideToken", "UPT") {
        _mint(msg.sender, initialSupply);
    }
}