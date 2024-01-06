// SPDX-License-Identifier: MIT
pragma solidity ^0.8.21;

import { IERC7579Execution } from "../../ModuleKitLib.sol";
import { UserOperation, UserOperationLib } from "../../external/ERC4337.sol";

enum ACCOUNT_EXEC_TYPE {
    EXEC_SINGLE,
    EXEC_BATCH,
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
}
