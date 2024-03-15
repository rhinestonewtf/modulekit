// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

interface ILicenseRegistry {
    struct License {
        uint48 validUntil;
        bool autoExtend;
    }

    function hasActiveLicense(address account, address module) external view returns (bool);
    function licenseUntil(address account, address module) external view returns (uint48);
}
