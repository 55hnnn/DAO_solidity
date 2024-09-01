// SPDX-License-Identifier: MIT
pragma solidity ^0.8.13;

import "forge-std/Test.sol";
import "../src/DAO.sol";
import "../src/UpSideToken.sol";

contract MyDAOTest is Test {
    MyGovernanceToken token;
    MyDAO dao;
    address addr1;
    address addr2;

    function setUp() public {
        token = new MyGovernanceToken(1000000);
        dao = new MyDAO(token);
        addr1 = address(0x123);
        addr2 = address(0x456);
        token.transfer(addr1, 100);
        token.transfer(addr2, 100);
    }

    function testCreateProposal() public {
        vm.startPrank(addr1);
        dao.createProposal("Proposal 1");
        (uint id, string memory description,,,) = dao.proposals(0);
        assertEq(description, "Proposal 1");
        vm.stopPrank();
    }

    function testVote() public {
        vm.startPrank(addr1);
        dao.createProposal("Proposal 1");
        token.approve(address(dao), 100);
        dao.vote(0);
        (, , uint voteCount,,) = dao.proposals(0);
        assertEq(voteCount, 100);
        vm.stopPrank();
    }

    function testExecuteProposal() public {
        vm.startPrank(addr1);
        dao.createProposal("Proposal 1");
        token.approve(address(dao), 100);
        dao.vote(0);
        dao.executeProposal(0);
        (, , , bool executed,) = dao.proposals(0);
        assertTrue(executed);
        vm.stopPrank();
    }
}