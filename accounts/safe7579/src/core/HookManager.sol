// SPDX-License-Identifier: MIT
pragma solidity ^0.8.23;

import { ModuleManager } from "./ModuleManager.sol";
import { IHook, IModule } from "erc7579/interfaces/IERC7579Module.sol";
import { MODULE_TYPE_HOOK } from "erc7579/interfaces/IERC7579Module.sol";
import { ISafe, ExecOnSafeLib } from "../lib/ExecOnSafeLib.sol";
import { Safe7579DCUtil, ModuleInstallUtil } from "../utils/DCUtil.sol";
/**
 * @title reference implementation of HookManager
 * @author zeroknots.eth | rhinestone.wtf
 */

abstract contract HookManager is ModuleManager {
    using ExecOnSafeLib for ISafe;

    mapping(address smartAccount => mapping(bytes4 => address hook)) internal $hookManager;

    error HookPostCheckFailed();
    error HookAlreadyInstalled(address currentHook);

    function _installHook(
        address hook,
        bytes calldata data
    )
        internal
        virtual
        withRegistry(hook, MODULE_TYPE_HOOK)
    {
        (bytes4 selector, bytes memory initData) = abi.decode(data, (bytes4, bytes));
        address currentHook = $hookManager[msg.sender][selector];
        if (currentHook != address(0)) {
            revert HookAlreadyInstalled(currentHook);
        }
        $hookManager[msg.sender][selector] = hook;
        ISafe(msg.sender).execDelegateCall({
            target: UTIL,
            callData: abi.encodeCall(
                ModuleInstallUtil.installModule, (MODULE_TYPE_HOOK, hook, initData)
            )
        });
    }

    function _uninstallHook(address hook, bytes calldata data) internal virtual {
        (bytes4 selector, bytes memory initData) = abi.decode(data, (bytes4, bytes));
        delete $hookManager[msg.sender][selector];

        ISafe(msg.sender).execDelegateCall({
            target: UTIL,
            callData: abi.encodeCall(
                ModuleInstallUtil.unInstallModule, (MODULE_TYPE_HOOK, hook, initData)
            )
        });
    }

    function _isHookInstalled(
        address module,
        bytes calldata context
    )
        internal
        view
        returns (bool)
    {
        bytes4 selector = abi.decode(context, (bytes4));
        return $hookManager[msg.sender][selector] == module;
    }

    function getActiveHook(bytes4 selector) public view returns (address hook) {
        return $hookManager[msg.sender][selector];
    }
}
