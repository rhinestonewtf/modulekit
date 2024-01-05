// SPDX-License-Identifier: MIT
pragma solidity ^0.8.21;

import { IERC7579Execution } from "../../ModuleKitLib.sol";
import { UserOperation } from "../../ModuleKit.sol";

library ParseCalldataLib {
    function parseBatchExecCalldata(bytes calldata _userOpCalldata)
        internal
        pure
        returns (
            address[] calldata destinations,
            uint256[] calldata callValues,
            bytes[] calldata operationCalldatas
        )
    {
        /*
         * Batch Call Calldata Layout
         * Offset (in bytes)    | Length (in bytes) | Contents
         * 0x0                  | 0x4               | bytes4 function selector
        * 0x4                  | -                 | abi.encode(destinations, callValues,
        operationCalldatas)
         */
        assembly ("memory-safe") {
            let offset := add(_userOpCalldata.offset, 0x4)
            let baseOffset := offset

            let dataPointer := add(baseOffset, calldataload(offset))

            // Extract the destinations
            destinations.offset := add(dataPointer, 0x20)
            destinations.length := calldataload(dataPointer)
            offset := add(offset, 0x20)

            // Extract the call values
            dataPointer := add(baseOffset, calldataload(offset))
            callValues.offset := add(dataPointer, 0x20)
            callValues.length := calldataload(dataPointer)
            offset := add(offset, 0x20)

            // Extract the operation calldatas
            dataPointer := add(baseOffset, calldataload(offset))
            operationCalldatas.offset := add(dataPointer, 0x20)
            operationCalldatas.length := calldataload(dataPointer)
        }
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
