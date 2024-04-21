// SPDX-License-Identifier: AGPL-3.0-only
pragma solidity ^0.8.25;

import { ERC7579ValidatorBase } from "modulekit/src/Modules.sol";
import { PackedUserOperation } from "modulekit/src/external/ERC4337.sol";
import { SentinelList4337Lib, SENTINEL } from "sentinellist/SentinelList4337.sol";
import { CheckSignatures } from "checknsignatures/CheckNSignatures.sol";
import { IERC7579Account } from "modulekit/src/Accounts.sol";
import { ModeLib, CallType, ModeCode, CALLTYPE_SINGLE } from "erc7579/lib/ModeLib.sol";
import { ExecutionLib } from "erc7579/lib/ExecutionLib.sol";
import { LibSort } from "solady/utils/LibSort.sol";
import { ECDSA } from "solady/utils/ECDSA.sol";

/**
 * @title SocialRecovery
 * @dev Module that allows users to recover their account using a social recovery mechanism
 * @author Rhinestone
 */
contract SocialRecovery is ERC7579ValidatorBase {
    using LibSort for *;
    using SentinelList4337Lib for SentinelList4337Lib.SentinelList;

    /*//////////////////////////////////////////////////////////////////////////
                            CONSTANTS & STORAGE
    //////////////////////////////////////////////////////////////////////////*/

    error UnsopportedOperation();
    error InvalidGuardian(address guardian);
    error ThresholdNotSet();
    error InvalidThreshold();

    // account => guardians
    SentinelList4337Lib.SentinelList guardians;
    // account => threshold
    mapping(address account => uint256) public threshold;

    /*//////////////////////////////////////////////////////////////////////////
                                     CONFIG
    //////////////////////////////////////////////////////////////////////////*/

    /**
     * Initializes the module with the threshold and guardians
     * @dev data is encoded as follows: abi.encode(threshold, guardians)
     *
     * @param data encoded data containing the threshold and guardians
     */
    function onInstall(bytes calldata data) external override {
        // if the module is already initialized, revert
        if (isInitialized(msg.sender)) revert AlreadyInitialized(msg.sender);

        // get the threshold and guardians from the data
        (uint256 _threshold, address[] memory _guardians) = abi.decode(data, (uint256, address[]));

        // sort and uniquify the guardians to make sure a guardian is not reused
        _guardians.sort();
        _guardians.uniquifySorted();

        // make sure the threshold is set
        if (_threshold == 0) {
            revert ThresholdNotSet();
        }

        // make sure the threshold is less than the number of guardians
        uint256 guardiansLength = _guardians.length;
        if (guardiansLength < _threshold) {
            revert InvalidThreshold();
        }

        // set threshold
        threshold[msg.sender] = _threshold;

        // get the account
        address account = msg.sender;

        // initialize the guardian list
        guardians.init(account);

        // add guardians to the list
        for (uint256 i = 0; i < guardiansLength; i++) {
            address _guardian = _guardians[i];
            if (_guardian == address(0)) {
                revert InvalidGuardian(_guardian);
            }
            guardians.push(account, _guardian);
        }
    }

    /**
     * Handles the uninstallation of the module and clears the threshold and guardians
     * @dev the data parameter is not used
     */
    function onUninstall(bytes calldata) external override {
        // cache the account address
        address account = msg.sender;

        // clear the guardians
        guardians.popAll(account);

        // delete the threshold
        threshold[account] = 0;
    }

    /**
     * Checks if the module is initialized
     *
     * @param smartAccount address of the smart account
     * @return true if the module is initialized, false otherwise
     */
    function isInitialized(address smartAccount) public view returns (bool) {
        return threshold[smartAccount] != 0;
    }

    /**
     * Sets the threshold for the account
     * @dev the function will revert if the module is not initialized
     *
     * @param _threshold uint256 threshold to set
     */
    function setThreshold(uint256 _threshold) external {
        // cache the account address
        address account = msg.sender;
        // check if the module is initialized and revert if it is not
        if (!isInitialized(account)) revert NotInitialized(account);

        // make sure the threshold is set
        if (_threshold == 0) {
            revert InvalidThreshold();
        }

        // TODO check if the threshold is less than the number of guardians

        // set the threshold
        threshold[account] = _threshold;
    }

    /**
     * Adds a guardian to the account
     * @dev will revert if the guardian is already added
     *
     * @param guardian address of the guardian to add
     */
    function addGuardian(address guardian) external {
        // cache the account address
        address account = msg.sender;
        // check if the module is initialized and revert if it is not
        if (!isInitialized(account)) revert NotInitialized(account);

        // revert if the guardian is address(0)
        if (guardian == address(0)) {
            revert InvalidGuardian(guardian);
        }

        // add the guardian to the list
        guardians.push(account, guardian);
    }

    /**
     * Removes a guardian from the account
     * @dev will revert if the guardian is not added or the previous guardian is invalid
     *
     * @param prevGuardian address of the previous guardian
     * @param guardian address of the guardian to remove
     */
    function removeGuardian(address prevGuardian, address guardian) external {
        // remove the guardian from the list
        guardians.pop(msg.sender, prevGuardian, guardian);
    }

    /**
     * Gets the guardians for the account
     *
     * @param account address of the account
     *
     * @return guardiansArray array of guardians
     */
    function getGuardians(address account)
        external
        view
        returns (address[] memory guardiansArray)
    {
        // TODO: return length
        // get the guardians from the list
        (guardiansArray,) = guardians.getEntriesPaginated(account, SENTINEL, 10);
    }

    /*//////////////////////////////////////////////////////////////////////////
                                     MODULE LOGIC
    //////////////////////////////////////////////////////////////////////////*/

    /**
     * Validates a user operation
     *
     * @param userOp PackedUserOperation struct containing the UserOperation
     * @param userOpHash bytes32 hash of the UserOperation
     *
     * @return ValidationData the UserOperation validation result
     */
    function validateUserOp(
        PackedUserOperation calldata userOp,
        bytes32 userOpHash
    )
        external
        override
        returns (ValidationData)
    {
        // get the account
        address account = userOp.sender;

        // get the threshold and check that its set
        uint256 _threshold = threshold[account];
        if (_threshold == 0) {
            return VALIDATION_FAILED;
        }

        // recover the signers from the signatures
        address[] memory signers = CheckSignatures.recoverNSignatures(
            ECDSA.toEthSignedMessageHash(userOpHash), userOp.signature, _threshold
        );

        // sort and uniquify the signers to make sure a signer is not reused
        signers.sort();
        signers.uniquifySorted();

        // Check if the signers are guardians
        uint256 validSigners;
        for (uint256 i = 0; i < signers.length; i++) {
            if (guardians.contains(account, signers[i])) {
                validSigners++;
            }
        }

        // check if the execution is allowed
        bool isAllowedExecution;
        bytes4 selector = bytes4(userOp.callData[0:4]);
        if (selector == IERC7579Account.execute.selector) {
            // decode and check the execution
            // only single executions to installed validators are allowed
            isAllowedExecution = _decodeAndCheckExecution(account, userOp.callData);
        }

        // check if the threshold is met and the execution is allowed and return the result
        if (validSigners >= _threshold && isAllowedExecution) {
            return VALIDATION_SUCCESS;
        }
        return VALIDATION_FAILED;
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
                                     INTERNAL
    //////////////////////////////////////////////////////////////////////////*/

    /**
     * Decodes and checks the execution
     *
     * @param account address of the account
     * @param callData bytes calldata containing the call data
     *
     * @return isAllowedExecution true if the execution is allowed, false otherwise
     */
    function _decodeAndCheckExecution(
        address account,
        bytes calldata callData
    )
        internal
        view
        returns (bool isAllowedExecution)
    {
        // get the mode and call type
        ModeCode mode = ModeCode.wrap(bytes32(callData[4:36]));
        CallType calltype = ModeLib.getCallType(mode);

        if (calltype == CALLTYPE_SINGLE) {
            // decode the calldata
            (address to,,) = ExecutionLib.decodeSingle(callData[100:]);

            // check if the module is installed as a validator
            return IERC7579Account(account).isModuleInstalled(TYPE_VALIDATOR, to, "");
        } else {
            return false;
        }
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
        return typeID == TYPE_VALIDATOR;
    }

    /**
     * Returns the name of the module
     *
     * @return name of the module
     */
    function name() external pure virtual returns (string memory) {
        return "SocialRecoveryValidator";
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
