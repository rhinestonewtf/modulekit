// SPDX-License-Identifier: MIT
pragma solidity ^0.8.23;

import { IERC7579Module } from "../external/ERC7579.sol";

abstract contract ERC7579ModuleBase is IERC7579Module {
    uint256 constant TYPE_VALIDATOR = 1;
    uint256 constant TYPE_EXECUTOR = 2;
    uint256 constant TYPE_FALLBACK = 3;
    uint256 constant TYPE_HOOK = 4;
}
