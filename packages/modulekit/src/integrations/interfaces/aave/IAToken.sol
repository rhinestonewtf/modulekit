// SPDX-License-Identifier: MIT

pragma solidity ^0.8.10;

abstract contract IAToken {
    function redeem(uint256 _amount) external virtual;
    function balanceOf(address _owner) external view virtual returns (uint256 balance);
    function UNDERLYING_ASSET_ADDRESS() external view virtual returns (address);
}
