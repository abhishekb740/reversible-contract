// SPDX-License-Identifier: MIT
pragma solidity ^0.8.27;

contract ERC20RStorage {
    string public _name;
    string public _symbol;
    uint256 public _totalSupply;
    uint256 public lockPeriod;
    address public owner;
    address public platformWallet;
    uint256 public constant PLATFORM_FEE_BPS = 50; // 0.5%
    uint256 public constant JUDGE_FEE_BPS = 150; // 1.5%
    uint256 public constant BASIS_POINTS = 10000; // 100%

    error ZeroAddressNotAllowed();
    error InsufficientBalance();
    error InsufficientAllowance();
    error TokensStillLocked();
    error InvalidIndex();
    error TokensLocked();
    error OnlyOwnerAllowed();
    error FromAddressAndMsgSenderNotSame();
    error ToAddressAndMsgSenderNotSame();
    error OnlyJudgeManager();
    error DisputeAlreadyRaised();
    error TransactionNotFound();
    error OnlySenderCanRaiseDispute();
    error DisputeNotRaised();
    error DisputeRaised();
    error SenderAndAddressMustNotBeSame();

    struct TransactionDetails {
        uint256 amount;
        uint256 lockTime;
        address from;
        address to;
        uint256 index;
        bool fastWithdrawAllowed;
        bool isDispute;
    }

    struct UserDetails {
        uint256 RBalance;
        uint256 NRBalance;
    }

    event TokensUnlocked(
        address indexed account,
        uint256 amount,
        address indexed from
    );
    event TokensMinted(address indexed account, uint256 amount);
    event FastWithdrawAllowed(
        address indexed account,
        address indexed to,
        uint256 index
    );
    event LockPeriodChanged(uint256 newLockPeriod);
    event TransactionReversed(
        address indexed from,
        address indexed to,
        uint256 index,
        uint256 amount
    );
    event TransactionReverseRejected(
        address indexed from,
        address indexed to,
        uint256 index
    );
    event FeesDistributed(
        address indexed from,
        address indexed platformWallet,
        uint256 platformFee,
        uint256 judgeFee
    );
    event JudgeFeesDistributed(
        address[] judges,
        uint256 feePerJudge,
        uint256 totalAmount
    );

    mapping(address account => UserDetails userDetails) public userDetails;
    mapping(address account => mapping(address spender => uint256 allowance))
        public allowances;
    mapping(address from => mapping(address to => mapping(uint256 index => TransactionDetails lockedTransactions)))
        public lockedTransactions;
    mapping(address from => mapping(address to => uint256 index))
        public transferCount;
}
