// SPDX-License-Identifier: MIT
pragma solidity ^0.8.27;

import "./IJudgeManager.sol";
import {JudgeManagerStorage} from "./JudgeManagerStorage.sol";
import "../reversible/ERC20R.sol";

contract JudgeManager is JudgeManagerStorage, IJudgeManager {
    constructor() {
        owner = msg.sender;
    }

    modifier onlyJudge() {
        if (!judges[msg.sender]) revert NotJudge();
        _;
    }

    function addJudge(address _judge, bool _isHuman) external override {
        if (msg.sender != owner) revert OnlyOwner();
        if (judges[_judge]) revert AlreadyJudge();
        
        judges[_judge] = true;
        isHumanJudge[_judge] = _isHuman;
        judgeCount++;
        judgeList.push(_judge);
        
        emit JudgeAdded(_judge);
    }

    function removeJudge(address _judge) external override {
        if (msg.sender != owner) revert OnlyOwner();
        if (!judges[_judge]) revert NotJudge();
        
        judges[_judge] = false;
        isHumanJudge[_judge] = false;
        judgeCount--;
        
        // Remove from judgeList (optional, but gas intensive)
        for (uint256 i = 0; i < judgeList.length; i++) {
            if (judgeList[i] == _judge) {
                judgeList[i] = judgeList[judgeList.length - 1];
                judgeList.pop();
                break;
            }
        }
        
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
        dispute.state = DisputeState.PENDING;

        emit DisputeCreated(disputeCount, msg.sender, _token);
        return disputeCount;
    }

    function voteAndResolve(
        uint256 _disputeId,
        DisputeState _vote
    ) external override onlyJudge {
        Dispute storage dispute = disputes[_disputeId];

        // Check if dispute exists
        if (_disputeId == 0 || _disputeId > disputeCount)
            revert DisputeNotExists();
        // Check if dispute is not pending
        if (dispute.state != DisputeState.PENDING)
            revert DisputeAlreadyResolved();

        // Check if judge has already voted
        if (dispute.hasVoted[msg.sender]) revert AlreadyVoted();

        // Ensure vote is valid (not PENDING)
        if (_vote == DisputeState.PENDING) revert("Invalid vote type");

        // Record the vote
        dispute.hasVoted[msg.sender] = true;
        dispute.votes[msg.sender] = _vote;

        // Update vote counts
        if (_vote == DisputeState.PASS) {
            dispute.votesFor++;
        } else if (_vote == DisputeState.FAIL) {
            dispute.votesAgainst++;
        }

        emit VoteCast(_disputeId, msg.sender, _vote == DisputeState.PASS);

        bool isVotingPeriodOver = block.timestamp >
            dispute.createdAt + VOTING_PERIOD;

        // During voting period - check for immediate majority
        if (!isVotingPeriodOver) {
            // Case 1: More than 50% judges voted PASS
            if (dispute.votesFor > judgeCount / 2) {
                dispute.state = DisputeState.PASS;
                ERC20R(dispute.token).reverseTransaction(
                    dispute.transferIndex,
                    dispute.from,
                    dispute.to
                );
                emit DisputeResolved(_disputeId, true);
                return;
            }
            // Case 2: More than 50% judges voted FAIL
            if (dispute.votesAgainst > judgeCount / 2) {
                dispute.state = DisputeState.FAIL;
                ERC20R(dispute.token).rejectReverseTransaction(
                    dispute.transferIndex,
                    dispute.from,
                    dispute.to
                );
                emit DisputeResolved(_disputeId, false);
                return;
            }
        }

        // After voting period ends
        if (isVotingPeriodOver) {
            if (dispute.votesFor > dispute.votesAgainst) {
                dispute.state = DisputeState.PASS;
                ERC20R(dispute.token).reverseTransaction(
                    dispute.transferIndex,
                    dispute.from,
                    dispute.to
                );
                emit DisputeResolved(_disputeId, true);
            } else {
                dispute.state = DisputeState.FAIL;
                ERC20R(dispute.token).rejectReverseTransaction(
                    dispute.transferIndex,
                    dispute.from,
                    dispute.to
                );
                emit DisputeResolved(_disputeId, false);
            }
        }
    }

    function getDisputeDetails(
        uint256 _disputeId
    )
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
            DisputeState state
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
            dispute.state
        );
    }

    function getDisputeCount() public view returns (uint256) {
        return disputeCount;
    }
    
    function getHumanJudgesForDispute(uint256 _disputeId) external view returns (address[] memory) {
        Dispute storage dispute = disputes[_disputeId];
        
        // First, count how many human judges voted
        uint256 humanJudgeCount = 0;
        address[] memory tempJudges = new address[](judgeCount);
        
        // Iterate through all judges to find human judges who voted
        for (uint256 i = 0; i < judgeCount; i++) {
            address judge = getJudgeAtIndex(i);  // You'll need to implement this
            if (dispute.hasVoted[judge] && isHumanJudge[judge]) {
                tempJudges[humanJudgeCount] = judge;
                humanJudgeCount++;
            }
        }
        
        address[] memory humanJudges = new address[](humanJudgeCount);
        for (uint256 i = 0; i < humanJudgeCount; i++) {
            humanJudges[i] = tempJudges[i];
        }
        
        return humanJudges;
    }

    function getJudgeAtIndex(uint256 index) public view returns (address) {
        require(index < judgeList.length, "Index out of bounds");
        return judgeList[index];
    }
}
