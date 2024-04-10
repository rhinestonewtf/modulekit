// SPDX-License-Identifier: MIT
pragma solidity ^0.8.25;

import "./ExecutionHelper.sol";

contract EventEmitter {
    event ModuleInstalled(uint256 moduleTypeId, address module);
    event ModuleUninstalled(uint256 moduleTypeId, address module);

    function emitModuleInstalled(uint256 moduleTypeId, address module) external {
        emit ModuleInstalled(moduleTypeId, module);
    }

    function emitModulesInstalled(uint256 moduleTypeId, address[] calldata modules) external {
        uint256 length = modules.length;
        for (uint256 i; i < length; i++) {
            emit ModuleInstalled(moduleTypeId, modules[i]);
        }
    }

    function emitModuleUninstalled(uint256 moduleTypeId, address module) external {
        emit ModuleUninstalled(moduleTypeId, module);
    }

    function emitModulesUninstalled(uint256 moduleTypeId, address[] calldata modules) external {
        uint256 length = modules.length;
        for (uint256 i; i < length; i++) {
            emit ModuleUninstalled(moduleTypeId, modules[i]);
        }
    }
}

contract EventManager is ExecutionHelper {
    EventEmitter internal EVENT;

    constructor() {
        EVENT = new EventEmitter();
    }

    function _emitModuleInstall(uint256 moduleTypeId, address module) internal {
        bool success = ISafe(msg.sender).execTransactionFromModule(
            address(EVENT),
            0,
            abi.encodeCall(EventEmitter.emitModuleInstalled, (moduleTypeId, module)),
            1
        );
        if (!success) revert ExecutionFailed();
    }

    function _emitModuleUninstall(uint256 moduleTypeId, address module) internal {
        bool success = ISafe(msg.sender).execTransactionFromModule(
            address(EVENT),
            0,
            abi.encodeCall(EventEmitter.emitModuleUninstalled, (moduleTypeId, module)),
            1
        );
        if (!success) revert ExecutionFailed();
    }
}
