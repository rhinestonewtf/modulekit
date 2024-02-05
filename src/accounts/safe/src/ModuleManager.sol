// SPDX-License-Identifier: MIT
pragma solidity ^0.8.21;

import { SentinelListLib, SENTINEL } from "sentinellist/SentinelList.sol";
import { AccountBase } from "erc7579/core/AccountBase.sol";
import "erc7579/interfaces/IERC7579Module.sol";
import { Receiver } from "erc7579/core/Receiver.sol";
import "./AccessControl.sol";
import "./interfaces/ISafe.sol";

import "forge-std/console2.sol";

struct ValidatorManagerStorage {
    // linked list of validators. List is initialized by initializeAccount()
    SentinelListLib.SentinelList _validators;
}

struct ModuleManagerStorage {
    // linked list of executors. List is initialized by initializeAccount()
    SentinelListLib.SentinelList _executors;
    // single fallback handler for all fallbacks
    // account vendors may implement this differently. This is just a reference implementation
    address fallbackHandler;
    // single hook
    address hook;
}

// keccak256("modulemanager.storage.msa");
bytes32 constant MODULEMANAGER_STORAGE_LOCATION =
    0xf88ce1fdb7fb1cbd3282e49729100fa3f2d6ee9f797961fe4fb1871cea89ea02;

function _getValidatorStorage() pure returns (ValidatorManagerStorage storage ims) {
    bytes32 position = MODULEMANAGER_STORAGE_LOCATION;
    assembly {
        ims.slot := position
    }
}

contract ModuleStorage {
    using SentinelListLib for SentinelListLib.SentinelList;

    function initModuleManager() external virtual {
        ValidatorManagerStorage storage ims = _getValidatorStorage();
        ims._validators.init();
    }
    /////////////////////////////////////////////////////
    //  Manage Validators
    ////////////////////////////////////////////////////

    function installValidator(address validator, bytes calldata data) external virtual {
        SentinelListLib.SentinelList storage _validators = _getValidatorStorage()._validators;
        _validators.push(validator);
        IValidator(validator).onInstall(data);
    }

    function uninstallValidator(address validator, bytes calldata data) external {
        // TODO: check if its the last validator. this might brick the account
        SentinelListLib.SentinelList storage _validators = _getValidatorStorage()._validators;
        (address prev, bytes memory disableModuleData) = abi.decode(data, (address, bytes));
        _validators.pop(prev, validator);
        IValidator(validator).onUninstall(disableModuleData);
    }

    function isValidatorInstalled(address validator) external view virtual returns (bool) {
        SentinelListLib.SentinelList storage _validators = _getValidatorStorage()._validators;
        return _validators.contains(validator);
    }
}

/**
 * @title ModuleManager
 * @author zeroknots.eth | rhinestone.wtf
 */
abstract contract ModuleManager is AccessControl, Receiver {
    using SentinelListLib for SentinelListLib.SentinelList;

    error InvalidModule(address module);
    error CannotRemoveLastValidator();

    ModuleStorage immutable STORAGE_MANAGER;

    mapping(address smartAccount => ModuleManagerStorage) private _moduleManagerStorage;

    constructor() {
        STORAGE_MANAGER = new ModuleStorage();
    }

    function _getModuleManagerStorage(address account)
        internal
        view
        returns (ModuleManagerStorage storage ims)
    {
        return _moduleManagerStorage[account];
    }

    modifier onlyExecutorModule() {
        if (!_isExecutorInstalled(_msgSender())) revert InvalidModule(_msgSender());
        _;
    }

    function _initModuleManager() internal {
        bool success = ISafe(msg.sender).execTransactionFromModule({
            to: address(STORAGE_MANAGER),
            value: 0,
            data: abi.encodeCall(ModuleStorage.initModuleManager, ()),
            operation: 1
        });
        require(success, "ModuleManager: failed to initialize module manager");

        ModuleManagerStorage storage ims = _getModuleManagerStorage(msg.sender);
        ims._executors.init();
    }

    /////////////////////////////////////////////////////
    //  Manage Validators
    ////////////////////////////////////////////////////
    function _installValidator(address validator, bytes calldata data) internal virtual {
        bool success = ISafe(msg.sender).execTransactionFromModule({
            to: address(STORAGE_MANAGER),
            value: 0,
            data: abi.encodeCall(ModuleStorage.installValidator, (validator, data)),
            operation: 1
        });
        require(success, "ModuleManager: failed to install validator");
    }

    function _uninstallValidator(address validator, bytes calldata data) internal {
        bool success = ISafe(msg.sender).execTransactionFromModule({
            to: address(STORAGE_MANAGER),
            value: 0,
            data: abi.encodeCall(ModuleStorage.uninstallValidator, (validator, data)),
            operation: 1
        });
        require(success, "ModuleManager: failed to uninstall validator");
    }

    function getKeyEncodedWithMappingIndex(
        SentinelListLib.SentinelList storage linkedList,
        address key
    )
        private
        pure
        returns (bytes32 hash)
    {
        bytes32 slot;
        assembly {
            slot := linkedList.slot
            mstore(0, key)
            mstore(0x20, slot)
            hash := keccak256(0, 0x40)
        }
    }

    function _isValidatorInstalled(address validator) internal view virtual returns (bool) {
        // calculate slot for linked list
        SentinelListLib.SentinelList storage _validators = _getValidatorStorage()._validators;
        bytes32 slot = getKeyEncodedWithMappingIndex(_validators, validator);
        bytes32 value = bytes32(ISafe(msg.sender).getStorageAt(uint256(slot), 1));
        address link = address(uint160(uint256(value)));
        bool ok = SENTINEL != validator && link != address(0);
        return ok;
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
        if (start != SENTINEL && _isExecutorInstalled(start)) revert();
        if (pageSize == 0) revert();

        array = new address[](pageSize);

        // Populate return array
        uint256 entryCount = 0;
        SentinelListLib.SentinelList storage _validators = _getValidatorStorage()._validators;
        bytes32 slot = getKeyEncodedWithMappingIndex(_validators, start);
        bytes32 value = bytes32(ISafe(msg.sender).getStorageAt(uint256(slot), 1));
        address next = address(uint160(uint256(value)));
        while (next != address(0) && next != SENTINEL && entryCount < pageSize) {
            array[entryCount] = next;
            bytes32 slot = getKeyEncodedWithMappingIndex(_validators, next);
            bytes32 value = bytes32(ISafe(msg.sender).getStorageAt(uint256(slot), 1));
            address next = address(uint160(uint256(value)));
            entryCount++;
        }

        /**
         * Because of the argument validation, we can assume that the loop will always iterate over
         * the valid entry list values
         *       and the `next` variable will either be an enabled entry or a sentinel address
         * (signalling the end).
         *
         *       If we haven't reached the end inside the loop, we need to set the next pointer to
         * the last element of the entry array
         *       because the `next` variable (which is a entry by itself) acting as a pointer to the
         * start of the next page is neither
         *       incSENTINELrent page, nor will it be included in the next one if you pass it as a
         * start.
         */
        if (next != SENTINEL) {
            next = array[entryCount - 1];
        }
        // Set correct size of returned array
        // solhint-disable-next-line no-inline-assembly
        /// @solidity memory-safe-assembly
        assembly {
            mstore(array, entryCount)
        }
    }

    /////////////////////////////////////////////////////
    //  Manage Executors
    ////////////////////////////////////////////////////

    function _installExecutor(address executor, bytes calldata data) internal {
        SentinelListLib.SentinelList storage _executors =
            _getModuleManagerStorage(msg.sender)._executors;
        _executors.push(executor);
        console2.log("install executor", executor);
        IExecutor(executor).onInstall(data);
    }

    function _uninstallExecutor(address executor, bytes calldata data) internal {
        SentinelListLib.SentinelList storage _executors =
            _getModuleManagerStorage(msg.sender)._executors;
        (address prev, bytes memory disableModuleData) = abi.decode(data, (address, bytes));
        _executors.pop(prev, executor);
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
