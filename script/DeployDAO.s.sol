// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "forge-std/Script.sol";

import "../src/UpSideGovernor.sol";
import "../src/UpSideToken.sol";
import "../src/Timelock.sol";

import "../src/Counter/CounterV1.sol";
import "../src/Counter/CounterV2.sol";
import "@openzeppelin/contracts/proxy/ERC1967/ERC1967Proxy.sol";

contract DeployScript is Script {
    uint256 public constant VOTING_DELAY = 7200; // 1 day
    uint256 public constant VOTING_PERIOD = 50400; // 1 week
    uint256 public constant VOTER_BALANCE = 10 ether;

    function run() external {
        // Start broadcasting transactions to the network
        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY"); // 환경 변수에서 프라이빗 키 가져오기
        address deployerAddress = vm.envAddress("USER_ADDR"); // 환경 변수에서 계정 가져오기
        address[] memory deployerArrAddress = new address[](1);
        deployerArrAddress[0] = deployerAddress;
        vm.startBroadcast(deployerPrivateKey);

        // 컨트랙트 배포
        CounterV1 counterV1 = new CounterV1();
        CounterV2 counterV2 = new CounterV2();
        ERC1967Proxy proxy = new ERC1967Proxy(
            address(counterV1),
            abi.encodeWithSignature("initialize()")
        );

        // Timelock timelock = new Timelock(1 days, deployerArrAddress, deployerArrAddress);
        Timelock timelock = new Timelock(1, deployerArrAddress, deployerArrAddress);
        UpSideToken token = new UpSideToken(deployerAddress);
        UpSideGovernor governor = new UpSideGovernor(token, timelock);

        // address(proxy).call(
        //     abi.encodeWithSignature(
        //         "transferOwnership(address)",
        //         address(timelock)
        //     )
        // );
        // address(token).call(
        //     abi.encodeWithSignature(
        //         "transferOwnership(address)", 
        //         address(governor)
        //     )
        // );
        timelock.grantRole(timelock.PROPOSER_ROLE(), address(governor));
        timelock.grantRole(timelock.EXECUTOR_ROLE(), address(governor));

        // 배포된 컨트랙트의 주소 출력
        console.log("export COUNTERV1=%s", address(counterV1));
        console.log("export COUNTERV2=%s", address(counterV2));
        console.log("export PROXY=%s", address(proxy));

        console.log("export TIMELOCK=%s", address(timelock));
        console.log("export TOKEN=%s", address(token));
        console.log("export GOVERNOR=%s", address(governor));

        vm.stopBroadcast();
    }
}
