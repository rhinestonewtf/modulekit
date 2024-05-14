// SPDX-License-Identifier: MIT
pragma solidity ^0.8.21;

import { ModuleManager } from "erc7579/core/ModuleManager.sol";
import { HookManager } from "erc7579/core/HookManager.sol";

contract RhinestoneBootstrap is ModuleManager, HookManager {
    address internal constant REGISTRY = 0xe0cde9239d16bEf05e62Bbf7aA93e420f464c826;
    address internal constant REGISTRY_HOOK = 0x34dEDac925C00d63bD91800Ff821e535fE59d6F5;

    function init() external {
        // add Registry Hook
        _installHook(REGISTRY_HOOK, abi.encodePacked(REGISTRY));
    }
}
