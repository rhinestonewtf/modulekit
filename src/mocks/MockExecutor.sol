// SPDX-License-Identifier: MIT
pragma solidity ^0.8.23;

import { ERC7579ExecutorBase } from "../Modules.sol";
import { IERC7579Account } from "../external/ERC7579.sol";
import { ModuleTypeLib, EncodedModuleTypes, ModuleType } from "erc7579/lib/ModuleTypeLib.sol";

contract MockExecutor is ERC7579ExecutorBase {
    EncodedModuleTypes immutable MODULE_TYPES;

    constructor() {
        ModuleType[] memory moduleTypes = new ModuleType[](1);
        moduleTypes[0] = ModuleType.wrap(TYPE_EXECUTOR);
        MODULE_TYPES = ModuleTypeLib.bitEncode(moduleTypes);
    }

    function onInstall(bytes calldata data) external override { }

    function onUninstall(bytes calldata data) external override { }

    function exec(
        address account,
        address to,
        uint256 value,
        bytes calldata callData
    )
        external
        returns (bytes memory)
    {
        return _execute(account, to, value, callData);
    }

    function isModuleType(uint256 typeID) external pure override returns (bool) {
        return typeID == TYPE_EXECUTOR;
    }

    function isInitialized(address smartAccount) external pure returns (bool) {
        return false;
    }

    function getModuleTypes() external view returns (EncodedModuleTypes) {
        return MODULE_TYPES;
    }
}
