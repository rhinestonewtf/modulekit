// SPDX-License-Identifier: MIT
pragma solidity ^0.8.23;

import { SentinelListLib, SENTINEL } from "sentinellist/SentinelList.sol";
import { IExecutor, IValidator, IFallback } from "erc7579/interfaces/IERC7579Module.sol";
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

// keccak256("modulemanager.storage.msa");
bytes32 constant MODULEMANAGER_STORAGE_LOCATION =
    0xf88ce1fdb7fb1cbd3282e49729100fa3f2d6ee9f797961fe4fb1871cea89ea02;

/**
 * @title ModuleManager
 * Contract that implements ERC7579 Module compatibility for Safe accounts
 * @author zeroknots.eth | rhinestone.wtf
 */
abstract contract ModuleManager is AccessControl, Receiver, ExecutionHelper {
    using SentinelListLib for SentinelListLib.SentinelList;
    using ValidatorStorageLib for SentinelListLib.SentinelList;

    error InvalidModule(address module);
    error LinkedListError();
    error CannotRemoveLastValidator();
    error InitializerError();
    error ValidatorStorageHelperError();

    ValidatorStorageHelper internal immutable VALIDATOR_STORAGE;

    mapping(address smartAccount => ModuleManagerStorage) private $moduleManager;

    constructor() {
        VALIDATOR_STORAGE = new ValidatorStorageHelper();
    }

    function _getModuleManagerStorage(address account)
        internal
        view
        returns (ModuleManagerStorage storage ims)
    {
        return $moduleManager[account];
    }

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
        bool success = ISafe(msg.sender).execTransactionFromModule({
            to: address(VALIDATOR_STORAGE),
            value: 0,
            data: abi.encodeCall(ValidatorStorageHelper.initModuleManager, ()),
            operation: 1 // <--- DELEGATECALL
         });
        // this will be false if the list is already initialized
        if (!success) revert InitializerError();

        ModuleManagerStorage storage ims = _getModuleManagerStorage(msg.sender);
        // this will revert if list is already initialized
        ims._executors.init();
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
        bool success = ISafe(msg.sender).execTransactionFromModule({
            to: address(VALIDATOR_STORAGE),
            value: 0,
            data: abi.encodeCall(ValidatorStorageHelper.installValidator, (validator, data)),
            operation: 1 // <-- DELEGATECALL
         });
        if (!success) revert ValidatorStorageHelperError();
    }

    /**
     * Uninstall and de-initialize validator module
     * @dev this function Write into the Safe account storage (validator linked) list via
     * ValidatorStorageHelper DELEGATECALL
     * the onUninstall call to the module (ERC7579), will be executed from the Safe
     */
    function _uninstallValidator(address validator, bytes memory data) internal {
        bool success = ISafe(msg.sender).execTransactionFromModule({
            to: address(VALIDATOR_STORAGE),
            value: 0,
            data: abi.encodeCall(ValidatorStorageHelper.uninstallValidator, (validator, data)),
            operation: 1 // <-- DELEGATECALL
         });
        if (!success) revert ValidatorStorageHelperError();
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
        // calculate slot for linked list
        SentinelListLib.SentinelList storage $validators = $validator()._validators;
        // predict slot for validator in ValidatorStorageHelper linked list
        address link = $validators.getNextEntry(validator);
        // See https://github.com/zeroknots/sentinellist/blob/main/src/SentinelList.sol#L52
        isInstalled = SENTINEL != validator && link != address(0);
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
        if (start != SENTINEL && _isExecutorInstalled(start)) revert LinkedListError();
        if (pageSize == 0) revert LinkedListError();

        array = new address[](pageSize);

        // Populate return array
        uint256 entryCount;
        SentinelListLib.SentinelList storage $validators = $validator()._validators;
        next = $validators.getNextEntry(start);
        while (next != address(0) && next != SENTINEL && entryCount < pageSize) {
            array[entryCount] = next;
            next = $validators.getNextEntry(next);
            entryCount++;
        }

        if (next != SENTINEL) {
            next = array[entryCount - 1];
        }
        // Set correct size of returned array
        // solhint-disable-next-line no-inline-assembly
        assembly ("memory-safe") {
            mstore(array, entryCount)
        }
    }

    /////////////////////////////////////////////////////
    //  Manage Executors
    ////////////////////////////////////////////////////

    function _installExecutor(address executor, bytes memory data) internal {
        SentinelListLib.SentinelList storage _executors =
            _getModuleManagerStorage(msg.sender)._executors;
        _executors.push(executor);
        // TODO:
        IExecutor(executor).onInstall(data);
    }

    function _uninstallExecutor(address executor, bytes calldata data) internal {
        SentinelListLib.SentinelList storage _executors =
            _getModuleManagerStorage(msg.sender)._executors;
        (address prev, bytes memory disableModuleData) = abi.decode(data, (address, bytes));
        _executors.pop(prev, executor);
        // TODO:
        IExecutor(executor).onUninstall(disableModuleData);
    }

    function _isExecutorInstalled(address executor) internal view virtual returns (bool) {
        SentinelListLib.SentinelList storage _executors =
            _getModuleManagerStorage(msg.sender)._executors;
        return _executors.contains(executor);
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
        SentinelListLib.SentinelList storage _executors =
            _getModuleManagerStorage(msg.sender)._executors;
        return _executors.getEntriesPaginated(cursor, size);
    }

    /////////////////////////////////////////////////////
    //  Manage Fallback
    ////////////////////////////////////////////////////

    function _installFallbackHandler(address handler, bytes calldata initData) internal virtual {
        ModuleManagerStorage storage ims = _getModuleManagerStorage(msg.sender);
        ims.fallbackHandler = handler;
        IFallback(handler).onInstall(initData);
    }

    function _uninstallFallbackHandler(address handler, bytes calldata initData) internal virtual {
        ModuleManagerStorage storage ims = _getModuleManagerStorage(msg.sender);
        ims.fallbackHandler = address(0);
        IFallback(handler).onUninstall(initData);
    }

    function _getFallbackHandler() internal view virtual returns (address fallbackHandler) {
        ModuleManagerStorage storage ims = _getModuleManagerStorage(msg.sender);
        return ims.fallbackHandler;
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
