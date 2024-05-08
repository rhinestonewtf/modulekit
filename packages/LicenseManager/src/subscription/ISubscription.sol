// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

interface ISubscription {
    function mint(address account, address module, uint256 validUntil) external;
    function burn(address account, address module) external;

    function subscriptionOf(
        address module,
        address account
    )
        external
        view
        returns (uint256 validUntil);
}
