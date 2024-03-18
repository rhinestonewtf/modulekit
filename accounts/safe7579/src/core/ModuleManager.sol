// SPDX-License-Identifier: MIT
pragma solidity ^0.8.23;

import { SentinelListLib } from "sentinellist/SentinelList.sol";
import { SentinelList4337Lib } from "sentinellist/SentinelList4337.sol";
import { IModule } from "erc7579/interfaces/IERC7579Module.sol";
import { ExecutionHelper } from "./ExecutionHelper.sol";
import { Receiver } from "erc7579/core/Receiver.sol";
import { AccessControl } from "./AccessControl.sol";
import { CallType, CALLTYPE_SINGLE, CALLTYPE_DELEGATECALL } from "erc7579/lib/ModeLib.sol";

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
abstract contract ModuleManager is AccessControl, Receiver, ExecutionHelper {
    using SentinelListLib for SentinelListLib.SentinelList;
    using SentinelList4337Lib for SentinelList4337Lib.SentinelList;

    error InvalidModule(address module);
    error LinkedListError();
    error CannotRemoveLastValidator();
    error InitializerError();
    error ValidatorStorageHelperError();
    error NoFallbackHandler(bytes4 msgSig);
    error FallbackInstalled(bytes4 msgSig);

    mapping(address smartAccount => ModuleManagerStorage moduleManagerStorage) internal
        $moduleManager;

    SentinelList4337Lib.SentinelList internal $validators;

    modifier onlyExecutorModule() {
        if (!_isExecutorInstalled(_msgSender())) revert InvalidModule(_msgSender());
        _;
    }

    /**
     * Initializes linked list that handles installed Validator and Executor
     */
    function _initModuleManager() internal {
        ModuleManagerStorage storage $mms = $moduleManager[msg.sender];
        // this will revert if list is already initialized
        $validators.init({ account: msg.sender });
        $mms._executors.init();
    }

    /////////////////////////////////////////////////////
    //  Manage Validators
    ////////////////////////////////////////////////////
    /**
     * install and initialize validator module
     */
    function _installValidator(address validator, bytes calldata data) internal virtual {
        $validators.push({ account: msg.sender, newEntry: validator });

        // Initialize Validator Module via Safe
        _execute({
            safe: msg.sender,
            target: validator,
            value: 0,
            callData: abi.encodeCall(IModule.onInstall, (data))
        });
    }

    /**
     * Uninstall and de-initialize validator module
     */
    function _uninstallValidator(address validator, bytes calldata data) internal {
        (address prev, bytes memory disableModuleData) = abi.decode(data, (address, bytes));
        $validators.pop({ account: msg.sender, prevEntry: prev, popEntry: validator });

        // De-Initialize Validator Module via Safe
        _execute({
            safe: msg.sender,
            target: validator,
            value: 0,
            callData: abi.encodeCall(IModule.onUninstall, (disableModuleData))
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

    function _installExecutor(address executor, bytes calldata data) internal {
        SentinelListLib.SentinelList storage $executors = $moduleManager[msg.sender]._executors;
        $executors.push(executor);
        // Initialize Executor Module via Safe
        _execute({
            safe: msg.sender,
            target: executor,
            value: 0,
            callData: abi.encodeCall(IModule.onInstall, (data))
        });
    }

    function _uninstallExecutor(address executor, bytes calldata data) internal {
        SentinelListLib.SentinelList storage $executors = $moduleManager[msg.sender]._executors;
        (address prev, bytes memory disableModuleData) = abi.decode(data, (address, bytes));
        $executors.pop(prev, executor);

        // De-Initialize Executor Module via Safe
        _execute({
            safe: msg.sender,
            target: executor,
            value: 0,
            callData: abi.encodeCall(IModule.onUninstall, (disableModuleData))
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
    function _installFallbackHandler(address handler, bytes calldata params) internal virtual {
        (bytes4 functionSig, CallType calltype, bytes memory initData) =
            abi.decode(params, (bytes4, CallType, bytes));
        if (_isFallbackHandlerInstalled(functionSig)) revert FallbackInstalled(functionSig);

        FallbackHandler storage $fallbacks = $moduleManager[msg.sender]._fallbacks[functionSig];
        $fallbacks.calltype = calltype;
        $fallbacks.handler = handler;

        _execute({
            safe: msg.sender,
            target: handler,
            value: 0,
            callData: abi.encodeCall(IModule.onInstall, (initData))
        });
    }

    function _isFallbackHandlerInstalled(bytes4 functionSig) internal view virtual returns (bool) {
        FallbackHandler storage $fallback = $moduleManager[msg.sender]._fallbacks[functionSig];
        return $fallback.handler != address(0);
    }

    function _uninstallFallbackHandler(address handler, bytes calldata initData) internal virtual {
        (bytes4 functionSig) = abi.decode(initData, (bytes4));

        ModuleManagerStorage storage $mms = $moduleManager[msg.sender];
        $mms._fallbacks[functionSig].handler = address(0);
        // De-Initialize Fallback Module via Safe
        _execute({
            safe: msg.sender,
            target: handler,
            value: 0,
            callData: abi.encodeCall(IModule.onUninstall, (initData))
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

        // dis wont work. need Enum.Operation static, cause safe account emits event
        // if (calltype == CALLTYPE_STATIC) {
        //     return _executeStaticReturnData(
        //         msg.sender, handler, 0, abi.encodePacked(callData, _msgSender())
        //     );
        // }
        if (calltype == CALLTYPE_SINGLE) {
            return
                _executeReturnData(msg.sender, handler, 0, abi.encodePacked(callData, _msgSender()));
        }
        // TODO: do we actually want this? security questionable...
        if (calltype == CALLTYPE_DELEGATECALL) {
            return _executeDelegateCallReturnData(msg.sender, handler, callData);
        }
    }
}
