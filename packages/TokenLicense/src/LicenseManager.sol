// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import { ILicenseManager } from "./interfaces/ILicenseManager.sol";
import { Subscription } from "./router/Subscription.sol";
import { ModuleRecords } from "./router/ModuleRecords.sol";
import { Swapper } from "./router/SwapperUniV3.sol";
import { IPermit2 } from "permit2/src/interfaces/IPermit2.sol";
import { ISwapRouter } from "@uniswap/v3-periphery/contracts/interfaces/ISwapRouter.sol";

contract LicenseManager is Subscription {
    constructor(
        IPermit2 permit2,
        address factory,
        address nativeToken
    )
        ModuleRecords(permit2)
        Swapper(factory, nativeToken)
    { }

    function domainSeparator() external view returns (bytes32) {
        return _domainSeparator();
    }
}
