// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import { ILicenseManager } from "../interfaces/ILicenseManager.sol";
import { IERC20 } from "forge-std/interfaces/IERC20.sol";

contract TxModuleBase {
    ILicenseManager internal immutable LICENSE_MANAGER;

    constructor(ILicenseManager licenseManager) {
        LICENSE_MANAGER = licenseManager;
    }

    function _claimTxFee(
        address smartAccount,
        IERC20 token,
        uint256 totalTransactedAmount
    )
        internal
    {
        LICENSE_MANAGER.claimTxFee(smartAccount, smartAccount, token, totalTransactedAmount);
    }
}
