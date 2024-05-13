// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "../DataTypes.sol";
import "../ILicenseManager.sol";

abstract contract FeeAuthorization is ILicenseManager {
    error UnauthorizedTransaction();

    mapping(address module => mapping(address account => Authorization)) internal $authorization;

    function _requireModuleIsAuthorized(
        address account,
        address module,
        ClaimType claimType
    )
        internal
        view
    {
        if (claimType == ClaimType.Transaction && !$authorization[module][account].allowTransaction)
        {
            revert UnauthorizedTransaction();
        }

        if (
            claimType == ClaimType.Subscription
                && !$authorization[module][account].allowSubscription
        ) {
            revert UnauthorizedTransaction();
        }

        if (claimType == ClaimType.PerUse && !$authorization[module][account].allowPerUse) {
            revert UnauthorizedTransaction();
        }
    }

    modifier onlyAuthorizedModule(address account, address module, ClaimType claimType) {
        _requireModuleIsAuthorized(account, module, claimType);
        _;
    }

    function authorizeModule(address module, Authorization calldata authorization) external {
        $authorization[module][msg.sender] = authorization;
    }
}
