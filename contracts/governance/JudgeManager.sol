// SPDX-License-Identifier: MIT
pragma solidity ^0.8.27;

import "./IJudgeManager.sol";
import {JudgeManagerStorage} from "./JudgeManagerStorage.sol";
import "../reversible/ERC20R.sol";

contract JudgeManager is JudgeManagerStorage, IJudgeManager {
    constructor () {
        owner = msg.sender;
    }

    modifier onlyJudge() {
        if (!judges[msg.sender]) revert NotJudge();
        _;
    }

    function addJudge(address _judge) external override {
        if (msg.sender != owner) revert OnlyOwner();
        if (judges[_judge]) revert AlreadyJudge();
        judges[_judge] = true;
        judgeCount++;
        emit JudgeAdded(_judge);
    }

    function removeJudge(address _judge) external override {
        if (msg.sender == owner) revert OnlyOwner();
        if (!judges[_judge]) revert NotJudge();
        judges[_judge] = false;
        judgeCount--;
        emit JudgeRemoved(_judge);
    }

    function isJudge(address _account) external view override returns (bool) {
        return judges[_account];
    }

    function createDispute(
        address _token,
        uint256 _transferIndex,
        address _from,
        address _to
    ) external override returns (uint256) {
        disputeCount++;
        Dispute storage dispute = disputes[disputeCount];
        dispute.token = _token;
        dispute.transferIndex = _transferIndex;
        dispute.from = _from;
        dispute.to = _to;
        dispute.createdAt = block.timestamp;
        dispute.resolved = false;

        emit DisputeCreated(disputeCount, msg.sender, _token);
        return disputeCount;
    }

    function vote(uint256 _disputeId, bool _support) external override onlyJudge {
        Dispute storage dispute = disputes[_disputeId];
        
        if (dispute.resolved) revert DisputeAlreadyResolved();
        if (block.timestamp > dispute.createdAt + VOTING_PERIOD) revert VotingPeriodEnded();
        if (dispute.hasVoted[msg.sender]) revert AlreadyVoted();

        dispute.hasVoted[msg.sender] = true;
        dispute.votes[msg.sender] = _support;
        
        if (_support) {
            dispute.votesFor++;
        } else {
            dispute.votesAgainst++;
        }

        emit VoteCast(_disputeId, msg.sender, _support);
    }

    function executeDispute(uint256 _disputeId) external override {
        Dispute storage dispute = disputes[_disputeId];

        if (dispute.resolved) revert DisputeAlreadyResolved();
        bool result = dispute.votesFor > judgeCount / 2;
       
        if (!result && block.timestamp <= dispute.createdAt + VOTING_PERIOD) revert VotingPeriodNotEnded();

        if (result) {
            ERC20R(dispute.token).reverseTransaction(
                dispute.transferIndex,
                dispute.from,
                dispute.to
            );
        } else {
            ERC20R(dispute.token).rejectReverseTransaction(
                dispute.transferIndex,
                dispute.from,
                dispute.to
            );
        }

        emit DisputeResolved(_disputeId, result);
    }

    function getDisputeDetails(uint256 _disputeId) 
        external 
        view 
        override
        returns (
            address token,
            uint256 transferIndex,
            address from,
            address to,
            uint256 votesFor,
            uint256 votesAgainst,
            uint256 createdAt,
            bool resolved
        ) 
    {
        Dispute storage dispute = disputes[_disputeId];
        return (
            dispute.token,
            dispute.transferIndex,
            dispute.from,
            dispute.to,
            dispute.votesFor,
            dispute.votesAgainst,
            dispute.createdAt,
            dispute.resolved
        );
    }
}
