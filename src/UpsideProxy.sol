// SPDX-License-Identifier: MIT
// Compatible with OpenZeppelin Contracts ^5.0.0
pragma solidity ^0.8.20;

import "@openzeppelin/contracts/proxy/ERC1967/ERC1967Proxy.sol";

contract UpsideProxy is ERC1967Proxy {
    constructor (address implAddr) ERC1967Proxy(implAddr, abi.encodeWithSignature("initialize()")) {}
}