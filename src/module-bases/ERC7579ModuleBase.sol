// SPDX-License-Identifier: AGPL-3.0-only
pragma solidity >=0.8.0 <0.9.0;

import { IModule as IERC7579Module } from "src/accounts/common/interfaces/IERC7579Module.sol";

abstract contract ERC7579ModuleBase is IERC7579Module {
    uint256 internal constant TYPE_VALIDATOR = 1;
    uint256 internal constant TYPE_EXECUTOR = 2;
    uint256 internal constant TYPE_FALLBACK = 3;
    uint256 internal constant TYPE_HOOK = 4;
    uint256 internal constant TYPE_POLICY = 7;
}
