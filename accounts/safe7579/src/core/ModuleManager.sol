// SPDX-License-Identifier: MIT
pragma solidity ^0.8.23;

import { SentinelListLib, SENTINEL } from "sentinellist/SentinelList.sol";
import { SentinelList4337Lib } from "sentinellist/SentinelList4337.sol";
import { IModule, IExecutor, IValidator, IFallback } from "erc7579/interfaces/IERC7579Module.sol";
import { ExecutionHelper } from "./ExecutionHelper.sol";
import { Receiver } from "erc7579/core/Receiver.sol";
import { AccessControl } from "./AccessControl.sol";
import { ISafe } from "../interfaces/ISafe.sol";
import {
    ValidatorStorageHelper, ValidatorStorageLib, $validator
} from "./ValidatorStorageHelper.sol";

struct ModuleManagerStorage {
    // linked list of executors. List is initialized by initializeAccount()
    SentinelListLib.SentinelList _executors;
    // single fallback handler for all fallbacks
    // account vendors may implement this differently. This is just a reference implementation
    address fallbackHandler;
}

// // keccak256("modulemanager.storage.msa");
// bytes32 constant MODULEMANAGER_STORAGE_LOCATION =
//     0xf88ce1fdb7fb1cbd3282e49729100fa3f2d6ee9f797961fe4fb1871cea89ea02;
//
// // keccak256("modulemanager.validator.storage.msa")
// bytes32 constant VALIDATOR_STORAGE_LOCATION =
//     0x7ab08468dcbe2bcd9b34ba12d148d0310762840a62884f0cdee905ee43538c87;
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

    ValidatorStorageHelper internal immutable VALIDATOR_STORAGE;

    mapping(address smartAccount => ModuleManagerStorage) private $moduleManager;

    SentinelList4337Lib.SentinelList $validators;

    modifier onlyExecutorModule() {
        if (!_isExecutorInstalled(_msgSender())) revert InvalidModule(_msgSender());
        _;
    }

    /**
     * Initializes linked list that handles installed Validator and Executor
     * For Validators:
     *      The Safe Account will call VALIDATOR_STORAGE via DELEGTATECALL.
     *      Due to the storage restrictions of ERC-4337 of the validation phase,
     *      Validators are stored within the Safe's account storage.
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
     * @dev this function Write into the Safe account storage (validator linked) list via
     * ValidatorStorageHelper DELEGATECALL
     * the onInstall call to the module(ERC7579), will be executed from the Safe
     */
    function _installValidator(address validator, bytes memory data) internal virtual {
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
     * @dev this function Write into the Safe account storage (validator linked) list via
     * ValidatorStorageHelper DELEGATECALL
     * the onUninstall call to the module (ERC7579), will be executed from the Safe
     */
    function _uninstallValidator(address validator, bytes memory data) internal {
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
     * THIS IS NOT PART OF THE STANDARD
     * Helper Function to access linked list
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

    function _installExecutor(address executor, bytes memory data) internal {
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
    /**
     * THIS IS NOT PART OF THE STANDARD
     * Helper Function to access linked list
     */

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

    function _installFallbackHandler(address handler, bytes calldata initData) internal virtual {
        ModuleManagerStorage storage $mms = $moduleManager[msg.sender];
        $mms.fallbackHandler = handler;
        // Initialize Fallback Module via Safe
        _execute({
            safe: msg.sender,
            target: handler,
            value: 0,
            callData: abi.encodeCall(IModule.onInstall, (initData))
        });
    }

    function _uninstallFallbackHandler(address handler, bytes calldata initData) internal virtual {
        ModuleManagerStorage storage $mms = $moduleManager[msg.sender];
        $mms.fallbackHandler = address(0);
        // De-Initialize Fallback Module via Safe
        _execute({
            safe: msg.sender,
            target: handler,
            value: 0,
            callData: abi.encodeCall(IModule.onUninstall, (initData))
        });
    }

    function _getFallbackHandler() internal view virtual returns (address fallbackHandler) {
        ModuleManagerStorage storage $mms = $moduleManager[msg.sender];
        return $mms.fallbackHandler;
    }

    function _isFallbackHandlerInstalled(address _handler) internal view virtual returns (bool) {
        return _getFallbackHandler() == _handler;
    }

    function getActiveFallbackHandler() external view virtual returns (address) {
        return _getFallbackHandler();
    }

    // FALLBACK
    fallback() external payable override(Receiver) receiverFallback {
        address handler = _getFallbackHandler();
        if (handler == address(0)) revert();
        /* solhint-disable no-inline-assembly */
        /// @solidity memory-safe-assembly
        // solhint-disable-next-line no-inline-assembly
        assembly {
            // When compiled with the optimizer, the compiler relies on a certain assumptions on how
            // the
            // memory is used, therefore we need to guarantee memory safety (keeping the free memory
            // point 0x40 slot intact,
            // not going beyond the scratch space, etc)
            // Solidity docs: https://docs.soliditylang.org/en/latest/assembly.html#memory-safety
            function allocate(length) -> pos {
                pos := mload(0x40)
                mstore(0x40, add(pos, length))
            }

            let calldataPtr := allocate(calldatasize())
            calldatacopy(calldataPtr, 0, calldatasize())

            // The msg.sender address is shifted to the left by 12 bytes to remove the padding
            // Then the address without padding is stored right after the calldata
            let senderPtr := allocate(20)
            mstore(senderPtr, shl(96, caller()))

            // Add 20 bytes for the address appended add the end
            let success := call(gas(), handler, 0, calldataPtr, add(calldatasize(), 20), 0, 0)

            let returnDataPtr := allocate(returndatasize())
            returndatacopy(returnDataPtr, 0, returndatasize())
            if iszero(success) { revert(returnDataPtr, returndatasize()) }
            return(returnDataPtr, returndatasize())
        }
        /* solhint-enable no-inline-assembly */
    }
}
