// SPDX-License-Identifier: AGPL-3.0-only
pragma solidity ^0.8.25;

import { ERC7579ValidatorBase, ERC7579HookBase } from "modulekit/src/Modules.sol";
import { PackedUserOperation } from "modulekit/src/ModuleKit.sol";
import { SignatureCheckerLib } from "solady/utils/SignatureCheckerLib.sol";
import { ECDSA } from "solady/utils/ECDSA.sol";

/**
 * @title DeadmanSwitch
 * @dev Module that allows users to set a nominee that can recover their account if they are
 * inactive for a certain period of time
 * @author Rhinestone
 */
contract DeadmanSwitch is ERC7579HookBase, ERC7579ValidatorBase {
    using SignatureCheckerLib for address;

    /*//////////////////////////////////////////////////////////////////////////
                            CONSTANTS & STORAGE
    //////////////////////////////////////////////////////////////////////////*/

    struct DeadmanSwitchStorage {
        uint48 lastAccess;
        uint48 timeout;
        address nominee;
    }

    // account => config
    mapping(address account => DeadmanSwitchStorage) public config;

    event Recovery(address account, address nominee);

    error UnsopportedOperation();
    error MissingCondition();

    /*//////////////////////////////////////////////////////////////////////////
                                     CONFIG
    //////////////////////////////////////////////////////////////////////////*/

    /**
     * Initializes the module with the nominee and the timeout
     * @dev data is encoded as follows: abi.encodePacked(nominee, timeout)
     *
     * @param data encoded data containing the nominee and the timeout
     */
    function onInstall(bytes calldata data) external {
        // cache the account address
        address account = msg.sender;

        // check if the module is initialized
        if (isInitialized(account)) {
            if (data.length == 0) {
                // if data is empty, return
                // this is to allow for the module to be installed as a second module type
                return;
            } else {
                // if data is not empty, revert
                revert AlreadyInitialized(account);
            }
        }

        // decode the data to get the nominee and the timeout
        address nominee = address(uint160(bytes20(data[0:20])));
        uint48 timeout = uint48(bytes6(data[20:26]));

        // set the config
        config[account] = DeadmanSwitchStorage({
            lastAccess: uint48(block.timestamp),
            timeout: timeout,
            nominee: nominee
        });
    }

    /**
     * Handles the uninstallation of the module and clears the config
     * @dev the data parameter is not used
     */
    function onUninstall(bytes calldata) external override {
        // delete the config
        delete config[msg.sender];
        // clear the trusted forwarder
        clearTrustedForwarder();
    }

    /**
     * Checks if the module is initialized
     *
     * @param smartAccount address of the smart account
     * @return true if the module is initialized, false otherwise
     */
    function isInitialized(address smartAccount) public view returns (bool) {
        return config[smartAccount].nominee != address(0);
    }

    /*//////////////////////////////////////////////////////////////////////////
                                     MODULE LOGIC
    //////////////////////////////////////////////////////////////////////////*/

    /**
     * Called on precheck before every execution
     * @dev this function updates the last access time for the account
     */
    function _preCheck(
        address account,
        address,
        uint256,
        bytes calldata
    )
        internal
        override
        returns (bytes memory hookData)
    {
        // if the module is not initialized, return and dont update the last access time
        if (!isInitialized(account)) return "";

        // update the last access time
        DeadmanSwitchStorage storage _config = config[account];
        _config.lastAccess = uint48(block.timestamp);
    }

    /**
     * Called on postcheck after every execution
     * @dev this function is unused
     */
    function _postCheck(address, bytes calldata) internal override { }

    /**
     * Validates the userOperation during the validation phase
     * @dev this function checks if the signature is valid and if the timeout has passed
     *
     * @param userOp PackedUserOperation struct containing the userOperation
     * @param userOpHash hash of the userOperation
     *
     * @return ValidationData userOperation validation data
     */
    function validateUserOp(
        PackedUserOperation calldata userOp,
        bytes32 userOpHash
    )
        external
        view
        override
        returns (ValidationData)
    {
        // get the config for the sender
        DeadmanSwitchStorage memory _config = config[userOp.sender];
        // get the nominee
        address nominee = _config.nominee;
        // if nominee is not set, return validation failed
        if (nominee == address(0)) return VALIDATION_FAILED;

        // check the signature of the nominee
        bool sigValid = nominee.isValidSignatureNow({
            hash: ECDSA.toEthSignedMessageHash(userOpHash),
            signature: userOp.signature
        });

        // return validation data
        // if signature is invalid, validation fails
        // if the timeout has not passed, validAfter will be when the timeout will pass
        return _packValidationData({
            sigFailed: !sigValid,
            validAfter: _config.lastAccess + _config.timeout,
            validUntil: type(uint48).max
        });
    }

    /**
     * Validates an ERC-1271 signature with the sender
     * @dev ERC-1271 not supported for DeadmanSwitch
     */
    function isValidSignatureWithSender(
        address,
        bytes32,
        bytes calldata
    )
        external
        pure
        override
        returns (bytes4)
    {
        revert UnsopportedOperation();
    }

    /*//////////////////////////////////////////////////////////////////////////
                                     METADATA
    //////////////////////////////////////////////////////////////////////////*/

    /**
     * Returns the type of the module
     *
     * @param typeID type of the module
     *
     * @return true if the type is a module type, false otherwise
     */
    function isModuleType(uint256 typeID) external pure override returns (bool) {
        return typeID == TYPE_HOOK || typeID == TYPE_VALIDATOR;
    }

    /**
     * Returns the name of the module
     *
     * @return name of the module
     */
    function name() external pure virtual returns (string memory) {
        return "DeadmanSwitch";
    }

    /**
     * Returns the version of the module
     *
     * @return version of the module
     */
    function version() external pure virtual returns (string memory) {
        return "1.0.0";
    }
}
