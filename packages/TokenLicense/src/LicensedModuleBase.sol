// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "./interfaces/ILicenseRegistry.sol";

contract LicensedModuleBase {
    ILicenseRegistry immutable LICENSE_MANAGER;

    constructor(ILicenseRegistry _lm) {
        LICENSE_MANAGER = _lm;
    }

    modifier onlyLicense(address account) {
        if (LICENSE_MANAGER.hasActiveLicense(account, address(this))) {
            _;
        }
    }

    function _validLicenseUntil(address account) internal returns (uint48) {
        return LICENSE_MANAGER.licenseUntil(account, address(this));
    }
}
