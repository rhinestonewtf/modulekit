// SPDX-License-Identifier: MIT
pragma solidity ^0.8.23;

import { ModuleManager } from "./ModuleManager.sol";
import { IHook, IModule } from "erc7579/interfaces/IERC7579Module.sol";
import { MODULE_TYPE_HOOK } from "erc7579/interfaces/IERC7579Module.sol";
import { ISafe, ExecOnSafeLib } from "../lib/ExecOnSafeLib.sol";

/**
 * @title reference implementation of HookManager
 * @author zeroknots.eth | rhinestone.wtf
 */
abstract contract HookManager is ModuleManager {
    using ExecOnSafeLib for ISafe;

    mapping(address smartAccount => address hook) internal $hookManager;

    error HookPostCheckFailed();
    error HookAlreadyInstalled(address currentHook);

    // function _preHook(address hook) internal returns (bytes memory hookPreContext) {
    //     hookPreContext = abi.decode(
    //         _executeReturnData({
    //             safe: msg.sender,
    //             target: hook,
    //             value: 0,
    //             callData: abi.encodeCall(IHook.preCheck, (_msgSender(), msg.value, msg.data))
    //         }),
    //         (bytes)
    //     );
    // }
    //
    // function _postHook(
    //     address hook,
    //     bool executionSuccess,
    //     bytes memory executionReturnValue,
    //     bytes memory hookPreContext
    // )
    //     internal
    // {
    //     _execute({
    //         safe: msg.sender,
    //         target: hook,
    //         value: 0,
    //         callData: abi.encodeCall(
    //             IHook.postCheck, (hookPreContext, executionSuccess, executionReturnValue)
    //         )
    //     });
    // }

    function _installHook(
        address hook,
        bytes calldata data
    )
        internal
        virtual
        withRegistry(hook, MODULE_TYPE_HOOK)
    {
        address currentHook = $hookManager[msg.sender];
        if (currentHook != address(0)) {
            revert HookAlreadyInstalled(currentHook);
        }
        $hookManager[msg.sender] = hook;
        ISafe(msg.sender).exec({
            target: hook,
            value: 0,
            callData: abi.encodeCall(IModule.onInstall, (data))
        });
        _emitModuleInstall(MODULE_TYPE_HOOK, hook);
    }

    function _uninstallHook(address hook, bytes calldata data) internal virtual {
        $hookManager[msg.sender] = address(0);
        ISafe(msg.sender).exec({
            target: hook,
            value: 0,
            callData: abi.encodeCall(IModule.onUninstall, (data))
        });
        _emitModuleUninstall(MODULE_TYPE_HOOK, hook);
    }

    function _isHookInstalled(address module) internal view returns (bool) {
        return $hookManager[msg.sender] == module;
    }

    function getActiveHook() public view returns (address hook) {
        return $hookManager[msg.sender];
    }
}
