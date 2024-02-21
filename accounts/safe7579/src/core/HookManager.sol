// SPDX-License-Identifier: MIT
pragma solidity ^0.8.23;

import { ModuleManager } from "./ModuleManager.sol";
import { IHook, IModule } from "erc7579/interfaces/IERC7579Module.sol";

/**
 * @title reference implementation of HookManager
 * @author zeroknots.eth | rhinestone.wtf
 */
abstract contract HookManager is ModuleManager {
    mapping(address smartAccount => address hook) internal $hookManager;

    error HookPostCheckFailed();
    error HookAlreadyInstalled(address currentHook);

    modifier withHook() {
        address hook = $hookManager[msg.sender];
        bool isHookEnabled = hook != address(0);
        bytes memory hookPreContext;

        // pre hook
        if (isHookEnabled) hookPreContext = _doPreHook(hook);

        _; // <-- hooked Function Bytecode here

        // post hook
        if (isHookEnabled) _doPostHook(hook, hookPreContext);
    }

    function _doPreHook(address hook) internal returns (bytes memory hookPreContext) {
        hookPreContext = abi.decode(
            _executeReturnData({
                safe: msg.sender,
                target: hook,
                value: 0,
                callData: abi.encodeCall(IHook.preCheck, (_msgSender(), msg.data))
            }),
            (bytes)
        );
    }

    function _doPostHook(address hook, bytes memory hookPreContext) internal {
        _execute({
            safe: msg.sender,
            target: hook,
            value: 0,
            callData: abi.encodeCall(IHook.postCheck, (hookPreContext))
        });
    }

    function _installHook(address hook, bytes calldata data) internal virtual {
        address currentHook = $hookManager[msg.sender];
        if (currentHook != address(0)) {
            revert HookAlreadyInstalled(currentHook);
        }
        $hookManager[msg.sender] = hook;
        _execute({
            safe: msg.sender,
            target: hook,
            value: 0,
            callData: abi.encodeCall(IModule.onInstall, (data))
        });
    }

    function _uninstallHook(address hook, bytes calldata data) internal virtual {
        $hookManager[msg.sender] = address(0);
        _execute({
            safe: msg.sender,
            target: hook,
            value: 0,
            callData: abi.encodeCall(IModule.onUninstall, (data))
        });
    }

    function _isHookInstalled(address module) internal view returns (bool) {
        return $hookManager[msg.sender] == module;
    }

    function getActiveHook() external view returns (address hook) {
        return $hookManager[msg.sender];
    }
}
