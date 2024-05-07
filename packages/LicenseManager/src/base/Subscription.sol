// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "../interfaces/ILicenseManager.sol";
import "../DataTypes.sol";

abstract contract Subscription is ILicenseManager {
    error SubscriptionAmountTooLow(uint256 amount, uint256 minAmount);

    event NewSubscription(address account, address module, uint48 newValidUntil);

    mapping(address module => mapping(address account => SubscriptionRecord)) internal
        $activeLicenses;
    mapping(address module => SubscriptionPricing conf) internal $moduleSubPricing;

    // TODO: access control
    function setSubscriptionConfig(
        address module,
        Currency currency,
        uint128 pricePerSecond,
        uint128 minSubTime
    )
        external
    {
        $moduleSubPricing[module] = SubscriptionPricing({
            currency: currency,
            pricePerSecond: pricePerSecond,
            minSubTime: minSubTime
        });
    }

    function _validUntil(
        address smartAccount,
        address module,
        uint256 amount
    )
        internal
        view
        returns (uint48 newValidUntil)
    {
        SubscriptionPricing memory subscriptionPricing = $moduleSubPricing[module];
        uint256 minAmount = subscriptionPricing.minSubTime * subscriptionPricing.pricePerSecond;
        if (amount < minAmount) revert SubscriptionAmountTooLow(amount, minAmount);
        uint256 currentValidUntil = getSubscriptionValidUntil(smartAccount, module);

        newValidUntil = (currentValidUntil == 0)
            ? uint48(block.timestamp + subscriptionPricing.minSubTime) // license is not valid, so
                // start from now
            : uint48(currentValidUntil + subscriptionPricing.minSubTime); // license is valid, so extend

        if (newValidUntil < block.timestamp) {
            revert SubscriptionTooShort();
        }
    }

    function isActiveSubscription(address account, address module) external view returns (bool) {
        return $activeLicenses[module][account].validUntil > block.timestamp;
    }

    function getSubscriptionValidUntil(
        address account,
        address module
    )
        public
        view
        returns (uint48)
    {
        return $activeLicenses[module][account].validUntil;
    }
}
