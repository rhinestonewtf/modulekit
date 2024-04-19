// SPDX-License-Identifier: MIT
pragma solidity ^0.8.23;

import { SentinelListLib } from "sentinellist/SentinelList.sol";
import { SentinelList4337Lib } from "sentinellist/SentinelList4337.sol";
import { IModule, IHook } from "../interfaces/IERC7579Module.sol";
import { ISafe } from "../interfaces/ISafe.sol";

import { Safe7579DCUtil, ModuleInstallUtil } from "../utils/DCUtil.sol";
import { RegistryAdapter } from "./RegistryAdapter.sol";
import { Receiver } from "erc7579/core/Receiver.sol";
import { AccessControl } from "./AccessControl.sol";
import { CallType, CALLTYPE_STATIC, CALLTYPE_SINGLE } from "../lib/ModeLib.sol";
import {
    MODULE_TYPE_VALIDATOR,
    MODULE_TYPE_EXECUTOR,
    MODULE_TYPE_FALLBACK,
    MODULE_TYPE_HOOK
} from "erc7579/interfaces/IERC7579Module.sol";

/**
 * @title ModuleManager
 * Contract that implements ERC7579 Module compatibility for Safe accounts
 * @author zeroknots.eth | rhinestone.wtf
 * @dev All Module types  are handled within this
 * contract. To make it a bit easier to read, the contract is split into different sections:
 * - Validator Modules
 * - Executor Modules
 * - Fallback Modules
 * - Hook Modules
 * Note: the Storage mappings for each section, are not listed on the very top, but in the
 * respective section
 *
 */
abstract contract ModuleManager is AccessControl, Receiver, RegistryAdapter {
    using SentinelListLib for SentinelListLib.SentinelList;
    using SentinelList4337Lib for SentinelList4337Lib.SentinelList;

    error InvalidModule(address module);
    error LinkedListError();
    error InitializerError();
    error ValidatorStorageHelperError();
    error InvalidInput();

    /*´:°•.°+.*•´.*:˚.°*.˚•´.°:°•.°•.*•´.*:˚.°*.˚•´.°:°•.°+.*•´.*:*/
    /*                     VALIDATOR MODULES                       */
    /*.•°:°.´+˚.*°.˚:*.´•*.+°.•°:´*.´•*.•°.•°:°.´:•˚°.*°.˚:*.´+°.•*/
    // No mapping account => list necessary. this sentinellist flavour handles associated storage to
    // smart account itself to comply with 4337 storage restrictions
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
    error NoFallbackHandler(bytes4 msgSig);
    error InvalidFallbackHandler(bytes4 msgSig);
    error FallbackInstalled(bytes4 msgSig);

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

        FallbackHandler storage $fallbacks = $fallbackStorage[msg.sender][functionSig];
        return $fallbacks.handler == _handler;
    }

    /**
     * Fallback implementation supports callTypes:
     *     - CALLTYPE_STATIC
     *     - CALLTYPE_SINGLE
     */
    // solhint-disable-next-line no-complex-fallback
    fallback(bytes calldata callData)
        external
        payable
        virtual
        override(Receiver)
        receiverFallback
        withHook(msg.sig)
        returns (bytes memory fallbackRet)
    {
        // using JUMPI to avoid stack too deep
        return _callFallbackHandler(callData);
    }

    function _callFallbackHandler(bytes calldata callData)
        private
        returns (bytes memory fallbackRet)
    {
        // get handler for specific function selector
        FallbackHandler storage $fallbacks = $fallbackStorage[msg.sender][msg.sig];
        address handler = $fallbacks.handler;
        CallType calltype = $fallbacks.calltype;
        // if no handler is set for the msg.sig, revert
        if (handler == address(0)) revert NoFallbackHandler(msg.sig);

        // according to ERC7579, when calling to fallback modules, ERC2771 msg.sender has to be
        // appended to the calldata, this allows fallback modules to implement
        // authorization control
        if (calltype == CALLTYPE_STATIC) {
            return _staticcallReturn({
                safe: ISafe(msg.sender),
                target: handler,
                callData: abi.encodePacked(callData, _msgSender()) // append ERC2771
             });
        }
        if (calltype == CALLTYPE_SINGLE) {
            return _execReturn({
                safe: ISafe(msg.sender),
                target: handler,
                value: 0,
                callData: abi.encodePacked(callData, _msgSender()) // append ERC2771
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
    error InvalidHookType();

    enum HookType {
        GLOBAL,
        SIG
    }

    function _preHooks(
        address globalHook,
        address sigHook
    )
        internal
        returns (bytes memory global, bytes memory sig)
    {
        if (globalHook != address(0)) {
            global = _execReturn({
                safe: ISafe(msg.sender),
                target: globalHook,
                value: 0,
                callData: abi.encodeCall(IHook.preCheck, (_msgSender(), msg.value, msg.data))
            });
            global = abi.decode(global, (bytes));
        }
        if (sigHook != address(0)) {
            sig = _execReturn({
                safe: ISafe(msg.sender),
                target: sigHook,
                value: 0,
                callData: abi.encodeCall(IHook.preCheck, (_msgSender(), msg.value, msg.data))
            });
            sig = abi.decode(sig, (bytes));
        }
    }

    function _postHooks(
        address globalHook,
        address sigHook,
        bytes memory global,
        bytes memory sig
    )
        internal
    {
        if (globalHook != address(0)) {
            _exec({
                safe: ISafe(msg.sender),
                target: globalHook,
                value: 0,
                callData: abi.encodeCall(IHook.postCheck, (global))
            });
        }
        if (sigHook != address(0)) {
            _exec({
                safe: ISafe(msg.sender),
                target: sigHook,
                value: 0,
                callData: abi.encodeCall(IHook.postCheck, (sig))
            });
        }
    }

    modifier withHook(bytes4 selector) {
        address globalHook = $globalHook[msg.sender];
        address sigHook = $hookManager[msg.sender][selector];
        (bytes memory global, bytes memory sig) = _preHooks(globalHook, sigHook);
        _;
        _postHooks(globalHook, sigHook, global, sig);
    }

    function _installHook(
        address hook,
        bytes calldata data
    )
        internal
        virtual
        withRegistry(hook, MODULE_TYPE_HOOK)
    {
        (HookType hookType, bytes4 selector, bytes memory initData) =
            abi.decode(data, (HookType, bytes4, bytes));
        address currentHook;

        // handle global hooks
        if (hookType == HookType.GLOBAL && selector == 0x0) {
            currentHook = $globalHook[msg.sender];
            // Dont allow hooks to be overwritten. If a hook is currently installed, it must be
            // uninstalled first
            if (currentHook != address(0)) {
                revert HookAlreadyInstalled(currentHook);
            }
            $globalHook[msg.sender] = hook;
        } else if (hookType == HookType.SIG) {
            // Dont allow hooks to be overwritten. If a hook is currently installed, it must be
            // uninstalled first
            if (currentHook != address(0)) {
                revert HookAlreadyInstalled(currentHook);
            }
            currentHook = $hookManager[msg.sender][selector];
            $hookManager[msg.sender][selector] = hook;
        } else {
            revert InvalidHookType();
        }

        // delegatecall neccessary, since event for installModule has to be emitted by SafeProxy
        _delegatecall({
            safe: ISafe(msg.sender),
            target: UTIL,
            callData: abi.encodeCall(
                ModuleInstallUtil.installModule, (MODULE_TYPE_HOOK, hook, initData)
            )
        });
    }

    function _uninstallHook(address hook, bytes calldata data) internal virtual {
        (HookType hookType, bytes4 selector, bytes memory initData) =
            abi.decode(data, (HookType, bytes4, bytes));
        if (hookType == HookType.GLOBAL && selector == 0x0) {
            delete $globalHook[msg.sender];
        } else if (hookType == HookType.SIG) {
            delete $hookManager[msg.sender][selector];
        } else {
            revert InvalidHookType();
        }

        // delegatecall neccessary, since event for uninstallModule has to be emitted by SafeProxy
        _delegatecall({
            safe: ISafe(msg.sender),
            target: UTIL,
            callData: abi.encodeCall(
                ModuleInstallUtil.unInstallModule, (MODULE_TYPE_HOOK, hook, initData)
            )
        });
    }

    function _getCurrentHook(
        HookType hookType,
        bytes4 selector
    )
        internal
        view
        returns (address hook)
    {
        // handle global hooks
        if (hookType == HookType.GLOBAL && selector == 0x0) {
            hook = $globalHook[msg.sender];
        }
        if (hookType == HookType.SIG) {
            hook = $hookManager[msg.sender][selector];
        }
    }

    function _isHookInstalled(
        address module,
        bytes calldata context
    )
        internal
        view
        returns (bool)
    {
        (HookType hookType, bytes4 selector) = abi.decode(context, (HookType, bytes4));
        address hook = _getCurrentHook({ hookType: hookType, selector: selector });
        return hook == module;
    }

    function getActiveHook(bytes4 selector) public view returns (address hook) {
        return $hookManager[msg.sender][selector];
    }

    function getActiveHook() public view returns (address hook) {
        return $globalHook[msg.sender];
    }

    function _multiTypeInstall(
        address module,
        uint256[] calldata types,
        bytes[] calldata contexts,
        bytes calldata onInstallData
    )
        internal
    {
        uint256 length = types.length;
        if (contexts.length != length) revert InvalidInput();

        for (uint256 i; i < length; i++) {
            uint256 _type = types[i];

            if (_type == MODULE_TYPE_VALIDATOR) {
                $validators.push({ account: msg.sender, newEntry: module });
            } else if (_type == MODULE_TYPE_EXECUTOR) {
                $executorStorage[msg.sender].push(module);
            } else if (_type == MODULE_TYPE_FALLBACK) {
                // do nothing

                (bytes4 functionSig, CallType calltype) =
                    abi.decode(contexts[i], (bytes4, CallType));

                // disallow calls to onInstall or onUninstall.
                // this could create a security issue
                if (
                    functionSig == IModule.onInstall.selector
                        || functionSig == IModule.onUninstall.selector
                ) revert InvalidFallbackHandler(functionSig);
                if (_isFallbackHandlerInstalled(functionSig)) revert FallbackInstalled(functionSig);

                FallbackHandler storage $fallbacks = $fallbackStorage[msg.sender][functionSig];
                $fallbacks.calltype = calltype;
                $fallbacks.handler = module;
            } else if (_type == MODULE_TYPE_HOOK) {
                (HookType hookType, bytes4 selector) = abi.decode(contexts[i], (HookType, bytes4));
                address currentHook;

                // handle global hooks
                if (hookType == HookType.GLOBAL && selector == 0x0) {
                    currentHook = $globalHook[msg.sender];
                    // Dont allow hooks to be overwritten. If a hook is currently installed, it must
                    // be uninstalled first
                    if (currentHook != address(0)) {
                        revert HookAlreadyInstalled(currentHook);
                    }
                    $globalHook[msg.sender] = module;
                } else if (hookType == HookType.SIG) {
                    // Dont allow hooks to be overwritten. If a hook is currently installed, it must
                    // be uninstalled first
                    if (currentHook != address(0)) {
                        revert HookAlreadyInstalled(currentHook);
                    }
                    currentHook = $hookManager[msg.sender][selector];
                    $hookManager[msg.sender][selector] = module;
                } else {
                    revert InvalidHookType();
                }
            }
        }

        // delegatecall neccessary, since event for installModule has to be emitted by SafeProxy
        _delegatecall({
            safe: ISafe(msg.sender),
            target: UTIL,
            callData: abi.encodeCall(
                ModuleInstallUtil.installModule, (MODULE_TYPE_HOOK, module, onInstallData)
            )
        });
    }
}
