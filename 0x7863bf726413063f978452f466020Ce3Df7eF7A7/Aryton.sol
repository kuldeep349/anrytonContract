// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/access/Ownable.sol";

contract Aryton is ERC20, Ownable {
    
    struct MintingSale {
        string name;
        uint160 supply;
        address walletAddress;
    }

    uint160 private constant MAX_TOTAL_SUPPLY = 400000000 ether;
    string private _latestSale = "FRIEND_FAMILY";
    uint8 public mintingCounter = 0;

    /** track wallet and supply assigned to a particular supply */
    mapping(string => address) private assignedWalletToSale;
    mapping(string => mapping(address => uint256)) private mintedWalletSupply;
    mapping(uint => MintingSale) public mintedSale;

    event MintedWalletSuupply(
        string indexed sale,
        uint256 indexed supply,
        address indexed walletAddress
    );

    constructor(
        string memory _tokenName,
        string memory _tokenSymbol
    ) ERC20(_tokenName, _tokenSymbol) Ownable(msg.sender) {
        _setCommissions(msg.sender);
    }

    function _setCommissions(address _owner) private {
        _calcSaleSupply(1, "FRIEND_FAMILY", _owner, 12000000 ether);
        _calcSaleSupply(2, "PRIVATE_SALE", _owner, 24000000 ether);
        _calcSaleSupply(3, "PUBLIC_SALE", _owner, 24000000 ether);
        _calcSaleSupply(4, "TEAM", _owner, 40000000 ether);
        _calcSaleSupply(5, "RESERVES", _owner, 100000000 ether);
        _calcSaleSupply(
            6,
            "STORAGE_MINTING_ALLOCATION",
            _owner,
            40000000 ether
        );
        _calcSaleSupply(7, "GRANTS_REWARD", _owner, 80000000 ether);
        _calcSaleSupply(8, "MARKETTING", _owner, 40000000 ether);
        _calcSaleSupply(9, "ADVISORS", _owner, 12000000 ether);
        _calcSaleSupply(
            10,
            "LIQUIDITY_EXCHANGE_LISTING",
            _owner,
            20000000 ether
        );
        _calcSaleSupply(11, "STAKING", _owner, 8000000 ether);

        /** mint once every partician is done
         * First sale will be get minted "FRIEND_FAMILY"
         */
        mint();
    }

    /***
     * @function _calcSaleSupply
     * @dev defining sales in a contract
     */
    function _calcSaleSupply(
        uint8 serial,
        string memory _name,
        address _walletAddress,
        uint160 _supply
    ) private {
        mintedSale[serial].name = _name;
        mintedSale[serial].supply = _supply;
        mintedSale[serial].walletAddress = _walletAddress;
    }

    /***
     * @function mintTokens
     * @dev mint token on a owner address
     * @notice onlyOwner can access this function
     */
    function mint() public onlyOwner {
        uint8 saleCount = ++mintingCounter;
        MintingSale memory mintingSale = mintedSale[saleCount];
        /** Validate amount and address should be greater than zero */
        require(
            mintingSale.supply > 0,
            "ERC20:: Mint amount should be greater than zero"
        );
        require(
            mintingSale.walletAddress != address(0),
            "ERC20:: user should not be equal to address zero"
        );

        /** Mint and set default sale supply */
        _mint(mintingSale.walletAddress, mintingSale.supply);
        _setSaleSupplyWallet(
            mintingSale.name,
            mintingSale.walletAddress,
            mintingSale.supply
        );
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