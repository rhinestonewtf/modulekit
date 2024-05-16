// SPDX-License-Identifier: AGPL-3.0-only
pragma solidity ^0.8.25;

import { IERC7579Module } from "../external/ERC7579.sol";

abstract contract ERC7579ModuleBase is IERC7579Module {
    uint256 constant TYPE_VALIDATOR = 1;
    uint256 constant TYPE_EXECUTOR = 2;
    uint256 constant TYPE_FALLBACK = 3;
    uint256 constant TYPE_HOOK = 4;
}
