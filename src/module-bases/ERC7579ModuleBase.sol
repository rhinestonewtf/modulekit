// SPDX-License-Identifier: AGPL-3.0-only
pragma solidity >=0.8.0 <0.9.0;

import { IModule as IERC7579Module } from "../accounts/common/interfaces/IERC7579Module.sol";
import {
    MODULE_TYPE_VALIDATOR,
    MODULE_TYPE_EXECUTOR,
    MODULE_TYPE_FALLBACK,
    MODULE_TYPE_HOOK,
    MODULE_TYPE_POLICY,
    MODULE_TYPE_SIGNER,
    MODULE_TYPE_STATELESS_VALIDATOR
} from "./utils/ERC7579Constants.sol";

abstract contract ERC7579ModuleBase is IERC7579Module {
    uint256 internal constant TYPE_VALIDATOR = MODULE_TYPE_VALIDATOR;
    uint256 internal constant TYPE_EXECUTOR = MODULE_TYPE_EXECUTOR;
    uint256 internal constant TYPE_FALLBACK = MODULE_TYPE_FALLBACK;
    uint256 internal constant TYPE_HOOK = MODULE_TYPE_HOOK;
    uint256 internal constant TYPE_POLICY = MODULE_TYPE_POLICY;
    uint256 internal constant TYPE_SIGNER = MODULE_TYPE_SIGNER;
    uint256 internal constant TYPE_STATELESS_VALIDATOR = MODULE_TYPE_STATELESS_VALIDATOR;
}
