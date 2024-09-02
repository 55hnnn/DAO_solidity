// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "forge-std/Test.sol";

import "../src/UpSideGovernor.sol";
import "../src/UpSideToken.sol";
import "../src/Timelock.sol";

import "../src/Counter/CounterV1.sol";
import "../src/Counter/ICounterV1.sol";
import "../src/Counter/CounterV2.sol";
import "../src/Counter/ICounterV2.sol";
import "@openzeppelin/contracts/proxy/ERC1967/ERC1967Proxy.sol";


contract UpSideGovernorTest is Test {
    uint256 public constant VOTING_DELAY = 7200; // 1 day
    uint256 public constant VOTING_PERIOD = 50400; // 1 week
    uint256 public constant VOTER_BALANCE = 10 ether;

    UpSideGovernor public governor;
    UpSideToken public token;
    Timelock public timelock;

    ERC1967Proxy public proxy;
    CounterV1 public counterV1;
    CounterV2 public counterV2;

    address public deployer;
    address public proposer;
    address public voter;

    function setUp() public {
        // address 초기화
        deployer = makeAddr("deployer");
        proposer = makeAddr("proposer");
        voter = makeAddr("voter");

        vm.label(deployer, "deployer");
        vm.label(proposer, "proposer");
        vm.label(voter, "voter");

        address[] memory proposers = new address[](1);
        address[] memory excutors = new address[](1);
        proposers[0] = proposer;
        excutors[0] = address(this);

        // deployer가 governor, token, counter를 배포
        vm.startPrank(deployer);
        token = new UpSideToken(deployer);
        governor = new UpSideGovernor(token, timelock);
        timelock = new Timelock(1 days, proposers, excutors);

        counterV1 = new CounterV1();
        counterV2 = new CounterV2();

        vm.label(address(token), "token");
        vm.label(address(governor), "governor");
        vm.label(address(timelock), "timelock");

        vm.label(address(counterV1), "counterV1");
        vm.label(address(counterV2), "counterV2");

        proxy = new ERC1967Proxy(address(counterV1), abi.encodeWithSignature("initialize()"));

        // voter에게 VOTER_BALANCE만큼 토큰을 mint
        token.mint(voter, VOTER_BALANCE);

        vm.stopPrank();

        // 투표권을 위임하기 전에 voter의 토큰 상태 확인
        assertEq(token.getVotes(voter), 0);

        // voter가 자신에게 투표권을 위임
        vm.prank(voter);
        token.delegate(voter);

        assertEq(token.balanceOf(voter), VOTER_BALANCE);
        assertEq(token.delegates(voter), voter);
        assertEq(token.getVotes(voter), VOTER_BALANCE);
    }

    function test_Propose() public {
        address[] memory targets = new address[](1);
        uint256[] memory values = new uint256[](1);
        bytes[] memory calldatas = new bytes[](1);
        string memory description = "Upgrade to CounterV2";

        targets[0] = address(counterV2);
        values[0] = 0;
        calldatas[0] = abi.encodeWithSignature("upgradeToAndCall(address,bytes)", address(counterV2), "");

        bytes32 descriptionHash = keccak256(abi.encodePacked(description));

        // proposalId 계산
        uint256 proposalId = governor.hashProposal(
            targets,
            values,
            calldatas,
            descriptionHash
        );

        uint256 voteStart = block.timestamp + VOTING_DELAY;
        uint256 voteEnd = voteStart + VOTING_PERIOD;

        // 발생할 이벤트 예상
        vm.expectEmit(true, true, true, true);
        emit IGovernor.ProposalCreated(
            proposalId,
            proposer,
            targets,
            values,
            new string[](1),
            calldatas,
            voteStart,
            voteEnd,
            description
        );

        // proposer가 proposal을 생성
        vm.prank(proposer);
        governor.propose(targets, values, calldatas, description);

        // proposal 상태 확인
        assertEq(
            uint256(governor.state(proposalId)),
            uint256(IGovernor.ProposalState.Pending)
        );
        assertEq(governor.proposalProposer(proposalId), proposer);
        assertEq(governor.proposalSnapshot(proposalId), voteStart);
        assertEq(governor.proposalDeadline(proposalId), voteEnd);
    }

    function test_CastVote() public {
        address[] memory targets = new address[](1);
        uint256[] memory values = new uint256[](1);
        bytes[] memory calldatas = new bytes[](1);
        string memory description = "Upgrade to CounterV2";

        targets[0] = address(counterV2);
        values[0] = 0;
        calldatas[0] = abi.encodeWithSignature("upgradeToAndCall(address,bytes)", address(counterV2), "");

        // proposer가 proposal을 생성
        vm.prank(proposer);
        uint256 proposalId = governor.propose(
            targets,
            values,
            calldatas,
            description
        );

        /*
            [support]
            0: Against
            1: For
            2: Abstain
        */

        // voter가 투표, 그러나 투표 기간이 아님
        vm.expectRevert();
        vm.prank(voter);
        governor.castVote(proposalId, 1);

        // 투표 기간으로 이동
        vm.roll(block.number + VOTING_DELAY + 1);
        vm.warp(block.timestamp + (VOTING_DELAY + 1) * 12);

        assertEq(
            uint256(governor.state(proposalId)),
            uint256(IGovernor.ProposalState.Active)
        );

        // 정족수 확인
        uint256 quorum = governor.quorum(block.number - 1);

        // voter가 투표
        vm.expectEmit(true, true, true, true);
        emit IGovernor.VoteCast(voter, proposalId, 1, VOTER_BALANCE, "");

        vm.prank(voter);
        uint256 weight = governor.castVote(proposalId, 1);

        // 투표 상태 확인
        assertEq(weight, VOTER_BALANCE);
        assertEq(governor.hasVoted(proposalId, voter), true);

        (
            uint256 againstVotes,
            uint256 forVotes,
            uint256 abstainVotes
        ) = governor.proposalVotes(proposalId);
        assertEq(againstVotes, 0);
        assertEq(forVotes, VOTER_BALANCE);
        assertEq(abstainVotes, 0);
        assertGt(forVotes + abstainVotes, quorum);
    }

    function test_Execute() public {
        address[] memory targets = new address[](1);
        uint256[] memory values = new uint256[](1);
        bytes[] memory calldatas = new bytes[](1);
        string memory description = "Upgrade to CounterV2";

        targets[0] = address(counterV2);
        values[0] = 0;
        calldatas[0] = abi.encodeWithSignature("upgradeToAndCall(address,bytes)", address(counterV2), "");

        // proposer가 proposal을 생성
        vm.prank(proposer);
        uint256 proposalId = governor.propose(
            targets,
            values,
            calldatas,
            description
        );

        // 투표 기간으로 이동
        vm.roll(block.number + VOTING_DELAY + 1);
        vm.warp(block.timestamp + (VOTING_DELAY + 1) * 12);

        vm.prank(voter);
        governor.castVote(proposalId, 1);

        // 투표 마감으로 이동
        vm.roll(block.number + VOTING_PERIOD + 1);
        vm.warp(block.timestamp + (VOTING_PERIOD + 1) * 12);

        assertEq(
            uint256(governor.state(proposalId)),
            uint256(IGovernor.ProposalState.Succeeded)
        );

        // proposal 실행
        uint256 countBefore = counterV2.counter();
        bytes32 descriptionHash = keccak256(abi.encodePacked(description));

        vm.expectEmit(true, true, true, true);
        emit IGovernor.ProposalExecuted(proposalId);
        governor.execute(targets, values, calldatas, descriptionHash);

        uint256 countAfter = counterV2.counter();

        // assertEq(countBefore + 1, countAfter);
        assertEq(
            uint256(governor.state(proposalId)),
            uint256(IGovernor.ProposalState.Executed)
        );
    }
}
