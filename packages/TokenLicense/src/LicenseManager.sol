// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import { TxFee } from "./core/TxFee.sol";
import { ModuleMonetization } from "./core/ModuleMonetization.sol";
import { ILicenseManager } from "./interfaces/ILicenseManager.sol";
import { IPermit2 } from "permit2/src/interfaces/IPermit2.sol";

contract LicenseManager is ILicenseManager, TxFee {
    constructor(IPermit2 permit2, address token) ModuleMonetization(permit2, token) { }

    function domainSeparator() external view returns (bytes32) {
        return _domainSeparator();
    }
}
