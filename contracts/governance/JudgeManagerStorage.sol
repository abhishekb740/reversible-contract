// SPDX-License-Identifier: MIT
pragma solidity ^0.8.27;

abstract contract JudgeManagerStorage {

    address public owner;

    struct Dispute {
        address token;
        uint256 transferIndex;
        address from;
        address to;
        uint256 votesFor;
        uint256 votesAgainst;
        uint256 createdAt;
        bool resolved;
        mapping(address => bool) hasVoted;
        mapping(address => bool) votes;
    }

    mapping(address => bool) public judges;
    uint256 public judgeCount;
    mapping(uint256 => Dispute) public disputes;
    uint256 public disputeCount;
    uint256 public constant VOTING_PERIOD =  5 minutes;

    event JudgeAdded(address indexed judge);
    event JudgeRemoved(address indexed judge);
    event DisputeCreated(uint256 indexed disputeId, address indexed creator, address indexed token);
    event VoteCast(uint256 indexed disputeId, address indexed judge, bool vote);
    event DisputeResolved(uint256 indexed disputeId, bool result);

    error AlreadyJudge();
    error NotJudge();
    error DisputeNotExists();
    error DisputeAlreadyResolved();
    error VotingPeriodEnded();
    error VotingPeriodNotEnded();
    error AlreadyVoted();
    error InvalidVotingPeriod();
    error OnlyOwner();
}