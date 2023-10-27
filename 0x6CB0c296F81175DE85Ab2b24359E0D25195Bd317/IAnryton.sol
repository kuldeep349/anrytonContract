// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";

interface IAnryton is IERC20 {
    function getAssignedWalletAndSupply(string memory _saleName) external view returns (uint256, address);
    function getMaxSupply() external view returns (uint64);
    function getLatestSale() external view returns (string memory);
}