// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "./Sales.sol";
import "@openzeppelin/contracts/utils/ReentrancyGuard.sol";

contract Stake is Sales, ReentrancyGuard {
    struct Staking {
        uint232 stakeAmount;
        uint160 unStakedAmount;
        uint256 stakedAt;
        bool isUnstaked;
    }

    struct Locking {
        uint248 lockedAmount;
        uint256 lockedAt;
        uint256 unLockedAt;
        bool isUnlocked;
    }

    struct Deposit {
        uint208 depositAmount;
        uint208 withdrawAmount;
        uint256 depositedAt;
        string sale;
        bool isMatured;
    }

    struct UserInfo {
        uint184 tokenBalance;
        uint184 withdrawTokens;
        uint128 stakedTokens;
        uint128 lockedTokens;
        uint48 totalStakes;
        uint48 totalLocks;
        uint48 totalDeposits;
    }

    /** always multiply with 10 to ignore decials in smart contract */
    uint16 public stakingPercentage = 100;

    /*** @dev finances for getting all info related to user total invested amount */
    mapping(address => UserInfo) public users;
    mapping(address => mapping(uint => Staking)) public stakings;
    mapping(address => mapping(uint => Locking)) public lockings;
    mapping(address => mapping(uint => Deposit)) public deposits;

    event StakePercentage(uint8 indexed percentage, address indexed changedBy);
    event DepositWithdraw(
        address indexed user,
        uint256 indexed amount,
        string indexed action
    );
    event WhitelistTeamFriends(address indexed user, string indexed role);
    event StakedTokens(
        address indexed user,
        uint256 indexed amount,
        uint256 indexed serialNo
    );
    event LockedTokens(
        address indexed user,
        uint256 indexed amount,
        uint256 indexed serialNo
    );

    /*** @dev require to check amount should be greater than zero */
    modifier amountZero(uint256 _amount) {
        require(_amount > 0, "STAKE:: amount should be greater than zero.");
        _;
    }

    /** @dev check if user adress is zero or not */
    modifier addressZero(address _user) {
        require(
            _user != address(0),
            "STAKE:: user should not be equal to address zero"
        );
        _;
    }

    /** @dev Initialising or deploying smart contract */
    constructor(address _token) Sales(_token) {}

    /***
     * @function deposit
     * @dev deposit ERC20 token amount to contract
     * @notice update balance and transfer token from user account to this contract
     */
    function deposit(
        address user,
        uint208 tokenAmount
    ) public nonReentrant returns (bool) {
        _updateTokenBalance(user, tokenAmount, "DEPOSIT");
        bool isTransferred = token.transferFrom(
            msg.sender,
            address(this),
            tokenAmount
        );
        return isTransferred;
    }

    /***
     * @function withdraw
     * @dev deposit ERC20 token amount to contract
     * @notice update balance after withdraw, send token to user account
     */
    function withdraw() public returns (bool) {
        uint256 currentTime = block.timestamp;
        uint256 _maturedAmt = 0;
        uint256 _releasedAmt = 0;

        for (uint256 m = 7; m <= 42; m++) {
            uint256 _withdrawnAmt = 0;

            for (uint256 i = 1; i <= users[msg.sender].totalDeposits; i++) {
                Deposit memory userDeposit = deposits[msg.sender][i];
                if (!userDeposit.isMatured) {
                    (uint256 _vestedAmt, bool _isMatured) = _vesting(
                        m,
                        currentTime,
                        userDeposit
                    );

                    if (_vestedAmt > 0) {
                        _maturedAmt += _vestedAmt;
                        _withdrawnAmt += userDeposit.withdrawAmount;
                        deposits[msg.sender][i].withdrawAmount += uint160(
                            _vestedAmt
                        );
                        if (_isMatured)
                            deposits[msg.sender][i].isMatured = true;
                    }
                }
            }

            if (_withdrawnAmt > 0) _releasedAmt = _withdrawnAmt;
        }

        _maturedAmt -= _releasedAmt;
        if (_maturedAmt <= 0)
            revert("STAKE:: there is no funds to be transferred.");
        _updateTokenBalance(msg.sender, uint160(_maturedAmt), "WITHDRAW");
        bool isTransferred = token.transfer(msg.sender, _maturedAmt);
        return isTransferred;
    }

    /***
     * @function updateTokenBalance
     * @dev update user token balance, scope (private)
     */
    function _updateTokenBalance(
        address _user,
        uint208 _amount,
        string memory _action
    ) private amountZero(_amount) addressZero(_user) {
        uint256 balance = users[_user].tokenBalance;
        if (_compareEqual(_action, "DEPOSIT")) {
            balance += _amount;
            _deposti(_user, _amount);
        } else if (_compareEqual(_action, "WITHDRAW")) {
            balance -= _amount;
            users[_user].withdrawTokens += uint184(_amount);
        }

        users[_user].tokenBalance = uint184(balance);
        emit DepositWithdraw(_user, _amount, _action);
    }

    /***
     * @function _deposit
     * @dev adding info of each time deposit
     */
    function _deposti(address _user, uint208 _amount) private {
        uint256 _latestSale = getLatestSaleCount();
        uint48 _count = ++users[_user].totalDeposits;
        deposits[_user][_count].depositAmount = _amount;
        deposits[_user][_count].depositedAt = block.timestamp;
        deposits[_user][_count].sale = saleInfo[_latestSale].name;
    }

    /***
     * @function stakeTokens
     * @dev Staking token if deposited by a user
     * @notice adding modifiers to check amount should be greater than zero
     */
    function stakeOrLockTokens(
        address to,
        uint232 tokenAmount,
        string memory stakeOrLockType
    )
        public
        amountZero(tokenAmount)
        addressZero(to)
        nonReentrant
        returns (bool)
    {
        uint256 currentTime = block.timestamp;
        /** check if type is LOCK or STAKE */
        if (_compareEqual(stakeOrLockType, "STAKE")) {
            users[to].stakedTokens += uint128(tokenAmount);
            return _stakeTokens(msg.sender, to, tokenAmount, currentTime);
        } else if (_compareEqual(stakeOrLockType, "LOCK")) {
            users[to].lockedTokens += uint128(tokenAmount);
            return _lockTokens(msg.sender, to, tokenAmount, currentTime);
        } else {
            revert("STAKE:: type should be 'LOCK' or 'STAKE'");
        }
    }

    /***
     * @function _stakedTokens
     * @dev called by stakedAmount function
     * @notice scope private
     */
    function _stakeTokens(
        address _from,
        address _to,
        uint232 _amount,
        uint256 _currentTime
    ) private returns (bool) {
        uint48 _count = ++users[_to].totalStakes;
        /** set stakedAt, unStakedAt time and amount */
        stakings[_to][_count].stakedAt = _currentTime;
        stakings[_to][_count].stakeAmount = _amount;
        /** emit information in StakedTokens event */
        emit StakedTokens(_to, _amount, _count);
        bool isTransferred = token.transferFrom(_from, address(this), _amount);
        return isTransferred;
    }

    /***
     * @function _lockedTokens
     * @dev locking tokens of a particular user for a limit of time
     * @notice scope is private
     */
    function _lockTokens(
        address _from,
        address _to,
        uint232 _amount,
        uint256 _currentTime
    ) private returns (bool) {
        uint48 _count = ++users[msg.sender].totalLocks;
        /** set stakedAt, unStakedAt time and amount */
        lockings[_to][_count].lockedAt = _currentTime;
        lockings[_to][_count].unLockedAt = _currentTime + 2 seconds;
        lockings[_to][_count].lockedAmount = uint248(_amount);
        /** emit information in StakedTokens event */
        emit LockedTokens(_to, _amount, _count);
        bool isTransferred = token.transferFrom(_from, address(this), _amount);
        return isTransferred;
    }

    /***
     * @function unStakeTokens
     * @dev unStake or unLock tokens on a particular ID
     */
    function unStakeOrUnLock(
        string memory stakeOrLock
    ) public nonReentrant returns (bool) {
        uint256 currentTime = block.timestamp;
        if (_compareEqual(stakeOrLock, "UN_STAKE")) {
            return _unStakeTokens(msg.sender, currentTime);
        } else if (_compareEqual(stakeOrLock, "UN_LOCK")) {
            return _unLockTokens(msg.sender, currentTime);
        } else {
            revert("STAKE:: type should be 'UN_LOCK' or 'UN_STAKE'");
        }
    }

    /***
     * @function _unStakeTokens
     * @dev unStaked tokens on a particular id
     * @notice this can be called publically as it is private
     */
    function _unStakeTokens(
        address _user,
        uint256 _currentTime
    ) private returns (bool) {
        uint256 _maturedAmt = 0;
        uint256 _withdrawnAmt = 0;

        for (uint256 m = 13; m <= 18; m++) {
            _withdrawnAmt = 0;
            for (uint256 i = 1; i <= users[_user].totalStakes; i++) {
                Staking memory userStaking = stakings[_user][i];
                if (!userStaking.isUnstaked) {
                    uint256 releasedAmt = _getMaturedStakeAmt(
                        m,
                        _currentTime,
                        userStaking
                    );

                    if (releasedAmt > 0) {
                        uint256 profit = mulDiv(
                            releasedAmt,
                            stakingPercentage,
                            1000
                        );

                        releasedAmt += profit;
                        stakings[_user][i].unStakedAmount += uint160(
                            releasedAmt
                        );
                        if (m == 18) stakings[_user][i].isUnstaked = true;
                        _maturedAmt += releasedAmt;
                        _withdrawnAmt += userStaking.unStakedAmount;
                    }
                }
            }
        }

        _maturedAmt -= _withdrawnAmt;
        if (_maturedAmt == 0)
            revert("STAKE:: there is no token to be un-stake");
        bool isTransferred = token.transfer(_user, _maturedAmt);
        return isTransferred;
    }

    /***
     * @function _unLockTokens
     * @dev unLocked all tokens on particular Id
     * @notice this can be called publically as it is private
     */
    function _unLockTokens(
        address _user,
        uint256 _currentTime
    ) private returns (bool) {
        uint256 _maturedAmt = 0;

        for (uint i = 1; i <= users[_user].totalLocks; i++) {
            Locking memory _locked = lockings[msg.sender][i];
            /** get current time to verify with unStakedAt */
            if (!_locked.isUnlocked) {
                if (_currentTime > _locked.unLockedAt) {
                    _maturedAmt += _locked.lockedAmount;
                    lockings[_user][i].isUnlocked = true;
                }
            }
        }

        if (_maturedAmt == 0)
            revert("STAKE: there is no amount to be transferred.");
        bool isTransferred = token.transfer(_user, _maturedAmt);
        return isTransferred;
    }

    /***
     * @function getMaturedStakedAmt
     * @dev get total matured balance after staking
     */
    function getMaturedStakedAmt(address user) public view returns (uint256) {
        uint256 maturedAmt = 0;
        uint256 withdrawnAmt = 0;
        uint256 currentTime = block.timestamp;

        for (uint256 m = 13; m <= 18; m++) {
            withdrawnAmt = 0;

            for (uint256 i = 1; i <= users[user].totalStakes; i++) {
                Staking memory userStaking = stakings[user][i];
                uint256 releasedAmt = _getMaturedStakeAmt(
                    m,
                    currentTime,
                    userStaking
                );

                if (releasedAmt > 0) {
                    uint256 profit = mulDiv(
                        releasedAmt,
                        stakingPercentage,
                        1000
                    );
                    releasedAmt += profit;
                    maturedAmt += releasedAmt;
                    withdrawnAmt += userStaking.unStakedAmount;
                }
            }
        }

        maturedAmt -= withdrawnAmt;
        return maturedAmt;
    }

    /***
     * @function _getMaturedStakeAmt
     * @dev get single stake value calling func in a loop
     */
    function _getMaturedStakeAmt(
        uint256 m,
        uint256 currentTime,
        Staking memory userStaking
    ) private pure returns (uint256) {
        uint256 _amount = 0;
        /** 5 sec === 1 month */
        uint256 endTime = userStaking.stakedAt + (m * 5);

        if (currentTime > endTime) {
            uint256 unStakePerMonth = userStaking.stakeAmount / 6;
            _amount += unStakePerMonth;
        }

        return _amount;
    }

    /***
     * @function changeStakePercentage
     * @dev change percentage of staking profit (always multiply by 10 before call this func)
     */
    function changeStakePercentage(
        uint8 percentage
    ) public amountZero(percentage) onlyOwner {
        stakingPercentage = percentage;
        emit StakePercentage(percentage, msg.sender);
    }

    /***
     * @function compareStrings
     * @dev comparing two string with bytes length
     */
    function _compareEqual(
        string memory a,
        string memory b
    ) private pure returns (bool) {
        return (bytes(a).length == bytes(b).length);
    }

    /***
     * @function getLeftBalance
     * @dev get left amount after staked or locked amount
     * @notice publically readable
     */
    function getLeftBalance(address user) public view returns (uint) {
        UserInfo memory finance = users[user];
        /** get total staked and locked tokens and add them to deduct from tokenBalance */
        uint256 balance = finance.stakedTokens + finance.lockedTokens;
        balance = finance.tokenBalance - balance;
        return balance;
    }

    /***
     * @function vesting
     * @dev getting info all the vesting data
     */
    function vesting(address user) public view returns (uint256) {
        uint256 currentTime = block.timestamp;
        uint256 maturedAmt = 0;
        uint256 releasedAmt = 0;

        for (uint256 m = 7; m <= 42; m++) {
            uint256 withdrawnAmt = 0;

            for (uint256 i = 1; i <= users[user].totalDeposits; i++) {
                Deposit memory userDeposit = deposits[user][i];
                if (!userDeposit.isMatured) {
                    (uint256 _vestedAmt, ) = _vesting(
                        m,
                        currentTime,
                        userDeposit
                    );
                    if (_vestedAmt > 0) {
                        maturedAmt += _vestedAmt;
                        withdrawnAmt += userDeposit.withdrawAmount;
                    }
                }
            }

            if (withdrawnAmt > 0) releasedAmt = withdrawnAmt;
        }

        maturedAmt -= releasedAmt;
        return maturedAmt;
    }

    /***
     * @function _vesting
     * @dev get info of single deposit in a loop
     */
    function _vesting(
        uint256 _m,
        uint256 _currentTime,
        Deposit memory _userDeposit
    ) private pure returns (uint256, bool) {
        uint256 _amount = 0;
        uint256 _tgcAmount = 0;
        bool _isMatured = false;

        /** cliff calculation */
        if (_m == 7) {
            _tgcAmount = _calcTgcAmount(_userDeposit, _currentTime);
            _amount += _tgcAmount;
        }

        uint256 endTime = _userDeposit.depositedAt + (_m * 5);
        // uint256 endTime = userDeposit.depositedAt + (m * 30 * 24 * 60 * 60);
        if (_currentTime > endTime) {
            _userDeposit.depositAmount -= uint160(_tgcAmount);

            /** check if sale is "PUBLIC_SALE" OR "PRIVATE_SALE" */
            if (
                _compareEqual(_userDeposit.sale, "FAMILY_FRIEND") ||
                _compareEqual(_userDeposit.sale, "PRIVATE_SALE") ||
                _compareEqual(_userDeposit.sale, "PUBLIC_SALE")
            ) {
                if (_m == 18) _isMatured = true;
                if ((_m >= 7) && (_m <= 18))
                    _amount += _userDeposit.depositAmount / 12;
            }

            /** check if sale is "TEAM" OR "ADVISORS" */
            if (
                _compareEqual(_userDeposit.sale, "TEAM") ||
                _compareEqual(_userDeposit.sale, "ADVISORS")
            ) {
                if (_m == 36) _isMatured = true;
                if ((_m >= 13) && (_m <= 36))
                    _amount += _userDeposit.depositAmount / 24;
            }

            /** check if sale is "RESERVES" OR "STORAGE_MINTING_ALLOCATION" */
            if (
                _compareEqual(_userDeposit.sale, "RESERVES") ||
                _compareEqual(_userDeposit.sale, "STORAGE_MINTING_ALLOCATION")
            ) {
                if (_m == 36) _isMatured = true;
                if ((_m >= 25) && (_m <= 36))
                    _amount += _userDeposit.depositAmount / 12;
            }

            /** Getting value for MARKETTING */
            if (_compareEqual(_userDeposit.sale, "MARKETTING")) {
                if (_m == 42) _isMatured = true;
                _amount += _calcMarketting(_m, _userDeposit.depositAmount);
            }
        }

        return (_amount, _isMatured);
    }

    /***
     * @function _calcTgcAmount
     * @dev Calculate TGC amount of PUBLIC_SALE
     */
    function _calcTgcAmount(
        Deposit memory _userDeposit,
        uint256 _currentTime
    ) private pure returns (uint256) {
        uint256 _tgcAmount = 0;
        /** Only for Public Sale which is given after two days  */
        if (_compareEqual(_userDeposit.sale, "PUBLIC_SALE")) {
            uint256 tgcTime = _userDeposit.depositedAt + 4 seconds;
            if (_currentTime > tgcTime)
                _tgcAmount = mulDiv(_userDeposit.depositAmount, 20, 100);
        }

        return _tgcAmount;
    }

    /***
     * @function _calcMarketting
     * @dev calculate marketting value
     */
    function _calcMarketting(
        uint256 _m,
        uint208 _depositedAmt
    ) private pure returns (uint256) {
        uint _amount = 0;
        uint8 age = 0;
        if (_m > 18) age = 1;
        else if (_m > 24) age = 2;
        else if (_m > 30) age = 3;
        else if (_m > 36) age = 4;
        else if (_m == 42) age = 5;

        if (age > 0) {
            _amount = mulDiv(_depositedAmt, 20, 100);
            _amount = _amount * age;
        }

        return _amount;
    }

    /***
     * @function mulDiv
     */
    function mulDiv(
        uint256 value,
        uint256 percentage,
        uint256 denominator
    ) public pure returns (uint256) {
        return (value * percentage) / denominator;
    }
}