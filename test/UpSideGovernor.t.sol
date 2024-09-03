// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "forge-std/Test.sol";

import "../src/UpSideGovernor.sol";
import "../src/UpSideToken.sol";
import "../src/Timelock.sol";

import "../src/Counter/CounterV1.sol";
import "../src/Counter/CounterV2.sol";
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
    address public voter1;
    address public voter2;
    address public voter3;

    function setUp() public {
        // address 초기화
        deployer = makeAddr("deployer");
        proposer = makeAddr("proposer");
        voter1 = makeAddr("voter1");
        voter2 = makeAddr("voter2");

        vm.label(deployer, "deployer");
        vm.label(proposer, "proposer");
        vm.label(voter1, "voter1");
        vm.label(voter2, "voter2");

        address[] memory proposers = new address[](1);
        address[] memory excutors = new address[](1);
        proposers[0] = proposer;
        excutors[0] = proposer;

        // deployer가 governor, token, timelock, counter를 배포
        vm.startPrank(deployer);
        {
            token = new UpSideToken(deployer);
            timelock = new Timelock(1 days, proposers, excutors);
            governor = new UpSideGovernor(token, timelock);

            counterV1 = new CounterV1();
            counterV2 = new CounterV2();

            vm.label(address(token), "token");
            vm.label(address(governor), "governor");
            vm.label(address(timelock), "timelock");

            vm.label(address(counterV1), "counterV1");
            vm.label(address(counterV2), "counterV2");

            proxy = new ERC1967Proxy(
                address(counterV1),
                abi.encodeWithSignature("initialize()")
            );

            address(proxy).call(
                abi.encodeWithSignature(
                    "transferOwnership(address)",
                    address(timelock)
                )
            );
            timelock.grantRole(timelock.PROPOSER_ROLE(), address(governor));
            timelock.grantRole(timelock.EXECUTOR_ROLE(), address(governor));

            // voter에게 VOTER_BALANCE만큼 토큰을 mint
            token.mint(voter1, VOTER_BALANCE);
            token.mint(voter2, VOTER_BALANCE * 2);
        }
        vm.stopPrank();

        // 투표권을 위임하기 전에 voter의 토큰 상태 확인
        assertEq(token.getVotes(voter1), 0);

        // voter가 자신에게 투표권을 위임
        vm.prank(voter1);
        token.delegate(voter1);

        // timelock.grantRole(timelock.PROPOSER_ROLE(), address(governor));

        assertEq(token.balanceOf(voter1), VOTER_BALANCE);
        assertEq(token.delegates(voter1), voter1);
        assertEq(token.getVotes(voter1), VOTER_BALANCE);
    }

    function test_Pending() public {
        address[] memory targets = new address[](1);
        uint256[] memory values = new uint256[](1);
        bytes[] memory calldatas = new bytes[](1);
        string memory description = "Upgrade to CounterV2";

        targets[0] = address(proxy);
        values[0] = 0;
        calldatas[0] = abi.encodeWithSignature(
            "upgradeToAndCall(address,bytes)",
            address(counterV2),
            ""
        );

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

    function test_Active() public {
        // propose
        address[] memory targets = new address[](1);
        uint256[] memory values = new uint256[](1);
        bytes[] memory calldatas = new bytes[](1);
        string memory description = "Upgrade to CounterV2";

        targets[0] = address(proxy);
        values[0] = 0;
        calldatas[0] = abi.encodeWithSignature(
            "upgradeToAndCall(address,bytes)",
            address(counterV2),
            ""
        );

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
        vm.prank(voter1);
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
        emit IGovernor.VoteCast(voter1, proposalId, 1, VOTER_BALANCE, "");

        vm.prank(voter1);
        uint256 weight = governor.castVote(proposalId, 1);

        // 투표 상태 확인
        assertEq(weight, VOTER_BALANCE);
        assertEq(governor.hasVoted(proposalId, voter1), true);

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

    function test_Defeated() public {
        address[] memory targets = new address[](1);
        uint256[] memory values = new uint256[](1);
        bytes[] memory calldatas = new bytes[](1);
        string memory description = "Upgrade to CounterV2";

        targets[0] = address(proxy);
        values[0] = 0;
        calldatas[0] = abi.encodeWithSignature(
            "upgradeToAndCall(address,bytes)",
            address(counterV2),
            ""
        );

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

        vm.prank(voter1);
        governor.castVote(proposalId, 2);

        // 투표 마감으로 이동
        vm.roll(block.number + VOTING_PERIOD + 1);
        vm.warp(block.timestamp + (VOTING_PERIOD + 1) * 12);

        assertEq(
            uint256(governor.state(proposalId)),
            uint256(IGovernor.ProposalState.Defeated)
        );
    }

    function test_Queued() public {
        address[] memory targets = new address[](1);
        uint256[] memory values = new uint256[](1);
        bytes[] memory calldatas = new bytes[](1);
        string memory description = "Upgrade to CounterV2";

        targets[0] = address(proxy);
        values[0] = 0;
        calldatas[0] = abi.encodeWithSignature(
            "upgradeToAndCall(address,bytes)",
            address(counterV2),
            ""
        );

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

        vm.prank(voter1);
        governor.castVote(proposalId, 1);

        // 투표 마감으로 이동
        vm.roll(block.number + VOTING_PERIOD + 1);
        vm.warp(block.timestamp + (VOTING_PERIOD + 1) * 12);

        assertEq(
            uint256(governor.state(proposalId)),
            uint256(IGovernor.ProposalState.Succeeded)
        );

        bytes32 descriptionHash = keccak256(abi.encodePacked(description));
        governor.queue(targets, values, calldatas, descriptionHash);

        assertEq(
            uint256(governor.state(proposalId)),
            uint256(IGovernor.ProposalState.Queued)
        );
    }

    function test_Execute() public {
        address[] memory targets = new address[](1);
        uint256[] memory values = new uint256[](1);
        bytes[] memory calldatas = new bytes[](1);
        string memory description = "Upgrade to CounterV2";

        targets[0] = address(proxy);
        values[0] = 0;
        calldatas[0] = abi.encodeWithSignature(
            "upgradeToAndCall(address,bytes)",
            address(counterV2),
            ""
        );

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

        vm.prank(voter1);
        governor.castVote(proposalId, 1);

        // 투표 마감으로 이동
        vm.roll(block.number + VOTING_PERIOD + 1);
        vm.warp(block.timestamp + (VOTING_PERIOD + 1) * 12);

        assertEq(
            uint256(governor.state(proposalId)),
            uint256(IGovernor.ProposalState.Succeeded)
        );

        bytes32 descriptionHash = keccak256(abi.encodePacked(description));
        governor.queue(targets, values, calldatas, descriptionHash);

        assertEq(
            uint256(governor.state(proposalId)),
            uint256(IGovernor.ProposalState.Queued)
        );

        vm.roll(block.number + 1 days + 1);
        vm.warp(block.timestamp + (1 days + 1) * 12);

        // proposal 실행
        vm.expectEmit(true, true, true, true);
        emit IGovernor.ProposalExecuted(proposalId);

        governor.execute(targets, values, calldatas, descriptionHash);

        assertEq(
            uint256(governor.state(proposalId)),
            uint256(IGovernor.ProposalState.Executed)
        );

        // 실행 후 실제로 CounterV2로 업그레이드 되었는지 확인
        (bool success, bytes memory returndata) = address(proxy).call(
            abi.encodeWithSignature("version()")
        );
        require(success, "Call to version() failed");
        assertEq(abi.decode(returndata, (string)), "V2");
    }

    function test_QuorumReached() public {
        // 프로포절 생성
        address[] memory targets = new address[](1);
        uint256[] memory values = new uint256[](1);
        bytes[] memory calldatas = new bytes[](1);
        string memory description = "Upgrade to CounterV2";

        targets[0] = address(this);
        values[0] = 0;
        calldatas[0] = abi.encodeWithSignature("someFunction()");

        vm.prank(proposer);
        uint256 proposalId = governor.propose(
            targets,
            values,
            calldatas,
            description
        );

        // 투표 기간으로 이동
        vm.roll(block.number + governor.votingDelay() + 1);
        vm.warp(block.timestamp + (governor.votingDelay() + 1) * 12);

        // 투표 진행 (voter1의 투표)
        vm.prank(voter1);
        governor.castVote(proposalId, 1); // 1 = 찬성

        // 정족수 확인
        uint256 quorum = governor.quorum(block.number - 1);
        assertEq(token.getPastVotes(voter1, block.number - 1), VOTER_BALANCE);
        assertGt(token.getPastVotes(voter1, block.number - 1), quorum);

        // 투표 종료로 이동
        vm.roll(block.number + governor.votingPeriod() + 1);
        vm.warp(block.timestamp + (governor.votingPeriod() + 1) * 12);

        // 프로포절 상태가 Succeeded인지 확인 (quorum 충족)
        assertEq(
            uint256(governor.state(proposalId)),
            uint256(IGovernor.ProposalState.Succeeded)
        );
    }

    function test_QuorumNotReached() public {
        address[] memory targets = new address[](1);
        uint256[] memory values = new uint256[](1);
        bytes[] memory calldatas = new bytes[](1);
        string memory description = "Upgrade to CounterV2";

        targets[0] = address(this);
        values[0] = 0;
        calldatas[0] = abi.encodeWithSignature("someFunction()");

        vm.prank(proposer);
        uint256 proposalId = governor.propose(
            targets,
            values,
            calldatas,
            description
        );

        // 투표 기간으로 이동
        vm.roll(block.number + governor.votingDelay() + 1);
        vm.warp(block.timestamp + (governor.votingDelay() + 1) * 12);

        // 정족수 미달로 인해 투표하지 않음 (또는 너무 적게 투표)

        // 투표 종료로 이동
        vm.roll(block.number + governor.votingPeriod() + 1);
        vm.warp(block.timestamp + (governor.votingPeriod() + 1) * 12);

        // 프로포절 상태가 Defeated인지 확인 (quorum 미충족)
        assertEq(
            uint256(governor.state(proposalId)),
            uint256(IGovernor.ProposalState.Defeated)
        );
    }
}
