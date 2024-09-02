pragma solidity ^0.8.20;

import {Initializable} from "@openzeppelin/contracts/proxy/utils/Initializable.sol";
import {ICounterV1} from "./ICounterV1.sol";
import {UUPSUpgradeable} from "@openzeppelin/contracts-upgradeable/proxy/utils/UUPSUpgradeable.sol";
import {OwnableUpgradeable} from "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";

contract CounterV1 is UUPSUpgradeable, OwnableUpgradeable, ICounterV1 {
    uint256 public counter;

    function initialize() public initializer {
        __Ownable_init(_msgSender());
        __UUPSUpgradeable_init();
    }

    function increment() external {
        unchecked {
            ++counter;
        }
    }

    function _authorizeUpgrade(address newImplementation) internal override onlyOwner {}
}
