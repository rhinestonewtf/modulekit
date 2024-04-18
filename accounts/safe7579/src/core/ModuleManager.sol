// SPDX-License-Identifier: MIT
pragma solidity ^0.8.23;

import { SentinelListLib } from "sentinellist/SentinelList.sol";
import { SentinelList4337Lib } from "sentinellist/SentinelList4337.sol";
import { IModule } from "erc7579/interfaces/IERC7579Module.sol";
import { SimulateTxAccessor } from "../utils/DCUtil.sol";
import { ISafe } from "../interfaces/ISafe.sol";

import { Safe7579DCUtil, ModuleInstallUtil } from "../utils/DCUtil.sol";
import { Enum } from "@safe-global/safe-contracts/contracts/common/Enum.sol";
import { RegistryAdapter } from "./RegistryAdapter.sol";
import { Receiver } from "erc7579/core/Receiver.sol";
import { AccessControl } from "./AccessControl.sol";
import { ExecutionHelper } from "./ExecutionHelper.sol";
import { Safe7579DCUtil, Safe7579DCUtilSetup } from "./SetupDCUtil.sol";
import { CallType, CALLTYPE_SINGLE, CALLTYPE_DELEGATECALL } from "erc7579/lib/ModeLib.sol";

import {
    MODULE_TYPE_VALIDATOR,
    MODULE_TYPE_EXECUTOR,
    MODULE_TYPE_FALLBACK,
    MODULE_TYPE_HOOK
} from "erc7579/interfaces/IERC7579Module.sol";

CallType constant CALLTYPE_STATIC = CallType.wrap(0xFE);

// struct FallbackHandler {
//     address handler;
//     CallType calltype;
// }
//
// struct ModuleManagerStorage {
//     // linked list of executors. List is initialized by initializeAccount()
//     SentinelListLib.SentinelList _executors;
//     mapping(bytes4 selector => FallbackHandler fallbackHandler) _fallbacks;
// }

/**
 * @title ModuleManager
 * Contract that implements ERC7579 Module compatibility for Safe accounts
 * @author zeroknots.eth | rhinestone.wtf
 */
abstract contract ModuleManager is AccessControl, Receiver, RegistryAdapter {
    using SentinelListLib for SentinelListLib.SentinelList;
    using SentinelList4337Lib for SentinelList4337Lib.SentinelList;

    error InvalidModule(address module);
    error LinkedListError();
    error CannotRemoveLastValidator();
    error InitializerError();
    error ValidatorStorageHelperError();
    error NoFallbackHandler(bytes4 msgSig);
    error InvalidFallbackHandler(bytes4 msgSig);
    error FallbackInstalled(bytes4 msgSig);

    /*´:°•.°+.*•´.*:˚.°*.˚•´.°:°•.°•.*•´.*:˚.°*.˚•´.°:°•.°+.*•´.*:*/
    /*                     VALIDATOR MODULES                       */
    /*.•°:°.´+˚.*°.˚:*.´•*.+°.•°:´*.´•*.•°.•°:°.´:•˚°.*°.˚:*.´+°.•*/
    SentinelList4337Lib.SentinelList internal $validators;

    /**
     * install and initialize validator module
     */
    function _installValidator(
        address validator,
        bytes calldata data
    )
        internal
        withRegistry(validator, MODULE_TYPE_VALIDATOR)
    {
        $validators.push({ account: msg.sender, newEntry: validator });

        // Initialize Validator Module via Safe
        _delegatecall({
            safe: ISafe(msg.sender),
            target: UTIL,
            callData: abi.encodeCall(
                ModuleInstallUtil.installModule, (MODULE_TYPE_VALIDATOR, validator, data)
            )
        });
    }

    /**
     * Uninstall and de-initialize validator module
     */
    function _uninstallValidator(address validator, bytes calldata data) internal {
        (address prev, bytes memory disableModuleData) = abi.decode(data, (address, bytes));
        $validators.pop({ account: msg.sender, prevEntry: prev, popEntry: validator });

        // De-Initialize Validator Module via Safe
        _delegatecall({
            safe: ISafe(msg.sender),
            target: UTIL,
            callData: abi.encodeCall(
                ModuleInstallUtil.unInstallModule, (MODULE_TYPE_VALIDATOR, validator, disableModuleData)
            )
        });
    }

    /**
     * Helper function that will calculate storage slot for
     * validator address within the linked list in ValidatorStorageHelper
     * and use Safe's getStorageAt() to read 32bytes from Safe's storage
     */
    function _isValidatorInstalled(address validator)
        internal
        view
        virtual
        returns (bool isInstalled)
    {
        isInstalled = $validators.contains({ account: msg.sender, entry: validator });
    }

    /**
     * Get paginated list of installed validators
     */
    function getValidatorPaginated(
        address start,
        uint256 pageSize
    )
        external
        view
        virtual
        returns (address[] memory array, address next)
    {
        return $validators.getEntriesPaginated({
            account: msg.sender,
            start: start,
            pageSize: pageSize
        });
    }

    /*´:°•.°+.*•´.*:˚.°*.˚•´.°:°•.°•.*•´.*:˚.°*.˚•´.°:°•.°+.*•´.*:*/
    /*                      EXECUTOR MODULES                      */
    /*.•°:°.´+˚.*°.˚:*.´•*.+°.•°:´*.´•*.•°.•°:°.´:•˚°.*°.˚:*.´+°.•*/
    mapping(address smartAccount => SentinelListLib.SentinelList _executors) internal
        $executorStorage;

    modifier onlyExecutorModule() {
        if (!_isExecutorInstalled(_msgSender())) revert InvalidModule(_msgSender());
        _;
    }

    function _installExecutor(
        address executor,
        bytes calldata data
    )
        internal
        withRegistry(executor, MODULE_TYPE_EXECUTOR)
    {
        SentinelListLib.SentinelList storage $executors = $executorStorage[msg.sender];
        $executors.push(executor);
        // Initialize Executor Module via Safe
        _delegatecall({
            safe: ISafe(msg.sender),
            target: UTIL,
            callData: abi.encodeCall(
                ModuleInstallUtil.installModule, (MODULE_TYPE_EXECUTOR, executor, data)
            )
        });
    }

    function _uninstallExecutor(address executor, bytes calldata data) internal {
        SentinelListLib.SentinelList storage $executors = $executorStorage[msg.sender];
        (address prev, bytes memory disableModuleData) = abi.decode(data, (address, bytes));
        $executors.pop(prev, executor);

        // De-Initialize Validator Module via Safe
        _delegatecall({
            safe: ISafe(msg.sender),
            target: UTIL,
            callData: abi.encodeCall(
                ModuleInstallUtil.unInstallModule, (MODULE_TYPE_EXECUTOR, executor, disableModuleData)
            )
        });
    }

    function _isExecutorInstalled(address executor) internal view virtual returns (bool) {
        SentinelListLib.SentinelList storage $executors = $executorStorage[msg.sender];
        return $executors.contains(executor);
    }

    function getExecutorsPaginated(
        address cursor,
        uint256 size
    )
        external
        view
        virtual
        returns (address[] memory array, address next)
    {
        SentinelListLib.SentinelList storage $executors = $executorStorage[msg.sender];
        return $executors.getEntriesPaginated(cursor, size);
    }

    /*´:°•.°+.*•´.*:˚.°*.˚•´.°:°•.°•.*•´.*:˚.°*.˚•´.°:°•.°+.*•´.*:*/
    /*                      FALLBACK MODULES                      */
    /*.•°:°.´+˚.*°.˚:*.´•*.+°.•°:´*.´•*.•°.•°:°.´:•˚°.*°.˚:*.´+°.•*/
    struct FallbackHandler {
        address handler;
        CallType calltype;
    }

    mapping(address smartAccount => mapping(bytes4 selector => FallbackHandler handlerConfig))
        internal $fallbackStorage;

    function _installFallbackHandler(
        address handler,
        bytes calldata params
    )
        internal
        virtual
        withRegistry(handler, MODULE_TYPE_FALLBACK)
    {
        (bytes4 functionSig, CallType calltype, bytes memory initData) =
            abi.decode(params, (bytes4, CallType, bytes));

        // disallow calls to onInstall or onUninstall.
        // this could create a security issue
        if (
            functionSig == IModule.onInstall.selector || functionSig == IModule.onUninstall.selector
        ) revert InvalidFallbackHandler(functionSig);
        if (_isFallbackHandlerInstalled(functionSig)) revert FallbackInstalled(functionSig);

        FallbackHandler storage $fallbacks = $fallbackStorage[msg.sender][functionSig];
        $fallbacks.calltype = calltype;
        $fallbacks.handler = handler;

        _delegatecall({
            safe: ISafe(msg.sender),
            target: UTIL,
            callData: abi.encodeCall(
                ModuleInstallUtil.installModule, (MODULE_TYPE_FALLBACK, handler, initData)
            )
        });
    }

    function _isFallbackHandlerInstalled(bytes4 functionSig) internal view virtual returns (bool) {
        FallbackHandler storage $fallbacks = $fallbackStorage[msg.sender][functionSig];
        return $fallbacks.handler != address(0);
    }

    function _uninstallFallbackHandler(address handler, bytes calldata context) internal virtual {
        (bytes4 functionSig, bytes memory initData) = abi.decode(context, (bytes4, bytes));

        FallbackHandler storage $fallbacks = $fallbackStorage[msg.sender][functionSig];
        $fallbacks.handler = address(0);
        // De-Initialize Fallback Module via Safe
        _delegatecall({
            safe: ISafe(msg.sender),
            target: UTIL,
            callData: abi.encodeCall(
                ModuleInstallUtil.unInstallModule, (MODULE_TYPE_FALLBACK, handler, initData)
            )
        });
    }

    function _isFallbackHandlerInstalled(
        address _handler,
        bytes calldata additionalContext
    )
        internal
        view
        virtual
        returns (bool)
    {
        bytes4 functionSig = abi.decode(additionalContext, (bytes4));

        // TODO: check that no onInstall / onUninstall is called

        FallbackHandler storage $fallbacks = $fallbackStorage[msg.sender][functionSig];
        return $fallbacks.handler == _handler;
    }

    // FALLBACK
    // solhint-disable-next-line no-complex-fallback
    fallback(bytes calldata callData)
        external
        payable
        virtual
        override(Receiver)
        receiverFallback
        returns (bytes memory fallbackRet)
    {
        FallbackHandler storage $fallbacks = $fallbackStorage[msg.sender][msg.sig];
        address handler = $fallbacks.handler;
        CallType calltype = $fallbacks.calltype;
        if (handler == address(0)) revert NoFallbackHandler(msg.sig);

        if (calltype == CALLTYPE_STATIC) {
            bytes memory ret = _delegatecallReturn({
                safe: ISafe(msg.sender),
                target: UTIL,
                callData: abi.encodeCall(
                    SimulateTxAccessor.simulate,
                    (handler, 0, abi.encodePacked(callData, _msgSender()), Enum.Operation.Call)
                )
            });
            (,, fallbackRet) = abi.decode(ret, (uint256, bool, bytes));
            return fallbackRet;
        }
        if (calltype == CALLTYPE_SINGLE) {
            return _execReturn({
                safe: ISafe(msg.sender),
                target: handler,
                value: 0,
                callData: abi.encodePacked(callData, _msgSender())
            });
        }
    }

    /*´:°•.°+.*•´.*:˚.°*.˚•´.°:°•.°•.*•´.*:˚.°*.˚•´.°:°•.°+.*•´.*:*/
    /*                        HOOK MODULES                        */
    /*.•°:°.´+˚.*°.˚:*.´•*.+°.•°:´*.´•*.•°.•°:°.´:•˚°.*°.˚:*.´+°.•*/

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
