// SPDX-License-Identifier: GPL-3.0
pragma solidity ^0.8.23;

import { ERC7579ValidatorBase } from "modulekit/src/Modules.sol";
import { PackedUserOperation } from "modulekit/src/external/ERC4337.sol";
import { SentinelList4337Lib, SENTINEL } from "sentinellist/SentinelList4337.sol";
import { CheckSignatures } from "checknsignatures/CheckNSignatures.sol";
import { IERC7579Account } from "modulekit/src/Accounts.sol";
import { ModeLib, CallType, ModeCode, CALLTYPE_SINGLE } from "erc7579/lib/ModeLib.sol";
import { ExecutionLib } from "erc7579/lib/ExecutionLib.sol";
import { LibSort } from "solady/utils/LibSort.sol";
import { ECDSA } from "solady/utils/ECDSA.sol";

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

    SentinelList4337Lib.SentinelList guardians;
    mapping(address account => uint256) public threshold;

    /*//////////////////////////////////////////////////////////////////////////
                                     CONFIG
    //////////////////////////////////////////////////////////////////////////*/

    function onInstall(bytes calldata data) external override {
        if (isInitialized(msg.sender)) revert AlreadyInitialized(msg.sender);

        // Get the threshold and guardians from the data
        (uint256 _threshold, address[] memory _guardians) = abi.decode(data, (uint256, address[]));

        // Sort and uniquify the guardians to make sure a guardian is not reused
        _guardians.sort();
        _guardians.uniquifySorted();

        // Make sure the threshold is set
        if (_threshold == 0) {
            revert ThresholdNotSet();
        }

        // Make sure the threshold is less than the number of guardians
        uint256 guardiansLength = _guardians.length;
        if (guardiansLength < _threshold) {
            revert InvalidThreshold();
        }

        // Set threshold
        threshold[msg.sender] = _threshold;

        // Get the account
        address account = msg.sender;

        // Initialize the guardian list
        guardians.init(account);

        // Add guardians to the list
        for (uint256 i = 0; i < guardiansLength; i++) {
            address _guardian = _guardians[i];
            if (_guardian == address(0)) {
                revert InvalidGuardian(_guardian);
            }
            guardians.push(account, _guardian);
        }
    }

    function onUninstall(bytes calldata) external override {
        // TODO
        threshold[msg.sender] = 0;
    }

    function isInitialized(address smartAccount) public view returns (bool) {
        return threshold[smartAccount] != 0;
    }

    function setThreshold(uint256 _threshold) external {
        address account = msg.sender;
        if (!isInitialized(account)) revert NotInitialized(account);

        if (_threshold == 0) {
            revert InvalidThreshold();
        }

        // TODO check if the threshold is less than the number of guardians
        threshold[account] = _threshold;
    }

    function addGuardian(address guardian) external {
        address account = msg.sender;
        if (!isInitialized(account)) revert NotInitialized(account);

        if (guardian == address(0)) {
            revert InvalidGuardian(guardian);
        }

        if (guardians.contains(account, guardian)) {
            revert InvalidGuardian(guardian);
        }

        guardians.push(account, guardian);
    }

    function removeGuardian(address prevGuardian, address guardian) external {
        guardians.pop(msg.sender, prevGuardian, guardian);
    }

    function getGuardians(address account)
        external
        view
        returns (address[] memory guardiansArray)
    {
        // TODO: return length
        (guardiansArray,) = guardians.getEntriesPaginated(account, SENTINEL, 10);
    }

    /*//////////////////////////////////////////////////////////////////////////
                                     MODULE LOGIC
    //////////////////////////////////////////////////////////////////////////*/

    function validateUserOp(
        PackedUserOperation calldata userOp,
        bytes32 userOpHash
    )
        external
        override
        returns (ValidationData)
    {
        // Get the account
        address account = userOp.sender;

        // Get the threshold and check that its set
        uint256 _threshold = threshold[account];
        if (_threshold == 0) {
            return VALIDATION_FAILED;
        }

        // Recover the signers from the signatures
        address[] memory signers = CheckSignatures.recoverNSignatures(
            ECDSA.toEthSignedMessageHash(userOpHash), userOp.signature, _threshold
        );

        // Sort and uniquify the signers to make sure a signer is not reused
        signers.sort();
        signers.uniquifySorted();

        // Check if the signers are guardians
        uint256 validSigners;
        for (uint256 i = 0; i < signers.length; i++) {
            if (guardians.contains(account, signers[i])) {
                validSigners++;
            }
        }

        // Check if the execution is allowed
        bool isAllowedExecution;
        bytes4 selector = bytes4(userOp.callData[0:4]);
        if (selector == IERC7579Account.execute.selector) {
            // Decode and check the execution
            // Only single executions to installed validators are allowed
            isAllowedExecution = _decodeAndCheckExecution(account, userOp.callData);
        }

        // Check if the threshold is met and the execution is allowed and return the result
        if (validSigners >= _threshold && isAllowedExecution) {
            return VALIDATION_SUCCESS;
        }
        return VALIDATION_FAILED;
    }

    function isValidSignatureWithSender(
        address,
        bytes32 hash,
        bytes calldata data
    )
        external
        view
        override
        returns (bytes4)
    {
        // ERC-1271 not supported for recovery
        revert UnsopportedOperation();
    }

    /*//////////////////////////////////////////////////////////////////////////
                                     INTERNAL
    //////////////////////////////////////////////////////////////////////////*/

    function _decodeAndCheckExecution(
        address account,
        bytes calldata callData
    )
        internal
        returns (bool isAllowedExecution)
    {
        // Get the mode and call type
        ModeCode mode = ModeCode.wrap(bytes32(callData[4:36]));
        CallType calltype = ModeLib.getCallType(mode);

        if (calltype == CALLTYPE_SINGLE) {
            // Decode the calldata
            (address to,,) = ExecutionLib.decodeSingle(callData[100:]);

            // Check if the module is installed as a validator
            return IERC7579Account(account).isModuleInstalled(TYPE_VALIDATOR, to, "");
        } else {
            return false;
        }
    }

    /*//////////////////////////////////////////////////////////////////////////
                                     METADATA
    //////////////////////////////////////////////////////////////////////////*/

    function name() external pure returns (string memory) {
        return "SocialRecoveryValidator";
    }

    function version() external pure returns (string memory) {
        return "1.0.0";
    }

    function isModuleType(uint256 typeID) external pure override returns (bool) {
        return typeID == TYPE_VALIDATOR;
    }
}
