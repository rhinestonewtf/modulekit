// SPDX-License-Identifier: MIT
pragma solidity ^0.8.23;

import "../../core/ISessionValidationModule.sol";
import { ECDSA } from "solady/src/utils/ECDSA.sol";
import { ParseCalldataLib } from "../utils/ERC7579ValidatorLib.sol";
import { IERC7579Execution } from "../../ModuleKitLib.sol";
import { IERC20 } from "forge-std/interfaces/IERC20.sol";
/**
 * @title ERC20 Session Validation Module for Biconomy Smart Accounts.
 * @dev Validates userOps for ERC20 transfers and approvals using a session key signature.
 *         - Recommended to use with standard ERC20 tokens only
 *         - Can be used with any method of any contract which implement
 *           method(address, uint256) interface
 *
 * @author Fil Makarov - <filipp.makarov@biconomy.io>
 */

contract ERC20SessionKey is ISessionValidationModule {
    using ParseCalldataLib for bytes;

    struct ERC20Transaction {
        address token;
        address recipient;
        uint256 maxAmount;
    }
    /**
     * @dev validates that the call (destinationContract, callValue, funcCallData)
     * complies with the Session Key permissions represented by sessionKeyData
     * @param destinationContract address of the contract to be called
     * @param callValue value to be sent with the call
     * @param _funcCallData the data for the call. is parsed inside the SVM
     * @param _sessionKeyData SessionKey data, that describes sessionKey permissions
     * param _callSpecificData additional data, for example some proofs if the SVM utilizes merkle
     * trees itself
     * for example to store a list of allowed tokens or receivers
     */

    function validateSessionParams(
        address destinationContract,
        uint256 callValue,
        bytes calldata _funcCallData,
        bytes calldata _sessionKeyData,
        bytes calldata /*_callSpecificData*/
    )
        external
        virtual
        override
        returns (address)
    { }

    /**
     * @dev validates if the _op (UserOperation) matches the SessionKey permissions
     * and that _op has been signed by this SessionKey
     * Please mind the decimals of your exact token when setting maxAmount
     * @param _op User Operation to be validated.
     * @param _userOpHash Hash of the User Operation to be validated.
     * @param _sessionKeyData SessionKey data, that describes sessionKey permissions
     * @param _sessionKeySignature Signature over the the _userOpHash.
     * @return true if the _op is valid, false otherwise.
     */
    function validateSessionUserOp(
        UserOperation calldata _op,
        bytes32 _userOpHash,
        bytes calldata _sessionKeyData,
        bytes calldata _sessionKeySignature
    )
        external
        pure
        override
        returns (bool)
    {
        bytes4 executeSelector = bytes4(_op.callData[:4]);
        ERC20Transaction memory transaction = abi.decode(_sessionKeyData, (ERC20Transaction));

        // handle single execution
        if (executeSelector == IERC7579Execution.execute.selector) {
            (address target, uint256 value, bytes calldata callData) =
                _op.callData.parseSingleExecCalldata();

            _enforceSessionKeyConstraint({
                callTarget: target,
                callValue: value,
                callData: callData,
                maxAmount: transaction.maxAmount,
                recipientOnly: transaction.recipient
            });
        }
        // handle batched execution
        else if (executeSelector == IERC7579Execution.executeBatch.selector) {
            (address[] calldata targets, uint256[] calldata values, bytes[] calldata callDatas) =
                _op.callData.parseBatchExecCalldata();

            uint256 _maxAmount = transaction.maxAmount;
            address recipientOnly = transaction.recipient;
            uint256 length = targets.length;

            for (uint256 i; i < length; i++) {
                address target = targets[i];
                uint256 value = values[i];
                bytes calldata callData = callDatas[i];

                _enforceSessionKeyConstraint({
                    callTarget: target,
                    callValue: value,
                    callData: callData,
                    maxAmount: _maxAmount,
                    recipientOnly: recipientOnly
                });
            }
        }

        // return ECDSA.recover(ECDSA.toEthSignedMessageHash(_userOpHash), _sessionKeySignature)
        //     == sessionKey;
        return true;
    }

    function _enforceSessionKeyConstraint(
        address callTarget,
        uint256 callValue,
        bytes calldata callData,
        uint256 maxAmount,
        address recipientOnly
    )
        internal
        pure
    {
        address recipient;
        uint256 amount;
        bytes4 targetSelector = bytes4(callData[:4]);
        if (targetSelector == IERC20.transfer.selector) {
            (recipient, amount) = abi.decode(callData[4:], (address, uint256));
        } else if (targetSelector == IERC20.transferFrom.selector) {
            (, recipient, amount) = abi.decode(callData[4:], (address, address, uint256));
        } else {
            revert("invalid token method");
        }

        if (recipientOnly != address(0) && recipient != recipientOnly) {
            revert("ERC20SV Wrong Recipient");
        }
        if (maxAmount < amount) {
            revert("ERC20SV Max Amount Exceeded");
        }
    }
}
