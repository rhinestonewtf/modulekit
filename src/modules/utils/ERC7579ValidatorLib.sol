// SPDX-License-Identifier: MIT
pragma solidity ^0.8.21;

import { IERC7579Execution } from "../../ModuleKitLib.sol";
import { IERC7579Config, IERC7579ConfigHook } from "../../external/ERC7579.sol";
import { UserOperation, UserOperationLib } from "../../external/ERC4337.sol";

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
    function decodeExecType(UserOperation calldata _ops)
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

        if (IERC7579Execution.execute.selector == functionSig) {
            _type = ACCOUNT_EXEC_TYPE.EXEC_SINGLE;
        } else if (IERC7579Execution.executeBatch.selector == functionSig) {
            _type = ACCOUNT_EXEC_TYPE.EXEC_BATCH;
        } else if (IERC7579Execution.executeFromExecutor.selector == functionSig) {
            _type = ACCOUNT_EXEC_TYPE.EXEC_SINGLE_FROM_EXECUTOR;
        } else if (IERC7579Execution.executeBatchFromExecutor.selector == functionSig) {
            _type = ACCOUNT_EXEC_TYPE.EXEC_BATCH_FROM_EXECUTOR;
        } else if (IERC7579Config.installValidator.selector == functionSig) {
            _type = ACCOUNT_EXEC_TYPE.INSTALL_VALIDATOR;
        } else if (IERC7579Config.installExecutor.selector == functionSig) {
            _type = ACCOUNT_EXEC_TYPE.INSTALL_EXECUTOR;
        } else if (IERC7579ConfigHook.uninstallHook.selector == functionSig) {
            _type = ACCOUNT_EXEC_TYPE.UNINSTALL_HOOK;
        } else {
            _type = ACCOUNT_EXEC_TYPE.ERROR;
        }
    }

    function decodeCalldataBatch(bytes calldata userOpCalldata)
        internal
        pure
        returns (IERC7579Execution.Execution[] calldata executionBatch)
    {
        /*
         * Batch Call Calldata Layout
         * Offset (in bytes)    | Length (in bytes) | Contents
         * 0x0                  | 0x4               | bytes4 function selector
        *  0x4                  | -                 |
        abi.encode(IERC7579Execution.Execution[])
         */
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
        callData = accountExecCallData[128:];
    }

    function decodeConfig(bytes calldata callData)
        internal
        pure
        returns (address module, bytes calldata _callData)
    {
        module = address(bytes20(callData[12:32]));
        _callData = callData[32:];
    }
}

abstract contract Decoder {
    using ERC7579ValidatorLib for *;
    using UserOperationLib for *;

    function validate(UserOperation calldata userOp) internal {
        ACCOUNT_EXEC_TYPE accountExecType = userOp.callData.decodeExecType();
        address smartAccount = userOp.getSender();

        if (ACCOUNT_EXEC_TYPE.EXEC_SINGLE == accountExecType) {
            (address target, uint256 value, bytes calldata data) =
                ERC7579ValidatorLib.decodeCalldataSingle(userOp.callData);
            onValidate(smartAccount, target, value, data);
        } else if (ACCOUNT_EXEC_TYPE.EXEC_BATCH == accountExecType) {
            IERC7579Execution.Execution[] calldata executionBatch =
                ERC7579ValidatorLib.decodeCalldataBatch(userOp.callData);
            uint256 length;
            for (uint256 i; i < length; i++) {
                IERC7579Execution.Execution calldata execution = executionBatch[i];
                onValidate(smartAccount, execution.target, execution.value, execution.callData);
            }
        } else {
            revert();
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
