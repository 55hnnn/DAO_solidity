pragma solidity ^0.8.20;

interface ICounterV2 {
    function counter() external view returns (uint256);
    function increment() external;
    function reset() external;

    function registerUpgradingContract(address addr) external;
    function revokeUpgradingContract(address addr) external;
}
