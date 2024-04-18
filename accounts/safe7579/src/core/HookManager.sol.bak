// SPDX-License-Identifier: MIT
pragma solidity ^0.8.23;

import { IHook, IModule } from "erc7579/interfaces/IERC7579Module.sol";
import { ISafe } from "../interfaces/ISafe.sol";
import { MODULE_TYPE_HOOK } from "erc7579/interfaces/IERC7579Module.sol";
import { Safe7579DCUtil, ModuleInstallUtil } from "../utils/DCUtil.sol";
/**
 * @title reference implementation of HookManager
 * @author zeroknots.eth | rhinestone.wtf
 */

abstract contract HookManager {
    mapping(address smartAccount => address globalHook) internal $globalHook;
    mapping(address smartAccount => mapping(bytes4 => address hook)) internal $hookManager;

    error HookPostCheckFailed();
    error HookAlreadyInstalled(address currentHook);

    enum HookType {
        GLOBAL,
        SIG
    }

    modifier withSelectorHook(bytes4 hookSig) {
        address hook = $hookManager[msg.sender][hookSig];
        bool enabled = hook != address(0);
        bytes memory _data;
        // if (enabled) _data = ISafe(msg.sender).preHook({ withHook: hook });
        _;
        // if (enabled) ISafe(msg.sender).postHook({ withHook: hook, hookPreContext: _data });
    }

    modifier withGlobalHook() {
        address hook = $globalHook[msg.sender];
        bool enabled = hook != address(0);
        bytes memory _data;
        // if (enabled) _data = ISafe(msg.sender).preHook({ withHook: hook });
        _;
        // if (enabled) ISafe(msg.sender).postHook({ withHook: hook, hookPreContext: _data });
    }

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

        _delegatecall({
            safe: ISafe(msg.sender),
            target: UTIL,
            callData: abi.encodeCall(
                ModuleInstallUtil.installModule, (MODULE_TYPE_HOOK, hook, initData)
            )
        });
    }

    function _uninstallHook(address hook, bytes calldata data) internal virtual {
        (bytes4 selector, bytes memory initData) = abi.decode(data, (bytes4, bytes));
        delete $hookManager[msg.sender][selector];

        _delegatecall({
            safe: ISafe(msg.sender),
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
