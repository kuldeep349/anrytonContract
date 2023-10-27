// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/access/Ownable.sol";

contract Aryton is ERC20, Ownable {
    uint160 private constant MAX_TOTAL_SUPPLY = 75000000 ether;
    string private _latestSale = "FRIEND_FAMILY";

    /** track wallet and supply assigned to a particular supply */
    mapping(string => address) private assignedWalletToSale;
    mapping(string => mapping(address => uint256)) private mintedWalletSupply;

    event MintedWalletSuupply(
        string indexed sale,
        uint256 indexed supply,
        address indexed walletAddress
    );

    constructor(
        string memory _tokenName,
        string memory _tokenSymbol,
        uint256 _supply
    ) ERC20(_tokenName, _tokenSymbol) Ownable(msg.sender) {
        mint(_latestSale, msg.sender, _supply);
    }

    /***
     * @function mintTokens
     * @dev mint token on a owner address
     * @notice onlyOwner can access this function
     */
    function mint(
        string memory saleName,
        address walletAddress,
        uint256 supply
    ) public onlyOwner {
        /** Validate amount and address should be greater than zero */
        require(supply > 0, "ERC20:: Mint amount should be greater than zero");
        require(
            walletAddress != address(0),
            "ERC20:: user should not be equal to address zero"
        );

        /** Calc pending supply */
        uint160 _pendingSupply = MAX_TOTAL_SUPPLY - uint160(totalSupply());
        require(
            supply < _pendingSupply,
            "ERC20:: Mint amount should not be greater than 75 million."
        );

        /** Mint and set default sale supply */
        _mint(walletAddress, supply);
        _setSaleSupplyWallet(saleName, walletAddress, supply);
    }

    /***
     * @function _defaultSupplyWallet
     * @dev persist user address attaches with sale name
     */
    function _setSaleSupplyWallet(
        string memory _saleName,
        address _walletAddress,
        uint256 _supply
    ) private {
        _latestSale = _saleName;
        assignedWalletToSale[_saleName] = _walletAddress;
        mintedWalletSupply[_saleName][_walletAddress] = _supply;
        emit MintedWalletSuupply(_saleName, _supply, _walletAddress);
    }

    /***
     * @function getPerSaleWalletSupply
     * @dev return minted supply on a assgined wallet to a sale.
     */
    function getAssignedWalletAndSupply(
        string memory saleName
    ) public view returns (uint256, address) {
        address walletAddress = assignedWalletToSale[saleName];
        uint256 mintedSupply = mintedWalletSupply[saleName][walletAddress];
        return (mintedSupply, walletAddress);
    }

    /***
     * @function getDefaultSale
     * @dev Get default sale name on other contracts
     */
    function getLatestSale() public view returns (string memory) {
        return _latestSale;
    }

    /***
     * @function getMaxSupply
     * @dev returns maxTotalSupply variable
     */
    function getMaxSupply() public pure returns (uint160) {
        return MAX_TOTAL_SUPPLY;
    }
}