// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import { ISubscription } from "../subscription/ISubscription.sol";
import { LicensedModuleBase } from "./Base.sol";

abstract contract SubscriptionModuleBase is LicensedModuleBase {
    ISubscription private immutable SUBTOKEN;

    constructor() {
        SUBTOKEN = LICENSE_MANAGER.subtoken();
    }

    function _getValidUntil(
        address account,
        address module
    )
        internal
        view
        returns (uint48 validUntil)
    {
        validUntil = uint48(SUBTOKEN.subscriptionOf(module, account));
    }
}
