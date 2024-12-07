// SPDX-License-Identifier: MIT
pragma solidity ^0.8.27;

import {IERC20} from "@openzeppelin/contracts/interfaces/IERC20.sol";
import {ERC20RStorage} from "./ERC20RStorage.sol";
import {IJudgeManager} from "../governance/IJudgeManager.sol";

contract ERC20R is ERC20RStorage, IERC20 {
    IJudgeManager public judgeManager;

    modifier onlyJudgeManager() {
        if (msg.sender != address(judgeManager)) revert ERC20RStorage.OnlyJudgeManager();
        _;
    }

    constructor(
        string memory _name, 
        string memory _symbol, 
        uint256 _lockPeriod, 
        address _judgeManager,
        address _platformWallet
    ) {
        ERC20RStorage.owner = msg.sender;
        ERC20RStorage._name = _name;
        ERC20RStorage.lockPeriod = _lockPeriod;
        ERC20RStorage._symbol = _symbol;
        judgeManager = IJudgeManager(_judgeManager);
        platformWallet = _platformWallet;
    }

    function transfer(address to, uint256 amount)
        public
        virtual
        override
        returns (bool)
    {   
        require(to != address(0), ERC20RStorage.ZeroAddressNotAllowed());
        require(balanceOf(msg.sender) >= amount, ERC20RStorage.InsufficientBalance());
        require(msg.sender!=to, ERC20RStorage.SenderAndAddressMustNotBeSame());
        
        userDetails[msg.sender].NRBalance -= amount;
        userDetails[to].RBalance += amount;

        uint256 transferIndex = ERC20RStorage.transferCount[msg.sender][to]++;

        ERC20RStorage.lockedTransactions[msg.sender][to][transferIndex] = TransactionDetails({
            amount: amount,
            lockTime: block.timestamp,
            from: msg.sender,
            to: to,
            index: transferIndex,
            fastWithdrawAllowed: false,
            isDispute: false
        });
        
        emit Transfer(msg.sender, to, amount);
        return true;
    }

    function totalSupply() public view override returns (uint256) {
        return _totalSupply;
    }

    function balanceOf(address account) public view override returns (uint256) {
        return userDetails[account].NRBalance;
    }

    function allowance(address owner, address spender) public view override returns (uint256) {
        return allowances[owner][spender];
    }

    function approve(address spender, uint256 amount) public override returns (bool) {
        require(spender != address(0), ERC20RStorage.ZeroAddressNotAllowed());
        allowances[msg.sender][spender] = amount;
        emit Approval(msg.sender, spender, amount);
        return true;
    }

    function transferFrom(address from, address to, uint256 amount) public override returns (bool) {
        require(to != address(0), ERC20RStorage.ZeroAddressNotAllowed());
        require(balanceOf(from) >= amount, ERC20RStorage.InsufficientBalance());
        require(allowance(from, msg.sender) >= amount, ERC20RStorage.InsufficientAllowance());
        
        allowances[from][msg.sender] -= amount;
        userDetails[from].NRBalance -= amount;
        userDetails[to].RBalance += amount;
        
        emit Transfer(from, to, amount);
        return true;
    }

    function getRBalance(address account) public view returns (uint256) {
        return userDetails[account].RBalance;
    }

    function withdrawLockedTokens(uint256 index, address from) public returns (bool) {
        UserDetails storage user = userDetails[msg.sender];
        TransactionDetails storage lockedTransaction = ERC20RStorage.lockedTransactions[from][msg.sender][index];
        require(msg.sender == lockedTransaction.to, ERC20RStorage.ToAddressAndMsgSenderNotSame());
        require(from == lockedTransaction.from, ERC20RStorage.FromAddressAndMsgSenderNotSame());
        require(index <= ERC20RStorage.transferCount[from][lockedTransaction.to], ERC20RStorage.InvalidIndex());
        require(lockedTransaction.amount > 0, ERC20RStorage.InsufficientBalance());
        require(lockedTransaction.isDispute==false, ERC20RStorage.DisputeRaised());
        require(block.timestamp > lockedTransaction.lockTime + lockPeriod || lockedTransaction.fastWithdrawAllowed, ERC20RStorage.TokensLocked());
        uint256 amountToUnlock = lockedTransaction.amount;
        user.RBalance -= amountToUnlock;
        user.NRBalance += amountToUnlock;
        lockedTransaction.amount = 0;
        emit TokensUnlocked(msg.sender, amountToUnlock, lockedTransaction.from);
        return true;
    }

    function fastWithdraw(uint256 index, address from, address to) public returns (bool) {
        require(from != address(0), ERC20RStorage.ZeroAddressNotAllowed());
        require(from==msg.sender, ERC20RStorage.FromAddressAndMsgSenderNotSame());
        TransactionDetails storage lockedTransaction = ERC20RStorage.lockedTransactions[msg.sender][to][index];
        require(to == lockedTransaction.to, ERC20RStorage.ToAddressAndMsgSenderNotSame());
        require(index <= ERC20RStorage.transferCount[msg.sender][to], ERC20RStorage.InvalidIndex());
        lockedTransaction.fastWithdrawAllowed = true;
        emit FastWithdrawAllowed(msg.sender, to, index);
        return true;
    }

    function getTransferCount(address from, address to) 
        public 
        view 
        returns (uint256) 
    {
        return ERC20RStorage.transferCount[from][to];
    }

    function mint(address to, uint256 amount) public returns (bool) {
        require(to != address(0), ERC20RStorage.ZeroAddressNotAllowed());
        _totalSupply += amount;
        userDetails[to].NRBalance += amount;
        emit TokensMinted(to, amount);
        return true;
    }

    function changeLockPeriod(uint256 newLockPeriod) public returns (bool) {
        require(msg.sender == ERC20RStorage.owner, ERC20RStorage.OnlyOwnerAllowed());
        lockPeriod = newLockPeriod;
        emit ERC20RStorage.LockPeriodChanged(newLockPeriod);
        return true;
    }

    function raiseDispute(uint256 index, address from, address to) public returns (uint256) {
        TransactionDetails storage transaction = lockedTransactions[from][to][index];
        if (transaction.amount == 0) revert ERC20RStorage.TransactionNotFound();
        if (msg.sender != from) revert ERC20RStorage.OnlySenderCanRaiseDispute();
        if (transaction.isDispute) revert ERC20RStorage.DisputeAlreadyRaised();

        transaction.isDispute = true;
        return judgeManager.createDispute(address(this), index, from, to);
    }

    function reverseTransaction(uint256 index, address from, address to) public onlyJudgeManager returns (bool) {
        TransactionDetails storage transaction = lockedTransactions[from][to][index];
        if (transaction.amount == 0) revert ERC20RStorage.TransactionNotFound();
        if (!transaction.isDispute) revert ERC20RStorage.DisputeNotRaised();
        
        uint256 amountToReverse = transaction.amount;
        
        // Calculate fees
        uint256 platformFee = (amountToReverse * PLATFORM_FEE_BPS) / BASIS_POINTS;
        uint256 judgeFee = (amountToReverse * JUDGE_FEE_BPS) / BASIS_POINTS;
        uint256 amountAfterFees = amountToReverse - platformFee - judgeFee;
    
        // Update balances
        userDetails[to].RBalance -= amountToReverse;
        userDetails[from].NRBalance += amountAfterFees;
        userDetails[platformWallet].NRBalance += platformFee + judgeFee;  // Temporarily store all fees
        
        delete lockedTransactions[from][to][index];
        
        // Get human judges from JudgeManager and distribute fees
        address[] memory humanJudges = judgeManager.getHumanJudgesForDispute(index);
        if (humanJudges.length > 0) {
            uint256 feePerJudge = judgeFee / humanJudges.length;
            
            // Distribute fees to human judges
            for(uint256 i = 0; i < humanJudges.length; i++) {
                userDetails[platformWallet].NRBalance -= feePerJudge;
                userDetails[humanJudges[i]].NRBalance += feePerJudge;
            }
            
            // Handle any remaining dust
            uint256 remainingFees = judgeFee - (feePerJudge * humanJudges.length);
            if (remainingFees > 0) {
                userDetails[platformWallet].NRBalance -= remainingFees;
                userDetails[humanJudges[0]].NRBalance += remainingFees;
            }
            
            emit JudgeFeesDistributed(humanJudges, feePerJudge, judgeFee);
        }
        
        emit TransactionReversed(from, to, index, amountToReverse);
        emit FeesDistributed(from, platformWallet, platformFee, judgeFee);
        return true;
    }

    function rejectReverseTransaction(uint256 index, address from, address to) public onlyJudgeManager returns (bool) {
        TransactionDetails storage transaction = lockedTransactions[from][to][index];
        if (transaction.amount == 0) revert ERC20RStorage.TransactionNotFound();
        if (!transaction.isDispute) revert ERC20RStorage.DisputeNotRaised();
        
        transaction.isDispute = false;
        uint256 amount = transaction.amount;
        userDetails[to].RBalance -= amount;
        userDetails[to].NRBalance += amount;
        
        emit ERC20RStorage.TransactionReverseRejected(from, to, index);
        return true;
    }

    function distributeJudgeFees(address[] calldata humanJudges, uint256 totalFeeAmount) public returns (bool) {
        require(msg.sender == platformWallet, "Only platform wallet can distribute fees");
        require(humanJudges.length > 0, "No judges provided");
        require(userDetails[platformWallet].NRBalance >= totalFeeAmount, "Insufficient fee balance");
        
        uint256 feePerJudge = totalFeeAmount / humanJudges.length;
        require(feePerJudge > 0, "Fee per judge too small");
        
        // Distribute fees equally among judges
        for(uint256 i = 0; i < humanJudges.length; i++) {
            require(humanJudges[i] != address(0), "Invalid judge address");
            userDetails[platformWallet].NRBalance -= feePerJudge;
            userDetails[humanJudges[i]].NRBalance += feePerJudge;
        }
        
        // Handle any remaining dust (due to division)
        uint256 remainingFees = totalFeeAmount - (feePerJudge * humanJudges.length);
        if (remainingFees > 0) {
            userDetails[platformWallet].NRBalance -= remainingFees;
            userDetails[humanJudges[0]].NRBalance += remainingFees;
        }
        
        emit ERC20RStorage.JudgeFeesDistributed(humanJudges, feePerJudge, totalFeeAmount);
        return true;
    }
}
