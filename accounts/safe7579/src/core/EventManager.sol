// SPDX-License-Identifier: MIT
pragma solidity ^0.8.25;

import "./ExecutionHelper.sol";

contract EventEmitter {
    event ModuleInstalled(uint256 moduleTypeId, address module);
    event ModuleUninstalled(uint256 moduleTypeId, address module);

    function emitModuleInstalled(uint256 moduleTypeId, address module) external {
        emit ModuleInstalled(moduleTypeId, module);
    }

    function emitModuleUninstalled(uint256 moduleTypeId, address module) external {
        emit ModuleUninstalled(moduleTypeId, module);
    }
}

contract EventManager is ExecutionHelper {
    EventEmitter internal EVENT;

    constructor() {
        EVENT = new EventEmitter();
    }

    function _emitModuleInstall(uint256 moduleTypeId, address module) internal {
        _executeDelegateCallMemory({
            safe: msg.sender,
            target: address(EVENT),
            callData: abi.encodeCall(EventEmitter.emitModuleInstalled, (moduleTypeId, module))
        });
    }

    function _emitModuleUninstall(uint256 moduleTypeId, address module) internal {
        _executeDelegateCallMemory({
            safe: msg.sender,
            target: address(EVENT),
            callData: abi.encodeCall(EventEmitter.emitModuleUninstalled, (moduleTypeId, module))
        });
    }
}
