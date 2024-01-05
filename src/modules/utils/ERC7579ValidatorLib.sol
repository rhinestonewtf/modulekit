// SPDX-License-Identifier: MIT
pragma solidity ^0.8.21;

import "forge-std/console2.sol";

import { IERC7579Execution } from "../../ModuleKitLib.sol";

library ParseCalldataLib {
    function parseBatchExecCalldata(bytes calldata _userOpCalldata)
        internal
        pure
        returns (IERC7579Execution.Execution[] calldata executionBatch)
    {
        /*
         * Batch Call Calldata Layout
         * Offset (in bytes)    | Length (in bytes) | Contents
         * 0x0                  | 0x4               | bytes4 function selector
        *  0x4                  | -                 | abi.encode(IERC7579Execution.Execution[])
         */
        assembly ("memory-safe") {
            let offset := add(_userOpCalldata.offset, 0x4)
            let baseOffset := offset

            let dataPointer := add(baseOffset, calldataload(offset))

            // Extract the ERC7579 Executions
            executionBatch.offset := add(dataPointer, 32)
            executionBatch.length := calldataload(dataPointer)
        }

        console2.log("exec batch length", executionBatch.length);
    }

    function parseSingleExecCalldata(bytes calldata _userOpCalldata)
        internal
        pure
        returns (address destination, uint256 value, bytes calldata callData)
    {
        bytes calldata accountExecCallData = _userOpCalldata[4:];
        destination = address(bytes20(accountExecCallData[12:32]));
        value = uint256(bytes32(accountExecCallData[32:64]));
        callData = accountExecCallData[128:];
    }
}
