pragma solidity ^0.8.20;

interface ICounterV1 {
    function counter() external view returns (uint256);
    function increment() external;
}
