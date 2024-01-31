// SPDX-License-Identifier: MIT
pragma solidity ^0.8.23;

import { ERC7579HookBase } from "../Modules.sol";
import { ModuleTypeLib, EncodedModuleTypes, ModuleType } from "umsa/lib/ModuleTypeLib.sol";

contract MockHook is ERC7579HookBase {
    EncodedModuleTypes immutable MODULE_TYPES;

    constructor() {
        ModuleType[] memory moduleTypes = new ModuleType[](1);
        moduleTypes[0] = ModuleType.wrap(TYPE_HOOK);
        MODULE_TYPES = ModuleTypeLib.bitEncode(moduleTypes);
    }

    function onInstall(bytes calldata data) external override { }

    function onUninstall(bytes calldata data) external override { }

    function preCheck(
        address msgSender,
        uint256 msgValue,
        bytes calldata msgData
    )
        external
        override
        returns (bytes memory hookData)
    { }

    function postCheck(bytes calldata) external override returns (bool success) {
        return true;
    }

    function isInitialized(address smartAccount) external pure returns (bool) {
        return false;
    }

    function isModuleType(uint256 typeID) external pure returns (bool) {
        return typeID == TYPE_HOOK;
    }

    function getModuleTypes() external view returns (EncodedModuleTypes) {
        return MODULE_TYPES;
    }
}
