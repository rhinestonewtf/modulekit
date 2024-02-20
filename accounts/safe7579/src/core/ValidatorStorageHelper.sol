// SPDX-License-Identifier: MIT
pragma solidity ^0.8.23;

import { SentinelListLib, SENTINEL } from "sentinellist/SentinelList.sol";
import { IValidator } from "erc7579/interfaces/IERC7579Module.sol";
import { ISafe } from "../interfaces/ISafe.sol";

struct ValidatorStorage {
    // linked list of validators. List is initialized by initializeAccount()
    SentinelListLib.SentinelList _validators;
}

// keccak256("modulemanager.storage.msa");
// TODO: change this
bytes32 constant VALIDATORMANAGER_STORAGE_LOCATION =
    0xf88ce1fdb7fb1cbd3282e49729100fa3f2d6ee9f797961fe4fb1871cea89ea02;

function $validator() pure returns (ValidatorStorage storage $validators) {
    bytes32 position = VALIDATORMANAGER_STORAGE_LOCATION;
    // solhint-disable-next-line no-inline-assembly
    assembly {
        $validators.slot := position
    }
}

/**
 * @title ValidatorStorage - Storage for ModuleManager
 * Due to the storage restrictions of ERC4337,
 *  storing a linked list outside of the ERC-4337 UserOp.sender account is not possible
 * In order to make storage of the linked list possible, the Safe account with DELEGATECALL
 * the functions within ModuleStorage and thus write into its own storage.
 * ModuleStorage is using MODULEMANAGER_STORAGE_LOCATION to store data, to ensure no storage slot
 * conflicts
 */
contract ValidatorStorageHelper {
    using SentinelListLib for SentinelListLib.SentinelList;

    error Unauthorized();

    // Ensures that the functions are only interacted with via delegatecall
    modifier onlyDelegateCall() {
        // if (msg.sender != address(this)) revert Unauthorized();
        _;
    }

    /**
     * Initializes the module manager storage
     * Due to the nature of SentinelListLib,
     *  a linked list first has to be initialized before it can be used
     */
    function initModuleManager() external virtual onlyDelegateCall {
        ValidatorStorage storage $v = $validator();
        $v._validators.init();
    }
    /////////////////////////////////////////////////////
    //  Manage Validators
    ////////////////////////////////////////////////////

    /**
     * Installs Validator to ModuleStorage
     * @param validator address of ERC7579 Validator module
     * @param data init data that will be passed to Validator Module
     */
    function installValidator(
        address validator,
        bytes calldata data
    )
        external
        virtual
        onlyDelegateCall
    {
        SentinelListLib.SentinelList storage $validators = $validator()._validators;
        $validators.push(validator);
        IValidator(validator).onInstall(data);
    }

    /**
     * Uninstalls Validator module from ModuleStorage
     * @param validator address of ERC7579 Validator Module
     * @param data deinitialization data that will be passed to the validator module
     */
    function uninstallValidator(address validator, bytes calldata data) external onlyDelegateCall {
        SentinelListLib.SentinelList storage _validators = $validator()._validators;
        (address prev, bytes memory disableModuleData) = abi.decode(data, (address, bytes));
        _validators.pop(prev, validator);
        IValidator(validator).onUninstall(disableModuleData);
    }
}

library ValidatorStorageLib {
    using ValidatorStorageLib for SentinelListLib.SentinelList;

    function getSlot(
        SentinelListLib.SentinelList storage linkedList,
        address key
    )
        internal
        pure
        returns (bytes32 hash)
    {
        bytes32 slot;
        // solhint-disable-next-line no-inline-assembly
        assembly {
            slot := linkedList.slot
            mstore(0, key)
            mstore(0x20, slot)
            hash := keccak256(0, 0x40)
        }
    }

    function getNextEntry(
        SentinelListLib.SentinelList storage $validators,
        address key
    )
        internal
        view
        returns (address next)
    {
        bytes32 slot = $validators.getSlot(key);
        bytes32 value = bytes32(ISafe(msg.sender).getStorageAt(uint256(slot), 1));
        next = address(uint160(uint256(value)));
    }
}
