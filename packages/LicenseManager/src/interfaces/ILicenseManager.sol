// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "../lib/Currency.sol";

interface ILicenseManager {
    event TransactionSettled(address account, address module, uint256 amountCharged);
    event SubscriptionSettled(address account, address module, uint256 amountCharged);

    error SubscriptionTooShort();
}