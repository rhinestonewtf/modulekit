// SPDX-License-Identifier: MIT
pragma solidity ^0.8.23;

import { IERC7579Account, Execution } from "../../Accounts.sol";
import { PackedUserOperation, UserOperationLib } from "../../external/ERC4337.sol";

enum ACCOUNT_EXEC_TYPE {
    EXEC_SINGLE,
    EXEC_BATCH,
    EXEC_SINGLE_FROM_EXECUTOR,
    EXEC_BATCH_FROM_EXECUTOR,
    UNINSTALL_HOOK,
    INSTALL_VALIDATOR,
    INSTALL_EXECUTOR,
    ERROR
}

library ERC7579ValidatorLib {
    error InvalidExecutionType();

    function decodeExecType(PackedUserOperation calldata _ops)
        internal
        pure
        returns (ACCOUNT_EXEC_TYPE _type)
    {
        return decodeExecType(_ops.callData);
    }

    function decodeExecType(bytes calldata userOpCalldata)
        internal
        pure
        returns (ACCOUNT_EXEC_TYPE _type)
    {
        bytes4 functionSig = bytes4(userOpCalldata[:4]);

        // if (IERC7579Account.execute.selector == functionSig) {
        //     _type = ACCOUNT_EXEC_TYPE.EXEC_SINGLE;
        // } else if (IERC7579Account.executeBatch.selector == functionSig) {
        //     _type = ACCOUNT_EXEC_TYPE.EXEC_BATCH;
        // } else if (IERC7579Account.executeFromExecutor.selector == functionSig) {
        //     _type = ACCOUNT_EXEC_TYPE.EXEC_SINGLE_FROM_EXECUTOR;
        // } else if (IERC7579Account.executeBatchFromExecutor.selector == functionSig) {
        //     _type = ACCOUNT_EXEC_TYPE.EXEC_BATCH_FROM_EXECUTOR;
        // } else if (IERC7579Account.installValidator.selector == functionSig) {
        //     _type = ACCOUNT_EXEC_TYPE.INSTALL_VALIDATOR;
        // } else if (IERC7579Account.installExecutor.selector == functionSig) {
        //     _type = ACCOUNT_EXEC_TYPE.INSTALL_EXECUTOR;
        // } else if (IERC7579Account.uninstallHook.selector == functionSig) {
        //     _type = ACCOUNT_EXEC_TYPE.UNINSTALL_HOOK;
        // } else {
        //     _type = ACCOUNT_EXEC_TYPE.ERROR;
        // }
    }

    function decodeCalldataBatch(bytes calldata userOpCalldata)
        internal
        pure
        returns (Execution[] calldata executionBatch)
    {
        /*
         * Batch Call Calldata Layout
         * Offset (in bytes)    | Length (in bytes) | Contents
         * 0x0                  | 0x4               | bytes4 function selector
        *  0x4                  | -                 |
        abi.encode(Execution[])
         */
        // solhint-disable-next-line no-inline-assembly
        assembly ("memory-safe") {
            let offset := add(userOpCalldata.offset, 0x4)
            let baseOffset := offset

            let dataPointer := add(baseOffset, calldataload(offset))

            // Extract the ERC7579 Executions
            executionBatch.offset := add(dataPointer, 32)
            executionBatch.length := calldataload(dataPointer)
        }
    }

    function decodeCalldataSingle(bytes calldata userOpCalldata)
        internal
        pure
        returns (address destination, uint256 value, bytes calldata callData)
    {
        bytes calldata accountExecCallData = userOpCalldata[4:];
        destination = address(bytes20(accountExecCallData[12:32]));
        value = uint256(bytes32(accountExecCallData[32:64]));
        callData = accountExecCallData[128:userOpCalldata.length - 32];
    }

    function decodeConfig(bytes calldata callData)
        internal
        pure
        returns (address module, bytes calldata _callData)
    {
        module = address(bytes20(callData[12:32]));
        _callData = callData[32:];
    }

    function validateWith(
        PackedUserOperation calldata userOp,
        function(PackedUserOperation calldata,address,uint256,bytes calldata) internal returns(uint48,uint48)
            validationFunction
    )
        internal
        returns (uint48 validUntil, uint48 validAfter)
    {
        ACCOUNT_EXEC_TYPE _type = decodeExecType(userOp);

        address target;
        uint256 value;
        bytes calldata callData;
        if (ACCOUNT_EXEC_TYPE.EXEC_SINGLE == _type) {
            (target, value, callData) = decodeCalldataSingle(userOp.callData);
            (validUntil, validAfter) = validationFunction(userOp, target, value, callData);
        } else if (ACCOUNT_EXEC_TYPE.EXEC_BATCH == _type) {
            Execution[] calldata executionBatch = decodeCalldataBatch(userOp.callData);
            uint256 length = executionBatch.length;
            for (uint256 i; i < length; i++) {
                Execution calldata execution = executionBatch[i];
                (target, value, callData) = (execution.target, execution.value, execution.callData);
                (uint256 _newValidUntil, uint256 _newValidAfter) =
                    validationFunction(userOp, target, value, callData);
                (validUntil, validAfter) =
                    getValidUntil(validUntil, validAfter, _newValidUntil, _newValidAfter);
            }
        } else {
            revert InvalidExecutionType();
        }
    }
}

abstract contract Decoder {
    using ERC7579ValidatorLib for *;
    using UserOperationLib for *;

    function validate(PackedUserOperation calldata userOp) internal {
        ACCOUNT_EXEC_TYPE accountExecType = userOp.callData.decodeExecType();
        address smartAccount = userOp.getSender();

        if (ACCOUNT_EXEC_TYPE.EXEC_SINGLE == accountExecType) {
            (address target, uint256 value, bytes calldata data) =
                ERC7579ValidatorLib.decodeCalldataSingle(userOp.callData);
            onValidate(smartAccount, target, value, data);
        } else if (ACCOUNT_EXEC_TYPE.EXEC_BATCH == accountExecType) {
            Execution[] calldata executionBatch =
                ERC7579ValidatorLib.decodeCalldataBatch(userOp.callData);
            uint256 length;
            for (uint256 i; i < length; i++) {
                Execution calldata execution = executionBatch[i];
                onValidate(smartAccount, execution.target, execution.value, execution.callData);
            }
        } else {
            revert ERC7579ValidatorLib.InvalidExecutionType();
        }
    }

    function onValidate(
        address smartAccount,
        address target,
        uint256 value,
        bytes calldata data
    )
        internal
        virtual
        returns (bytes[] memory);
}

function getValidUntil(
    uint256 maxValidUntil,
    uint256 minValidAfter,
    uint256 newValidUntil,
    uint256 newValidAfter
)
    pure
    returns (uint48 _maxValidUntil, uint48 _minValidAfter)
{
    if (newValidUntil > maxValidUntil) {
        _maxValidUntil = uint48(newValidUntil);
    } else {
        _maxValidUntil = uint48(maxValidUntil);
    }

    if (newValidAfter > minValidAfter) {
        _minValidAfter = uint48(newValidAfter);
    } else {
        _minValidAfter = uint48(minValidAfter);
    }
}
