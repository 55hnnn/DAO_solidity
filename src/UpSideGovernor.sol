// SPDX-License-Identifier: MIT
// Compatible with OpenZeppelin Contracts ^5.0.0
pragma solidity ^0.8.20;

import "@openzeppelin/contracts/governance/Governor.sol";
import "@openzeppelin/contracts/governance/extensions/GovernorSettings.sol";
import "@openzeppelin/contracts/governance/extensions/GovernorCountingSimple.sol";
import "@openzeppelin/contracts/governance/extensions/GovernorVotes.sol";
import "@openzeppelin/contracts/governance/extensions/GovernorVotesQuorumFraction.sol";
import "@openzeppelin/contracts/governance/extensions/GovernorTimelockControl.sol";

contract UpSideGovernor is Governor, GovernorSettings, GovernorCountingSimple, GovernorVotes, GovernorVotesQuorumFraction, GovernorTimelockControl {
    constructor(IVotes _token, TimelockController _timelock)
        Governor("UpSideGovernor")
        GovernorSettings(7200 /* 1 day */, 50400 /* 1 week */, 0)
        GovernorVotes(_token)
        GovernorVotesQuorumFraction(10)
        GovernorTimelockControl(_timelock){}

    /* 
    1. 토큰을 어떻게 발행하고, 소각시킬 수 있을까
    2. 투표에서 승리할 경우 어떻게 보상할 수 있을까
    3. 투표시간을 줄이는 방법
    */
    uint256[] _proposedList;
    mapping(uint256 => bool) public proposalEndedEarly;

    struct ProposalComponent {
        address[] targets;
        uint256[] values;
        bytes[] calldatas;
        bytes32 descriptionHash;
    }

    mapping(uint256 => ProposalComponent) public proposeItem;

    function propose(address[] memory targets, uint256[] memory values, bytes[] memory calldatas, string memory description) public override returns (uint256){
        uint256 proposalId = super.propose(targets, values, calldatas, description);
        _proposedList.push(proposalId);
        proposeItem[proposalId] = ProposalComponent({
            targets: targets,
            values: values,
            calldatas: calldatas,
            descriptionHash: keccak256(bytes(description))
        });
        return proposalId;
    }

    function getproposedList() external view returns (uint256[] memory) {
        return _proposedList;
    }

    function endVoteEarly(uint256 proposalId) public {
        ProposalState state = state(proposalId);
        require(state == ProposalState.Active, "Vote is not active");

        uint256 totalVotes = quorum(proposalSnapshot(proposalId));
        if(totalVotes > 1) {
            proposalEndedEarly[proposalId] = true;
        }
    }

    function Queue(uint256 proposalId) external returns (uint256) {
        ProposalComponent storage proposal = proposeItem[proposalId];
        return queue(proposal.targets, proposal.values, proposal.calldatas, proposal.descriptionHash);
    }
    function Execute(uint256 proposalId) external returns (uint256) {
        ProposalComponent storage proposal = proposeItem[proposalId];
        return execute(proposal.targets, proposal.values, proposal.calldatas, proposal.descriptionHash);
    }
    function Cancel(uint256 proposalId) external returns (uint256) {
        ProposalComponent storage proposal = proposeItem[proposalId];
        return cancel(proposal.targets, proposal.values, proposal.calldatas, proposal.descriptionHash);
    }
    // The following functions are overrides required by Solidity.

    function votingDelay()
        public
        view
        override(Governor, GovernorSettings)
        returns (uint256)
    {
        return GovernorSettings.votingDelay();
    }

    function votingPeriod()
        public
        view
        override(Governor, GovernorSettings)
        returns (uint256)
    {
        return GovernorSettings.votingPeriod();
    }

    function quorum(uint256 blockNumber)
        public
        view
        override(Governor, GovernorVotesQuorumFraction)
        returns (uint256)
    {
        return GovernorVotesQuorumFraction.quorum(blockNumber);
    }

    function state(uint256 proposalId)
        public
        view
        override(Governor, GovernorTimelockControl)
        returns (ProposalState)
    {
        if (proposalEndedEarly[proposalId]){
            return ProposalState.Succeeded;
        }
        return GovernorTimelockControl.state(proposalId);
    }

    function proposalNeedsQueuing(uint256 proposalId)
        public
        view
        override(Governor, GovernorTimelockControl)
        returns (bool)
    {
        return GovernorTimelockControl.proposalNeedsQueuing(proposalId);
    }

    function proposalThreshold()
        public
        view
        override(Governor, GovernorSettings)
        returns (uint256)
    {
        return GovernorSettings.proposalThreshold();
    }

    function _queueOperations(uint256 proposalId, address[] memory targets, uint256[] memory values, bytes[] memory calldatas, bytes32 descriptionHash)
        internal
        override(Governor, GovernorTimelockControl)
        returns (uint48)
    {
        return GovernorTimelockControl._queueOperations(proposalId, targets, values, calldatas, descriptionHash);
    }

    function _executeOperations(uint256 proposalId, address[] memory targets, uint256[] memory values, bytes[] memory calldatas, bytes32 descriptionHash)
        internal
        override(Governor, GovernorTimelockControl)
    {
        GovernorTimelockControl._executeOperations(proposalId, targets, values, calldatas, descriptionHash);
    }

    function _cancel(address[] memory targets, uint256[] memory values, bytes[] memory calldatas, bytes32 descriptionHash)
        internal
        override(Governor, GovernorTimelockControl)
        returns (uint256)
    {
        return GovernorTimelockControl._cancel(targets, values, calldatas, descriptionHash);
    }

    function _executor()
        internal
        view
        override(Governor, GovernorTimelockControl)
        returns (address)
    {
        return msg.sender;
        // return GovernorTimelockControl._executor();
    }
    function _checkGovernance() internal override {
        require(_executor()==msg.sender);
    }
}
