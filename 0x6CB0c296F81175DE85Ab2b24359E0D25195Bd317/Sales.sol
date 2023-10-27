// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "./IAnryton.sol";
import "@openzeppelin/contracts/access/Ownable.sol";

contract Sales is Ownable {
    uint256 private saleCounter = 0;

    struct Sale {
        string name;
        uint160 supply;
        address walletAddress;
        uint256 startAt;
    }

    IAnryton immutable public token;

    mapping(string => uint256) public saleId;
    mapping(uint256 => Sale) public saleInfo;

    event SaleInfo(
        uint256 saleId,
        string indexed name,
        uint256 indexed startAt
    );

    constructor(address _token) Ownable(msg.sender) {
        token = IAnryton(_token);
        _defaultSale();
    }

    /***
     * @function _defaultSale
     * @dev start "Friend & Family" sale at the time of deoloy
     */
    function _defaultSale() private {
        startSale();
    }

    /***
     * @function startSale
     * @dev starting sale PUBLIC or PRIVATE
     * @notice only by owner
     */
    function startSale() public onlyOwner {
        uint256 _currentTime = block.timestamp;
        uint256 _count = ++saleCounter;
        (
            string memory _saleName,
            uint256 _supply,
            address _walletAddress
        ) = getLatestMintedSale();
        /** add sale based on count number */
        _addSale(_count, _saleName, _supply, _walletAddress, _currentTime);
    }

    function _addSale(
        uint256 _count,
        string memory _saleName,
        uint256 _supply,
        address _walletAddress,
        uint256 _currentTime
    ) private {
        saleInfo[_count].name = _saleName;
        saleInfo[_count].supply = uint160(_supply);
        saleInfo[_count].walletAddress = _walletAddress;
        saleInfo[_count].startAt = _currentTime;
        saleId[_saleName] = _count;
        emit SaleInfo(_count, _saleName, _currentTime);
    }

    /***
     * @function getLatestMintedSale
     * @dev Latest minted sale on ERC20 contract, ONLY READ
     */
    function getLatestMintedSale()
        public
        view
        returns (string memory, uint256, address)
    {
        string memory _saleName = token.getLatestSale();
        (uint256 _supply, address _walletAddress) = token
            .getAssignedWalletAndSupply(_saleName);
        return (_saleName, _supply, _walletAddress);
    }

    /***
     * @function getCurrentSaleCount
     * @dev Returning latest count of sale counter
     */
    function getLatestSaleCount() public view returns (uint256) {
        return saleCounter;
    }
}