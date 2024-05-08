// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import { ILicenseManager } from "../interfaces/ILicenseManager.sol";

abstract contract LicensedModuleBase {
    ILicenseManager immutable LICENSE_MANAGER;

    constructor(ILicenseManager licenseManager) {
        LICENSE_MANAGER = licenseManager;
    }
}
