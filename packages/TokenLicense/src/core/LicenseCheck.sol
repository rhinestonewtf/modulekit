// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import { ILicenseManager } from "../interfaces/ILicenseManager.sol";
import "../DataTypes.sol";

abstract contract LicenseCheck is ILicenseManager {
    mapping(address module => mapping(address account => License)) internal _accountLicenses;

    function hasActiveLicense(address account, address module) external view returns (bool) {
        return _accountLicenses[module][account].validUntil > block.timestamp;
    }

    function licenseUntil(address account, address module) external view returns (uint48) {
        return _accountLicenses[module][account].validUntil;
    }
}
