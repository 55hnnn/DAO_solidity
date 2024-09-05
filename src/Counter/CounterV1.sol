pragma solidity ^0.8.20;

import {UUPSUpgradeable} from "@openzeppelin/contracts-upgradeable/proxy/utils/UUPSUpgradeable.sol";
import {OwnableUpgradeable} from "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";

contract CounterV1 is UUPSUpgradeable, OwnableUpgradeable {
    uint256 public counter;

    function initialize() public initializer {
        __Ownable_init(_msgSender());
        __UUPSUpgradeable_init();
    }

    function increment() external {
        counter++;
    }

    function version() public returns (string memory){
        return "V1";
    }

    function _authorizeUpgrade(address newImplementation) internal override onlyOwner {}
}
