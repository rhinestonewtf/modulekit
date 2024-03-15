// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "../interfaces/ILicenseRegistry.sol";

contract LicenseRegistry is ILicenseRegistry {
    mapping(address module => mapping(address account => License)) internal _accountLicenses;

    function hasActiveLicense(
        address account,
        address module
    )
        external
        view
        override
        returns (bool)
    {
        return _accountLicenses[module][account].validUntil > block.timestamp;
    }

    function licenseUntil(
        address account,
        address module
    )
        external
        view
        override
        returns (uint48)
    {
        return _accountLicenses[module][account].validUntil;
    }
}
