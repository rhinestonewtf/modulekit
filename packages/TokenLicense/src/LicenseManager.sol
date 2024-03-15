// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "./core/Distributor.sol";
import "./core/LicenseRegistry.sol";

contract LicenseManager is Distributor {
    constructor(address token) Distributor(token) { }
}
