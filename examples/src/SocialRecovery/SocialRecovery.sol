// SPDX-License-Identifier: GPL-3.0
pragma solidity ^0.8.23;

import { ERC7579ValidatorBase } from "modulekit/src/Modules.sol";
import { PackedUserOperation } from "modulekit/src/external/ERC4337.sol";
import { SentinelListLib } from "sentinellist/SentinelList.sol";
import { CheckSignatures } from "checknsignatures/CheckNSignatures.sol";
import { IERC7579Account } from "modulekit/src/Accounts.sol";
import { ModeLib, CallType, ModeCode, CALLTYPE_SINGLE } from "erc7579/lib/ModeLib.sol";
import { ExecutionLib } from "erc7579/lib/ExecutionLib.sol";
import { LibSort } from "solady/utils/LibSort.sol";

contract SocialRecovery is ERC7579ValidatorBase {
    using LibSort for *;
    using SentinelListLib for SentinelListLib.SentinelList;

    /*//////////////////////////////////////////////////////////////////////////
                            CONSTANTS & STORAGE
    //////////////////////////////////////////////////////////////////////////*/

    error UnsopportedOperation();
    error InvalidGuardian(address guardian);
    error ThresholdNotSet();
    error InvalidThreshold();

    SentinelListLib.SentinelList guardians;
    mapping(address account => uint256) thresholds;

    /*//////////////////////////////////////////////////////////////////////////
                                     CONFIG
    //////////////////////////////////////////////////////////////////////////*/

    function onInstall(bytes calldata data) external override {
        // Get the threshold and guardians from the data
        (uint256 threshold, address[] memory _guardians) = abi.decode(data, (uint256, address[]));

        // Sort and uniquify the guardians to make sure a guardian is not reused
        _guardians.sort();
        _guardians.uniquifySorted();

        // Make sure the threshold is set
        if (threshold == 0) {
            revert ThresholdNotSet();
        }

        uint256 guardiansLength = _guardians.length;
        if (guardiansLength < threshold) {
            revert InvalidThreshold();
        }

        // Set threshold
        thresholds[msg.sender] = threshold;

        // Initialize the guardian list
        guardians.init();

        // Add guardians to the list
        for (uint256 i = 0; i < guardiansLength; i++) {
            address _guardian = _guardians[i];
            if (_guardian == address(0)) {
                revert InvalidGuardian(_guardian);
            }
            guardians.push(_guardian);
        }
    }

    function onUninstall(bytes calldata) external override {
        // todo
    }

    function isInitialized(address smartAccount) external view returns (bool) {
        return thresholds[smartAccount] != 0;
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
        // Get the threshold and check that its set
        uint256 threshold = thresholds[msg.sender];
        if (threshold == 0) {
            return VALIDATION_FAILED;
        }

        // Recover the signers from the signatures
        address[] memory signers =
            CheckSignatures.recoverNSignatures(userOpHash, userOp.signature, threshold);

        // Sort and uniquify the signers to make sure a signer is not reused
        signers.sort();
        signers.uniquifySorted();

        // Check if the signers are guardians
        SentinelListLib.SentinelList storage _guardians = guardians;
        uint256 validSigners;
        for (uint256 i = 0; i < signers.length; i++) {
            if (_guardians.contains(signers[i])) {
                validSigners++;
            }
        }

        // Check if the execution is allowed
        bool isAllowedExecution;
        bytes4 selector = bytes4(userOp.callData[0:4]);
        if (selector == IERC7579Account.execute.selector) {
            // Decode and check the execution
            // Only single executions to installed validators are allowed
            isAllowedExecution = _decodeAndCheckExecution(userOp.callData);
        }

        // Check if the threshold is met and the execution is allowed and return the result
        if (validSigners >= threshold && isAllowedExecution) {
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

    function _decodeAndCheckExecution(bytes calldata callData)
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
            return IERC7579Account(msg.sender).isModuleInstalled(TYPE_VALIDATOR, to, "");
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
        return "0.0.1";
    }

    function isModuleType(uint256 typeID) external pure override returns (bool) {
        return typeID == TYPE_VALIDATOR;
    }
}
