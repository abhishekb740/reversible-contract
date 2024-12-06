// SPDX-License-Identifier: MIT
pragma solidity ^0.8.27;

interface IJudgeManager {
    function addJudge(address _judge) external;
    function removeJudge(address _judge) external;
    function isJudge(address _account) external view returns (bool);
    
    function createDispute(
        address _token,
        uint256 _transferIndex,
        address _from,
        address _to
    ) external returns (uint256);
    
    function vote(uint256 _disputeId, bool _support) external;
    function executeDispute(uint256 _disputeId) external;
    
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
            bool resolved
        );
}
