// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import { ModuleMonetization } from "./ModuleMonetization.sol";
import { LicenseCheck } from "./LicenseCheck.sol";
import { SafeTransferLib } from "solady/src/utils/SafeTransferLib.sol";
import { ILicenseManager } from "../interfaces/ILicenseManager.sol";

abstract contract Subscription is ILicenseManager, ModuleMonetization, LicenseCheck {
    using SafeTransferLib for address;

    function approvalSubscription(address module, uint256 amount) external {
        // how many seconds does the amount cover?
        uint256 secondsCovered = amount / _moduleMoneyConfs[module].pricePerSecond;
        uint256 validUntil = _accountLicenses[module][msg.sender].validUntil;

        uint48 newValidUntil = (validUntil == 0)
            ? uint48(block.timestamp + secondsCovered) // license is not valid, so start from now
            : uint48(validUntil + secondsCovered); // license is valid, so extend it

        // check if newValidUntil is greater that minimum subscription perion
        if (newValidUntil < block.timestamp + _moduleMoneyConfs[module].minSubSeconds) {
            revert SubscriptionTooShort();
        }

        _accountLicenses[module][msg.sender].validUntil = uint48(newValidUntil);

        address(TOKEN).safeTransferFrom(msg.sender, _moduleMoneyConfs[module].splitter, amount);
    }

    function signedSubscription(
        address module,
        uint256 amount,
        bytes calldata signature
    )
        external
    { }
}
