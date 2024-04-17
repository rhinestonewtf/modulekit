// SPDX-License-Identifier: MIT
pragma solidity ^0.8.23;

import { SentinelListLib } from "sentinellist/SentinelList.sol";
import { SentinelList4337Lib } from "sentinellist/SentinelList4337.sol";
import { IModule } from "erc7579/interfaces/IERC7579Module.sol";
import { ISafe, ExecOnSafeLib } from "../lib/ExecOnSafeLib.sol";
import { SimulateTxAccessor } from "../utils/DelegatecallTarget.sol";

import { Safe7579DCUtil, ModuleInstallUtil } from "../utils/DCUtil.sol";
import { Enum } from "@safe-global/safe-contracts/contracts/common/Enum.sol";
import { RegistryAdapter } from "./RegistryAdapter.sol";
import { Receiver } from "erc7579/core/Receiver.sol";
import { AccessControl } from "./AccessControl.sol";
import { Safe7579DCUtil, Safe7579DCUtilSetup } from "./DCUtil.sol";
import { CallType, CALLTYPE_SINGLE, CALLTYPE_DELEGATECALL } from "erc7579/lib/ModeLib.sol";

import {
    MODULE_TYPE_VALIDATOR,
    MODULE_TYPE_EXECUTOR,
    MODULE_TYPE_FALLBACK
} from "erc7579/interfaces/IERC7579Module.sol";

CallType constant CALLTYPE_STATIC = CallType.wrap(0xFE);

struct FallbackHandler {
    address handler;
    CallType calltype;
}

struct ModuleManagerStorage {
    // linked list of executors. List is initialized by initializeAccount()
    SentinelListLib.SentinelList _executors;
    mapping(bytes4 selector => FallbackHandler fallbackHandler) _fallbacks;
}

/**
 * @title ModuleManager
 * Contract that implements ERC7579 Module compatibility for Safe accounts
 * @author zeroknots.eth | rhinestone.wtf
 */
abstract contract ModuleManager is AccessControl, Receiver, RegistryAdapter, Safe7579DCUtilSetup {
    using ExecOnSafeLib for *;
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

    mapping(address smartAccount => ModuleManagerStorage moduleManagerStorage) internal
        $moduleManager;

    SentinelList4337Lib.SentinelList internal $validators;

    modifier onlyExecutorModule() {
        if (!_isExecutorInstalled(_msgSender())) revert InvalidModule(_msgSender());
        _;
    }

    /////////////////////////////////////////////////////
    //  Manage Validators
    ////////////////////////////////////////////////////
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
        ISafe(msg.sender).execDelegateCall({
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
        ISafe(msg.sender).execDelegateCall({
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

    /////////////////////////////////////////////////////
    //  Manage Executors
    ////////////////////////////////////////////////////

    function _installExecutor(
        address executor,
        bytes calldata data
    )
        internal
        withRegistry(executor, MODULE_TYPE_EXECUTOR)
    {
        SentinelListLib.SentinelList storage $executors = $moduleManager[msg.sender]._executors;
        $executors.push(executor);
        // Initialize Executor Module via Safe
        ISafe(msg.sender).execDelegateCall({
            target: UTIL,
            callData: abi.encodeCall(
                ModuleInstallUtil.installModule, (MODULE_TYPE_EXECUTOR, executor, data)
            )
        });
    }

    function _uninstallExecutor(address executor, bytes calldata data) internal {
        SentinelListLib.SentinelList storage $executors = $moduleManager[msg.sender]._executors;
        (address prev, bytes memory disableModuleData) = abi.decode(data, (address, bytes));
        $executors.pop(prev, executor);

        // De-Initialize Validator Module via Safe
        ISafe(msg.sender).execDelegateCall({
            target: UTIL,
            callData: abi.encodeCall(
                ModuleInstallUtil.unInstallModule, (MODULE_TYPE_EXECUTOR, executor, disableModuleData)
            )
        });
    }

    function _isExecutorInstalled(address executor) internal view virtual returns (bool) {
        SentinelListLib.SentinelList storage $executors = $moduleManager[msg.sender]._executors;
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
        SentinelListLib.SentinelList storage $executors = $moduleManager[msg.sender]._executors;
        return $executors.getEntriesPaginated(cursor, size);
    }

    /////////////////////////////////////////////////////
    //  Manage Fallback
    ////////////////////////////////////////////////////
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

        FallbackHandler storage $fallbacks = $moduleManager[msg.sender]._fallbacks[functionSig];
        $fallbacks.calltype = calltype;
        $fallbacks.handler = handler;

        ISafe(msg.sender).execDelegateCall({
            target: UTIL,
            callData: abi.encodeCall(
                ModuleInstallUtil.installModule, (MODULE_TYPE_FALLBACK, handler, initData)
            )
        });
    }

    function _isFallbackHandlerInstalled(bytes4 functionSig) internal view virtual returns (bool) {
        FallbackHandler storage $fallback = $moduleManager[msg.sender]._fallbacks[functionSig];
        return $fallback.handler != address(0);
    }

    function _uninstallFallbackHandler(address handler, bytes calldata context) internal virtual {
        (bytes4 functionSig, bytes memory initData) = abi.decode(context, (bytes4, bytes));

        ModuleManagerStorage storage $mms = $moduleManager[msg.sender];
        $mms._fallbacks[functionSig].handler = address(0);
        // De-Initialize Fallback Module via Safe

        ISafe(msg.sender).execDelegateCall({
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

        FallbackHandler storage $fallback = $moduleManager[msg.sender]._fallbacks[functionSig];
        return $fallback.handler == _handler;
    }

    // FALLBACK
    // solhint-disable-next-line no-complex-fallback
    fallback(bytes calldata callData)
        external
        payable
        override(Receiver)
        receiverFallback
        returns (bytes memory fallbackRet)
    {
        FallbackHandler storage $fallbackHandler = $moduleManager[msg.sender]._fallbacks[msg.sig];
        address handler = $fallbackHandler.handler;
        CallType calltype = $fallbackHandler.calltype;
        if (handler == address(0)) revert NoFallbackHandler(msg.sig);

        if (calltype == CALLTYPE_STATIC) {
            bytes memory ret = ISafe(msg.sender).execDelegateCallReturn({
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
            return ISafe(msg.sender).execReturn({
                target: handler,
                value: 0,
                callData: abi.encodePacked(callData, _msgSender())
            });
        }
    }
}
