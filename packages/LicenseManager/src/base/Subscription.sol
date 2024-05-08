// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "../interfaces/ILicenseManager.sol";
import "../DataTypes.sol";
import "./LicenseManagerBase.sol";
import "../subscription/ISubscription.sol";

abstract contract Subscription is ILicenseManager, LicenseManagerBase {
    error SubscriptionAmountTooLow(uint256 amount, uint256 minAmount);

    event NewSubscription(address account, address module, uint48 newValidUntil);

    ISubscription public subtoken;

    constructor(ISubscription _subtoken) {
        subtoken = _subtoken;
    }

    function migrateToken(ISubscription _newSubscriptionToken) external onlyOwner {
        subtoken = _newSubscriptionToken;
    }

    function _validUntil(
        address smartAccount,
        address module,
        uint256 amount
    )
        internal
        view
        returns (uint256 newValidUntil)
    {
        PricingSubscription memory subscriptionPricing = $module[module].subscription;
        uint256 minAmount = subscriptionPricing.minSubTime * subscriptionPricing.pricePerSecond;
        if (amount < minAmount) revert SubscriptionAmountTooLow(amount, minAmount);
        uint256 currentValidUntil = getSubscription({ account: smartAccount, module: module });

        newValidUntil = (currentValidUntil == 0)
            ? uint48(block.timestamp + subscriptionPricing.minSubTime) // license is not valid, so
                // start from now
            : uint48(currentValidUntil + subscriptionPricing.minSubTime); // license is valid, so extend

        if (newValidUntil < block.timestamp) {
            revert SubscriptionTooShort();
        }
    }

    function _mintSubscription(address account, address module, uint256 newValid) internal {
        subtoken.mint({ account: account, module: module, validUntil: newValid });
    }

    function isActiveSubscription(address account, address module) external view returns (bool) {
        return getSubscription({ account: account, module: module }) > block.timestamp;
    }

    function getSubscription(address account, address module) public view returns (uint256) {
        return subtoken.subscriptionOf({ account: account, module: module });
    }
}
