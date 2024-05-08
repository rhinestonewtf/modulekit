// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "../lib/Currency.sol";
import "../subscription/ISubscription.sol";

interface ILicenseManager {
    event TransactionSettled(address account, address module, uint256 amountCharged);
    event SubscriptionSettled(address account, address module, uint256 amountCharged);
    event PerUseSettled(address account, address module, uint256 amountCharged);

    error SubscriptionTooShort();

    function subtoken() external view returns (ISubscription);
}
