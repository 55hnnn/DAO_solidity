// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import "./UpSideToken.sol";

contract MyDAO {
    struct Proposal {
        uint id;
        string description;
        uint voteCount;
        bool executed;
        address proposer;
    }

    MyGovernanceToken public token;
    uint public proposalCount;
    mapping(uint => Proposal) public proposals;
    mapping(uint => mapping(address => bool)) public voted;

    event ProposalCreated(uint id, string description, address proposer);
    event Voted(uint proposalId, address voter);
    event Executed(uint proposalId);

    constructor(MyGovernanceToken _token) {
        token = _token;
    }

    function createProposal(string memory description) public {
        proposals[proposalCount] = Proposal({
            id: proposalCount,
            description: description,
            voteCount: 0,
            executed: false,
            proposer: msg.sender
        });
        emit ProposalCreated(proposalCount, description, msg.sender);
        proposalCount++;
    }

    function vote(uint proposalId) public {
        Proposal storage proposal = proposals[proposalId];
        require(!voted[proposalId][msg.sender], "Already voted.");
        require(!proposal.executed, "Proposal already executed.");

        proposal.voteCount += token.balanceOf(msg.sender);
        voted[proposalId][msg.sender] = true;
        emit Voted(proposalId, msg.sender);
    }

    function executeProposal(uint proposalId) public {
        Proposal storage proposal = proposals[proposalId];
        require(!proposal.executed, "Proposal already executed.");
        require(proposal.voteCount > 0, "No votes.");

        proposal.executed = true;
        // 여기에서 실제 실행할 로직을 추가할 수 있습니다.

        emit Executed(proposalId);
    }
}