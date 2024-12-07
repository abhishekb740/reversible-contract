// SPDX-License-Identifier: MIT
pragma solidity ^0.8.27;

interface IJudgeManager {
    enum DisputeState {
        PENDING,
        PASS,
        FAIL
    }

    function addJudge(address _judge) external;
    function removeJudge(address _judge) external;
    function isJudge(address _account) external view returns (bool);
    
    function createDispute(
        address _token,
        uint256 _transferIndex,
        address _from,
        address _to
    ) external returns (uint256);
    
    function voteAndResolve(uint256 _disputeId, DisputeState _vote) external;
    
    function getDisputeDetails(uint256 _disputeId) 
        external 
        view 
        returns (
            address token,
            uint256 transferIndex,
            address from,
            address to,
            uint256 votesFor,
            uint256 votesAgainst,
            uint256 createdAt,
            DisputeState state
        );
}
